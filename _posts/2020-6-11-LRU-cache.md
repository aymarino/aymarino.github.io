---
layout: post
title: Approximating a distributed LRU cache without extra information
---

Imagine you had to find duplicates in a large set of data. This isn't unlike something that could be solved with a map-reduce, but let's say the system it's run on isn't amenable to bringing in additional baggage of dependencies.

* The mapping: Process a piece of data into a hash, some metadata, and a counter.
* The reducing: Combine identical hashes with a "pick any" selection for the metadata, and a sum of the counts.

It's a distributed job across threads or processes working each on a subsection of the data chunks. Even since we're keeping it simple, the mapping is fine and in this case we can even just track things with a hash map (in this case it was a `std::unordered_map`, potentially more on that later): a new hash is just added, and an existing hash just takes the prior's metadata and increments the count.

The reducing is the tricky part, but if disk space is no issue, synchronization can be accomplished simply by flushing any new contents of the map (that is, since the last flush) onto disk. This does require tracking a second, temporary, map of new elements, though its size can be bounded by flushing after processing a set number of chunks. We synchronize with other workers by reading back the whole file into the larger map, adding up the counts of hashes. Clearly, performance in this area wasn't ever a particular priority--indeed, it turns out that the runtime of the system is heavily dominated by the generation of the hashes themselves.

The above architecture was what was implemented, for better or for worse. Later, a problem came up because in this scheme the size of the in-memory map can grow unbounded, which was starting to cause issues as the set of data grew. If we want to bound the memory usage (sacrificing some accuracy of finding duplicates), what's interesting is that the LRU-ness of the map is an emergent propery of the synchronization scheme: the earlier entries in the file (later if reading backwards) are approximately the LRU elements if they weren't also present later in the file. So, bounding the map size is as easy as refusing to insert new hashes after reaching the size bound.

However, the only reason this is an emergent property is that the on-disk file is approximately tracking every single hash-metadata item seen, in the order it was seen by one of the workers. If you don't need LRU tracking, this is absurdly redundant. But, it turns out to be quite useful to have that redundant information lying around when you _do_ need to use it.
