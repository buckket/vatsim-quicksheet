// vatsim-quicksheet: one-page airport quicksheets for VATSIM controllers.
//
//   #import "/src/lib.typ": quicksheet
//   #quicksheet(json("/data/EDDB.json"), sids: (grid: (("06L", "24R"), ("06R", "24L"))))
//
// `quicksheet` writes the page as Typst source (tables cell by cell, diagrams
// as calls on the data) and evaluates it. `make` writes the same source to
// sheets/<icao>.typ (the sheet that is built, editable by hand).

#import "generate.typ": *
#import "sheet.typ": *
#import "sheet.typ" as parts // Scope for evaluating the generated source

// A settings group with defaults; unknown keys are an error.
#let settings(group, given, defaults) = {
  for key in given.keys() {
    assert(key in defaults,
      message: "unknown setting `" + group + "." + key + "`, known: " + defaults.keys().join(", "))
  }
  defaults + given
}

// Every value must be known; the error lists the known ones.
#let check-values(icao, what, values, known) = {
  for v in values {
    assert(v in known, message: icao + ": " + what + " \"" + v + "\" not found, known: "
      + if known.len() > 0 { known.join(", ") } else { "none" })
  }
}

// Settings that name something in the data must match it.
#let check-settings(data, runways, sids, stations, ctr) = {
  let icao = data.icao
  let runway-ids = data.runways.map(r => r.ids).flatten()
  if runways != auto { check-values(icao, "runway in `runways`", runways, runway-ids) }
  if sids.grid != auto {
    check-values(icao, "runway in `sids.grid`", sids.grid.flatten().filter(r => r != none), runway-ids)
  }
  let letters = data.sids.filter(s => not s.oid).map(s => s.name.slice(-1)).dedup()
  check-values(icao, "variant in `sids.preferred`", sids.preferred, letters)
  check-values(icao, "exit fix in `sids.labels`", sids.labels.keys(), data.sids.map(s => s.exit_fix).filter(f => f != none).dedup())
  check-values(icao, "label side in `sids.labels`", sids.labels.values(), ("N", "NE", "E", "SE", "S", "SW", "W", "NW"))
  check-values(icao, "station in `stations.primary`", stations.primary, data.stations.map(s => s.id))
  if ctr.vrps != auto {
    let known = if data.ctr == none { () } else { data.ctr.vrps.map(v => v.fix) }
    check-values(icao, "VRP in `ctr.vrps`", ctr.vrps, known)
  }
  let mva = if data.ctr == none { () } else { data.ctr.mva.labels.map(mva-text).dedup() }
  check-values(icao, "MVA label in `ctr.mva-shift`", ctr.mva-shift.keys(), mva)
}

