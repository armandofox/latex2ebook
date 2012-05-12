TEX = latex
PDFLATEX = pdflatex
TEX4HT = tex4ht
T4HT = t4ht
BIBTEX = bibtex
PERL = 	perl
RUBY =  ruby
ERB = erb
KINDLEGEN = /Applications/kindlegen
CONVERT = convert
AVCONVERT = avconvert

OTHERFILES = # $(wildcard ch_*/figs/*) $(wildcard ch_*/tables/*) $(wildcard ch_*/code/*) $(wildcard ch_*/mov/*)
TEXFILES = $(shell find . -name \*.tex)
BIBFILES = book.bib
HTML_CONFIGS = book_html.cfg book_html.4ht
MOBI_CONFIGS = book_mobi.cfg book_mobi.4ht
PDF_CONFIGS = macros.tex 
SRCS = $(TEXFILES) $(BIBFILES) $(OTHERFILES)
CODEFILES = $(shell find ch_*/code/* -regex '.*/[^\#].*\..*[^~]$$')

TAGSRCS = $(SRCS) $(HTML_CONFIGS) $(MOBI_CONFIGS) $(PDF_CONFIGS) $(CODEFILES)

PDF_FIGURES = $(wildcard ch_*/figs/*.pdf)
PDF_GIF_FIGURES = $(patsubst %.pdf,%.pdf.gif,$(PDF_FIGURES))
PDF_ICONS = $(wildcard icons/*.pdf)
JPG_FIGURES = $(shell find $(wildcard ch_*/figs) -name '*jpg' -not -name '*_SB*')
SCALED_SIDEBAR_FIGURES = $(patsubst %.jpg,%_SB.jpg,$(JPG_FIGURES))

all: help

.PHONY: outline html mobi css pdf clean cleanup help newchapter only

help:
	@echo "'make html' creates www/ directory containing HTML5 version"
	@echo "'make mobi' creates book.mobi (for Kindle)"
	@echo "'make ibook' creates .rtfd files for importing into iWork Pages and then into iBooks Author"
	@echo "'make pdf' creates book.pdf"
	@echo "'make only CHAPTER=big_ideas' creates a draft PDF of just chapter 'big_ideas.tex'"
	@echo "      (NOTE: you must do 'make clean && make pdf' first)"
	@echo "'make update_pastebin' uploads all new code/ examples to Pastebin and updates LaTeX files in place (SAVE ALL YOUR FILES AND RUN git commit BEFORE DOING THIS)"
	@echo "'make outline' prints out TOC without chapter numbers"

outline: $(SRCS)
	@perl -ne 'print "$$1.tex " if /[^%][ *]\\include{(ch_.*\/.*)}/' common.tex | xargs $(PERL) script/outl.pl -n

only: $(SRCS)
	@echo '\\def\\onechap{TRUE} \\includeonly{ch_$(CHAPTER)/$(CHAPTER)}' > only.tex
	make pdf
	rm -f only.tex

onlyquick: $(SRCS)
	@echo '\\def\\onechap{TRUE} \\includeonly{ch_$(CHAPTER)/$(CHAPTER)}' > only.tex
	make 'QUICK=#' pdf
	rm -f only.tex

mobi: book_mobi.html css/mobi.css book_mobi.ncx book_mobi.opf $(SCALED_SIDEBAR_FIGURES) $(PDF_GIF_FIGURES)
	$(RUBY) script/mobi_postprocess.rb $<.bak > $<
	cat css/mobi.css >> mobi.css
	-$(KINDLEGEN) book_mobi.opf 
	mv book_mobi.mobi book.mobi

%.ncx: %.ncx.erb
	$(ERB) $<  >  $@

book_mobi.html: book_mobi.tex book_mobi.dvi $(MOBI_CONFIGS) 
	$(TEX4HT) $<
	$(T4HT) $<
	cp $@ $@.bak

book_html.html: book_html.tex book_html.dvi $(HTML_CONFIGS) 
	$(TEX4HT) $<
	$(T4HT) $<
	cp $@ $@.bak

.PHONY: html
html: book_html.html html_preamble.html footer.tex
	rm -f book_html.css
	$(RUBY) script/html_postprocess.rb book_html{ch,ap,li}*.html

html_postprocess: book_html.html book_htmlli*.html book_htmlch*.html book_htmlap*.html
	$(RUBY) script/html_postprocess.rb $^

find_undefined: book.pdf
	$(PDFLATEX) book_pdf | grep -i defined | grep -v 'Font shape' 2>&1

pdf: book_pdf.tex $(SRCS) $(PDF_CONFIGS)
	$(PDFLATEX) $(basename $<)
	$(QUICK) -for i in bu?*.aux ; do bibtex `basename $$i .aux` ; done
	$(QUICK) $(PDFLATEX) $(basename $<)
	$(QUICK) $(PDFLATEX) $(basename $<)
	mv $(basename $<).pdf book.pdf

%.dvi: $(SRCS) $(HTML_CONFIGS) $(MOBI_CONFIGS)
	$(TEX) $(basename $@)
	-for i in bu?*.aux ; do bibtex `basename $$i .aux` ; done
	$(TEX) $(basename $@)
	$(TEX) $(basename $@)
	rm -f only.tex

# image conversion
# convert fullsize PDF images to GIF (for Kindle)
%.pdf.gif: %.pdf
	$(CONVERT) -flatten -background '#ffffff' -transparent-color '#ffffff' -density 300x300 -resize 1024x $^ $@  2>/dev/null

# resize fullsize images to sidebar images (for Kindle)
%_SB.jpg: %.jpg
	$(CONVERT) -flatten -background '#ffffff'  -transparent-color '#ffffff' -resize x150 $^ $@ 2>/dev/null

.PHONY: update_pastebin clear_pastebin diff_pastebin
clear_pastebin:
	-$(RUBY) script/update_pastebin delete_all
	-$(RUBY) script/update_pastebin truncate_pastie_file

update_pastebin:
	@echo Uploading files to pastebin, this may take a couple of minutes...
	-$(RUBY) script/update_pastebin update $(CODEFILES)
	@echo Updating LaTeX files with Pastebin URIs, be sure to reload them in your editor....
	$(RUBY) -p -i.bak script/update_tex_with_pasties $(SRCS) && find . -name '*.tex.bak' -exec rm '{}' ';'

diff_pastebin:
	-$(RUBY) script/update_pastebin diff $(CODEFILES)

update_vimeo:
	@echo Updating LaTeX files with Vimeo URIs
	$(RUBY) -p -i.bak script/update_tex_with_screencasts $(SRCS) && find . -name '*.tex.bak' -exec rm '{}' ';'

TAGS: $(TAGSRCS)
	etags $^

.PHONY: check_blank_lines
check_blank_lines:
	@echo The following code files may have spurious blank lines at end:
	-@pcregrep -l -M '(^\s*$$){2,}\Z' $(CODEFILES)

# remove changebars
.PHONY: remove_changebars
remove_changebars:
	$(PERL) -p -i.bak -e 's/\\\\cb(start|end)\{\}//g' $(TEXFILES)

.PHONY: fulltags
fulltags:
	find . -name '.#*' -prune -o -name '*.tex' -o -name '*.bib' -o -name '*.rb' -type f | xargs etags 

veryclean: clean clean_figs 

clean_docs:
	rm -f book_pdf.pdf  book_html.html  book_mobi.html

clean_figs:
	rm -f ch_*/figs/*_SB.* ch_*/figs/*.pdf.gif ch_*/figs/*.jpg.gif icons/*_SB.*

clean: clean_docs
	rm -f \
only.tex \
*.bbl *.dvi *.idx *.ilg *.ind *.out *.ist *.bak \
*.cb *.cb2 *.glo *.glg *.gls *.mtc* bu*.blg \
book_*.{ps,ent,blg,toc,4ct,4tc,xref,idv,lg,tmp,css,lof,lot,lg,xref,ncx,maf} \
book_html*.gif zzbook* book_mobi*x.png \
book_html{ch,ap,li}*.html
	find . -name '*.bak' -or -name '*~' -or -name '*.log' -or -name '*.aux' | xargs rm -f

