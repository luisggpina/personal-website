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
raphael:		true
comments: True
---

[Rubah]({{ site.url }}/rubah.html) is a Dynamic Software Updating system for Java that works on the stock
Oracle HotSpot JVM, does not add any measurable overhead when running a program,
and performs dynamic software updates efficiently.

In this post, I explain how Rubah uses the low-level unsafe operations available
in class `sun.misc.Unsafe` (which I shall refer to as the unsafe API) to
implement the optimizations that make it so efficient.  I start by explaining
what the unsafe API is and how to use it, then I describe the object memory
layout of the Oracle HotSpot JVM and how to explore it with the unsafe API, then
I discuss how Rubah does that to improve its performance, and finally I propose
how to make some of the unsafe operations safer in a way that is compatible with
Rubah.

What is sun.misc.Unsafe?
========================

The class `sun.misc.Unsafe` is a proprietary API that enables a Java program to
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
unsafe API to avoid any bounds check:

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

While this is faster than regular Java array manipulation, it may lead to
out-of-bounds accesses that [can be exploited
maliciously](http://en.wikipedia.org/wiki/Heartbleed).

The unsafe API is used extensively throughout the `java.util.concurrent` package
to perform atomic compare-and-swap operations and volatile read/write on arrays.
Currently, that is the only way to do those operations. However, the Oracle JVM
development team is looking into ways to make this API safe and part of the Java
API.

Most of the low-level memory operations can also be made through JNI native
code. However, using the unsafe API is more efficient because it avoids the cost
of switching context from Java to JNI and back. Besides, the JIT compiles some
calls to the unsafe API directly to JVM intrinsics[^intrinsics].

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

HotSpot JVM object memory layout
================================

There is a code pattern when using the unsafe API to manipulate data in object
fields or arrays.  The code above shows an example of that pattern: First, it
gets a base pointer with method `arrayBaseOffset`, then, it gets the array scale
factor with method `arrayIndexScale`, and ,finally, it computes the formula
`base + i * scale` to manipulate position `i` on the array with methods `getInt`
or `putInt`.

A similar pattern applies to manipulating objects, the following example shows:

<pre><code class="java">
// For this to work, add the class to the bootstrap classloader by passing
// the option -Xbootclasspath/a:. to the java command
Unsafe u       = Unsafe.getUnsafe();
LinkedList obj = new LinkedList();
Class c        = LinkedList.class;
Field f        = c.getDeclaredField("first");
long  offset   = u.objectFieldOffset(f);

u.getObject(obj, offset);
u.putObject(obj, offset, null);

// Nothing prevents me from writting a wrong type:
// u.putObject(obj, offset, c);
</code></pre>

For manipulating object fields, we do not get a base pointer and a scale factor.
We get, instead, the offset of each individual field with method
`objectFieldOffset`.  We can then manipulate object fields using methods
`getObject` and `putObject`.  Note that these are the same methods as in the
previous example: If field `first` had type `int`, we would use methods `getInt`
and `putInt`.

Both these code patterns map directly to how the JVM lays objects in memory. The
following figure shows how objects look in memory (memory addresses of
variables/fields from the code above are writen in a C-like style with a
preceding `&`):

<div id="obj_layout" style="width: 100%; height: 150px" >
</div>

<script type="text/javascript">
	var w = 700;
	var h = 150;
	var w_bit = 2;
	var w_len = 64 * w_bit;
	function addLabelToWord(word, label) {
		var bbox    = word.getBBox();
		var label_x = bbox.x + (bbox.width/2);
		var label_y = bbox.y + (bbox.height/2);
 
		paper.text(label_x, label_y, label).attr({
			"font-size": 16,
			"text-anchor": "middle"
		});
	}
	function addLabelToBits(word, start, end, label, level) {
		var bbox    = word.getBBox();
		var level		= 10 + 30 * level;
		var start_x	= bbox.x + (start * w_bit) + 1;
		var end_x		= bbox.x + (end * w_bit) - 1;
		var y 			= bbox.y + bbox.height + level;
		var label_x	= start_x + ((end - start) * w_bit / 2);
		var label_y	= y + 10;
 
		paper.path("M"+start_x+","+y+"L"+end_x+","+y).attr({
			//"arrow-end": "classic-wide-long",
			//"arrow-start": "classic-wide-long"
		});
 
		paper.text(label_x, label_y, label).attr({
			"font-size": 14,
			"text-anchor": "middle"
		});
	}
  var paper = new Raphael('obj_layout');
	paper.setViewBox(0, 0, w, h, true);
	paper.canvas.setAttribute('preserveAspectRatio', 'none');	

	var mark	= paper.rect(30, 40, w_len, 30).attr({
      fill : "white",
      stroke : "black",
      strokeWidth : 2
  });
	addLabelToWord(mark, "_mark", true);
	addLabelToBits(mark,  0, 31, "hash", 0);
	addLabelToBits(mark, 31, 35, "age",  0);
	addLabelToBits(mark, 59, 63, "001",  0);

	addLabelToBits(mark,  0, 59, "ptr",  1);
	addLabelToBits(mark, 59, 63, "lock", 1);

	var klass = mark.clone();
	klass.transform("t" + w_len + ",0");
	addLabelToWord(klass, "_klass");

	var field2 = klass.clone();
	field2.transform("t" + 2.75 * w_len + ",0");
	addLabelToWord(field2, "...");

	var field1 = klass.clone();
	field1.transform("t" + 2 * w_len + ",0");
	addLabelToWord(field1, "first");

	var fieldN = klass.clone();
	fieldN.transform("t" + 3.5 * w_len + ",0");
	addLabelToWord(fieldN, "last");

	var bbox = mark.getBBox(false);
	paper.path("M"+bbox.x+",20L" + bbox.x + ","+(bbox.y-5)).attr({
		"arrow-end": "classic-wide-long"
	});
	paper.text(bbox.x, 10, '&obj').attr({
		"font-size": 14,
		"text-anchor": "middle"
	});

	var bbox = field1.getBBox(false);
	paper.path("M"+bbox.x+",20L" + bbox.x + ","+(bbox.y-5)).attr({
		"arrow-end": "classic-wide-long"
	});
	paper.text(bbox.x, 10, '&obj + offset').attr({
		"font-size": 14,
		"text-anchor": "middle"
	});
	
	

</script>

Given the similarity between the HotSpot and the OpenJDK, I shall use the
OpenJDK names in the description of the object memory layout, with links to the
relevant header files in the OpenJDK source.  Every object starts with a fixed
sized header that has two fields, as defined by the header file
[src/share/vm/oops/oop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/oop.hpp):

* **_mark**:
	Defined in header file
[src/share/vm/oops/markOop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/markOop.hpp).
One word that contains either:
	* Unlocked object:
		* **hash**: Identity hash code;
		* **age**:  GC information about the age of the object;
		* Some unused bits to keep the field word-aligned;
	* Locked object[^locking]:
		* **ptr**:  pointer to where the header is (either on the stack or wrapped by an inflated lock);
		* **lock**: state of the lock (biased/inflated), 001 means not locked;
* **_klass**: Defined in header file
[src/share/vm/oops/klassOop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/klassOop.hpp).
Quoting the source: "A klassOop is the C++ equivalent of a Java class".
This is where the vtable is located, together with more low level information
about each object of each particular class, such as its size and the offset where
to find each field.

[^locking]:
	Locking in the JVM is complex, using both biased and thin locks, which I
	do not discuss in this post for the sake of simplicity.  From the JVM
	documentation:

	> **-XX:+UseBiasedLocking** Enables a technique for improving the performance
	> of uncontended synchronization. An object is "biased" toward the thread
	> which first acquires its monitor via a `monitorenter` bytecode or
	> `synchronized` method invocation; subsequent monitor-related operations
	> performed by that thread are relatively much faster on multiprocessor
	> machines. Some applications with significant amounts of uncontended
	> synchronization may attain significant speedups with this flag enabled; some
	> applications with certain patterns of locking may see slowdowns, though
	> attempts have been made to minimize the negative impact.

	Thin locks are explained in the paper [Thin locks: featherweight
	Synchronization for
	Java](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.42.1683)

Arrays also have a header that starts with the same two fields, followed by an
extra field, as defined by header file
[src/share/vm/oops/arrayOop.hpp](http://hg.openjdk.java.net/jdk7u/jdk7u/hotspot/file/f49c3e79b676/src/share/vm/oops/arrayOop.hpp):

* **lenght**: Number of elements in this particular array

Manipulating the object model
=============================

Rubah uses the unsafe API to manipulate the metadata on the object header. This
is extremely unsafe[^portability] and getting it right was itself an important
implementation challenge. This is also brittle because the unsafe API is
not part of the standard Java API.  Future versions of the HotSpot JVM are free
to change how objects are layed out in memory.

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
	This means accessing every field, which may not be publicly visible. The unsafe
	API gives Rubah unrestricted and efficient access to every field of every
	object.

	Also, both migration algorithms that Rubah has (parallel and lazy) use
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
	so by creating a new object in the new version that will replace the outdated
	one, and then migrating the state of the old object to the new one. When
	traversing the program state, Rubah replaces all references to the old object by
	references to the new one. This way, if two references are `==` to each other in
	the old version, they will also be `==` after the update takes place.

	However, the identity hash-code of such two objects will differ, and this can
	break the program semantics.  For instance, if the class does not override the
	`hashCode()` method and the program keeps these objects in a `java.util.HashMap`,
	which is perfectly valid, then Rubah would break the semantics of the program:
	After the update, the objects will be on the wrong buckets of the HashMap and,
	therefore, impossible to find.

	Initially, Rubah solved this problem by rewritting the bytecode of all classes
	to add an extra field to keep the identity hash-code and to change every
	constructor to initialize such field.  Rubah also added an `hashCode()` method
	to all classes that did not have any that just returned the value of the extra
	field.  With this semantics preserving rewritting, migrating the identity
	hash-code between versions is just a matter of copying a field. However, this
	prevents the JIT compiler to use intrinsics to access the identity hash-code
	efficiently and prevented the JVM from initializing hash-codes lazily. As a
	result, this added about 5% overhead to steady-state execution. Also, it does
	not work for arrays.[^overhead]

	Rubah now writes the identity hash-code of the new instance directly in the
	object header using the unsafe API. This works objects and arrays and removes
	the performance overhead.  The following code example, adapted from a class in
	Rubah called
	[UnsafeUtils](https://github.com/plum-umd/rubah/blob/master/src/main/java/rubah/runtime/state/migrator/UnsafeUtils.java),
	shows how Rubah does that:

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

	Rubah's' lazy program state migration algorithm introduces the concept of
	proxies, used to intercept method invocations on outdated objects that need
	migration. Each proxy class extend the proxied class and override all methods so
	that Rubah can intercept method calls. At the object layout level, this means
	that proxies have the same fields on the same offset but a different `_klass`.
	So, all Rubah needs to do is to install the proxy `_klass` on existing objects
	to turn them into proxies.

	Besides proxies, Rubah also changes the class of existing objects for another
	reason.  Between two versions, the vast majority of objects do not need to be
	migrated because their class was not updated. However, consider the following
	example: Class **A** changed, class **B** did not change and has a field of type
	**A**. Of course, we have to migrate every instance of **A**. However, class
	**B** has the same layout in memory in both versions. Rubah just needs to
	update the code of class **B** to use the field with the correct new type.

	Both this scenarios illustrate the need for Rubah to change the class of
	existing objects by using the unsafe API to adjust the `_klass` field on the
	object header. This is the most brittle optimization that Rubah performs. In fact,
	getting it to work was a challenge. In part, because the code the JIT compiler
	emits assumes that the `_klass` does not change during the execution of a method.
	If it does, the JVM crashes. So, Rubah is carefully implemented in a way
	that prevents the code that changes the `_klass` from ever being inlined with
	application code.

	Besides the JIT compiler, the garbage collector uses the `_klass` to access
	the size and structure of objects it visits. However, this is not as problematic
	because both the old and the new `_klass` fields agree on the same information
	the GC needs to do its job.  Therefore, the regular GC operation does not cause
	the JVM to crash when Rubah modifies the `_klass` field.

	Note that the alternative to deal with instances of unchanged classes between
	versions would be to either: (1) Copy them or (2) erase the type of all fields
	to `java.lang.Object` and inject the appropriate type cast before every bytecode
	that manipulates fields.  Option (1) would always require a deep copy of the
	whole heap at every update, so we discarded it from the start. Early versions of
	Rubah implemented option (2), which added a steady state overhead of
	5%.[^overhead]

	The following code examples, adapted from class
	[UnsafeUtils](https://github.com/plum-umd/rubah/blob/master/src/main/java/rubah/runtime/state/migrator/UnsafeUtils.java)
	in Rubah, shows how to change the class of an existing object by manipulating
	the `_klass` field:
	
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


[^overhead]:

	The steady-state overhead of the type-erasure **AND** hash-code field
	together was around 8%, and not 10% as the reader might expect.

How to make sun.misc.Unsafe safer
=================================

Useful as it may be, `sun.misc.Unsafe` is a proprietary API that will disappear
or be modified in future releases of the HotSpot JVM.  Rubah relies on features
of the unsafe API that might disappear.  So, in this section, I propose some
alternatives to make those features safe so that they can be made part of the
standard Java API.

* **Identity hash-code**

	The simplest approach, assuming that a method similar to
	`sun.misc.Unsafe.allocateInstance` makes it to the standard API, is to add an
	integer argument that sets the identity hash-code to be the least significant
	bits (the size of a Java hash-code) of that integer argument:

	<pre><code class="java">
// allocate instance without running constructors
public Object allocateInstance (Class cls);
public Object allocateInstance (Class cls, int hashCode);
	</code></pre>

	Assuming that this method does not make it to the standard API, Rubah could
	still allocate instances without running any real constructor by injecting dummy
	constructors to every class that do not do anything interesting. However, Rubah
	needs to set the identity hash-code of the new object being constructed.

	In this scenario, one key observation is that it is safe to set the identity
	hash-code of any object being constructed before any reference to that object
	escapes the constructor.  The invariant that the identity hash-code does not
	change during the lifetime of the object is kept, except for the constructor
	code that actually changes the identity hash-code. I claim that this behavior is
	safe and acceptable.

	The bytecode sequence that creates an object involves a `NEW` instruction and
	a `INVOKESPECIAL` instruction to invoke a constructor of the superclass on the
	newly created object.  Between these two bytecodes, the object is instantiated
	but not constructed.  The JVM performs escape analysis to reject any bytecode
	that leaks references to this object by writing it to some field or passing it
	as an argument to some method.

	This is the right moment to set the identity hash-code of the new object. One
	option is to add a special API method.  However, this involves passing the
	instantiated but not constructed object to that method, which makes the bytecode
	verifier to reject such bytecode.  This option thus require modifications to the
	bytecode verifier:

	<pre><code>
NEW java.lang.Object
DUP
ICONST 42
INVOKESTATIC java.lang.System.setIdentityHashCode
INVOKESPECIAL java.lang.Object()
	</code></pre>

	Another option is to add an extra constructor to `java.lang.Object` that takes
	an integer and sets the identity hash-code to that value. The bytecode verifier
	remains unchanged, but we are now exposing a new constructor that should almost
	never be used. This problem could be mitigated by making this method invisible
	to the compiler and only accessible through reflection:

	<pre><code class="java">
Object.class
	.getConstructor(new Class[]{ Integer.class })
	.invoke(new Object[]{ new Integer(42) });
	</code></pre>

	Yet another option is to have the developer add a constructor that takes an
	integer as the first argument and has a special annotation to note that such
	argument is actually the identity hash-code of the object being constructed. Or,
	instead of an integer, that argument has a special type (e.g.
	`java.lang.IdentityHashCode`), so that it does not collide with any existing
	constructor that already takes an integer:

	<pre><code class="java">
public class A {
	@IdentityHashCodeConstructor
	public A(java.lang.IdentityHashCode hash) {
	}
}
	</code></pre>

* **Changing the class of an object**

	The JVM keeps the invariant that the class of any given object does not change
	during the lifetime of that object. Therefore, no matter how safe we make this
	operation, it violates this invariant by design. This is our starting point in
	making this operation safe.

	Rubah gets away with it in part because it traverses the heap and fixes
	references to instances of `java.lang.Class`. So, if some structure maps classes
	to objects of that class, Rubah changes the class of every object and all
	references to the instance of `java.lang.Class` associated with the outdated
	class (e.g.  Rubah supports updating instances kept in instances of
	`java.util.EnumMap`, which does something similar).

	However, finding some way to relax this invariant allows efficient
	implementations of proxies. A proxy, in this sense, is a class that extends the
	proxied class, does not define any fields, and overrides all methods to redirect
	the invocation to some other new method that the developer can customize. From
	the point of view of the object memory layout, a proxy looks exactly the same as
	the proxied instance (same size, same fields at the same offset) except for the
	`_klass` field in the object header. Proxying an object, or turning an existing
	proxy into real objects, can be as simple as a writing over the `_klass` field.

	<pre><code class="java">
void changeClass(E object, Class<? extends E> newClass)
	throws IllegalArgumentException;
	</code></pre>

	To change the class of an object safely to another class that defines a
	different set of fields in this way, by changing the `_klass` field, we have to
	place restrictions on how different the set of fields can be. The idea is that
	the representation of the object in memory should, at least, have the same size.
	So, we can require the new class to define the same number of fields of the same
	broad type (reference or same primitive type).

	If this pre-condition is met, we can take a [CLOS-like
	approach](https://www.cs.cmu.edu/Groups/AI/html/cltl/clm/node300.html) to map
	the fields: Pass, as an argument to the method that changes the class, an
	object that implements method `mapFields` which takes two maps from fields to
	their values and initalizes the new map given the values on the old map:

	<pre><code class="java">
interface Mapper {
	void mapFields(
		Map<Field, Object> oldMap, 
		Map<Field, Object> newMap);
}
void changeClass(E object, Class<? extends E> newClass, Mapper mapper)
	throws IllegalArgumentException;
	</code></pre>

----------------------------------