/// One-page quicksheet from the extractor data. All settings are optional;
/// keys left out of a group keep their default.
///
/// -> content
#let quicksheet(
  /// Loaded from the extractor JSON.
  /// -> dictionary
  data,
  /// Runways shown in the tables (auto: all); always ordered by number, then
  /// L, C, R.
  /// -> auto | array
  runways: auto,
  /// SID diagrams and table:
  /// / `grid`: rows of runway ids for the diagrams, `none` = empty cell
  ///   (auto: the table runways, two per row)
  /// / `height`: drawing height per diagram: auto (the width decides), a
  ///   length (maximum) or `"fit"` (as large as the page allows)
  /// / `labels`: compass side of an exit fix label where the default (away
  ///   from the airport) collides with another, e.g. `(IDEKO: "SE")`
  /// / `preferred`: variant letters preferred where several SIDs serve one
  ///   exit fix, e.g. `("Z",)`; the others become non-standard
  /// -> dictionary
  sids: (:),
  /// Control zone diagram:
  /// / `height`: drawing height
  /// / `vrps`: VRPs shown, e.g. `("DB-N", "DB-M")` (auto: the airport's own)
  /// / `shift`: `(east, north)` in NM to move the visible part, e.g. `(2, 0)`
  /// / `mva-shift`: MVA label text -> `(east, north)` offset in NM, for a
  ///   label that covers a VRP, e.g. `("2000/2300": (0, -1.5))`
  /// -> dictionary
  ctr: (:),
  /// Communication table:
  /// / `primary`: station IDs to staff first (bold rows)
  /// -> dictionary
  stations: (:),
  /// `(topic, text)` pairs, e.g. `(("DEL", [...]),)`.
  /// -> array
  sops: (),
  /// Lines in small text under a section's table or diagram, written by hand:
  /// section name (as in `columns`) -> one line or an array of lines, e.g.
  /// `(sids: [Departure release required for ...])`.
  /// -> dictionary
  notes: (:),
  /// Page layout:
  /// / `widths`: of the left and right column, e.g. `(2fr, 1fr)`
  /// / `balance`: false, true (the shorter column is spread to the longer
  ///   one's height) or `"page"` (both are spread to the page bottom)
  /// / `left`, `right`: sections top to bottom: "departures", "sids",
  ///   "ctr", "stations", "approaches", "missed", "stars", "holdings",
  ///   "sops", or an array of those side by side, e.g. `("stars", "holdings")`
  /// -> dictionary
  columns: (:),
  /// `size`, `flipped`, `one-page` (fail if the sheet needs more than one
  /// page).
  /// -> dictionary
  paper: (:),
  /// Base `font` and `size`; all other text sizes are relative to it.
  /// -> dictionary
  style: (:),
) = {
  let sids = settings("sids", sids, (grid: auto, height: auto, labels: (:), preferred: ()))
  let ctr = settings("ctr", ctr, (height: 40mm, vrps: auto, shift: (0, 0), mva-shift: (:)))
  let stations = settings("stations", stations, (primary: ()))
  let columns = settings("columns", columns, (
    widths: (2fr, 1fr),
    balance: true,
    left: ("departures", "sids", "holdings"),
    right: ("ctr", "stations", "approaches", "missed", "stars", "sops"),
  ))
  assert(columns.balance in (false, true, "page"),
    message: "`columns.balance` must be false, true or \"page\", not " + repr(columns.balance))
  let paper = settings("paper", paper, (size: "a4", flipped: true, one-page: true))
  let style = settings("style", style, (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt))
  check-settings(data, runways, sids, stations, ctr)

  let data = prepare(data, preferred: sids.preferred, labels: sids.labels)
  let runways = runway-order(data, runways)
  let sid-grid = if sids.grid == auto { runways.chunks(2) } else { sids.grid }

  // Notes per section, each an array of lines
  let notes = notes.pairs().map(((name, n)) => (name, if type(n) == array { n } else { (n,) })).to-dict()
  // Note lines as source, appended to a section's body
  let note-source(name) = notes.at(name, default: ()).map(n => "\n  #note[" + markup(n) + "]").join(default: "")

  // The source of every section; none = no content (left out)
  let section-source(name, title, source) = if source != none {
    fill("section[{title}][#{source}{notes}]", title: title, source: source, notes: note-source(name))
  }
  let sections = (
    departures: if data.sid_diagrams.len() > 0 {
      let lines = notes.at("departures", default: ())
      fill("departures(data, {grid}, height: {height}{notes})", grid: code(sid-grid), height: code(sids.height),
        notes: if lines.len() > 0 { ", notes: (" + lines.map(n => "[" + markup(n) + "], ").join() + ")" } else { "" })
    },
    sids: section-source("sids", "SIDs", sid-table(data, runways: runways)),
    stations: section-source("stations", "Communication", station-table(data, primary: stations.primary)),
    approaches: section-source("approaches", "Approach procedures", approach-table(data, runways: runways)),
    missed: section-source("missed", "Missed approach", missed-table(data, runways: runways)),
    stars: section-source("stars", "STARs", star-table(data, runways: runways)),
    holdings: section-source("holdings", "Holdings", holding-table(data)),
    ctr: if data.ctr != none {
      section-source("ctr", "Control zone", fill("ctr-diagram(data, height: {height}, vrps: {vrps}, shift: {shift}, mva-shift: {mva})",
        height: code(ctr.height), vrps: code(ctr.vrps), shift: code(ctr.shift), mva: code(ctr.mva-shift)))
    },
    sops: section-source("sops", "SOPs", sop-table(sops)),
  )
  // A note needs its section on the sheet (else it would silently be lost)
  let placed = (columns.left + columns.right).flatten()
  for name in notes.keys() {
    assert(name in sections, message: "unknown section `" + name + "` in `notes`, known: " + sections.keys().join(", "))
    assert(sections.at(name) != none, message: data.icao + ": `notes." + name + "`: the section has no content")
    assert(name in placed, message: data.icao + ": `notes." + name + "`: the section is not in `columns`")
  }
  // An array literal, one item per line (none items dropped)
  let list(items) = "(\n" + items.filter(s => s != none).map(s => "  " + indent(s) + ",\n").join() + ")"
  let item(it) = {
    if type(it) == array { return list(it.map(item)) } // Side by side
    assert(type(it) == str, message: "`columns` items are section names; other content: "
      + "edit sheets/" + lower(data.icao) + ".typ")
    assert(it in sections, message: "unknown section `" + it + "`, known: " + sections.keys().join(", "))
    sections.at(it)
  }
  let column(items) = indent(list(items.map(item)))

  let body = fill(```
    page-columns(
      widths: {widths},
      balance: {balance},
      left: {left},
      right: {right},
    )
    ```.text,
    widths: code(columns.widths), balance: code(columns.balance),
    left: column(columns.left), right: column(columns.right),
  )
  let file = fill(```
    // {ICAO} quicksheet, generated from airports/{icao}.typ by `make`. This
    // file is what is built; edit it by hand where the settings do not cover
    // something. `make` merges later changes (settings, data, template) into
    // it and keeps the hand edits; they are listed by `make diff-{icao}`.
    // Tables are written out cell by cell, diagrams read the data.
    // Cells: #empty (grey dash), #small[...], *bold*, #via[...] (climb via
    // SID), #steps[...][...] (missed approach), #swatch(colors.at("FIX")).
    // Data: AIRAC {airac}, EuroScope {euroscope}

    #import "/src/lib.typ": *

    #let data = prepare(
      json("/data/{ICAO}.json"),
      preferred: {preferred},
      labels: {labels},
    )
    #let colors = exit-colors(data)

    #show: sheet.with(data, paper: {paper}, style: {style})

    #{body}
    ```.text + "\n",
    ICAO: data.icao, icao: lower(data.icao), airac: data.sources.navigraph_airac,
    euroscope: data.sources.euroscope, preferred: code(sids.preferred), labels: code(sids.labels),
    paper: code(paper), style: code(style), body: body,
  )

  show: sheet.with(data, paper: paper, style: style)
  [#metadata(file)<sheet-source>] // Read by `make` (sheets/<icao>.typ)
  eval(body, mode: "code", scope: dictionary(parts) + (data: data, colors: exit-colors(data)))
}
