---
# Copyright 2014 Luís Pina
#
# This file is licensed under the Creative Commons Attribution-NoDerivatives 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-nd/4.0/.
#
layout: post
title: Presenter software for PDF slideshows
tags: beamer, latex, open-pdf-presenter, pdf, presentation
group: "blog"
---

Hello!

I use [Latex](http://www.latex-project.org/) to write all my
technical documents. I use it also <a
href="https://bitbucket.org/rivanvx/beamer/overview">to make slides</a> that I
show at my presentations. So, I end up with a PDF that contains the slides.

# The problem #

To show a PDF slideshow, we require some support from the PDF reader software.
At the very minimum, it needs to support fullscreen, which the vast majority
does. Some go a little further. For instance,<a
href="http://okular.kde.org/">Okular</a> shows the current slide number and a
visual representation of how many slides are still left.

But that's it. If we take a look at other presentation software, such as&nbsp;as
[Libre Office](http://www.libreoffice.org/)'s Impress, we see that it
takes advantage of a second monitor to show a presenter's console that features:
The current and next slide, the time elapsed and remaining, the notes that we
wrote for each slide, and some other information.

Using two monitors to present your slides is a very common usage scenario (laptop connected to a overhead projector) and the presenter screen is really, really useful. I can't stress that enough.

# The (incomplete) solutions #

Let's take a look at what software is there available specifically for presenting PDF slides, splitted into three classes:

* Slide transition effects:
	* [Impressive](http://impressive.sourceforge.net/)
	* [KeyJnote](http://freshmeat.net/projects/keyjnote/)
	* [BOSS Presentation Tool](http://sourceforge.net/projects/bosskeyjnotegui/)
	* [Projector](http://sourceforge.net/projects/pdf-projector/)
* Presenter console support:
	* [pdf-presenter-console](http://westhoffswelt.de/projects/pdf_presenter_console.html): Supports current and next slide, and displays time information. Does not support notes.
	* [pdf-presenter](http://code.google.com/p/pdf-presenter/): Uses two windows, one for the presenter console and other for the slide. Support current and next slide, and loads notes directly from the PDF (I have not tried this option). Does not display time information.
* Unsupported/abandoned:
	* [Haga](http://sourceforge.net/projects/haga/)
	* [PDFBeamer](http://sourceforge.net/projects/pdfbeamer/)
	* [splitshow](http://code.google.com/p/splitshow/)

The first class of programs bring some "eye-candy" to your presentations. I have
used impressive, and it works really well. It pre-loads all the slides, so
changing slides is really fast. It also animates the slide transition. A fast
crossfading between slides looks great, more elaborate transitions just looks
like showing off. I have not tried any of the others, but I guess they all
should do more or less the same.

Pdf-presenter-console and pdf-presenter support a presenter console. However,
none has all the features that I value. One supports notes but does not support
time information, the other supports time information but does not support
notes.

# My solution #

I could not find any PDF presenter program with all the features that I would
like to have. So I made my own!

I present you the brand new
[open-pdf-presenter](http://code.google.com/p/open-pdf-presenter/).  Version 0.1
was release yesterday! You can find [on the
wiki](http://code.google.com/p/open-pdf-presenter/w/list) instructions about
building and running it.

Here are some screenshots:

<div style="text-align: center;">
<a href="http://open-pdf-presenter.googlecode.com/files/mainSlide.png"><img height="225" src="http://open-pdf-presenter.googlecode.com/files/mainSlide.png" width="360" /></a>
<a href="http://open-pdf-presenter.googlecode.com/files/presenterConsole.png"><img height="225" src="http://open-pdf-presenter.googlecode.com/files/presenterConsole.png" width="360" /></a>
<p>&nbsp;</p>
</div>

Currently, it displays a presenter console with the current slide, the next
slide, the elapsed/remaining time, and how many slides are left. In the near
future, it will support notes on a separate file and some other nice features
from existing software:

* Fade slide screen to white/black (useful when projecting on white/black boards)
* Grid with thumbnails of all the slides (useful when someone in the audience wants to show that first slide after the second performance chart)

It is open-source, so feel free to inspect and modify my code. It uses git as the revision control system. If you make an useful and working patch, just [use git to format that patch](http://openhatch.org/wiki/How_to_generate_patches_with_git_format-patch) and email it to me.

I welcome all feedback (bug reports, feature requests, patches, <strike>trolling</strike>, <strike>rants</strike>,&nbsp;<strike>death
threats</strike>) so feel free to leave your own. I'll keep you posted when I
make another release.
