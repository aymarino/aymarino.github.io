---
layout: post
title: "Rust macros for simplifying FFI function calls in a binding crate"
categories: [rust]
---

If you have to interact with a system library that exposes a C programming interface,
[Joe Biden](https://www.whitehouse.gov/wp-content/uploads/2024/02/Final-ONCD-Technical-Report.pdf)
would rather you created a memory-safe wrapper on top of it and built applications against that. Not
only does this reduce the surface area of new code that's written in unsafe languages, it allows you
to write things in more productive, and pleasant, modern languages. Here, I'll focus on doing it in
Rust.

### Background: A whirlwind tour of writing FFI wrapper libraries in Rust

Building and maintaining Rust wrappers of C libraries typically follows two steps:

1. Build a `-sys` crate that generates and exports bindings from the function and type declarations
   in the library headers.

   There are many great tutorials[^1] for using `bindgen` or other tools to build such crates.

   But, these only generate _direct_ Rust translations of the C function signatures and types and
   links against the library. So, this allows you to call the library functions from Rust, but it
   will look something like this:

   ```rust
   let options = unsafe {
       let mut options = MaybeUninit::uninit();
       let result: u32 = ffi::foo_options_create(options.as_mut_ptr());
       if (result != ffi::foo_error_code_t_OK) {
         return Err(/* ... */);
       }
       options.assume_init()
   };

   let resource = unsafe {
       let mut resource = MaybeUninit::uninit();
       let result = ffi::foo_resource_create(options, resource.as_mut_ptr());
       // etc...
   };
   ```

   Since the calls are into a C library, they are inherently unsafe: calls require passing around
   raw pointers for inputs and outputs, there are no (Rust-enforced) guarantees about the lifetime
   of the underlying objects, and so on. Essentially, we are writing C with Rust syntax.

   If you were going to write a Rust application against this library, it would not only be painful
   to write, but also not much safer than simply using C[^2].

   So there's a second step:

2. Build a higher-level Rust crate that exposes Rust-native types and functions that wrap around
   `unsafe` calls into the generated FFI bindings.

   Building on the example above, you could export:

   ```rust
   pub struct Options {
     handle: ffi::foo_options_t,
   }

   impl Options {
     pub fn new() -> Result<Self, ErrorType> {
       let handle = unsafe {
         let mut options = MaybeUninit::uninit();
         let result: u32 = ffi::foo_options_create(options.as_mut_ptr());
         if (result != ffi::foo_error_code_t_OK) {
           Err(ErrorType::from(result));
         } else {
           Ok(options.assume_init())
         }
       }?;
       Ok(Options {
        handle
       })
     }
   }
   ```

   The `Options` type (encapsulating some concept from the original library) is re-exported with a
   Rust constructor that internalizes the `unsafe` FFI calls. So a user of the library could write
   their application with familiar, safe Rust:

   ```rust
   let options = foo_rs::Options::new()?;
   ```

   No `unsafe` in sight!

### The ugly reality of wrapper crates

These wrapper crates are great for their users, but a beast to write: there is no automated way of
generating such wrapper types, unlike the direct FFI interface. By its nature, it must be
hand-written with some level of considered design.

Even more fundamentally, look at that `unsafe` block above: it's a hand-numbing mess of
`MaybeUninit` and `assume_init` for the output parameter, casting around `mut ptr`s, checking and
propagating `u32` return values, and more.

I recently wrote a Rust sys-crate and wrapper crate for a library (which is unfortunately not open
source). As in the example above, the C interface for this library uses out-parameters and error
codes to indicate success. Since all the functionality of the wrapper involves calls to these FFI
functions, I found some techniques to reduce the tedium and repetition through Rust macros.

### First step: turning C-style error codes into `Result`s

The typical pattern I found myself constantly writing is similar to the above. Say our library `foo`
has a C interface with a function to create a `resource`:

```c
foo_error_code_t foo_resource_create(
  foo_options_t* options,
  const char* input,
  foo_resource_t** out_object
);
```

It takes a few inputs parameters, but the last formal is the function output object, while the
return value is the success-or-failure code of the operation.

With the Rust FFI binding, calling this function turns into:

```rust
let object_handle = unsafe {
  let mut resource = std::mem::MaybeUninit::uninit();
  let err_code = ffi::foo_resource_create(options_handle, input_handle, resource.as_mut_ptr());
  if err_code != ffi::foo_error_code_t_OK {
    Err(ErrorCode::from(err_code))
  } else {
    Ok(resource.assume_init())
  }
}?;
```

First we can create a convenience function to transform the error code into a result:

```rust
pub(crate)
fn to_result<T>(ok: T, err_code: ffi::foo_error_code_t) -> Result<T, ErrorCode> {
  if err_code == ffi::foo_error_code_t_OK {
    Ok(ok)
  } else {
    Err(ErrorCode::from(err_code))
  }
}
```

which reduces the boilerplate of handling the returned error code:

```rust
let object_handle = unsafe {
  let mut resource = std::mem::MaybeUninit::uninit();
  let err_code = ffi::foo_resource_create(options_handle, input_handle, resource.as_mut_ptr());
  // Note: calling .assume_init() when the object is possibly not initialized (e.g. when
  // error_code is not OK) is UB. This is relevant when the `T` behind the `MaybeUninit`
  // has a `Drop` impl -- but since the `T` here is always an FFI pointer object which
  // does not do anything on drop, and the `T` will never be used unless `err_code` is
  // OK, I took this shortcut.
  to_result(resource.assume_init(), error_code)
}?;
```

### Macros for FFI calls with out-parameters

But, we we can go further with macros. First, we can abstract out the function call and result
handling:

```rust
/// Transform the foo_error_code_t value returned by expr `f` to a Result<T, ErrorCode>,
/// where the `Ok()` value is given by `out` (but only read if `f` result is Ok).
macro_rules! unsafe_foo_result {
  ($out: expr, $f: expr) => {
    unsafe {
      let result = $f;
      $crate::error_code::to_result($out, result)
    }
  };
}
```

This gives an easier way to make calls to FFI functions that don't return anything but the error
code[^3]:

```rust
unsafe_foo_result!((), ffi::foo_execute_operation(operation_handle))?;
```

But for the majority of calls, which return something via the out-parameter, it still leaves us with
the repetitive `MaybeUninit` construction and also requires an unsatisfying, premature-looking
`.assume_init()` on the return value handle:

```rust
let resource_handle = {
  let mut resource = std::mem::MaybeUninit::uninit();
  unsafe_foo_result!(
    resource.assume_init(),
    ffi::foo_resource_create(options_handle, input_handle, resource.as_mut_ptr())
  )
}?;
```

Since this library, as do most, has a consistent convention of the out-parameter being the last one,
we can create a further sugar macro for such calls:

```rust
/// Call the given FooLib C interface `ffi_fn` with `params`. Expects that `ffi_fn` returns
/// its output via the last function parameter, and returns it as a result.
macro_rules! unsafe_foo_lib_ffi {
  ($ffi_fn: expr $(, $params:expr)*) => \{\{
    let mut out = std::mem::MaybeUninit::uninit();
    $crate::error_code::foo_result!(out.assume_init(), $ffi_fn($($params,)* out.as_mut_ptr()))
  }};
}
```

Which finally allows us to write:

```rust
let object_handle = unsafe_foo_lib_ffi!(
  ffi::foo_resource_create,
  options_handle,
  input_handle
)?;
```

for each FFI callsite.

[^1]:
    Check out this [blog post](https://kornel.ski/rust-sys-crate) from Kornel Lesiński, or this more
    interactive/real-time [video tutorial](https://www.youtube.com/watch?v=pePqWoTnSmQ) from Jon
    Gjengset.

[^2]:
    Except, of course, that the rest of the application around the calls into the library could have
    more safety checks.

[^3]:
    One thing the macro also does is remove the `unsafe` block from the callsites, internalizing it
    into the macro. While this does result in cleaner code, I don't appreciate that it hides the
    unsafe operation from where it happens, hence why I name the macro here with `unsafe_`.
