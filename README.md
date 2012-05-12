About
=====

A toolchain using free/open source tools to generate both PDF and ebooks
(.mobi and soon .epub) from a single set of LaTeX sources.

We used this toolchain to create the hardcopy and Kindle editions of our
textbook [Engineering Long-Lasting Software](http://saasbook.info),
along with additional design elements and macros to give our book its
unique appearance.

Warning
-------

This brief guide assumes you are *very* comfortable with LaTeX and the
Unix development environment (using Makefiles to manage complex builds,
etc.)  and will teach you nothing about those things.  If you haven't
used LaTeX before, writing in LaTeX is more like programming than like
authoring.  If that scares you, this bundle's not for you.  If you're
not comfortable running Makefile-based builds, good luck.

There is no support.  Seriously.  None.  Pull requests are welcome since
many improvements are needed, but sadly I just don't have the time to
teach people to use this.  It has lots of moving parts and things that
can break.  When better ebook authoring tools come around I'll be happy
to switch!

Basic Idea
----------

The two major ebook file formats today are Mobipocket (.prc) and ePub
(.epub).  Amazon bought Mobipocket, added their own DRM to Mobipocket
format, and rebranded it as "Kindle format" (.azw files); ePub is an
open standard that allows for but doesn't require DRM.  Amazon has since
extended its format to add more support for HTML positioning, wrapping,
etc; this is the new KF8 (Kindle Format 8), which is essentially a
proprietary extension to Mobipocket that takes advantage of the
renderers on the Kindle Fire and Kindle reading apps.  Currently, this
toolchain doesn't have support for the new KF8 features.

Both formats are based on HTML markup for text and embedded assets
(images, etc).  tex4ht was designed to output HTML from LaTeX documents.
However, because of differences between "plain old" HTML 5 and the
individual formats, limitations/quirks of tex4ht, and limitations/quirks
of the rendering software on ebook readers, substantial surgery is
needed on the output of tex4ht, and some care is needed in your LaTeX
authoring.  The 'mobi_postprocess.rb' and 'html_postprocess.rb' scripts
perform this surgery using the powerful Nokogiri XML library as a base.

The toolchain works exclusively with the LaTeX "book" document class.
There are some extensions and some limitations on what you can do.
In general, every logical type of document element---chapter header,
figure, sidebar, code file listing, etc.---must be wrapped in its own
LaTeX macro, because the output instructions for ebook generation may
differ substantially from the instructions for PDF output.

If you stick to the book elements described below, you should be able to
use everything as-is.  If you want to customize/add behaviors, see
Customizing at the end of this README.

Requirements
============

A Unix-like system (Mac OS X is fine, but you need to have Unix-fu) and
full installs of the following:

- Ruby 1.9.2 or later, including the Rubygems library manager
- The Nokogiri gem (see setup instructions below)
- A full install of LaTeX2e with lots o'packages.  The MacTeX installer
is a great choice for Mac OS X users.
- pdftex - included with MacTeX
- A full install of Ghostscript and ImageMagick, for converting images
for ebook output
- A full install of tex4ht (may be included with MacTeX, I forget)
- The [kindlegen script](http://www.amazon.com/kindleformat/KindleGen)
for building the .mobi file


Setup
=====

1. With Ruby 1.9.2+ installed, cd to the script/ subdirectory and run
'bundle install' to make sure the Nokogiri gem is available.
2. In Makefile, change KINDLEGEN to the path to your kindlegen script.
3. In Makefile, change the paths to various other binaries as needed.
4. In each of the following files, search for ::EDITME:: and edit the
self-explanatory metadata:
+  common.tex
+ book_mobi.ncx.erb
+ book_mobi.opf
5. Add a cover file for the Kindle version called cover.jpeg in the top
level directory.  Ideally, it should be 600 pixels wide by 800 pixels
wide at 72 dpi.  A sample is included.  

IMPORTANT: The .mobi ebook file WILL NOT BUILD unless you at least have
dummy values/files for all of the above.  

Adding LaTeX files and assets
=============================

If you add your book content according to the following structure, you
won't need any Makefile changes.  If you follow your own structure,
you'll need to make substantial changes to the Makefile and to
common.tex.  Unless you want to burn a lot of time on this, do it my
way.

Add your book chapters, each in its own subdirectory, organized as
follows for a chapter called mychap:

ch_mychap/
ch_mychap/mychap.tex  - toplevel file for that chapter
ch_mychap/figs/      - figures (.pdf files ONLY--see below)
ch_mychap/tables/    - tables (usually just .tex files)
ch_mychap/code/    - tables (usually just .tex files)

IMPORTANT: you should include ALL the subdirs figs, tables, code for
each chapter, even if empty, or some Makefile rules will break!

