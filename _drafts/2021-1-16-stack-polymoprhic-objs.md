---
layout: post
title: "Stack-allocating runtime polymorphic types in C++"
categories: [cpp]
---

A while back, I worked on a C++ system that had a performance problem. I was relatively new on the
team but a principal engineer on the team had already identified the root cause as simply way too
many heap allocations happening on the hot path. Specifically, since this was on Windows, the issue
was that the system calls for allocating require taking a global lock, and the application was
heavily multi-threaded. The second-order issue of _why_ there were so many heap allocations, was
that the code was designed around polymorphic types and virtual dispatch.

When working with dynamic polymorphic types in C++ (i.e. class hierarchies with dynamic dispatch via
`virtual` functions), doing certain things more or less requires that you heap-allocate those
polymorphic objects:

- A function that returns different derived types based on a runtime value (e.g., a factory
  function) must have a common return type, so typically you'd return a base class pointer, pointing
  to a heap-allocated object.
- Or, maybe you're storing a collection of objects of different derived types in the same standard
  container. Containers must store a single static type, and the stored elements must be the same
  size, so we typically store base class pointers (e.g. `std::vector<Base*>`), and the objects must
  be allocated in a separate lifetime longer than that of the container, such as on the heap.
- If types in the class hierarchy have different sizes, you need to dynamically size the space to
  store the object based on the runtime type.

This can be inefficient though, since it forces a particular _lifetime_ of the object---i.e., that
the lifetime of this object outlives the stack frame it's created or stored in---which may be longer
than required. If we have a function that only locally creates and uses polymorphic objects that are
the same size, it may still be forced to heap-allocate them if it needs to do either of the other
above things. And heap allocation is expensive!

This post outlines a technique and utility class for transparently moving the allocations for
runtime polymorphic objects off the heap. This was the technique I used to solve this particular
problem at the time, but since then I've seen the same pattern solved in different ways too.

## Illustrating example

An `Operation` is a common kind of class that might be subtyped to specialize its logic. E.g. one
derived class for `Add`, another for `Multiply`, and so on. Or it can be specialized for particular
kinds of business logic:

```cpp
int get_final_transaction_cost(const Transaction& tx) {
  std::vector<Operation*> tx_operations;

  tx_operations.push_back(new AddItemCost { tx.item_price }); // #1

  Operation* add_base_price = get_base_price_op(tx); // #2
  tx_operations.push_back(add_base_price);

  if (tx.has_sales_tax) {
    tx_operations.push_back(new MultiplyBy { tx.sales_tax_rate }); // #3
  }

  return apply_operations(tx_operations);
}
```

Whoever wrote this has wrangled the potentially-complicated and dynamic business logic by
sub-classing new kinds of operations, each of which might happen on any given transaction, to reach
a final result[^2]. But to store a homogenous list of the operations, or to break up the logic into
separate functions, it must reach for that handy operator `new`.

Instead of storing those objects on the heap and storing pointers to them, what would be better is
if we stored the objects somewhere on the stack and took pointers to them to dispatch to the right
runtime logic. That is, instead of allocation `#1` above, we could create a stack object of type
`AddItemCost` and push its pointer into the container. But, this doesn't work for objects created in
other functions, like `#2`, or other scopes, like `#3`[^3]. Furthermore, this is an intrusive
refactor, possible even a rewrite, which would take time and possibly introduce bugs.

What we need is a way to allocate and store these polymorphic objects in a lifetime pool that is not
the large hammer of heap, without giving up the flexibility of referring to them by type-erased
`Base*` pointer.

A neat technique to accomplish this transparently (i.e. without introducing custom allocators or
hacking `malloc` or some such) is by placement-allocating the objects into a memory buffer, and
passing that around as-if it were the type-erased pointer.

## A utility for placement of dynamic types

`PlacementHolder` is essentially just a statically-sized memory buffer which can be re-interpreted
as any concrete derived type. This is the full class definition, and I'll break down each piece:

