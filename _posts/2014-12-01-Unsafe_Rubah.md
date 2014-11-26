---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout:     post
title:      How Rubah uses sun.misc.Unsafe
tags:       java, unsafe, rubah, jvm
group:      "blog"
published:  false
---

What is sun.misc.Unsafe?
========================

It is an API that supports unsafe operations on the JVM.

List types of operations
* Direct memory access
* etc

These operations can also be made through native code, but the unsafe API avoids
the cost of context switch from Java to JNI and back.  The JIT also knows how to
emit efficient code for unsafe operations.

## Direct field access ##

* Sample code
* Read/write fields
* Explicit support for volatile read/writes
* Only way to volatile read/write on arrays
* Only way to CAS
* Extensively used on the java.util.concurrent library

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

How Rubah uses sun.misc.Unsafe
==============================

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
