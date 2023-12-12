---
layout: post
title: Branchless `max()`
categories: [cpp]
---

Recently a coworker told me about a question he'd gotten in an interview: write `max()` without
branches.

Branchless programming strikes me as a similar "game" to code golf (writing a program in as few
lines or characters as possible), though occasionally it has real utility. For example, if the
branchless program is a non-obvious-enough transformation, it could
[out-perform](https://dev.to/jacqueslucke/a-c-micro-optimization-exercise-3p65) a "branchy"
implementation in a heavily-pipelined CPU.

### "Branchy" `max`

Let's start with the trivial, "branchy" implementation:

```cpp
int branchy_max(int a, int b) {
    return a > b ? a : b;
}
```

Nothing to it, right?

### An approximate branchless implementation

For simple enough programs that have conditional computations, the general strategy of branchless
programming is to create a value that encodes the condition as either a 1 or 0, then multiply it
with the input values in a way that computes the result in both cases of the condition.

The condition in this case is `a > b`. Notice that transforming this into `a - b` gives a positive
value if the condition is true and negative otherwise. We can detect which it is by masking the sign
bit of the difference, which is only set if it's negative:

```cpp
auto difference = a - b;
constexpr auto sign_bit = sizeof(decltype(difference)) * 8 - 1;
int b_greater_than_a = (difference >> sign_bit) & 1;
```

Now we need to find an expression that evaluates to `b` if the difference is negative, and `a` if it
is positive.

Adding the conditional difference to `b` achieves this: `a - (a - b) * b_greater_than_a`. If the
difference is negative, we have `a - (a - b) * 1 == b`, and `a - (a - b) * 0 == a` otherwise.

Putting it together:

```cpp
int branchless_max(int a, int b) {
    const auto difference = a - b;
    constexpr auto sign_bit = sizeof(decltype(difference)) * 8 - 1;
    const int b_greater_than_a = (difference >> sign_bit) & 1;
    return a - difference * b_greater_than_a;
}
```

### Accounting for overflow & underflow

For the purpose of a thought exercise this is good. But it's not quite correct across its input
range: `a - b` could underflow, say if `a` is negative and `b` is a large positive number, or
conversely overflow if `b` is a large negative and `a` is positive.

We can detect an underflow if `a` is negative and `b` is positive, but `difference` is positive;
similarly, overflow happens iff `a` is positive and `b` is negative, but `difference` is negative.
Then, we can adjust the result to force it to the true max input:

```cpp
int branchless_max_overunder(int a, int b) {
    // Helper to avoid excessive use of '>>'
    constexpr auto is_negative = [](auto v) {
        constexpr auto sign_bit = sizeof(decltype(v)) * 8 - 1;
        return (v >> sign_bit) & 1;
    };

    auto difference = a - b;
    int b_greater_than_a = is_negative(difference);

    int underflow = is_negative(a) & !is_negative(b) & !b_greater_than_a;
    int overflow = (!is_negative(a)) & is_negative(b) & b_greater_than_a;
    int underflow_or_overflow = underflow | overflow;

    return (a - difference * b_greater_than_a) * !underflow_or_overflow
           + underflow * b + overflow * a;
}
```

### Genericizing & C++20

As a bonus, we can now generalize the parameters and return type for any signed integral type using
C++20 concepts:

```cpp
#include <concepts>

template <std::signed_integral T, std::signed_integral U>
auto generic_branchless_max(T a, U b) {
    // Helper to avoid excessive use of '>>'
    constexpr auto is_negative = [](auto v) {
        constexpr auto sign_bit = sizeof(decltype(v)) * 8 - 1;
        return (v >> sign_bit) & 1;
    };

    auto difference = a - b;
    int b_greater_than_a = is_negative(difference);

    int underflow = is_negative(a) & !is_negative(b) & !b_greater_than_a;
    int overflow = (!is_negative(a)) & is_negative(b) & b_greater_than_a;
    int underflow_or_overflow = underflow | overflow;

    return (a - difference * b_greater_than_a) * !underflow_or_overflow
           + underflow * b + overflow * a;
}
```

The `auto` return type is useful here because it allows un-bundling the two arguments into separate
template parameter types, so that things like `generic_branchless_max(2LL, 2)` work, with the return
type doing the necessary promotion and sign-extension.

### Results

I absolutely do not recommend writing code like this. It's convoluted and will almost certainly
generate worse optimized code. This was our original branchless implementation under LLVM's `-O3`:

```nasm
branchless_max(int, int):                   # @branchless_max(int, int)
        mov     eax, edi
        mov     ecx, edi
        sub     ecx, esi
        mov     edx, ecx
        sar     edx, 31
        and     edx, ecx
        sub     eax, edx
        ret
```

The code generated for taking into account overflow and underflow is much worse. This is the
instantiation on two 64-bit integer types, but the assembly is identical (up to bit shifts) with
other sized parameters:

```nasm
auto generic_branchless_max<long long, long long>(long long, long long):  # @auto generic_branchless_max<long long, long long>(long long, long long)
        mov     rax, rdi
        sub     rax, rsi
        mov     r8, rsi
        not     r8
        and     r8, rdi
        mov     rdx, rdi
        not     rdx
        and     rdx, rsi
        and     rdx, rax
        mov     r9, rax
        sar     r9, 63
        and     r9, rax
        not     rax
        and     rax, r8
        mov     rcx, rax
        or      rcx, rdx
        sar     rdx, 63
        and     rdx, rdi
        sub     rdi, r9
        sar     rcx, 63
        not     rcx
        and     rcx, rdi
        sar     rax, 63
        and     rax, rsi
        add     rax, rdx
        add     rax, rcx
        ret
```

And here is our original, branchy implementation (`a > b ? a : b`):

```nasm
max(int, int):                               # @max(int, int)
        mov     eax, esi
        cmp     edi, esi
        cmovg   eax, edi
        ret
```

Note that the assembly doesn't actually take any branches: `cmov` (as a generic x86 instruction) is
a conditional move by itself.
