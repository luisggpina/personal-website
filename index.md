---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout: default
title: index
group: "index"
---

<img src="{{ site.baseurl }}/imgs/personal.jpg" style="display: block; margin-left: auto; margin-right: auto; width: 50%" />

I am currently an Assistant Professor with the [CS department at University of Illinois Chicago (UIC)](https://cs.uic.edu/), since August of 2019.

Previously, I was a post-doc at [George Mason University's Department of
Computer Science](https://cs.gmu.edu), from 2017 to 2019.  I was part of the
[Software Reliability Group (SRG)](https://srg.doc.ic.ac.uk/) at Imperial
College London, from 2015 to 2017, part of the [Programming Languages Group
(PLUM)](https://www.cs.umd.edu/projects/PL/) at University of Maryland from 2012
to 2015, and part of the [Software Engineering Group
(ESW)](http://www.inesc-id.pt/group.php?grp=II03) at INESC-ID in Lisbon from
2009 to 2012.

I hold a [PhD on Information Systems and Computer
Engineering](https://fenix.tecnico.ulisboa.pt/cursos/deic?locale=en_EN) from
[Instituto Superior Técnico, University of Lisbon,
Portugal](http://tecnico.ulisboa.pt/en).  I developed
[my dissertation]({{ site.baseurl}}/details/pina16phd.html)
under the supervision of [Prof. Luís Veiga]({{ site.data.authors['lveiga'].url }})
and [Prof. Michael Hicks]({{ site.data.authors['mwh'].url }}),
focusing on [making Dynamic Software Updates (DSU) practical]({{ site.baseurl }}/projects/rubah.html).

#### Contact

<table width="90%" style="border-spacing: 10px;">
	<tr>
		<td style="font-weight: bold;">E-mail:</td>
		<td>
            <a id="OGKCF" href="{{ site.baseurl }}"><span id="nxyh">[ point here]</span></a>
            <script type="text/javascript">showEmail("OGKCF", "nxyh", "axd~}dcl", "uic.edu", key, "Luís Pina");</script>
		</td>
	</tr>
	<tr>
		<td style="vertical-align: top; font-weight: bold; padding-right: 10px;">Address:</td>
		<td>
            Department of Computer Science<br/>
            University of Illinois at Chicago<br/>
            851 S. Morgan Street<br/>
            Chicago, IL 60607-7053, USA<br>
		</td>
	</tr>
	<tr>
		<td style="vertical-align: top; font-weight: bold; padding-right: 10px;">Office:</td>
        <td> Science and Engineering Offices, Room 1340</td>
	</tr>
</table>

### Research

I work in the broad areas of software systems, programming languages, and software engineering.
My research interests include: Fuzz testing and property testing, Dynamic Software Updating, Concurrent Programming (Multiprocessor Programming, Lock-free/Wait-free Algorithms and Data Structures), High Level Language Virtual Machines.

My full publication list is <a href="publications.year.html">available here.</a>

#### Projects

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


### Current students

<ul>
{% for key_val in site.data.students %}
    {% assign student = key_val[1] %}
    {% assign key     = key_val[0] %}
    {% if student.end == nil %}
        <li>({% case student.level %}
        {% when "phd" %}PhD{% when "ms" %}MS{% when "mst" %}MS with thesis{% when "bs" %}BS{% endcase %})
            {% include student_line.html %}
        </li>
    {% endif %}
{% endfor %}
</ul>

#### Past students
<ul>
{% for key_val in site.data.students %}
    {% assign student = key_val[1] %}
    {% assign key     = key_val[0] %}
    {% if student.end != nil %}
        <li>({% case student.level %}
        {% when "phd" %}PhD{% when "ms" %}MS{% when "mst" %}MS with thesis{% when "bs" %}BS{% endcase %})
            {% include student_line.html %}
        </li>
    {% endif %}
{% endfor %}
</ul>

### Funding

My research is generously supported by the following grants:
* [NSF: SHF: Small: Multi-Version eXecution for Managed Languages](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2227183)

### Teaching

**Current**: [CS454 - Principles of Concurrent Programming](https://cs474-uic.github.io/cs454-s24-site/)

* CS361 - Systems Programming: [Spring 2023](https://cs474-uic.github.io/cs361-s23-site/)
* CS454 - Principles of Concurrent Programming: [Spring 2024](https://cs474-uic.github.io/cs454-s24-site/), [Spring 2022](https://cs474-uic.github.io/cs454-spring2022-site/)
    * CS494 - Principles of Concurrent Programming: [Spring 2021](https://cs474-uic.github.io/cs494-spring2021-site/), [Spring 2020](https://luisggpina.github.io/cs494-s20-site/)
* CS473 - Compiler Design: [Fall 2022](https://cs474-uic.github.io/cs473-f22-site/)
* CS474 - Object-Oriented Languages and Environments: [Fall 2021](https://cs474-uic.github.io/cs474-fall2021-site/), [Fall 2020](https://cs474-uic.github.io/cs474-fall2020-site/), [Fall 2019](https://luisggpina.github.io/cs474-2019-site/)
* Software Reliability (440) at Imperial College London: [Fall 2016](http://multicore.doc.ic.ac.uk/SoftwareReliability/2016-2017/)
