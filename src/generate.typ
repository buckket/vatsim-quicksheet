// Writing a sheet as Typst source: the table contents as `sheet-table(...)`
// calls with every cell written out as markup, one table row per line, plus
// the helpers for writing source. Used by `quicksheet` (lib.typ) only;
// rendering a sheet does not need this file.

#import "util.typ": *

#let fmt-course(c) = if c == none { none } else { pad3(calc.round(c)) }

// The table runways (given ones, else all), ordered by number, then L, C, R.
#let runway-order(data, runways) = {
  let ids = if runways != auto { runways } else { data.runways.map(r => r.ids).flatten() }
  ids.sorted(key: id => (int(id.slice(0, 2)), ("", "L", "C", "R").position(s => s == id.slice(2))))
}

// Most common value (first one on ties); works for none values too.
#let mode(values) = {
  let counts = (:)
  for v in values { counts.insert(repr(v), counts.at(repr(v), default: 0) + 1) }
  values.fold(none, (best, v) => if best == none or counts.at(repr(v)) > counts.at(repr(best)) { v } else { best })
}

// --- writing source ----------------------------------------------------------

/// Text as markup showing exactly this text (markup characters escaped).
/// -> str
#let esc(s) = if s == none { "" } else { str(s) }.replace(
  regex("[\\\\*_#\\[\\]$<>@`~'\"]|/[/*]|-[-?]|\\.\\.\\.|^[-+=]|^\\d+\\.( |$)"),
  m => m.text.clusters().map(c => if c.match(regex("[\\d ]")) != none { c } else { "\\" + c }).join(),
)

/// A value as cell markup; none -> grey dash.
/// -> str
#let cell(v) = if v == none { "#empty" } else { esc(v) }

/// A value as Typst code; lengths in mm where exact (`38mm`, not the
/// `107.72pt` of `repr`).
/// -> str
#let code(v) = {
  if type(v) == length and v.em == 0 and calc.abs(calc.round(v.mm(), digits: 2) * 1mm - v) < 0.001pt {
    str(calc.round(v.mm(), digits: 2)) + "mm"
  }
  else if type(v) == array { "(" + v.map(code).join(", ") + if v.len() == 1 { "," } + ")" }
  else if type(v) == dictionary {
    // Keys that are no identifiers are quoted, e.g. ("2000/2300": ...)
    let key(k) = if k.match(regex("^[A-Za-z_][\w-]*$")) != none { k } else { repr(k) }
    if v.len() == 0 { "(:)" } else { "(" + v.pairs().map(((k, x)) => key(k) + ": " + code(x)).join(", ") + ")" }
  }
  else { repr(v) }
}

/// Hand-written content (SOPs) back to markup: plain text, bold, italic and
/// line breaks; anything else stops with a message.
/// -> str
#let markup(c) = {
  if type(c) == str { return esc(c) }
  let f = c.func()
  if f == text { esc(c.text) }
  else if f == [ ].func() { " " }
  else if f == linebreak { "\\ " }
  else if f == parbreak { "\n\n" }
  else if f == smartquote { if c.double { "\"" } else { "'" } }
  else if f == strong { "#strong[" + markup(c.body) + "]" }
  else if f == emph { "#emph[" + markup(c.body) + "]" }
  else if f == [].func() or c.has("children") { c.children.map(markup).join() }
  else { panic("cannot write out " + repr(c) + "; use plain text, *bold* and _italic_ here") }
}

/// A template with `{name}` placeholders filled in with the named strings.
/// -> str
#let fill(template, ..values) = template.replace(regex("\{(\w+)\}"), m => values.named().at(m.captures.first()))

/// Indents every line but the first (source nested in source).
/// -> str
#let indent(s, by: "  ") = s.split("\n").join("\n" + by)

