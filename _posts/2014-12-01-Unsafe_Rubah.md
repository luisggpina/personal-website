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
highlight:	true
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
has ([more documentation available
here](http://grepcode.com/file/repository.grepcode.com/java/root/jdk/openjdk/7u40-b43/sun/misc/Unsafe.java/)):

<pre><code class="java">
public class Unsafe {
	// use reflection instead, this method throws an exception if the calling
	// class is not on the bootstrap classpath
	public static Unsafe getUnsafe();

	// static field/Object field/array manipulation utilities
	public Object staticFieldBase    (Field f);
	public long   staticFieldOffset  (Field f);
	public long   objectFieldOffset  (Field f);
	public int    arrayBaseOffset    (Class c);
	public int    arrayIndexScale    (Class c);

	// reference-type field manipulation
	public Object getObject (Object o, long offset);
	public void   putObject (Object o, long offset, Object x);

	// int-type field manipulation (repeated for every other primitive type)
	public int    getInt    (Object o, long offset);
	public void   putInt    (Object o, long offset, int x);

	// compare-and-swap object/int/long
	public boolean compareAndSwapObject (Object o, long offset, Object expected, Object x);
	public boolean compareAndSwapInt    (Object o, long offset, int expected,    int x);
	public boolean compareAndSwapLong   (Object o, long offset, long expected,   long x);

	// allocate instance without running constructors
	public Object allocateInstance (Class cls);

	// try entering a monitor, fail with false instead of blocking if not able to
	public boolean tryMonitorEnter (Object o);

}
</code></pre>

For instance, the following code sets an entire integer array to 1 using the
unsafe API to avoid any bounds check.

<pre><code class="java">
// For this to work, add the class to the bootstrap classloader by passing
// the option -Xbootclasspath/a:. to the java command
Unsafe u    = Unsafe.getUnsafe();
int   size  = 1 << 16;
int[] array = new int[size];
int   base  = u.arrayBaseOffset(Integer.class);
int   scale = u.arrayIndexScale(Integer.class);

for (int i = 0 ; i < size ; i++)
  u.putInt(array, (base + i * scale), 1);

// Nothing prevents me writting out of bounds:
// u.putInt(array, (base + size * scale), 1);
// Or reading:
// u.getInt(array, (base + size * scale));
</code></pre>

While this is indeed faster than regular Java array manipulation, it may lead to
out-of-bounds operations that can be [exploited
maliciously](http://en.wikipedia.org/wiki/Heartbleed).

The unsafe API is used extensively throughout the java.util.concurrent package
to perform atomic compare-and-swap operations and volatile read/write on arrays.
Currently, that is the only way to do those operations. However, the Oracle JVM
development team is looking into ways to make this API safe and part of the Java
API.

Most of these operations can also be made through JNI native code. However,
using the unsafe API is more efficient because it avoids the cost of context
switch from Java to JNI and back. Besides, the JIT compiles some calls to the
unsafe API directly to JVM intrinsics[^intrinsics].

[^intrinsics]:

	From [wikipedia](http://en.wikipedia.org/wiki/Intrinsic_function):

	> In compiler theory, an intrinsic function is a function
  > available for use in a given programming language whose implementation is
  > handled specially by the compiler. Typically, it substitutes a sequence of
  > automatically generated instructions for the original function call, similar to
  > an inline function. Unlike an inline function though, the compiler has an
  > intimate knowledge of the intrinsic function and can therefore better integrate
  > it and optimize it for the situation. This is also called builtin function in
  > many languages.

	For instance, calling
	[System.identityHashCode](http://docs.oracle.com/javase/7/docs/api/java/lang/System.html#identityHashCode(java.lang.Object))
	is compiled to an intrinsic operation that just reads the hash code from the
	object header in a few native instructions, rather than to a method call.

HotSpot (and OpenJDK) JVM memory model
======================================

There is a code pattern when using the unsafe API to manipulate data in object
fields or arrays.  The code in TODO2 shows an example of that pattern. First, it
gets a base pointer with method TODO. Then, it gets the array scale factor with
method TODO. Finally, it computes the formula TODO to access position i on the
array.

A similar pattern applies to manipulating objects, as we can see in the
following example:

<pre><code class="java">
// For this to work, add the class to the bootstrap classloader by passing
// the option -Xbootclasspath/a:. to the java command
Unsafe u     = Unsafe.getUnsafe();
LinkedList l = new LinkedList();
Class c      = LinkedList.class;
Field f      = c.getDeclaredField("first");
long  offset = u.objectFieldOffset(f);

u.getObject(l, offset);
u.putObject(l, offset, null);

// Nothing prevents me writting a wrong type:
// u.putObject(l, offset, new Object());
</code></pre>

Again, it starts by getting the base pointer with method TODO. Then, it gets the
offset of the field within the object with method TODO. And finally, it
manipulates the field with method TODO.

This code pattern maps directly to the way the JVM lays objects in memory. The
following figure shows how objects and arrays look in memory:

TODO

Given the similarity between the HotSpot and the OpenJDK, I shall use the
OpenJDK names in the description of the object memory layout, with links to the
relevant header files in the OpenJDK source.  Every object starts with a fixed
sized header that has two fields, as defined by the header file
[src/share/vm/oops/oop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/oop.hpp):

* **_mark**:
	Defined in header file
[src/share/vm/oops/markOop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/markOop.hpp). One word (32 or 64 bits, depending on the architecture) that contains either:
	* Regular case:
		* **hash** Identity hash code
		* **age**  GC information about the age of the object
	* Locked object:
		* **ptr**  pointer to where the header is (either on the stack or wrapped by an inflated lock)
* **_klass**: Defined in header file
[src/share/vm/oops/klassOop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/klassOop.hpp).
Quoting the source: "A klassOop is the C++ equivalent of a Java class".
This is where the vtable is located, together with more low level information
about each object of each particular class, such as its size and the offset where
to find each field.

The header of an array also starts with the same two fields.  It has, however,
an extra field, as defined by header file 
[src/share/vm/oops/arrayOop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/arrayOop.hpp):

* **lenght**: Size of this particular array

Manipulating the object model
=============================

As you can imagine by now, Rubah uses the unsafe API to manipulate the metadata
on the object header. This is extremely unsafe [^portability] and getting it
right was itself an important implementation challenge. Doing this is also very
brittle because the unsafe API is not part of the standard Java API.  Future
versions of the HotSpot JVM are free to change how objects are layed out in
memory.

[^portability]:

	To work with a different JVM, Rubah needs to be ported to use the memory
	layout of objects on that JVM.  For instance, Rubah can be ported to the Jikes
	RVM , which has a similar object memory layout, but all the sun.misc.Unsafe
	operations have to be rewritten to use instead [VM
	Magic](http://en.wikipedia.org/wiki/Jikes_RVM#VM_Magic).

	We argue that Rubah is portable between JVMs because it does not require any
	modification to the JVM itself.  Other DSU systems for Java require a custom GC
	algorithm and are much harder to port to different JVMs.

In the following, I list all the different ways Rubah manipulates the header
using the unsafe API:

* **Direct field access**

	To migrate the program state, Rubah needs to traverse every object it finds.
	This means accessing every field, which might not be visible. The unsafe API
	enables Rubah to access every field of every object in a very fast way.

	Also, both the migration algorithms that Rubah has (parallel and lazy) use
	compare-and-swap to ensure correctness while migrating the program state. The
	unsafe API is the only way to perform this operation on regular fields.[^cas]

[^cas]:

	The only way to perform compare-and-swap in a Java program without using the
	unsafe API is to use class
	[java.util.concurrent.AtomicReference](https://docs.oracle.com/javase/7/docs/api/java/util/concurrent/atomic/AtomicReference.html#compareAndSet(V,%20V))
	,which is [internally implemented using the unsafe
	API](http://grepcode.com/file/repository.grepcode.com/java/root/jdk/openjdk/7u40-b43/java/util/concurrent/atomic/AtomicReference.java#AtomicReference.compareAndSet%28java.lang.Object%2Cjava.lang.Object%29).

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
	steady-state execution. Also, it does not work for arrays.[^overhead]

	Rubah now writes the identity hash-code of the new instance directly in the
	object header using the unsafe API. This works objects and arrays and removes
	the performance overhead.

<pre><code class="java">
// For this to work, add the class to the bootstrap classloader by passing
// the option -Xbootclasspath/a:. to the java command
Unsafe u     = Unsafe.getUnsafe();
Object o     = new Object();

// Valid for a 64 bit JVM with compressed oops
// Might not work for different architectures
long offset  = 1L;

int newHash  = 42;

int identityHashCode = System.identityHashCode(o);
int unsafeHashCode   = u.getInt(o, offset);

assert (identityHashCode == unsafeHashCode != newHash); 
u.putInt(o, offset, newHash);

int identityHashCode = System.identityHashCode(o);
int unsafeHashCode   = u.getInt(o, offset);

assert (identityHashCode == unsafeHashCode == newHash);
</code></pre>
	
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
	state overhead of 5%.[^overhead]

<pre><code class="java">
class A { /* empty */ }
class B { /* empty */ }

// For this to work, add the class to the bootstrap classloader by passing
// the option -Xbootclasspath/a:. to the java command
Unsafe u     = Unsafe.getUnsafe();
Object a     = new A();
Object b     = new B();

// Valid for a 64 bit JVM with compressed oops
// Might not work for different architectures
long offset  = 8L;

// Do not keep this around for long, it changes over time
int klass    = u.getInt(a, offset);

assert (a instanceof A);
assert (b instanceof B);

u.putInt(b, offset, klass);

assert (a instanceof A);
// If this code gets JITed, the following line may terminate the JVM with SIGSEGV
assert (b instanceof A);
</code></pre>

The code examples in this section were taken from a class in Rubah called
[UnsafeUtils](https://github.com/plum-umd/rubah/blob/master/src/main/java/rubah/runtime/state/migrator/UnsafeUtils.java).

[^overhead]:

	The steady-state overhead of the type-erasure **AND** hash-code field
	together was around 8%, and not 10% as the reader might expect.

How to make sun.misc.Unsafe safer
=================================

Useful as it might be, sun.misc.Unsafe is a proprietary API that will disappear
in future releases of the HotSpot JVM. There is a JEP draft (TODO link) to
"create a public API replacement for sun.misc.Unsafe to prevent people from
accessing a private package in form of a direct memory kind of buffer and a
support class for other sun.misc.Unsafe operations independently from buffer
like memory operations".

It looks like the main motivation for this JEP is to bring off-heap buffers to
the standard API. Off-heap buffers are out of the reach of the
garbage-collector, and using can improve performance or make performance more
predictable with no pauses for a garbage-collector cycle.

Rubah, however, relies on features of sun.misc.Unsafe that might disappear. In
this section, I propose some alternatives to make those features safe so that
they can be made part of the standard Java API. I do not comment on the
features Rubah uses that are planned to be ported to the standard API.

* **Identity hash-code**

	The simplest approach, assuming that a method similar to
	sun.misc.Unsafe.allocateInstance makes it to the standard API, is to add an
	integer argument that sets the identity hash-code to be the least significant 24
	bits (the size of a Java hash-code) of that integer argument. TODO: Check that
	the size of a Java hash-code is actually 24 bits.

	Assuming that this method does not make it to the standard API, Rubah could
	still allocate instances without running any real constructor by adding dummy
	constructors to every class that do not do anything interesting. Still, Rubah
	needs to set the identity hash-code of the new object being constructed.

	In this scenario, note that setting the identity hash-code of an object that
	has just been created, before the method that creates that object makes any
	reference to the new object visible to any other part of the program, is safe.
	The invariant that the identity hash-code does not change during the lifetime of
	the object is kept, except for the code that actually changes the identity
	hash-code. I claim that this behavior is safe and acceptable.

	The bytecode sequence that creates an object involves a NEW instruction and a
	INVOKESPECIAL instruction to invoke a constructor of the superclass on the newly
	created object. Between these two bytecodes, the object is instantiated but
	not constructed. The JVM uses escape analysis to ensure that no references to
	this object get leaked by, for instance, writing it to some field or passing it
	as argument to some function. This check is made by the bytecode verifier, and
	the JVM refuses to load any code that fails this check.

	This is the right moment to set the identity hash-code of the new object. One
	option is to add a special method to do this and pass the object to that method.
	However, this requires changing the bytecode verifier to allow this method
	invocation.

	Another option is to add an extra constructor to java.lang.Object that takes
	an integer and sets the identity hash-code to that value. The bytecode verifier
	remains unchanged, but we are now exposing a new constructor that should almost
	never be used. This problem could be mitigated by making this method invisible
	to the compiler and only accessible through method handles, which were added in
	Java 8 to allow invoking methods more efficiently than by using the reflection
	API.  TODO add link to description of method handles, check if method handles
	can be used to call constructors. And improve the description of what method
	handles are.

	Yet another option is to have the developer add a constructor that takes an
	integer as the first argument and has a special annotation to note that such
	argument is actually the identity hash-code of the object being constructed. Or,
	instead of an integer, that argument has a special type (e.g.
	java.lang.IdentityHashCode), so that it does not collide with any existing
	constructor that already takes an integer.

* **Changing the class of an object**

	The JVM keeps the invariant that the class of a given object does not change
	during the lifetime of that object. Therefore, no matter how safe we make this
	operation, it violates this invariant by design. This is our starting point in
	making this operation safe.

	Rubah gets away with it because it traverses the heap and fixes references to
	instances of java.lang.Class. So, if some structure maps classes to objects of
	that class, Rubah changes the class of every object and the instance of
	java.lang.Class associated with it (e.g.  Rubah supports updating instances kept
	in a java.util.EnumMap, which does something similar). TODO link to grepcode

	However, finding some way to relax this invariant would lead to efficient
	implementation of proxies. A proxy, in this sense, is a class that extends the
	proxied class, does not define any fields, and overrides all methods to redirect
	the invocation to some other new method that the developer can customize. From
	the point of view of the memory model, a proxy looks exactly the same as the
	proxied instance (same size, same fields at the same offset) except for the
	_klass pointer. Proxying an object, or turning an existing proxy into a real
	object would be as simple as a writing one pointer to memory.

	To change the class of an object safely to another class that defines a
	different set of fields in this way, by changing the _klass pointer, we have to
	place restrictions on how different the set of fields can be. The idea is that
	the representation of the object in memory should, at least, have the same size.
	So, we can require the new class to define the same number of fields of the same
	broad type (reference or same primitive type). TODO: change this broad type by a
	more approriate term.

	If this pre-condition is met, we can take a CLOS-like approach to map the
	fields: Pass, as an argument to the method that changes the class, a method
	handle that takes an array of java.lang.Object, in which each position is a
	field that the object has, and returns an array of java.lang.Object, in which
	each position is compatible with the respective field on the new type. TODO: add
	links to the CLOS meta-object protocol that does this, the common LISP should be
	available on-line.

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
