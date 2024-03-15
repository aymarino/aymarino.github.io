---
layout: post
title: "Advent of Code 2023 Day 12: Easy function memoization in Rust"
categories: [aoc-2023, rust]
---

This is part of a series on little things I learned while doing the problems from
[Advent of Code 2023](https://adventofcode.com/2023). It won't fully explain any problems or
solutions from AOC. You can find all my solutions on
[Github](https://github.com/aymarino/advent-of-code-2023).

Advent of Code [day 12](https://adventofcode.com/2023/day/12) is a problem that can be solved
recursively, but the number of calls grows exponentially with the input size. Since those calls
involve a lot of repeated work, we can achieve a huge speedup by caching results for particular
input states --- indeed, the problem likely isn't tractable for the inputs they give without some
sort of caching.

Python has a nice [decorator](https://docs.python.org/3/library/functools.html#functools.cache)
`@functools.cache`, but writing my solutions in Rust I originally opted for the classic "inner
function" pattern to achieve the same (using fibonacci as a simple example):

```rust
fn fibonacci(n: u64, memo: &mut HashMap<u64, u64>) -> u64 {
    fn inner(n: u64, memo: &mut HashMap<u64, u64>) -> u64 {
        if n == 0 || n == 1 {
            n
        } else {
            fibonacci(n - 1, memo) + fibonacci(n - 2, memo)
        }
    }
    if let Some(result) = memo.get(&n) {
        *result
    } else {
        let result = inner(n, memo);
        memo.insert(n, result);
        result
    }
}

fn main() {
    println!("{}", fibonacci(80, &mut HashMap::new()));
}
```

There are other variations on this you could opt for, such as making the cache a global or
function-scope static singleton so that the caller doesn't have to provide it, but this is about as
simple as you can get, and it's not very ergonomic for either writing the function logic or for the
caller[^1].

I learned though, of the [cached](https://docs.rs/cached/latest/cached/) crate, which provides a
drop-in macro like Python's decorator to add caching behavior to expensive pure functions:

```rust
use cached::proc_macro::cached;

#[cached]
fn fibonacci(n: u64) -> u64 {
    if n == 0 || n == 1 {
        n
    } else {
        fibonacci(n - 1) + fibonacci(n - 2)
    }
}

fn main() {
    println!("{}", fibonacci(80));
}
```

Semantically, it'll set up a global mutex-guarded map to cache results, without the cruft of having
to do this yourself. It's fairly customizable -- for the AoC problem, for example, I needed to
customize the key for the function input and it allowed that
[pretty easily](https://github.com/aymarino/advent-of-code-2023/blob/main/src/day12.rs#L16-L17).

<hr/>

[^1]:
    Needing to carry the mutable ref to the `memo` object through the (potentially
    [much more complicated](https://github.com/aymarino/advent-of-code-2023/blob/main/src/day12.rs#L32-L52))
    function logic is particularly troublesome.
