#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2014, 2015, 2016 Karl Eichwalder <ke@suse.de>
# Copyright (c) 2015, 2016, 2017, 2018 Stefan Knorr <sknorr@suse.de>
#

DAPS_COMMAND=daps

XSLTPROC_COMMAND = xsltproc \
--stringparam generate.toc "/article toc" \
--stringparam generate.section.toc.level 0 \
--stringparam section.autolabel 1 \
--stringparam section.label.includes.component.label 2 \
--stringparam variablelist.as.blocks 1 \
--stringparam toc.section.depth 2 \
--stringparam toc.max.depth 3 \
--stringparam show.comments 0 \
--stringparam profile.os "$(PROFOS)" \
--xinclude --nonet

prereqs = DC-release-notes adoc/MAIN.release-notes.adoc
daps_xslt_rn_dir = /usr/share/daps/daps-xslt/relnotes

text_params =

webaccessparams = --stringparam="homepage=https://www.suse.com" \
  --stringparam="overview-page=https://www.suse.com/releasenotes" \
  --stringparam="overview-page-title=Back\ to\ Release\ Notes\ for\ SUSE\ products"

.PHONY: clean pdf text single-html validate

all: single-html pdf text

validate: $(prereqs)
	$(DAPS_COMMAND) -d $< validate

pdf: build/release-notes/release-notes_color_en.pdf
build/release-notes/release-notes_color_en.pdf: $(prereqs)
	$(DAPS_COMMAND) -vv -d $< pdf

single-html: build/release-notes/single-html/release-notes/index.html
build/release-notes/single-html/release-notes/index.html: $(prereqs)
	$(DAPS_COMMAND) -d $< html --single \
	  --param="toc.section.depth=2"

text: build/release-notes/release-notes.txt
# We need the text in ASCII to avoid issues when this is shown in text-only
# YaST.
build/release-notes/release-notes.txt: $(prereqs)
	$(DAPS_COMMAND) -d $< text $(text_params)
	iconv -f UTF-8 -t ASCII//TRANSLIT -o /dev/stdout $@ > $@.tmp
	mv $@.tmp $@

clean:
	rm -rf build/
