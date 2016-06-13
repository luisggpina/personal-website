---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout: project
project: varan
---

With the widespread availability of multi-core processors, running multiple
diversified variants or several different versions of an application in parallel
is becoming a viable approach for increasing the reliability and security of
software systems. The key component of such N-version execution (NVX) systems is
a runtime monitor that enables the execution of multiple versions in parallel.

Unfortunately, existing monitors impose either a large performance overhead
and/or rely on intrusive kernel-level changes. Moreover, none of the existing
solutions scales well with the number of versions, since the runtime monitor
acts as a performance bottleneck.

Varan is an NVX framework that combines selective binary rewriting with a novel
event-streaming architecture to significantly reduce performance overhead and
scale well with the number of versions, without relying on intrusive kernel
modifications.
