// Style, formatting and data helpers shared by all parts.

// --- style -------------------------------------------------------------------

// Exit fix colours, assigned clockwise from north. No grey: grey marks legs
// shared by SIDs to different exit fixes.
#let palette = (
  rgb("#1f77b4"), rgb("#d62728"), rgb("#2ca02c"), rgb("#ff7f0e"),
  rgb("#9467bd"), rgb("#8c564b"), rgb("#e377c2"), rgb("#17becf"),
  rgb("#bcbd22"), rgb("#393b79"),
)
#let climb-via-color = rgb("#1a8f3a")
#let trunk-color = luma(95) // Legs shared by SIDs to different exit fixes
#let head-fill = rgb("#c9d9ef") // Table header
#let label-fill = rgb("#eef3fa") // First table column

// Text sizes, relative to the base size (`style.size`) so that one setting
// scales all text.
#let size = (
  tiny: 0.8em, // Scale bars, footer, MVA labels
  small: 0.86em, // Secondary information
  label: 0.93em, // Diagram labels
  heading: 1.15em, // Section headings, header line
  title: 1.3em, // Diagram titles
  header: 2em, // Airport name
)

/// Secondary text.
/// -> content
#let small(body) = text(size.small, body)

/// Missing value: a grey dash.
#let empty = text(fill: luma(150), "–")

/// Colour square, e.g. before an exit fix.
/// -> content
#let swatch(color) = box(width: 0.7em, height: 0.7em, fill: color, radius: 1pt, baseline: 0.05em)

/// Map label background that keeps text readable on top of lines.
/// -> content
#let halo(body) = box(fill: white.transparentize(20%), inset: 0.8pt, radius: 1pt, body)

// --- formatting --------------------------------------------------------------

/// SID/STAR designator: "ARSAP4B" -> "4B"; other names stay complete.
/// -> str
#let designator(name) = {
  if name.match(regex("^[A-Z]{2,5}\d[A-Z]$")) == none { name } else { name.slice(-2) }
}

#let pad3(n) = { let s = str(n); "0" * (3 - s.len()) + s }

/// Altitude: 5000 -> "5000 ft", above the transition altitude `ta` -> "FL080".
/// -> str | none
#let fmt-alt(alt, ta: none) = {
  if alt == none { none }
  else if ta != none and alt > ta { "FL" + pad3(calc.div-euclid(alt, 100)) }
  else { str(alt) + " ft" }
}

// --- data --------------------------------------------------------------------

/// MVA label text: "summer/winter" altitude, e.g. "2100/2400"; one value if
/// both are equal or a season is missing.
/// -> str
#let mva-text(label) = {
  (label.at("summer", default: none), label.at("winter", default: none))
    .filter(a => a != none).dedup().map(str).join("/")
}

/// Exit fix -> colour, clockwise from north so that neighbours differ.
/// -> dictionary
#let exit-colors(data) = {
  let bearings = (:)
  for s in data.sids { if s.exit != none { bearings.insert(s.exit_fix, s.bearing) } }
  let colors = (:)
  for (i, fix) in bearings.keys().sorted(key: k => bearings.at(k)).enumerate() {
    colors.insert(fix, palette.at(calc.rem(i, palette.len())))
  }
  colors
}

/// The extractor data with the airport's SID settings applied.
///
/// -> dictionary
#let prepare(
  /// Loaded from the extractor JSON.
  /// -> dictionary
  data,
  /// Variant letters, e.g. `("Z",)`: where several SIDs serve one exit fix
  /// from one runway and one has such a letter, only those are standard (the
  /// others are dashed and shown in brackets).
  /// -> array
  preferred: (),
  /// Exit fix -> compass side of its label, e.g. `(IDEKO: "SE")`.
  /// -> dictionary
  labels: (:),
) = {
  let letter(s) = s.name.slice(-1)
  let data = data
  data.sids = data.sids.map(s => {
    let s = s
    let rivals = data.sids.filter(o => o.runway == s.runway and o.exit_fix == s.exit_fix and not o.oid)
    if not s.oid and rivals.any(o => letter(o) in preferred) { s.standard = letter(s) in preferred }
    if s.exit_fix != none and s.exit_fix in labels { s.direction = labels.at(s.exit_fix) }
    s
  })
  data
}
