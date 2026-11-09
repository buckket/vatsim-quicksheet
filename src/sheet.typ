// Page parts: diagrams, page setup and the two page columns; everything a
// sheet's source (sheets/<icao>.typ) calls.

#import "util.typ": *
#import "plot.typ": sid-plot, sid-plot-unit, diagram-frame
#import "ctr.typ": ctr-plot
#import "tables.typ": *

#let margin = (x: 8mm, top: 8mm, bottom: 10mm)

/// SID diagrams in a grid, all at the same scale and in equal frames.
///
/// -> content
#let sid-diagrams(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Rows of runway ids, `none` = empty cell, e.g.
  /// `(("06L", "24R"), ("06R", "24L"))`.
  /// -> array
  grid-rows,
  /// Maximum drawing height per diagram (auto: the width decides).
  /// -> auto | length
  height: auto,
) = layout(size => {
  let n = calc.max(..grid-rows.map(r => r.len()))
  let gap = 3mm
  let w = (size.width - (n - 1) * gap) / n
  let runways = grid-rows.flatten().filter(rw => rw != none)
  let unit = sid-plot-unit(data, runways, w - 6pt, height: height)
  let plots = (:)
  for rw in runways { plots.insert(rw, sid-plot(data, rw, unit: unit)) }
  // Labels stick out by different amounts per runway: all boxes get the
  // height of the tallest diagram
  let h = calc.max(..plots.values().map(p => measure(p).height))
  grid(
    columns: (w,) * n,
    gutter: gap,
    ..grid-rows.map(row => row + (none,) * (n - row.len())).flatten().map(rw => if rw != none {
      diagram-frame([RWY #rw], unit, width: w, box(height: h, align(horizon, plots.at(rw))))
    }),
  )
})

/// The "Departures" section: the SID diagrams (see `sid-diagrams`).
///
/// -> content | function
#let departures(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Rows of runway ids, as in `sid-diagrams`.
  /// -> array
  grid-rows,
  /// As in `sid-diagrams`, or `"fit"`: as large as the page allows; the
  /// section is then a function of the height, which `page-columns` chooses.
  /// -> auto | length | str
  height: auto,
  /// Lines under the diagrams, see `note`.
  /// -> array
  notes: (),
) = {
  let body(h) = section[Departures][#sid-diagrams(data, grid-rows, height: h)#notes.map(note).join()]
  if height == "fit" { body } else { body(height) }
}

/// Control zone diagram, framed, over the full available width: the CTR with
/// its margin (`ctr.bounds`) centred; extra width shows more surroundings.
/// None if the airport has no CTR map.
///
/// -> content | none
#let ctr-diagram(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Drawing height (less if the width is the limit).
  /// -> length
  height: 40mm,
  /// VRPs shown (auto: the airport's own).
  /// -> auto | array
  vrps: auto,
  /// `(east, north)` in NM to move the visible part, e.g. `(2, 0)` for a VRP
  /// label cut off at the edge (the CTR may then leave the frame).
  /// -> array
  shift: (0, 0),
  /// MVA label text -> `(east, north)` offset in NM, e.g.
  /// `("2000/2300": (0, -1.5))`, for a label that covers a VRP.
  /// -> dictionary
  mva-shift: (:),
) = {
  if data.ctr == none { return }
  let (x0, y0, x1, y1) = data.ctr.bounds
  let (dx, dy) = shift
  layout(size => {
    let w = size.width - 6pt
    let unit = calc.min(height / (y1 - y0), w / (x1 - x0))
    // Visible part in NM: centred on the CTR (+ shift), as wide as the frame
    let (cx, half) = ((x0 + x1) / 2 + dx, w / unit / 2)
    let view = (cx - half, y0 + dy, cx + half, y1 + dy)
    diagram-frame(none, unit, scale-nm: 5, width: size.width,
      box(width: w, height: unit * (y1 - y0), clip: true,
        place(center + horizon, dx: -dx * unit, dy: dy * unit,
          ctr-plot(data, unit: unit, vrps: vrps, view: view, mva-shift: mva-shift))))
  })
}

/// Header line: airport, elevation, transition altitude, variation, AIRAC.
///
/// -> content
#let sheet-header(data) = {
  grid(
    columns: (1fr, auto),
    align: (left + bottom, right + bottom),
    text(size.header, weight: "bold")[#data.icao #text(weight: "regular", fill: luma(80), data.name)],
    text(size.heading)[
      *ELEV* #data.elevation ft #h(1em)
      *TA* #fmt-alt(data.transition_altitude) #h(1em)
      #let var = data.magnetic_variation
      #if var != none [*VAR* #calc.abs(calc.round(var))°#if var >= 0 [E] else [W] #h(1em)]
      *AIRAC* #data.sources.navigraph_airac
    ],
  )
  v(-0.4em)
  line(length: 100%, stroke: 0.8pt)
}

/// Page setup, header line and one-page check; use as
/// `#show: sheet.with(data, ...)`.
///
/// -> content
#let sheet(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Header line (auto: `sheet-header(data)`).
  /// -> auto | content
  header: auto,
  /// `size`, `flipped`, `one-page` (fail if the sheet needs more than one
  /// page).
  /// -> dictionary
  paper: (size: "a4", flipped: true, one-page: true),
  /// Base `font` and `size`; all other text sizes are relative to it.
  /// -> dictionary
  style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt),
  /// The page content.
  /// -> content
  body,
) = {
  set page(
    paper: paper.size,
    flipped: paper.flipped,
    margin: margin,
    footer: context text(size.tiny, fill: luma(110))[
      AIRAC #data.sources.navigraph_airac · EuroScope: #data.sources.euroscope ·
      For flight simulation use only.
      #h(1fr) #counter(page).display()
    ],
  )
  set text(font: style.font, size: style.size)
  set par(leading: 0.45em)

  block(below: 3mm, if header == auto { sheet-header(data) } else { header })
  body

  // One-page check: which column is too long, by how much. Skipped with
  // `--input draft=1` (generating the source, the draft of a new airport),
  // so an overfull sheet can still be written and looked at.
  if paper.one-page and "draft" not in sys.inputs {
    context for marker in query(<column-end>) {
      let loc = marker.location()
      assert(loc.page() == 1, message: data.icao + ": the " + marker.value
        + " column does not fit on one page (about " + str(calc.round((loc.position().y - margin.top).mm()))
        + " mm too long); make diagrams smaller (sids.height, ctr.height) or move sections to the other column")
    }
  }
}

