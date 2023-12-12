---
layout: post
title: "Advent of Code 2023 Day 9: Lagrange interpolation with integer points"
categories: [aoc-2023, rust]
---

{% include katex.html %}

This is part of a series on little things I learned while doing the problems from
[Advent of Code 2023](https://adventofcode.com/2023). It won't fully explain any problems or
solutions from AOC. You can find all my solutions on
[Github](https://github.com/aymarino/advent-of-code-2023).

## Day 9

The problem is essentially to take a list of integers and extrapolate the next one. They describe
the technique for doing so by taking iterative differences between the values until the differences
are all constant, then building back up to the next number.

The naive brute-force (i.e. just following the algorithm from the problem statement) is quite easy
and fast, but it turns out there's a more interesting mathematical way of solving such problems.
[Lagrange interpolation](https://en.wikipedia.org/wiki/Lagrange_polynomial) is a way of defining a
unique polynomial which intersects a given set of points. By finding the coefficients of such a
polynomial

$$ y = P(x) $$

we can extrapolate the next value in the sequence by plugging in \\(P(x + 1)\\). The trick here is
that the \\(n\\) points given are the \\(y_i\\) values in \\((x_i, y_i)\\) where \\(i = 0, ... , n -
1\\), and, with a larger leap of faith, that \\(x_i = i\\).

Note that for the rest of this section, I'll be taking \\(\sum\_{i = 0}^{n}\\) to be exclusive at
the right side, i.e. \\(0 \leq i \lt n\\), as most ranges in programming work.

So, taking the formula for the Lagrange polynomial:

<!-- prettier-ignore-start -->

$$ P(x) = \sum_{j = 0}^{n} y_j \prod_{i, i \neq j}^{n} \frac{x - x_i}{x_j - x_i} $$

<!-- prettier-ignore-end -->

and substituting that \\(x_i = i\\) and that we want to calculate \\(P(n)\\):

<!-- prettier-ignore-start -->

$$ P(n) = \sum_{j = 0}^{n} y_j \prod_{i, i \neq j}^{n} \frac{n - i}{j - i} $$

<!-- prettier-ignore-end -->

What stands out is that, so long as \\(n\\) is constant between each set of inputs (i.e. the number
of \\(y_i\\) in each line of the input file is the same), we can pre-compute and re-use the
co-efficients given by the \\(\prod\\), call those \\(C_j\\), so that the formula becomes a
dot-product:

<!-- prettier-ignore-start -->

$$ P(n) = \sum_{j = 0}^{n} y_j C_j = [Y] \cdot [C] $$

<!-- prettier-ignore-end -->

for each line of the input, \\([Y]\\).

One further, very interesting step was given in a solution on
[reddit](https://old.reddit.com/r/adventofcode/comments/18e5ytd/2023_day_9_solutions/kclmyaa/):

<!-- prettier-ignore-start -->

$$ C_j = \prod_{i, i \neq j}^{n} \frac{n - i}{j - i} = \frac{\prod_i n - i}{\prod_i j - i} =
\frac{\frac{n!}{n - j}}{(n - 1 - j)!j!(-1)^{n - 1 - j}} $$

<!-- prettier-ignore-end -->

Note that in the denominator, \\(i\\) is varyingly greater and less than \\(j\\), since it spans the
range \\((0, 1, ..., j, ..., n)\\). Hence, the \\((-1)\\) factor makes the product positive or
negative.

<!-- prettier-ignore-start -->

$$ = (-1)^{n - 1 - j} \frac{n!}{(n - j)!j!} = (-1)^{n - 1- j} {n \choose j} $$

<!-- prettier-ignore-end -->

So the polynomial coefficients to the Lagrange can in fact be expressed as a combination, when
\\(x_i = i\\). This is particularly useful for programming the solution, since it eliminates the
need to deal with lossy floating point arithmetic (although it does require 128-bit integer math for
the factorial).

The programmed solution, written in Rust, is on my
[Github](https://github.com/aymarino/advent-of-code-2023/blob/8068d4063d5158a0a4d67b54fdb970abeec22a5b/src/day9.rs#L56-L57).
