# Airport quicksheets: airports/<icao>.typ (settings) -> sheets/<icao>.typ
# (the sheet, committed, editable by hand) -> build/pdf/<icao>.pdf
#
# The extracted data (data/<ICAO>.json) is committed: without the EuroScope
# package and navdata, the sheets are built from it (as on GitHub, see
# .github/workflows/sheets.yml). Everything generated goes to build/.
#
#   make              extract the data, update and build all sheets
#   make eddb         build one sheet
#   make new-eddh     start a new airport: airports/eddh.typ from the template
#                     (tools/airport.typ), extract its data, build its sheet
#   make sheets       only update sheets/*.typ from the settings, data and
#                     template (3-way merge, see below)
#   make diff-eddb    the hand edits in sheets/eddb.typ
#   make data         only extract the data (needs EuroScope + navdata)
#   make publish      all sheets under their release names, with the release
#                     notes -> build/publish/ (what GitHub releases, see
#                     tools/release.py)
#   make docs         reference manual of the Typst template -> build/docs.pdf
#   make reference    save images of all sheets
#   make check        after a change: which sheets look different
#   make lint         check the Python code (ruff, run via uvx)
#   make format       format the Python code (ruff)
#   make clean        delete build/ (not data/, sheets/)
#
# Inputs (licensed, not committed) in input/: the EuroScope package (EDWW/)
# and the Navigraph navdata (xplane12-native-<cycle>/; the newest is used).
# After an AIRAC update, put the new folder there and run make.

EUROSCOPE ?= input/EDWW
NAVDATA   ?= $(lastword $(sort $(wildcard input/xplane12-native-*)))
PYTHON    ?= python3
TYPST     ?= typst
RUFF      ?= uvx ruff
BUILD     ?= build
DATA      ?= data
PDF       ?= $(BUILD)/pdf

