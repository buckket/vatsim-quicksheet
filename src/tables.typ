// Table style, cell helpers and sections. The table contents are written by
// generate.typ; cells use `empty`, `small`, `swatch` (util.typ), `via`,
// `steps` and `colors`.

#import "util.typ": *

/// A table in the sheet's style: uppercase bold header on blue, first column
/// bold on light blue, thin grey grid.
///
/// -> content
#let sheet-table(
  /// Column widths.
  /// -> auto | array
  columns: auto,
  /// Header cells.
  /// -> array
  header: (),
  /// Body rows (0 = first) with a group line on top; darker, not only
  /// thicker (PDF viewers render sub-pixel widths inconsistently).
  /// -> array
  breaks: (),
  /// First column bold (off where bold marks something else).
  /// -> bool
  bold-labels: true,
  /// The body cells, row by row.
  /// -> content
  ..cells,
) = {
  show table.cell.where(x: 0): it => if bold-labels { strong(it) } else { it }
  table(
    columns: columns,
    stroke: (x, y) => {
      let thin = 0.4pt + luma(165)
      (left: thin, right: thin, bottom: thin, top: if y - 1 in breaks { 0.8pt + luma(60) } else { thin })
    },
    inset: (x: 3pt, y: 2.2pt),
    align: (x, y) => if x == 0 { left + horizon } else { center + horizon },
    fill: (x, y) => if y == 0 { head-fill } else if x == 0 { label-fill },
    table.header(..header.map(h => strong(upper(h)))),
    ..cells,
  )
}

/// A SID that climbs via the SID: green, bold unless `strong` is false
/// (alternatives on request).
/// -> content
#let via(
  /// Designator.
  /// -> content
  body,
  /// Bold.
  /// -> bool
  strong: true,
) = text(fill: climb-via-color, weight: if strong { "bold" } else { "regular" }, body)

/// Procedure steps, separated by dots; lines break only between steps.
///
/// -> content
#let steps(..parts) = align(left, parts.pos().map(box).join[ · ])

/// A note line under a section's table or diagram (setting `notes`), e.g. a
/// rule for the SIDs above it.
///
/// -> content
#let note(body) = block(above: 0.5em, below: 0em, text(size.small, body))

/// A section with a heading; nothing if `body` is none. More space above
/// the heading than below it, so it reads as part of its content.
///
/// -> content | none
#let section(title, body) = if body != none {
  block(breakable: false, above: 1.6em, below: 0.6em)[
    #text(size.heading, weight: "bold", upper(title))
    #v(-0.7em)
    #body
  ]
}
