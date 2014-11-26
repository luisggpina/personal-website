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

DuST'M - Dynamic Updates using Software Transactional Memory
============================================================

DuST'M is a [Dynamic Software Update](dsu.html) system for Java that uses a
multiversioned Software Transactional Memory ([JVSTM](jvstm.html)) to allow
software upgates that occur atomically, concurrently with the execution of the
program, and that convert the program's state lazily.

Publications
------------

{% bibliography --style _bibliography/myapa.list.csl --file references.site --query @*[custom_project=dustm] %}
