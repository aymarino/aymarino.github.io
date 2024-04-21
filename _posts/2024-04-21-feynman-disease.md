---
layout: post
title: "Feynman on the computer disease"
categories: []
---

In Richard Feynman's autobiography
[_Surely You're Joking, Mr. Feynman!_](https://en.wikipedia.org/wiki/Surely_You%27re_Joking,_Mr._Feynman!),
in the chapter talking about his work on the Manhattan Project, they were setting up a program to
use IBM tabulators and multipliers to do expensive computations in a sort of mass-production-line of
these machines[^1].

But they ran into a problem:

> Well, Mr. Frankel, who started this program, began to suffer from the computer disease that
> anybody who works with computers now knows about. It's a very serious disease and it interferes
> completely with the work. The trouble with computers is you _play_ with them. They are so
> wonderful. You have these switches­ ---­ if it's an even number you do this, if it's an odd number
> you do that ---­­ and pretty soon you can do more and more elaborate things if you are clever
> enough, on one machine.
>
> After a while the whole system broke down. Frankel wasn't paying any attention; he wasn't
> supervising anybody. The system was going very, very slowly --- ­­while he was sitting in a room
> figuring out how to make one tabulator automatically print arc-­tangent X, and then it would start
> and it would print columns and then _bitsi, bitsi, bitsi,_ and calculate the arc-­tangent
> automatically by integrating as it went along and make a whole table in one operation.
>
> Absolutely useless. We _had_ tables of arc­tangents. But if you've ever worked with computers, you
> understand the disease ­­--- the _delight_ in being able to see how much you can do. But he got
> the disease for the first time, the poor fellow who invented the thing.

Of course, this is pretty funny and just as relevant today as it was then. In my experience, people
in the field of software engineering are uniquely at risk for this disease, as compared to those in
other fields that also use programming (say, physics or data science).

Some activities that come to mind as symptoms of this disease in modern day:

- Creating useless demos to play with a new technology (this is what Mr. Frankel was doing!)
- Refactoring (or worse, rewriting) a codebase for the sake of use a new design pattern or language.
- Micro-optimizing code not on a hot path.
- Over-engineering the design of a new component to accommodate requirements that don't exist.
- Similarly, over-engineering the design of a new project to scale well, before having a single
  user.

All of these I have both exhibited myself and seen other people exhibit. These may not always be
strictly _useless_, but it's important to recognize when you're doing something because it brings
you personal satisfaction, and not because it's actually productive.

That said, even if the value of these things can't be easily measured in terms of productivity, they
still serve a purpose. Probably for many people in the field, how we first learned, and still learn,
technical skills is by playing around with new technologies and making them do cool things. Even in
the context of working for a company, spending time on useless demos or toying around with projects
might later become useful, simply by the experience and learning you get from that exploration. One
attribute of West-coast-tech-company culture seems to be a recognition and acceptance of this
importance, and tacit
[or explicit](https://en.wikipedia.org/wiki/Side_project_time#Google_implementation) encouragement
of it.

So it's an interesting problem to deal with on the people management side too. While you don't want
to encourage time-wasting useless activity, you also don't want to stifle the things that make
someone enthusiastic, and also don't want to restrict the kind of unstructured exploration that can
later lead to real productive things. A couple ways I've seen organizations balance this is:

- "learning days", where folks are encouraged to explore some topics they're interested in.
- hackathons, where folks are encouraged to create and show off these sorts of useless demos.
- Google's 20 percent time, which may or may not
  [still exist](https://www.theatlantic.com/technology/archive/2013/08/20-time-perk-google-no-more/312063/).

The common theme is to try to time-box unproductive work while still allowing it some space. Though
of course, the nature of this being a disease is that you can't control when it strikes you.

[^1]:
    Specifically, the calculations to figure out how much energy would be released during the bomb's
    implosion.