/// A `sheet-table(...)` call. None without cells: the section is then left
/// out.
///
/// -> str | none
#let table-source(
  /// Column widths.
  /// -> array
  columns,
  /// Header cells, as markup.
  /// -> array
  header,
  /// Body cells, as markup, row by row.
  /// -> array
  cells,
  /// As in `sheet-table`.
  /// -> array
  breaks: (),
  /// As in `sheet-table`.
  /// -> bool
  bold-labels: true,
) = {
  if cells.len() == 0 { return none }
  let lines = ("columns: " + code(columns) + ",", "header: (" + header.map(h => "[" + h + "], ").join() + "),")
  if breaks.len() > 0 { lines.push("breaks: " + code(breaks) + ",") }
  if not bold-labels { lines.push("bold-labels: false,") }
  lines += cells.chunks(columns.len()).map(row => row.map(c => "[" + c + "]").join(", ") + ",")
  "sheet-table(\n  " + lines.join("\n  ") + "\n)"
}

// A table with a column per runway; the first column labels the rows.
#let runway-table(corner, runways, cells) = if runways.len() > 0 {
  table-source((auto,) + (1fr,) * runways.len(), (corner,) + runways, cells)
}

// --- tables ------------------------------------------------------------------
// Each returns the table's source, or none if it has no rows.

// Responsible APP from the station IDs found: one -> `fmt(id)`, several ->
// COORD (sectors meet there), none -> dash.
#let responsible(app, fmt: id => id) = {
  if app.len() == 0 { "#empty" } else if app.len() == 1 { esc(fmt(app.first())) } else { "COORD" }
}

// Primary approach of a runway: ILS (Z before Y before X), then LOC, RNP, GLS.
#let primary-approach(apps) = apps.sorted(key: a => {
  let t = ("ILS", "LOC", "RNP", "GLS").position(t => t == a.type)
  (if t == none { 9 } else { t }, -(if a.suffix == none { 99 } else { a.suffix.to-unicode() }))
}).first()

// (runway, primary approach) for each table runway with approaches.
#let primary-approaches(data, runways) = {
  runway-order(data, runways)
    .filter(rw => data.approaches.any(a => a.runway == rw))
    .map(rw => (rw, primary-approach(data.approaches.filter(a => a.runway == rw))))
}

// Station ID -> frequency.
#let frequencies(data) = data.stations.map(s => (s.id, s.frequency)).to-dict()

/// SIDs, exit fix x runway: designators (climb via green, non-standard in
/// brackets), initial climbs where they differ from the runway's usual one,
/// OIDs, the usual initial climb and the departure frequency per runway.
///
/// -> str | none
#let sid-table(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Runways shown (auto: all), ordered by number, then L, C, R.
  /// -> auto | array
  runways: auto,
) = {
  if data.sids.len() == 0 { return none }
  let runways = runway-order(data, runways)
  let ta = data.transition_altitude
  let routes = data.sids.filter(s => not s.oid)
  let oids = data.sids.filter(s => s.oid)

  // Usual initial climb per runway (of its standard SIDs)
  let init = (:)
  for rw in runways {
    let inits = routes.filter(s => s.runway == rw and s.standard).map(s => s.initial_climb)
    init.insert(rw, mode(inits))
  }
  let deviating(s) = s.initial_climb != init.at(s.runway)

  let fmt-sid(s) = {
    let d = esc(designator(s.name))
    let alt = "#small[" + cell(fmt-alt(s.initial_climb, ta: ta)) + "]"
    if not s.standard {
      let d = if s.climb_via == true { "#via(strong: false)[" + d + "]" } else { d }
      if deviating(s) { "#emph[(" + d + ",] " + alt + "#emph[)]" } else { "#emph[(" + d + ")]" }
    } else {
      let label = if s.climb_via == true { "#via[" + d + "]" } else { "*" + d + "*" }
      if deviating(s) { label + " " + alt } else { label }
    }
  }

  let cells = ()
  for fix in exit-colors(data).keys() {
    cells.push("#swatch(colors.at(\"" + fix + "\")) " + esc(fix))
    for rw in runways {
      let sids = routes.filter(s => s.exit_fix == fix and s.runway == rw).sorted(key: s => not s.standard)
      cells.push(if sids.len() == 0 { "#empty" } else { sids.map(fmt-sid).join(" ") })
    }
  }
  if oids.len() > 0 {
    cells.push("OID")
    for rw in runways {
      let v = oids.find(s => s.runway == rw)
      cells.push(cell(if v != none { v.name }))
    }
  }
  cells.push("INIT CLB")
  for rw in runways { cells.push(cell(fmt-alt(init.at(rw), ta: ta))) }
  // Stations of the first DEP sectors the runway's SIDs enter
  let freq = frequencies(data)
  cells.push("DEP FREQ")
  for rw in runways {
    let deps = routes.filter(s => s.runway == rw).map(s => s.dep).flatten().dedup()
    cells.push(if deps.len() == 0 { "#empty" } else { esc(deps.map(id => freq.at(id)).join(" / ")) })
  }

  runway-table("SID", runways, cells)
}

