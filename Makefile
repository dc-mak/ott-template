# Some stuff from here
# https://clarkgrubb.com/makefile-style-guide

.SUFFIXES: .ml .ott .pdf .tex .cache .log

PREFIX := ott

FLAGS := -quiet
ifneq (,$(findstring B,$(MAKEFLAGS)))
    FLAGS := $(FLAGS) -g
endif

BUILD := _build

GEN := $(BUILD)/_gen

CACHE := $(BUILD)/ott.cache

OTTS := grammar.ott rules.ott operational.ott misc.ott

PDFS := defns.pdf soundness.pdf

all: $(PDFS) $(GEN)/grammar.ml

.PHONY: all

.SECONDEXPANSION:
$(PDFS):%.pdf: $(GEN)/$$*.tex \
    $(GEN)/$(PREFIX)_included.tex \
    $(GEN)/$(PREFIX)_override.tex \
    $(GEN)/$(PREFIX)_drulenames.tex | $(BUILD)
	max_print_line=10000 latexmk -pdf -dvi- -ps- $< -output-directory=$(BUILD) $(FLAGS) \
	    || (less +'/Error:|Undefined|Runaway argument|! ' $(BUILD)/$(basename $(notdir $<)).log && exit 1)
	@grep "Warning" $(BUILD)/$(basename $(notdir $<)).log || true
	mv $(BUILD)/$@ $@

$(GEN)/soundness.tex: soundness.tex $(CACHE) | check_rule_diff $(GEN)
	ott -readsys $(CACHE) -tex_name_prefix $(PREFIX) -tex_filter $< $@ | tac

# Subs\_Pat\_Value'\_Sym turns |-> \newcommand{\SubsPatValueSym}{\textsc{\Subs\_\allowbreak{}Pat\_\allowbreak{}Value'\_\allowbreak{}Sym}}
$(GEN)/$(PREFIX)_drulenames.tex: $(GEN)/defns.drulenames | $(GEN)
	@echo "Generating $@"
	@awk '{ x=$$0; gsub(/[^a-zA-Z]/, ""); gsub(/_/, "_\\allowbreak{}", x); print "\\newcommand{\\" $$0 "}{\\textsc{" x "}}"; }' $^ > $@

.PHONY: check_rule_diff

# Subs\_Pat\_Value'\_Sym                    |-> {\SubsPatValueSym}{}}
# \step{<0>\d\+}{\case{\SubsPatValueSym}{}} |-> {\SubsPatValueSym}{}}
check_rule_diff: $(GEN)/defns.drulenames | $(GEN)
	@echo "Checking for rule differences"
	@awk '{ gsub(/[^a-zA-Z]/, ""); print "{\\" $$0 "}{}}"; }' $^ > $@
	@awk -F'case' '/^\\step{<0>/{ print $$2; }' soundness.tex | diff -u --color - $@
	@rm $@

.PHONY: append_rule_cases

# Subs\_Pat\_Value'\_Sym |-> \step{<0>\d\+}{\case{\SubsPatValueSym}{}}
append_rule_cases: $(GEN)/defns.drulenames | $(GEN)
	@if [ ! -z "$$( git status soundness.tex --porcelain )" ]; then echo "save/stash soundness.tex first"; exit 1; fi
	@echo 'Appending \step{<0>$$RULE_NUM}{\case{$$RULE}{}}'
	@awk '{ gsub(/[^a-zA-Z]/, ""); print "\\step{<0>" NR "}{\\case" "{\\" $$0 "}{}}"; }' $^ > $@
	@sed '1,/^\end{document}$$/d' < soundness.tex > old_cases
	@sed -i".tmp" '/^\\end{document}$$/q' soundness.tex
	@cat $@ >> soundness.tex && rm $@

# {\cndrulename{Subs\_Pat\_Value'\_Sym}}{} |-> Subs\_Pat\_Value'\_Sym
$(GEN)/defns.drulenames: $(GEN)/$(PREFIX)_included.tex | $(GEN)
	@echo "Generating $@"
	@sed -n 's/^{\\$(PREFIX)drulename{\(.*\)}}{}%/\1/p' $^ > $@

$(GEN)/$(PREFIX)_override.tex: override.tex | $(GEN)
	touch empty.ott
	ott -tex_wrap false -signal_parse_errors true \
	    -tex_name_prefix $(PREFIX) -tex_filter override.tex $@ empty.ott
	rm empty.ott

# You may need to patch the ott file because Ott's subrules and binders don't
# work with aux rules
$(GEN)/%.ml: %.ott | $(GEN)
	# patch < ocaml_gen.patch
	ott -o $@ $^
	# patch -R < ocaml_gen.patch

$(GEN)/defns.tex: defns.tex $(CACHE) | check_defns_diff $(GEN)
	ott -readsys $(CACHE) -tex_name_prefix $(PREFIX) -tex_filter $< $@

.PHONY: check_defns_diff

check_defns_diff: $(GEN)/$(PREFIX)_included.tex
	@echo "Checking for definitions differences"
	@grep -o '^\\$(PREFIX)defns[a-zA-Z]\+' $^ | head -n-1 > $@
	@grep -o '^\\$(PREFIX)defns[a-zA-Z]\+' defns.tex | diff -u - $@
	@rm $@

.PHONY: out_hack
out_hack: $(OTTS)
	sed -i".tmp" '/% OUT_HACK.*/{n;N;N;d;}' $(OTTS)
	for i in $(OTTS); do ./out_hack.awk -i inplace $$i; done

$(GEN)/$(PREFIX)_included.tex: $(CACHE) | $(GEN)
	@ott -readsys $(CACHE) \
	    -o $@ \
	    -tex_wrap false \
	    -tex_name_prefix $(PREFIX) \
	    -tex_show_categories true \
	    -tex_suppress_category X \
	    $(shell awk -F' ' '/{{ com Ott-hack, ignore }}/{ print "-tex_suppress_ntr " $$1; }' $(OTTS)) \
	    -tex_suppress_ntr terminals \
	    -tex_suppress_ntr user_syntax \
	    -tex_suppress_ntr judgement

$(CACHE): %: $(OTTS) | $(BUILD)
	ott -signal_parse_errors true -generate_aux_rules false $(addprefix -i , $^) -writesys $@

$(BUILD) $(GEN): %:
	mkdir -p $@

.PHONY: clean

clean:
	rm -rf soundness.tex.pfx old_cases $(BUILD)
