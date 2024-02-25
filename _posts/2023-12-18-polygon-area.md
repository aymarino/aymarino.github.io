---
layout: post
title: "Advent of Code 2023 Day 18: Shoelace formula for finding the area of a polygon"
categories: [aoc-2023, rust]
---

{% include katex.html %}

This is part of a series on little things I learned while doing the problems from
[Advent of Code 2023](https://adventofcode.com/2023). It won't fully explain any problems or
solutions from AOC. You can find all my solutions on
[Github](https://github.com/aymarino/advent-of-code-2023).

Day 18 involves taking an irregular [rectilinear](https://en.wikipedia.org/wiki/Rectilinear_polygon)
shape and finding the area of it. Specifically, taking a list of directions (right 6, down 5, etc.)
and turning it into an enclosed shape:

```
#######
#.....#
###...#
..#...#
..#...#
###.###
#...#..
##..###
.#....#
.######
```

then finding the number of squares enclosed, including those on the boundary.

For directions with small length `n`, this is easy to "brute-force" so to speak, with methods like
like a [flood fill](https://en.wikipedia.org/wiki/Flood_fill) algorithm, or
[ray-casting](https://en.wikipedia.org/wiki/Point_in_polygon#Ray_casting_algorithm) on each row to
count the interior points.

But, in part 2 of the problem, the `n` on each direction becomes very large --- larger than is
reasonable to use any algoirthm that is \\(O(n)\\). It turns out there is an analytical solution one
can use instead, which derives the polygon area from the coordinates of its vertices.

### Shoelace formula

The [shoelace formula](https://en.wikipedia.org/wiki/Shoelace_formula) gives the area of a simple
polygon (read: a single closed shape with no intersecting edges) \[[^1]\]:

<!-- prettier-ignore-start -->

$$ A = \lvert \frac{1}{2} \sum_{i = 1}^{n} (y_i + y_{i + 1})(x_i - x_{i+1}) \rvert $$

<!-- prettier-ignore-end -->

The geometric intuition for why this works is that each pair of \\((x, y)\\) coordinates for \\(i\\)
and \\(i+1\\) form a trapezoid with the \\(x\\)-axis. This trapezoid has area

<!-- prettier-ignore-start -->

$$ A = \frac{a + b}{2} h = \frac{y_i + y_{i+1}}{2} \lvert x_{i+1} - x_i \rvert $$

<!-- prettier-ignore-end -->

where \\(a\\), \\(b\\) are the lengths of the parallel sides, as usual.

<!-- prettier-ignore-start -->
These trapezoid areas _add_ to the polygon area when \\(x_i > x_{i+1}\\) (i.e., travelling from
\\(P_i \rightarrow P_{i+1} \\) is to the left), and _subtract_ from the area when travelling to the
right \[[^2]\], as illustrated via Wikipedia, below:
<!-- prettier-ignore-end -->

[![Wikiedia illustration of the shoelace algorithm](https://upload.wikimedia.org/wikipedia/commons/8/8f/Trapez-formel-prinz.svg)](https://en.wikipedia.org/wiki/Shoelace_formula#Trapezoid_formula_2)

The areas below the polygon are subtracted from the larger trapezoids formed by the points on the
top of the shape.

### Pick's theorem

The shoelace formula gives us to get the area with the points formed by the directions in the Advent
of Code problem, but this is different than what is asked for --- we need the number of squares
enclosed by the shape, including the boundary.

The crux of the difference between the area of the shape and the number of points in it is that a
line of length 1 from \\((0, 0)\\) to \\((0, 1)\\) contains 2 points. So take a simple square with
side length 1, would look like this in the Advent of Code problem:

```
....
.##.
.##.
....
```

but like this when the `#` coordinates are translated to points on the hypothetical cartesian plane:

![Unit square on a grid](/images/posts/unit-square.png)

The points form a shape with 4 boundary points, but area 1.

It turns out there's another formula relating a polygon's area \\(A\\) to the number of boundary
points \\(b\\) and interior points \\(i\\), called _Pick's theorem_:

$$ A = i + \frac{b}{2} - 1 $$

In AoC day 18, we can calculate \\(A\\) (using the Shoelace algorithm) and trivially compute \\(b\\)
\[[^3]\], and the answer is the total number of points touched or enclosed by the path, \\(b + i\\):

$$
\begin{aligned}
    i + \frac{b}{2} - 1 &= A \\
    i + b &= A + \frac{b}{2} + 1 \\
\end{aligned}
$$

My solution to the Advent of Code problem, written in Rust, is available
[here](https://github.com/aymarino/advent-of-code-2023/blob/main/src/day18.rs#L15-L48) (link
highlights the application of Shoelace and Pick's theorem).

<hr/>

<!-- prettier-ignore-start -->
[^1]:
    The shoelace formula is so-called because of its alternate form where each term in the summation
    is \\(x_i y_{i+1} - x\_{i+1}y_i \\) and there's a "criss-cross" of the \\(x\\) and \\(y\\) indices.

    To me, the other formula explained above is more geometrically intuitive.

[^2]:
    This assumes both that \\(y > 0\\) and each \\(P\\) is indexed going counter-clockwise, but the same
    intuition holds otherwise in terms of adding/subtracting to the _magnitude_ of the area, since we take
    the absolute value of the result.
<!-- prettier-ignore-end -->

[^3]: Given by the length of the path created by all the instructions.
