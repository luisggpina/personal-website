---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout: project
project: nlprepro
---

Developing and disseminating reproducible research is important across scientific fields.
It facilitates quality assurance and easy adoption of novel techniques, and it aids in deepening understanding of research methods and experimental findings.
However, demand and support for producing reproducible research is unevenly distributed.
Many computer science domains lag behind other areas of STEM in this regard, notably including AI research areas such as natural language processing (NLP) that are characterized by rapid, competitive growth and high compute needs.
Modern NLP research specifically relies on large datasets and non-deterministic models that are time-consuming and expensive to train.
For example, training GPT-3, a popular benchmark large language model (LLM) with 175 billion trainable parameters, costs approximately $12 million dollars on public cloud GPU or TPU models, and requires 350GB of memory.
Reproducing such a training process directly is environmentally wasteful, financially unfeasible for most research groups, and it diminishes the degree to which others can access and build upon this type of research.

This project addresses these shortcomings through a novel software platform that lowers the barrier to reproducibility in NLP research.
Our preliminary studies, inspired by the recent adoption of reproducibility checklists in the NLP community, motivate the need for such a platform.  
Reproducibility checklists require authors to provide an appendix with their source-code, a description of the computing infrastructure used, and their experimental configuration (e.g., the hyper-parameters, random seed, and number of runs), but they do not require self-contained and self-executable files.
Self-contained and self-executable files are the gold standard for reproducing results in short order while avoiding vulnerability to *bit rotting* as time passes and the gradual obsolescence of necessary tools and libraries.
Nonetheless, reproducibility checklists have positively affected source code availability, suggesting that the NLP community is willing and open to adopt new measures to support reproducibility.

Our proposed platform will generate self-contained artifacts using an adaptation of record/replay to capture necessary resources and move them into containers or VM images.
It will do this by identifying uses of non-determinism and employ innovative techniques to “fast-forward” deterministic execution when non-deterministic inputs are matched.
We anticipate that this will decrease the time and cost of reproducing large text classification and language models, while producing artifacts that are near the quality of those produced manually.
