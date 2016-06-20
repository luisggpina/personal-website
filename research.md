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

<h1>Publications</h1>

My full publication list is <a href="publications.year.html">available here.</a>

<h1>Projects</h1>

<ul>
{% for project in site.data.projects %}
	{% if project[1].active %}
  <li> <a href="projects/{{ project[0] }}.html">{{ project[1].title }}</a> </li>
	{% endif %}
{% endfor %}
</ul>

<h4>Past</h4>

<ul>
{% for project in site.data.projects %}
	{% if project[1].active == false %}
  <li> <a href="projects/{{ project[0] }}.html">{{ project[1].title }}</a> </li>
	{% endif %}
{% endfor %}
</ul>

<h1>Research Interests</h1>

* Dynamic Software Updating
* Concurrent Programming
    * Multiprocessor Programming
    * Lock-free/Wait-free Algorithms and Data Structures
    * Software/Hardware Transactional Memories
* High Level Language Virtual Machines
    * Garbage Collection
    * Just-In-Time Compiling
* Programming Languages