```cpp
/// A buffer in which to placement-allocate an object.
/// Enables allocating polymorphic derived classes without heap
/// allocation, while still being passed and used via the base class interface.
///
/// `BaseType` is the intended base class interface.
/// `Size` is the max size of any intended concrete type which may be instantiated.
/// `Alignment` is a type that gives the required alignment for types which
/// may be instantiated through this. Default is word-aligned.
template <typename BaseType, size_t Size, typename Alignment = std::intptr_t>
class PlacementHolder {
public:
    /// Default ctor creates an empty object.
    PlacementHolder() {
        set_disabled();
    }

    PlacementHolder(const PlacementHolder&) = delete;
    PlacementHolder& operator=(const PlacementHolder&) = delete;

    /// Only enable move construction, which copies the `other` placement's memory
    /// and disables its destructor.
    PlacementHolder(PlacementHolder&& other) {
        if (this == &other) return;
        std::memcpy(placement_buffer_, other.placement_buffer_, Size);
        other.set_disabled();
    }

    ~PlacementHolder() {
        if (is_enabled()) {
            get()->~BaseType(); // Calls derived class destructor through vtable
        }
    }

    /// Return the placement memory interpreted as the intended base type.
    BaseType* get() {
        return reinterpret_cast<BaseType*>(placement_buffer_);
    }

    /// Allow "pointer-like" interface with the Holder.
    BaseType& operator*() const { return *get(); }
    BaseType* operator->() const { return get(); }

protected:
    /// Constructs a `T` into the buffer using the constructor called
    /// by `T(args...)`.
    template <typename T, typename ... Args>
    void construct(Args&&... args) {
        // Static assertions to ensure the integrity and proper alignment of
        // the type being placement-allocated in this type.
        static_assert(sizeof(placement_buffer_) == sizeof(decltype(*this)));
        static_assert(sizeof(T) <= sizeof(placement_buffer_));
        static_assert(alignof(T) == alignof(decltype(*this)));

        new (reinterpret_cast<void*>(placement_buffer_)) T(std::forward<Args>(args)...);
    }

private:
    /// Enable and disable destruction of the held object by using the first word
    /// of the placement memory as a flag. In both Itanium and MSVC ABI, a vtable
    /// pointer is always laid out at offset 0 into the object layout. So if an object
    /// is held, the first word of memory in the allocated will always be non-zero.
    bool is_enabled() const { return first_word_ != 0; }
    void set_disabled() { first_word_ = 0; }

    union {
        /// The buffer holding the full concrete object representation.
        unsigned char placement_buffer_[Size];
        /// Word-sized buffer at offset 0 in the placement buffer.
        std::intptr_t first_word_;
        /// Unused: forces the Placement class to have the same alignment.
        Alignment at_;
    };

    // The polymorphic type's destructor must be virtual to correctly call the
    // base class dtor in '~PlacementHolder()'.
    static_assert(std::has_virtual_destructor_v<BaseType>);

    // Any BaseType should have at least a vtable pointer.
    static_assert(sizeof(placement_buffer_) >= sizeof(std::intptr_t));
};
```

You would instantiate the `PlacementBuffer` with three templated types:

1. `BaseType` being the intended base class interface, through which you make your virtual calls.
2. `Size` is the maximum size of _any_ concrete type that might be instantiated inside this class.
   This is the least ergonomic piece of the utility: for any given class hierarchy, you must keep
   track of the maximum size of any type therein, for it to continue to be substitutable for any of
   them. This may be easier than it seems, since there are compile-time checks such that any
   concrete type instantiated via this class fits.

The `placement_buffer_` member of the class is sized to accommodate the largest of any derived type
which might be allocated using it, and the pointer-like interface surfaces the memory as if it were
just the base-class pointer. The class owns the underlying object, and so cleans up by calling the
virtual destructor and requires that the object be moved and not copied (just as you couldn't copy
the underlying object with just the base class pointer otherwise).

One interesting thing this does is provide the interface at zero overhead if all the derived class
types are the same size. A moved-from type must somehow represent that the object is "empty" for
when the destructor is called---otherwise you could call the dtor twice for the same object. This
can be done with a `bool` member, but here we can alias the first pointer-sized bit of memory in the
allocation as that `bool`. A non-zero value there indicates that the object is occupied, a zero
there that it is not. We can guarantee that any valid object representation in the allocation must
have non-zero value in the first word of memory, because that's where the vtable pointer is always
laid out!

The usage would go like this. Let's say, continuing on the above example, we have a polymorphic
class hierarchy with a few types:

```cpp
struct OperationBase {
  virtual double apply(double acc) = 0;
  virtual ~OperationBase() {}
};

struct AddOp : OperationBase {
  double apply(double acc) override {
    return std::accumulate(operands_.begin(), operands_.end(), acc);
  }

  std::vector<double> operands_;
};

struct MulByFactorOp : OperationBase {
  double apply(double acc) override {
    return acc * factor_;
  }

  double factor_;
};
```

We can specialize the `Holder` utility for this hierarchy:

```cpp
constexpr size_t MAX_OPERATION_SIZE = std::max({
  sizeof(OperationBase),
  sizeof(AddOp),
  sizeof(MulByFactorOp)
});

struct OperationHolder : PlacementHolder<OperationBase, MAX_OPERATION_SIZE> {
    template <typename T, typename ... Args>
    static OperationHolder create(Args&&... args) {
        OperationHolder t;
        t.construct<T>(std::forward<Args>(args)...);
        return t;
    }
};
```

and use it as such in the context from before:

```cpp
double get_final_transaction_cost(const Transaction& tx) {
  std::vector<OperationHolder> tx_operations;

  tx_operations.push_back(OperationHolder::create<AddOp>(tx.item_price));

  OperationHolder add_base_price = get_base_price_op(tx); // #2
  tx_operations.push_back(std::move(add_base_price));
  if (tx.has_sales_tax) {
    tx_operations.push_back(OperationHolder::create<MulByFactorOp>(tx.sales_tax_rate)); // #3
  }

  return apply_operations(tx_operations);
}
```

## Other techniques

The more general description of this problem is: you don't always want or need to make allocations
on the heap. But you may want allocations in general, because they're polymorphic and use virtual
dispatch, or to hide objects behind an ABI boundary. So a more general solution is: provide a way to
allocate elsewhere than the heap.

The `PlacementHolder` technique does that: it just gives a sufficiently-sized stack object to
allocate into. But it's not the most general way of doing it. You could also, more generally pass
each function which may allocate such an object a generic `Allocator` object, which transparently
"allocates" objects, but may do so to some other memory than the heap.

## Other languages

E.g. Comparison to Rust
([https://guiand.xyz/blog-posts/unboxed-trait-objects.html](https://guiand.xyz/blog-posts/unboxed-trait-objects.html))

[^2]:
    Whether this is a well-designed system or there are better solutions is outside the scope of
    this problem.

[^3]: Of course, the function callee is just a special-case of a separate scope.
