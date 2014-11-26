---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout: default
title: research
group: "research"
---

JVSTM - Java Versioned Software Transactional Memory
====================================================

The Java Versioned Software Transactional Memory (JVSTM) is a pure Java library
implementing an STM. JVSTM introduces the concept of versioned boxes, which
are transactional locations that may be read and written during transactions,
much in the same way of other STMs, except that they keep the history of values
written to them by any committed transaction.

Links
-----
[JVSTM homepage](http://inesc-id-esw.github.io/jvstm/)

[JVSTM @ Github](https://github.com/inesc-id-esw/jvstm)

Publications
------------

{% bibliography --style _bibliography/myapa.list.csl --file references.site --query @*[custom_project=jvstm] %}
