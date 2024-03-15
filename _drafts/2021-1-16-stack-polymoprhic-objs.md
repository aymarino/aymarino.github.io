---
layout: post
title: "Stack-allocated polymorphic objects in C++"
---

Performance-sensitive systems often need to avoid excessively using heap-allocation (which require
system calls and taking global locks and whatnot). Runtime polymorphism (i.e. `virtual` functions
and bases) is one feature of C++ that effectively requires the use of heap-allocated memory[^1].

Various patterns lead us to reach for heap-allocation when using dynamic polymorphic types.
Functions that can return different concrete derived types need to have a common return type, so a
base class pointer is used. For a factory function, this prevents us from stack-allocating since we
cannot point to a local value (e.g. `Base* create(Kind)`). We may need to store different concrete
instances in the same container--once again, base class pointers are the natural type to store (e.g.
`std::vector<Base*>`), and therefore the objects must be allocated in a separate lifetime than the
container's. There are other considerations, like that different derived classes need not be the
same size as the base class.

<!-- What properties does dynamic dispatch require which leads us to typically use heap memory?
The storage scheme must allow:

1. passing and storing different concrete types in homogenous containers and interfaces (e.g. `std::vector<Base*>` or `foo(Base*)`).
2. concrete types with different sizes (`sizeof(Derived1)` need not equal `sizeof(Derived2)`).

Together these requirements require us to allocate the right concrete object size (requirement 2), then take a `Base` pointer to it which the programmer manages the same way for any concrete derived type (requirement 1).
When we need a stack instance of a polymorphic type that plays with generic interfaces and containers, the natural thing to do is heap-allocate it[^2]. -->

## Other languages

E.g. Comparison to Rust

[^1]:
    This is the primary motivation for Lovecraftian patterns like
    [CRTP](https://en.wikipedia.org/wiki/Curiously_recurring_template_pattern) when dynamic dispatch
    is not needed.

[^2]:
    Emphasis here on the _containers_ aspect. There are other optimizations one can take if we just
    need a `Base*`, like stack-allocating the concrete object and taking its address.