// Altitude restriction: "≤FL120", "≥5000 ft", "FL100–FL110", "FL120".
#let fmt-restriction(level, ta: none) = {
  if level == none { return none }
  let alt = fmt-alt(level.alt, ta: ta)
  if level.rule == "-" { "≤" + alt } else if level.rule == "+" { "≥" + alt }
  else if level.rule == "B" and level.at("lower", default: none) != none { fmt-alt(level.lower, ta: ta) + "–" + alt }
  else { alt }
}

/// STARs, entry fix x runway: designators, plus the responsible APP
/// frequency and the published level restriction at the entry fix.
///
/// -> str | none
#let star-table(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Runways shown (auto: all), ordered by number, then L, C, R.
  /// -> auto | array
  runways: auto,
) = {
  let runways = runway-order(data, runways)
  let ta = data.transition_altitude
  let by-fix = (:)
  for s in data.stars { by-fix.insert(s.entry_fix, by-fix.at(s.entry_fix, default: ()) + (s,)) }
  let freq = frequencies(data)
  let cells = ()
  for fix in by-fix.keys().sorted(key: f => by-fix.at(f).first().bearing) {
    let stars = by-fix.at(fix)
    cells.push(esc(fix))
    for rw in runways {
      let names = stars.filter(s => s.runway == rw).map(s => s.designator).dedup()
      cells.push(if names.len() == 0 { "#empty" } else { esc(names.join(" ")) })
    }
    cells.push(responsible(stars.first().app, fmt: id => freq.at(id, default: id)))
    cells.push(stars.map(s => s.entry_level).dedup().map(l => cell(fmt-restriction(l, ta: ta))).join(" / "))
  }
  // All data columns equally wide
  table-source((auto,) + (1fr,) * (runways.len() + 2), ("STAR",) + runways + ("APP freq", "Level at"), cells)
}

/// Holdings: fix, inbound course and turn, levels, speed, leg, APP.
///
/// -> str | none
#let holding-table(
  /// Prepared airport data.
  /// -> dictionary
  data,
) = {
  let ta = data.transition_altitude
  let cells = ()
  for h in data.holdings {
    cells += (
      esc(h.fix),
      cell(fmt-course(h.inbound_course)) + " " + esc("[" + h.turn + "]"),
      cell(fmt-alt(h.min_alt, ta: ta)),
      // Published maximum, else the APP sector's highest level
      cell(fmt-alt(if h.max_alt != none { h.max_alt } else { h.app_max_alt }, ta: ta)),
      cell(if h.max_speed != none { "≤" + str(h.max_speed) + " kt" }),
      esc(if h.leg_length_nm > 0 { str(h.leg_length_nm) + " NM" } else { str(h.leg_time_min) + " min" }),
      responsible(h.app),
    )
  }
  table-source((auto,) + (1fr,) * 6, ("Fix", esc("Inbd [Turn]"), "MHA", "Max", "Spd", "Leg", "APP"), cells)
}

