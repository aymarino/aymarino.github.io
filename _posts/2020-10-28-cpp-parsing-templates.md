---
layout: post
title: A C++ Parsing Brain Teaser
categories: [cpp]
---

C++ is already notorious for the insane context-dependence of its grammar, which is, yes,
[Turing-complete](http://port70.net/~nsz/c/c%2B%2B/turing.pdf), and yes, even
[undecidable](http://yosefk.com/c++fqa/web-vs-c++.html#misfeature-2). This is all
[old](https://stackoverflow.com/questions/794015/what-do-people-mean-when-they-say-c-has-undecidable-grammar)
and [talked](https://blog.reverberate.org/2013/08/parsing-c-is-literally-undecidable.html) about to
[death](https://medium.com/@mujjingun_23509/full-proof-that-c-grammar-is-undecidable-34e22dd8b664).

And yet, consider this otherworldly C++:

```cpp
template <int>
struct X {
    int a[2];
    static constexpr int Foo = 0;
    friend void operator >(int, const X&);
};

template <int>
struct Y {
    int a;
};

template <int>
struct C;

template <>
struct C<sizeof(X<0>)> {
    static constexpr int Data = 0;
};

template <>
struct C<sizeof(Y<0>)> {
    template <int>
    struct Data {
        static constexpr int Foo = 0;
    };
};

extern Y<0> yy;

int main() {
    X<C<sizeof(yy)>::Data<0>::Foo> yy;
    X<C<sizeof(yy)>::Data<0>::Foo> yy; // Is this well-formed? What does it do?
}
```

This snippet is a favorite of mine. It reads like a mystery-horror-thriller, where
seemingly-irrelevant details fall into place right at the big reveal. It's as if M. Night Shyamalan
directed a piece of code. At first, it looks like your run-of-the-mill over-engineered C++
("`friend operator >` what?!!"). Then, the two lines in `main` comprise the puzzle: they are
token-for-token identical to one another, yet appear to be declarations. How can that be legal?

This came up when I worked on the MSVC compiler team, as part of an old Boost test suite. I believe
the entire point of the test was specifically to test compilers' support for parsing template
identifiers. We had been working on the recursive-descent parser at the time and likely broke this
functionality in the process, which brought it to our attention.

## Solution

The key C++ concepts at play here are explicit template specialization, expression-vs-declaration
parsing, and, simply enough, name shadowing.

The focus will be on these two statements:

```cpp
X<C<sizeof(yy)>::Data<0>::Foo> yy; // S1
X<C<sizeof(yy)>::Data<0>::Foo> yy; // S2
```

### Statement `S1`

Let's explode this statement into its components:

```cpp
X
<
  C
  <
    sizeof(yy)
  >
  ::
  Data
  <
    0
  >
  ::
  Foo
>

yy
```

C++ parses left-to-right (top-to-bottom, if thinking about this as an AST). It makes local decisions
about the meaning of tokens based on the proceeding tokens and name lookup, not requiring arbitrary
lookahead (though possibly requiring arbitrary template instantiations).

Upon seeing `X<`, we need to determine whether the `<` starts a template, or an expression. So we
look up `X`, and find a template name: interpret `<` as beginning a template argument list. The
entire expression `C<sizeof(yy)>::Data<0>::Foo` is the single template argument.

Similarly, we proceed for `C`: name lookup finds a template name, so `<` starts another template
argument list, with single argument `sizeof(yy)`.

In `sizeof(yy)`, `yy` resolves to the global variable `yy` (names do not come into scope until after
their complete declaration \[[^1]\]). So, `sizeof(yy) == sizeof(Y<0>)`.

`C<sizeof(yy)>` will be an instantiation of the second explicit specialization of `C` (referring to
the complete snippet). So, lookup of `C<sizeof(yy)>::Data` finds the nested class defined in that
instantiation of `C`, which is a template so the following `<` begins a template argument list.
`C<sizeof(yy)>::Data<0>::Foo` is now straightforward: it's an integer static data member with
compile-time value `0`.

Returning up the "stack" to the instantiation of `X`, we have resolved it to the type `X<0>`, for a
full statement of `X<0> yy;`--clearly, a declaration of an automatic variable named `yy`. Note that
this `yy` shadows the global variable just above it--bad practice, maybe, but legal in C++.

### Statement `S2`

Moving on to the next statement, it is identical to the one above. But in a twist, it parses
differently.

Once again, we start the same: `X<` will start a template argument list for the class template `X`,
as will `C<`. This is the first key: in `sizeof(yy)`, `yy` will now refer to the local `yy`, of type
`X<0>` (rather than `Y<0>` as it is in the line above). So the instantiation selected for `C` is
`C<sizeof(X<0>)>`.

Now, we lookup `::Data` in the selected instantiation of `C`, which is an integer static data
member, with value `0`. Let's collapse `C<sizeof(yy)>::Data` -> `0` and look at the whole statement
again: `X<0<0>::Foo> yy`

Or, expanded:

```cpp
X
<
  0
  <
  0
>
::
Foo
>
yy
```

Now, the `<` token which previously started a template argument list is a less-than token in a
binary expression `0 < 0 == false`. The next `>` (which above closed the template argument list of
`Data`) now closes the template argument list of `X`.

Since `false` converts to integer `0`, we now have `X<0>::Foo > yy`.

`Foo` is an integer static data member of `X<0>`, with value `0`: `0 > yy`.

`X<0>` (the type of `yy`) has defined a global `operator >` which takes `int` on the left-hand-side,
and returns void. Hence, this statement is a function call expression to that operator.

Part of the beauty is that, since the `operator >` returns `void` (as opposed to something typical,
say `bool`), there's not even the possibility of a compiler warning for the discarded return value.

<hr/>

[^1]: But before their optional initializer.
