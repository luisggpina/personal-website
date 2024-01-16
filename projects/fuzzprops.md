---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout: project
project: fuzzprops
---

Software tests are the de-facto means of assuring software quality.
We have tools to quantify how good a test suite is (e.g., mutation testing tools), and we have empirical data that the quality of test suites correlates with the quality of the code under test, even if testing cannot guarantee the absence of bugs.
Writing good tests, however, is hard.
Typical tests set up the program under test in a particular, deterministic way; and then check that the result matches the one expected value.
Unfortunately, important program errors happen due to unexpected behavior, perhaps when processing unexpected input.
Even if the developer writing the test can anticipate inputs that the developer writing the program did not, it is reasonable to assume that there is some other input that no developer anticipated.

*Property tests* operate at a higher level than regular tests.
A key idea behind property tests is that the developer does *not* need to determine apriori all of the possible inputs that the program should operate under.
The developer writes a *property* of the program that should hold for any inputs (e.g.,  *data round-trip*: deserializing a serialized list should yield the same contents of the original list), and a *generator* that uses a *source of randomness* to generate input data acceptable by the property (e.g., a list of integers with random size and random contents).
Then, the property testing framework generates many inputs that explore the input space, checking if these properties hold across all sampled inputs.
%The testing system then exercises the same property test multiple times, each time with different input data provided by the generator.
As such, the testing system can use property tests to find new inputs that no developer anticipated, that potentially violate the high-level property.
Initial property testing frameworks used purely random sampling to generate these inputs, but recent advances have shown that using coverage-guided feedback or concolic execution can greatly increase the coverage of existing property tests.
This work has even shown that the combination of property tests and greybox fuzzing can greatly outperform state-of-the-art greybox fuzzers that operate without property tests.

Property tests differ from traditional tests in that developer must write generators to create inputs and properties to check over those inputs.
State-of-the-art approaches to evaluate and improve test case adequacy (e.g., mutation analysis) cannot be directly applied to property tests.
Using coverage (or other feedback) as guidance to generate inputs differs from traditional feedback-driven fuzzing in that a subtle change to the input can result in a significant change to the generated value.
Without these scientific foundations, existing property testing frameworks are hard to improve.
Moreover, educational and training materials cannot train the next generation of developers on best practices for property testing without a clear understanding of what makes a ``good'' property test.
Our prior results have shown that by improving existing property testing frameworks, we can empower developers to quickly find subtle bugs in their code that escape traditional testing, preventing these bugs from impacting millions of users in the US every day.
