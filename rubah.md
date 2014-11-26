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

Rubah
=====

Rubah is the first [Dynamic Software Update](dsu.html) system for Java that is:

* **Portable**, implemented via libraries and bytecode rewriting on top of a
standard JVM
* **Efficient**, imposing negligible overhead on normal, steady-state execution;
* **Flexible**, allowing nearly arbitrary changes to classes between updates;
* **Non-disruptive**, employing either a novel eager algorithm that transforms
the program state with multiple threads or a novel lazy algorithm that
transforms objects as they are demanded, after the update.

Links
-----

[Rubah @ Github](https://github.com/plum-umd/rubah)

Publications
------------

{% bibliography --style _bibliography/myapa.list.csl --file references.site --query @*[custom_project=rubah] %}
