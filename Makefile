NAME=Mada
VERSION=1.4
LATIN=SourceSansPro

SRCDIR=sources
DOCDIR=documentation
BUILDDIR=build
TOOLDIR=tools
TESTDIR=tests
DIST=$(NAME)-$(VERSION)

PY ?= python
PREPARE=$(TOOLDIR)/prepare.py
MKSLANT=$(TOOLDIR)/mkslant.py

SAMPLE="صف خلق خود كمثل ٱلشمس إذ بزغت يحظى ٱلضجيع بها نجلاء معطار"

MASTERS=ExtraLight Regular Black ExtraLightItalic BlackItalic ExtraLightSlanted BlackSlanted
FONTS=ExtraLight Light Regular Medium SemiBold Bold Black \
      ExtraLightItalic LightItalic Italic MediumItalic SemiBoldItalic BoldItalic BlackItalic

UFO=$(MASTERS:%=$(BUILDDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.otf)
TTF=$(FONTS:%=$(NAME)-%.ttf)
TFV=$(NAME)-VF.ttf
PDF=$(DOCDIR)/FontTable.pdf
PNG=$(DOCDIR)/FontSample.png
SMP=$(FONTS:%=%.png)

export SOURCE_DATE_EPOCH ?= 0

all: otf vf doc

otf: $(OTF)
ttf: $(TTF)
vf:  $(TFV)
doc: $(PDF) $(PNG)

SHELL=/usr/bin/env bash

.SECONDARY:

define prepare_masters
echo "   MASTER    $(notdir $(4))"
mkdir -p $(BUILDDIR)
$(PY) $(PREPARE) --version=$(VERSION)                                          \
                 --feature-file=$(3)                                           \
                 --out-file=$(4)                                               \
                 $(1) $(2)
endef

define generate_fonts
echo "     MAKE    $(1)"
mkdir -p $(BUILDDIR)
pushd $(BUILDDIR) 1>/dev/null;                                                 \
PYTHONPATH=$(3):${PYTHONMATH}                                                  \
fontmake $(2)                                                                  \
         --output=$(1)                                                         \
         --verbose=WARNING                                                     \
         --feature-writer KernFeatureWriter                                    \
         --feature-writer markFeatureWriter::MarkFeatureWriter                 \
         --production-names                                                    \
         --optimize-cff=0                                                      \
         --keep-overlaps                                                       \
         ;                                                                     \
popd 1>/dev/null
endef

$(TFV): $(BUILDDIR)/variable_ttf/$(TFV)
	@cp $< $@

$(NAME)-%.otf: $(BUILDDIR)/master_otf/$(NAME)-%.otf
	@cp $< $@

$(NAME)-%.ttf: $(BUILDDIR)/master_ttf/$(NAME)-%.ttf
	@cp $< $@

$(BUILDDIR)/instance_ufo/$(NAME)-%.ufo: $(UFO) $(BUILDDIR)/$(NAME).designspace
	@echo "     INST    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) -c                                                              \
	  "from mutatorMath.ufo.document import DesignSpaceDocumentReader as R;\
	   r = R('$(BUILDDIR)/$(NAME).designspace', ufoVersion=3);             \
	   r.readInstance(('postscriptfontname', '$(basename $(@F))'))"

$(BUILDDIR)/master_otf/$(NAME)-%.otf: $(BUILDDIR)/instance_ufo/$(NAME)-%.ufo
	@$(call generate_fonts,otf,-u $(abspath $<),$(abspath $(TOOLDIR)))

$(BUILDDIR)/master_ttf/$(NAME)-%.ttf: $(BUILDDIR)/instance_ufo/$(NAME)-%.ufo
	@$(call generate_fonts,ttf,-u $(abspath $<),$(abspath $(TOOLDIR)))

$(BUILDDIR)/variable_ttf/$(TFV): $(UFO) $(BUILDDIR)/$(NAME).designspace
	@$(call generate_fonts,variable,-m $(NAME).designspace,$(abspath $(TOOLDIR)))

$(BUILDDIR)/$(NAME)-ExtraLightItalic.ufo: $(BUILDDIR)/$(NAME)-ExtraLight.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ -15

$(BUILDDIR)/$(NAME)-BlackItalic.ufo: $(BUILDDIR)/$(NAME)-Black.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ -15

$(BUILDDIR)/$(NAME)-ExtraLightSlanted.ufo: $(BUILDDIR)/$(NAME)-ExtraLight.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ 15

$(BUILDDIR)/$(NAME)-BlackSlanted.ufo: $(BUILDDIR)/$(NAME)-Black.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ 15

$(BUILDDIR)/$(NAME)-%.ufo: $(SRCDIR)/$(NAME)-%.ufo $(SRCDIR)/$(LATIN)/Roman/Instances/%/font.ufo $(SRCDIR)/$(NAME).fea $(PREPARE)
	@echo "     PREP    $(@F)"
	@rm -rf $@
	@mkdir -p $(BUILDDIR)
	@$(PY) $(PREPARE) --version=$(VERSION) --out-file=$@ $< $(word 2,$+)

$(BUILDDIR)/$(NAME).designspace: $(SRCDIR)/$(NAME).designspace
	@echo "      GEN    $(@F)"
	@mkdir -p $(BUILDDIR)
	@cp $< $@

$(PDF): $(NAME)-Regular.otf
	@echo "   SAMPLE    $(@F)"
	@mkdir -p $(DOCDIR)
	@fntsample --font-file $< --output-file $@.tmp                         \
		   --write-outline --use-pango                                 \
		   --style="header-font: Noto Sans Bold 12"                    \
		   --style="font-name-font: Noto Serif Bold 12"                \
		   --style="table-numbers-font: Noto Sans 10"                  \
		   --style="cell-numbers-font:Noto Sans Mono 8"
	@mutool clean -d -i -f -a $@.tmp $@
	@rm -f $@.tmp

$(PNG): $(OTF)
	@echo "   SAMPLE    $(@F)"
	@for f in $(FONTS); do \
	  hb-view $(NAME)-$$f.otf $(SAMPLE) --font-size=130 > $$f.png; \
	 done
	@convert $(SMP) -define png:exclude-chunks=date,time -gravity center -append $@
	@rm -rf $(SMP)

dist: otf ttf vf doc
	@echo "     DIST    $(NAME)-$(VERSION)"
	@mkdir -p $(NAME)-$(VERSION)/{ttf,vf}
	@cp $(OTF) $(PDF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp $(TFV)  $(NAME)-$(VERSION)/vf
	@cp OFL.txt $(NAME)-$(VERSION)
	@sed -e "/^!\[Sample\].*./d" README.md > $(NAME)-$(VERSION)/README.txt
	@@echo "     ZIP    $(NAME)-$(VERSION)"
	@zip -rq $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(BUILDDIR) $(OTF) $(TTF) $(TFV) $(PDF) $(PNG) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