/// SOPs, with a group line where the topic changes.
///
/// -> str | none
#let sop-table(
  /// `(topic, text)` pairs.
  /// -> array
  sops,
) = {
  for (i, entry) in sops.enumerate() {
    assert(type(entry) == array and entry.len() == 2,
      message: "`sops` entry " + str(i + 1) + " must be a pair (topic, text), e.g. (\"DEL\", [...])")
  }
  table-source((auto, 1fr), ("Topic", "SOP"),
    sops.map(((topic, body)) => (markup(topic), "#align(left)[" + markup(body) + "]")).flatten(),
    breaks: range(1, sops.len()).filter(i => sops.at(i).first() != sops.at(i - 1).first()),
  )
}

/// Approaches, the primary one per runway: identification, ILS, final
/// approach fix, and the runway's other approaches.
///
/// -> str | none
#let approach-table(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Runways shown (auto: all), ordered by number, then L, C, R.
  /// -> auto | array
  runways: auto,
) = {
  let rows = primary-approaches(data, runways)
  let ta = data.transition_altitude
  // ILS category, only where the primary approach is an ILS
  let cat = (:)
  for r in data.runways { for e in r.ends { cat.insert(e.id, e.ils_category) } }
  let row(f) = rows.map(((rw, a)) => cell(f(rw, a)))
  let faf(f) = row((rw, a) => if a.faf != none { f(a.faf) })
  runway-table("RWY", rows.map(r => r.first()), (
    ("APP",) + rows.map(((rw, a)) => "*" + esc(a.label) + "*"),
    ("ID",) + row((rw, a) => if a.ils != none { a.ils.ident }),
    ("FREQ",) + row((rw, a) => if a.ils != none { a.ils.frequency }),
    ("CAT",) + row((rw, a) => if a.ils != none and cat.at(rw) != none { ("I", "II", "III").at(cat.at(rw) - 1) }),
    ("CRS",) + faf(f => fmt-course(f.course)),
    ("FAP",) + faf(f => f.fix),
    ("ALT",) + faf(f => fmt-alt(f.altitude, ta: ta)),
    ("OTHER",) + rows.map(((rw, a)) => "#small[" + esc(data.approaches
      .filter(o => o.runway == rw and o.ident != a.ident).map(o => o.label).dedup().join(", ")) + "]"),
  ).flatten())
}

/// Missed approach of each runway's primary approach, step by step.
///
/// -> str | none
#let missed-table(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Runways shown (auto: all), ordered by number, then L, C, R.
  /// -> auto | array
  runways: auto,
) = {
  let cells = primary-approaches(data, runways).map(((rw, a)) => (
    rw, "#small[" + esc(a.label) + "]", "#steps" + a.missed.map(m => "[" + esc(m) + "]").join(),
  ))
  table-source((auto, auto, 1fr), ("RWY", "APP", "Missed approach"), cells.flatten())
}

/// Stations, with a group line where the position type or the callsign
/// changes (e.g. "Bremen Radar" APP and DEP are separate groups).
///
/// -> str | none
#let station-table(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Station IDs to staff first; their rows are bold.
  /// -> array
  primary: (),
) = {
  let stations = data.stations
  let cells = ()
  for s in stations {
    let fmt(v) = if s.id in primary { "*" + esc(v) + "*" } else { esc(v) }
    cells += (fmt(s.id), fmt(s.frequency), fmt(s.name), "#small[" + fmt(s.callsign) + "]")
  }
  table-source((auto, auto, 1fr, auto), ("ID", "Freq", "Callsign", "Position"), cells,
    // Bold marks the primary stations, if any
    bold-labels: primary.len() == 0,
    breaks: range(1, stations.len()).filter(i => {
      let (a, b) = (stations.at(i - 1), stations.at(i))
      a.type != b.type or a.name != b.name
    }),
  )
}