// Column widths (fractions, lengths, ratios) resolved for a total width.
#let column-widths(widths, total) = {
  let fixed = widths.map(w => if type(w) == length { w } else if type(w) == ratio { w * total } else { 0pt })
  let frs = widths.map(w => if type(w) == fraction { w / 1fr } else { 0 })
  let rest = total - fixed.sum()
  fixed.zip(frs).map(((f, r)) => if r > 0 { rest * r / frs.sum() } else { f })
}

/// The two page columns below the header line.
///
/// -> content
#let page-columns(
  /// Items top to bottom: content (e.g. `section[Notes][...]`) or an array
  /// of those side by side (equal widths); none items are left out. A
  /// function item (`departures(..., height: "fit")`) gets the largest
  /// height at which its column still fits on the page.
  /// -> array
  left: (),
  /// As `left`.
  /// -> array
  right: (),
  /// Of the left and right column, e.g. `(2fr, 1fr)`.
  /// -> array
  widths: (2fr, 1fr),
  /// False, true (the shorter column is spread to the longer one's height)
  /// or `"page"` (both are spread to the page bottom); extra space goes
  /// evenly into the gaps between items.
  /// -> bool | str
  balance: true,
) = {
  let gutter = 6mm
  // An array = items side by side (spaced like a single section)
  let column(items, h) = {
    let resolve(it) = if type(it) == function { it(h) } else { it }
    items.map(it => if type(it) == array {
      let parts = it.map(resolve).filter(p => p != none)
      if parts.len() > 0 {
        block(above: 1.6em, below: 0.6em, grid(columns: (1fr,) * parts.len(), column-gutter: 4mm, ..parts))
      }
    } else { resolve(it) }).filter(it => it != none)
  }
  let sides = (left, right)

  layout(page-size => context {
    let widths = column-widths(widths, page-size.width - gutter)
    // Height left below the header
    let avail = page-size.height - (here().position().y - margin.top)

    // Height for function items ("fit"): the column grows by one diagram
    // height per diagram row, so two trial measurements give the height
    // that fills the page
    let fit = auto
    let i = sides.position(items => items.flatten().any(it => type(it) == function))
    if i != none {
      let height-at(h) = measure(block(width: widths.at(i), column(sides.at(i), h).join())).height
      if height-at(auto) > avail {
        let (a, b) = (height-at(20mm), height-at(10mm))
        let rows = calc.max(1, calc.round((a - b) / 10mm))
        fit = calc.max(10mm, 20mm + (avail - a) / rows - 1pt)
      }
    }

    // The columns' items at that height, and their heights
    let cols = sides.map(items => column(items, fit))
    let heights = cols.zip(widths).map(((items, w)) => measure(block(width: w, items.join())).height)

    // Balance: extra height spread evenly over the gaps between items
    // (spacing adds up linearly: one measurement suffices); never beyond the
    // page (an overlong column is reported instead)
    let target = if balance == "page" { avail - 1pt } else { calc.min(calc.max(..heights), avail - 1pt) }
    let gap(items, h) = {
      let n = items.len() - 1
      if balance != false and n > 0 and h < target { (target - h) / n } else { 0pt }
    }

    // Invisible markers at the end of each column for the one-page check
    grid(
      columns: widths,
      column-gutter: gutter,
      ..cols.zip(heights, ("left", "right")).map(((items, h, side)) =>
        items.join(v(gap(items, h))) + [#metadata(side)<column-end>]),
    )
  })
}