SHEETS   := $(notdir $(basename $(wildcard airports/*.typ)))
ICAOS    := $(shell echo $(SHEETS) | tr a-z A-Z)
TEMPLATE := $(wildcard src/*.typ)
EXTRACT  := $(filter-out tools/release.py,$(wildcard tools/*.py))
NAVINPUT := $(wildcard $(EUROSCOPE)/*.sct $(EUROSCOPE)/*.ese $(NAVDATA)/cycle_info.txt)

.PHONY: all data sheets publish docs reference check lint format clean $(SHEETS) FORCE

# No __pycache__ folders in tools/
export PYTHONDONTWRITEBYTECODE := 1

all: $(SHEETS:%=$(PDF)/%.pdf)

$(SHEETS): %: $(PDF)/%.pdf

# --- data --------------------------------------------------------------------
# One extractor run for all airports (reads the inputs once). It depends on
# the list of airports, not on their files: editing a sheet only rebuilds it.
# Without the inputs, the sheets depend on the committed data as it is.

STAMP := $(BUILD)/.extracted
LIST  := $(BUILD)/airports.txt
INPUT := $(if $(wildcard $(EUROSCOPE)/*.sct),$(STAMP),$(wildcard $(DATA)/*.json))

data: $(STAMP)

MISSING := $(filter-out $(wildcard $(DATA)/*.json),$(ICAOS:%=$(DATA)/%.json))

$(LIST): FORCE
	@mkdir -p $(BUILD)
	@echo $(ICAOS) | cmp -s - $@ && [ -z "$(MISSING)" ] || echo $(ICAOS) > $@

$(STAMP): $(EXTRACT) $(NAVINPUT) $(LIST)
	$(PYTHON) tools/extract.py $(ICAOS) --euroscope $(EUROSCOPE) --navdata $(NAVDATA) --out $(DATA)
	@touch $@

# --- sheets ------------------------------------------------------------------
# sheets/<icao>.typ is what is built (also by GitHub) and may be edited by
# hand. sheets/generated/<icao>.typ is the last generated version (never
# edited): the difference between the two is the hand edits (make diff-<icao>).
# When the settings, data or template change, the new generated version is
# merged into the sheet (git merge-file, as git merges branches): the hand
# edits are kept; where they touch the same lines as the change, the sheet
# gets conflict markers to resolve by hand.

sheets: $(SHEETS:%=sheets/generated/%.typ)

# Named here, so make does not treat them as intermediate files (a missing
# intermediate file is not remade while the PDF is newer than its inputs)
$(SHEETS:%=sheets/%.typ) $(SHEETS:%=sheets/generated/%.typ):

# Generated sheet source (metadata <sheet-source> of the settings file)
.PRECIOUS: $(BUILD)/%.fresh.typ
$(BUILD)/%.fresh.typ: airports/%.typ $(INPUT) $(TEMPLATE)
	@mkdir -p $(BUILD)
	@$(TYPST) eval --root . --input draft=1 --in $< 'query(<sheet-source>).first().value' \
		| $(PYTHON) -c 'import json, sys; sys.stdout.write(json.load(sys.stdin))' > $@

# Update the sheet: new (copy), unchanged (nothing to do) or merge
sheets/generated/%.typ: $(BUILD)/%.fresh.typ
	@mkdir -p sheets/generated
	@sheet=sheets/$*.typ; \
	if [ ! -e $$sheet ]; then \
		cp $< $$sheet && cp $< $@ && echo "$$sheet: new"; \
	elif [ ! -e $@ ]; then \
		echo "$$sheet: $@ is missing (the version the hand edits are based on)"; exit 1; \
	elif cmp -s $< $@; then \
		touch $@; \
	else \
		git merge-file -L "hand edits" -L "previous generated" -L "generated" $$sheet $@ $<; \
		conflicts=$$?; cp $< $@; \
		if [ $$conflicts -ne 0 ]; then \
			echo "$$sheet: CONFLICT, the change touches hand-edited lines: resolve the <<<<<<< markers, then make"; exit 1; \
		fi; \
		echo "$$sheet: updated"; \
	fi

# Every sheet is updated before it is built; a deleted sheet is restored
# from the generated version
sheets/%.typ: sheets/generated/%.typ
	@[ -e $@ ] || { cp $< $@ && echo "$@: new"; }

$(PDF)/%.pdf: sheets/%.typ $(INPUT) $(TEMPLATE)
	@if grep -q '^<<<<<<< ' $<; then echo "$<: unresolved conflict (<<<<<<< markers)"; exit 1; fi
	@mkdir -p $(PDF)
	$(TYPST) compile --root . $< $@

# A new airport: settings from the template, then its data and sheet (the
# extractor runs because the list of airports changed: needs the inputs). If
# the first version does not fit on one page, it is written as a draft
# without the one-page check; make fails for it until it fits.
new-%:
	@icao=$$(echo $* | tr A-Z a-z); f=airports/$$icao.typ; \
	if [ -e $$f ]; then echo "$$f exists"; exit 1; fi; \
	if [ -z "$(wildcard $(EUROSCOPE)/*.sct)" ]; then echo "needs the inputs in input/ (see README)"; exit 1; fi; \
	sed -e "s/{ICAO}/$$(echo $$icao | tr a-z A-Z)/g" -e "s/{icao}/$$icao/g" tools/airport.typ > $$f; \
	echo "$$f written from tools/airport.typ"; \
	log=$(BUILD)/new-$$icao.log; \
	$(MAKE) --no-print-directory $$icao > $$log 2>&1 && { cat $$log; exit 0; }; \
	if ! grep -q "does not fit on one page" $$log; then cat $$log; exit 1; fi; \
	grep -v "^typst compile" $$log | grep -m1 "does not fit"; \
	$(TYPST) compile --root . --input draft=1 sheets/$$icao.typ $(PDF)/$$icao.pdf && \
	echo "$(PDF)/$$icao.pdf: draft (more than one page): adapt the settings in $$f (columns, sids.height, ctr.height), then make $$icao"

diff-%: sheets/generated/%.typ
	@git diff --no-index $< sheets/$*.typ || true

# --- manual ------------------------------------------------------------------
# Reference manual of the template (src/), from its doc comments; title and
# version from typst.toml.

docs: $(BUILD)/docs.pdf

$(BUILD)/docs.pdf: docs/manual.typ $(TEMPLATE) typst.toml
	@mkdir -p $(BUILD)
	$(TYPST) compile --root . $< $@

# --- release -----------------------------------------------------------------
# Every airport in airports/ is checked (new ones are prepared on a branch),
# so all are released. TAG: the release tag for the links in the notes (set
# by GitHub for a tag push; default: the AIRAC cycle).

TAG  ?= $(if $(filter tag,$(GITHUB_REF_TYPE)),$(GITHUB_REF_NAME))
REPO ?= $(or $(GITHUB_REPOSITORY),buckket/vatsim-quicksheet)

publish: $(SHEETS:%=$(PDF)/%.pdf) tools/release.py
	@$(PYTHON) tools/release.py --pdf $(PDF) --data $(DATA) --out $(BUILD)/publish \
		--tag "$(TAG)" --repo $(REPO)

# --- regression check --------------------------------------------------------
# Identical pages render to byte-identical PNGs.

render = rm -f $(1)/*.png; $(foreach s,$(SHEETS),$(TYPST) compile --root . --ppi 100 \
	sheets/$(s).typ $(1)/$(s).png 2>/dev/null || echo "$(s): does not build";) true

reference: $(INPUT) sheets
	@mkdir -p $(BUILD)/reference
	@$(call render,$(BUILD)/reference)
	@echo "reference images in $(BUILD)/reference/"

check: $(INPUT) sheets
	@mkdir -p $(BUILD)/check
	@$(call render,$(BUILD)/check)
	@status=0; for s in $(SHEETS); do \
		if [ ! -e $(BUILD)/reference/$$s.png ]; then echo "$$s: no reference (make reference)"; status=1; \
		elif cmp -s $(BUILD)/reference/$$s.png $(BUILD)/check/$$s.png; then echo "$$s: unchanged"; \
		else echo "$$s: CHANGED, compare $(BUILD)/reference/$$s.png with $(BUILD)/check/$$s.png"; status=1; fi; \
	done; exit $$status

# --- Python code -------------------------------------------------------------
# Settings in pyproject.toml.

lint:
	$(RUFF) check tools/
	$(RUFF) format --check tools/

format:
	$(RUFF) check --fix tools/
	$(RUFF) format tools/

clean:
	rm -rf $(BUILD)
