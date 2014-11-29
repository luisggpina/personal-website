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
published:  true
---

In this post explain how Rubah uses sun.misc.Unsafe to implement the
optimizations that make its performance so good. I start by explaining what
sun.misc.Unsafe is, then I describe what the object memory layout of the Oracle
HotSpot JVM and how to explore it with sun.misc.Unsafe, then I discuss how Rubah
does that to optimize supporting Dynamic Software Updates, and finally I propose
how to make some of the operations the API exports safer in a way that is
compatible with Rubah.

What is sun.misc.Unsafe?
========================

The class sun.misc.Unsafe is a proprietary API that enables a Java program to
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

The unsafe API is used extensively throughout the java.util.concurrent package
to perform atomic compare-and-swap operations and volatile read/write on arrays.
Currently, that is the only way to do those operations. However, the Oracle JVM
development team is looking into ways to make this API safe and part of the Java
API.

Most of these operations can also be made through JNI native code. However,
using the unsafe API is more efficient because it avoids the cost of context
switch from Java to JNI and back. Besides, the JIT compiles some calls to the
unsafe API directly to JVM intrinsics.

TODO: Footnote explaining that an intrinsic is a special internal implementation
of a method. For instance, calling System.identityHashCode is translated to an
intrinsic operation that just reads the hash code from the object header in a
few assembly instructions, rather than calling a method.

HotSpot (and OpenJDK) JVM memory model
======================================

There is a code pattern when using the unsafe API to manipulate data in object
fields or arrays.  The code in TODO2 shows an example of that pattern. First, it
gets a base pointer with method TODO. Then, it gets the array scale factor with
method TODO. Finally, it computes the formula TODO to access position i on the
array.

A similar pattern applies to manipulating objects, as we can see in the
following example:

TODO

Again, it starts by getting the base pointer with method TODO. Then, it gets the
offset of the field within the object with method TODO. And finally, it
manipulates the field with method TODO.

This code pattern maps directly to the way the JVM lays objects in memory. The
following figure shows how objects and arrays look in memory:

Footnote above mentioning the OpenJDK header file that defines the JVM object layout.

TODO

Every object and array starts with a fixed sized header that has two fields:
_mark and _klass. For unlocked objects, field _mark has the identity hash-code
and a set of bits that the JVM uses to keep miscelaneous metadata (locked state
and GC state). For locked objects, the _mark has the address of a lock structure
that has information about which threads are waiting for the lock, plus the
identity hash-code and the GC metadata. For the sake of simplicity, let us just
assume that objects are always unlocked. Field _klass represents the class of
the objects and keeps low-level data about it (the size of each object, the
method vtable, etc).

TODO: Turn paragraph above into a definition list

The fields of regular object follow the header. The class defines the fields and
their order. On the HotSpot JVM, all objects of the same class have the same
fields in the same offset. On arrays, the header is followed by an integer that
specifies the length of the array. The elements of the array start after that.

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

Manipulating the object model
=============================

As you can imagine by now, Rubah uses the unsafe API to manipulate the metadata
on the object header. This is extremely unsafe and getting it right was itself
an important implementation challenge. Doing this is also very brittle because
the unsafe API is not part of the standard Java API. Future versions of the
HotSpot JVM are free to change how objects are layed out in memory.

TODO footnote about portability: VMMagic on Jikes would allow Rubah to be
implemented on Jikes. Rubah could be, therefore, implemented without changing
Othe Jikes JVM. Ither DSU systems that require modifications to the GC algorithm
are harder to port to different JVMs.

In the following, I list all the different ways Rubah manipulates the header
using the unsafe API:

* **Direct field access**

	To migrate the program state, Rubah needs to traverse every object it finds.
	This means accessing every field, which might not be visible. The unsafe API
	enables Rubah to access every field of every object in a very fast way.

	Also, both the migration algorithms that Rubah has (parallel and lazy) use
	compare-and-swap to ensure correctness while migrating the program state. The
	unsafe API is the only way to perform this operation on regular fields.

Footnote: If you want to be able to use the compare-and-swap operation safely in
your code, you should use AtomicReferences --- part of the java.util.concurrent
package --- which themselves are implemented using the unsafe API (link to
grepcode).

* **Identity hash-code**

	Rubah migrates objects between versions while keeping their identity. It does
	so by creating a new object in the new version that will take the place of the
	old one, and then migrating the state of the old object to the new one. When
	traversing the program state, Rubah replaces all references to the old object by
	references to the new one. This way, if two references == each other in the
	old version, they will also == after the update takes place.

	However, the identity hash-code of such two objects will differ. If the class
	does not override the hashCode method and the program keeps these objects in an
	HashMap, which is perfectly valid, then Rubah would break the semantics of the
	program: After the update, the objects will be on the wrong buckets of the
	HashMap and, therefore, impossible to find.

	Initially Rubah changed the bytecode of all classes, adding an extra field to
	keep the identity hash-code which was initialized on every constructor.
	Rubah also added the hashCode method to all classes that did not have any.
	Migrating the identity hash-code was not just a matter of migrating another
	field. However, this prevents the JIT compiler to use intrinsic operations to access
	the identity hash-code efficiently. As a result, this added about 5% overhead to
	steady-state execution. Also, it does not work for arrays.

	Rubah now writes the identity hash-code of the new instance directly in the
	object header using the unsafe API. This works objects and arrays and removes
	the performance overhead.
	
* **Changing the class of existing objects**

	Rubah's' lazy algorithm introduces the concept of proxies. These extend the
	proxied class and just override all methods so that Rubah can intercept any
	method call on a proxy. At the object layout level, this means that proxies
	have the same fields on the same offset but a different vtable with different
	methods. So, all Rubah needs to do is to install that vtable on existing
	objects to turn them into proxies.

	Between two versions, the vast majority of objects do not need to be migrated
	because their class has not changed. However, consider the following example:
	Class A changed, class B did not change and has a field of type A. Of course,
	we have to migrate every instance of A. However, class B has the same layout in
	memory in both versions. Rubah just needs to change the code so that the new
	version treats the new field using the new type.

	Both this scenarios illustrate the need for Rubah to change the class of
	existing objects my using the unsafe API to adjust the _klass field on the
	header. This is the most brittle optimization that Rubah performs. In fact,
	getting it to work was a challenge. In part, because the code the JIT compiler
	emits assumes that the _klass does not change during the execution of a method.
	If it does, the JVM may crash with a segfault. So, Rubah is implemented in a way
	that prevents the code that changes the _klass from being inlined with
	application code that might use that field.

	Also, the garbage collector relies on the _klass to learn the size and
	structure of the object it is about to visit. No matter what _klass field it
	reads, the old or the new, both agree on the same information the GC needs to do
	its job. Therefore, the regular GC operation does not cause the JVM to crash.

	Note that the alternative to deal with instances of unchanged classes between
	versions would be to either: (1) Copy them or (2) erase the type of all field to
	Object and inject the appropriate cast before every bytecode that reads fields.
	Option (1) would require a deep copy of the whole heap, so we discarded it from
	the start. Early versions of Rubah implemented option (2), thus adding a steady
	state overhead of 5%.

Footnote: The steady-state overhead of the type-erasure AND hash-code field
together was around 8%, and not 10%.

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
