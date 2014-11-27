---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout:     post
title:      Usages of sun.misc.Unsafe within Rubah
tags:       java, unsafe, rubah, jvm
group:      "blog"
published:  false
---

In this post explain how Rubah uses sun.misc.Unsafe to implement the
optimizations that make its performance so good. I start by explaining what
sun.misc.Unsafe is, then I describe what is Oracle HotSpot JVM object memory
layout and how we can explore it with sun.misc.Unsafe, then I discuss how Rubah
does that to allow efficient Dynamic Software Updates, and finally I propose new
ways to make the API safer without disallowing the otimizations Rubah uses.

What is sun.misc.Unsafe?
========================

The class sun.misc.Unsafe is a proprietary API that allows a Java program to
escape the control of the JVM and perform potentially unsafe operations, like
direct memory manipulation. Here is a list of interesting methods that this API
has:

TODO

For instance, the following code sets an array position to zero with method TODO
without performing any bounds check operation.

TODO2

While this is indeed faster than regular Java array manipulation, it may lead to
out-of-bounds operations that can be exploited maliciously (link to wikipedia
heartbleed).

This API is used extensively throughout the java.util.concurrent package to
perform atomic compare-and-swap operations and volatile read/write on arrays.
Currently, that is the only way to do those operations. However, the Oracle JVM
development team is looking into ways to make this API safe and part of the Java
API.

Most of these operations can also be made through native code, but the unsafe
API avoids the cost of context switch from Java to JNI and back. The JIT also
knows how to emit efficient code for unsafe operations.

HotSpot (and OpenJDK) JVM memory model
======================================

The code in TODO2 shows the code pattern when using the unsafe API. First, we
get a base pointer with method TODO. Then, we get the array scale factor with
method TODO. Finally, the formula TODO allows us to access position i on the
array.

The same pattern applies to manipulating objects. Again, we start by getting the
base pointer with method TODO. Then, we get the offset of the field within the
object with method TODO. And finally, we manipulate the field with method TODO.
Here is an example:

TODO

There is a direct mapping from this pattern to the way the JVM lays objects in
memory. The following figure shows how objects and arrays look in memory:

Footnote above mentioning the OpenJDK header file that defines the JVM object layout.

TODO

Every object starts with a fixed sized header that has metadata: The identity
hash-code, the class of the object, and information about the lock state
(locked/unlocked) and GC state (marked, survivor, etc). Then, we can find the
fields that the object has. The class defines which fields are in which order,
and all objects of the same class have the same fields in the same offset.

Arrays also start with a fixed header that has the same data. Then, they have an
integer that specifies the length of the array. Finally, the array itself
starts.

## Manipulating the object model ##

* What lies before the offset?
  * _mark
  * _klass
  * array size
  * header file in OpenJDK that defines this
* Can we modify it?
  * Change the identity hash code
    * Thin locks
  * Change the _klass
    * Careful with JIT inlining
    * _klass changes over time/GC
  * Unused bits on 64 bits _mark
    * May change in the future

sun.misc.Unsafe + Object memory layout
======================================

As you can imagine by now, Rubah uses the unsafe API to manipulate the metadata
on the object header. This is extremely unsafe and getting it right was itself
an implementation challenge. This is also very brittle because future versions
of the HotSpot/OpenJDK are free to change how objects are layed out in memory.

TODO footnote about portability: VMMagic on Jikes would allow Rubah to be
implemented on Jikes. Rubah could be, therefore, implemented without changing
Othe Jikes JVM. Ither DSU systems that require modifications to the GC algorithm
are harder to port to different JVMs.


* Direct field access
  * Fast and less unsafe
  * CAS
* Migrate the identity hash code
  * Object is always unlocked and not known to any other thread
* Change the _klass
  * Code that does this is *NEVER* inlined by the JIT
  * _klass concrete value is not cached
  * Safe-ish: Install proxy vtable
  * Very unsafe: Change _klass for unmodified classes
    * Alternative is type erasure
    * Adds problem with method overloading
    * Adds overhead (5%-10%, we measured)

How to make sun.misc.Unsafe safer
=================================

* Direct field access
  * Field handlers? Research this
* Identity hash code
  * Idea:
    * Only allow this on the JVM level, between NEW and calling the super constructor
    * The JVM already does escape analysis to ensure the new instance does not escape
    * Port with to Java with a special annotated constructor?
* Change _klass
  * Safe for subclasses that do not add any fields
    * Just ensure the JIT knows about this
  * For the other case, use a CLOS like approach
    * Sample code
