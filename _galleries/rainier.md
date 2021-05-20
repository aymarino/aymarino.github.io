---
layout: gallery
title: Mt. Rainier
---
{% assign gallery_id = page.url | split: "/" | last %}

Rainier!

Training hikes with cans of Rainier (not named after the mountain!):

{% include image-gallery.html gallery_id=gallery_id set_id="beer" %}
