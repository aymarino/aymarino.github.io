---
layout: post
title: "Advent of Code 2023 Day 6: Next higher integer"
categories: [aoc-2023, rust]
---

This is part of a series on little things I learned while doing the problems from
[Advent of Code 2023](https://adventofcode.com/2023). It won't fully explain any problems or
solutions from AOC. You can find all my solutions on
[Github](https://github.com/aymarino/advent-of-code-2023).

A small programming technique tidbit I hadn't encountered before: when finding solutions to strict
inequalities (e.g. find the smallest integer `x > y`), if your program solves for a floating point
`x` equal to `y` \[[^1]\], how do you find the next greater integer than it to satisfy the
inequality?

My first instinct was that it's simply `ceil(x)`, but that's actually wrong --- if `x` is already an
integer, then `ceil(x) == x == y` does not satisfy `x > y`. Instead, you do `floor(x) + 1`, to
guarantee that the result is 1. greater than `y`, and 2. an integer.

Similarly when you need integral `x < y`, you can do `ceil(x) - 1`.

<hr/>

[^1]:
    to make it more concrete, the AoC problem involved solving for the roots of a quadratic
    equation, and
    [finding the integral solutions](https://github.com/aymarino/advent-of-code-2023/blob/main/src/day6.rs#L10-L13)
    strictly between them.
