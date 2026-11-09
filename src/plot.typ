// Diagrams (cetz): shared parts and the SID diagram. Data coordinates are in
// NM around the airport (x = east, y = north); all diagrams are north-up.

#import "@preview/cetz:0.4.2"
#import "util.typ": *

// --- shared ------------------------------------------------------------------

/// Scale bar and north arrow.
///
/// -> content
#let scale-bar(
  /// The diagram's length of one NM.
  /// -> length
  unit,
  /// Length of the bar in NM.
  /// -> int
  nm: 10,
) = {
  let pt = 1pt / unit
  let c = luma(90)
  cetz.canvas(length: unit, {
    import cetz.draw: *
    line((0, 0), (nm, 0), stroke: 0.8pt + c)
    line((0, -2 * pt), (0, 2 * pt), stroke: 0.8pt + c)
    line((nm, -2 * pt), (nm, 2 * pt), stroke: 0.8pt + c)
    content((nm, 0), anchor: "west", padding: 2 * pt, text(size.tiny, fill: c)[#nm NM])
    line((-6 * pt, -2 * pt), (-6 * pt, 7 * pt), stroke: 0.8pt + c, mark: (end: ">", fill: c, scale: 0.5))
    content((-6 * pt, 2 * pt), anchor: "east", padding: 2 * pt, text(size.tiny, fill: c)[N])
  })
}

/// Frame around a diagram with its own scale bar. With a title, title and
/// scale bar form a row above the drawing; without, the scale bar sits on
/// the drawing (top right).
///
/// -> content
#let diagram-frame(
  /// Diagram title.
  /// -> content | none
  title,
  /// The diagram's length of one NM.
  /// -> length
  unit,
  /// The drawing.
  /// -> content
  body,
  /// Frame width.
  /// -> auto | length
  width: auto,
  /// Length of the scale bar in NM.
  /// -> int
  scale-nm: 10,
) = box(
  width: width, stroke: 0.4pt + luma(170), inset: 3pt, radius: 2pt,
)[
  #let bar = scale-bar(unit, nm: scale-nm)
  #if title == none {
    align(center, body)
    place(top + right, box(fill: white.transparentize(20%), inset: 2pt, radius: 1pt, bar))
  } else {
    grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      column-gutter: 1em,
      text(size.title, weight: "bold", title), bar,
    )
    align(center, body)
  }
]

/// Runways, drawn inside a cetz canvas: active ones black, the others grey.
#let draw-runways(
  /// The airport's runways (`data.runways`).
  /// -> array
  runways,
  /// Runway ids drawn black (auto: all).
  /// -> auto | array
  active: auto,
  /// Line width of the active runways.
  /// -> length
  width: 2.2pt,
) = {
  import cetz.draw: *
  for r in runways {
    let on = active == auto or r.ids.any(id => id in active)
    line(r.ends.at(0).pos, r.ends.at(1).pos,
      stroke: if on { width + black } else { (width - 0.4pt) + luma(170) })
  }
}

// --- SID diagram -------------------------------------------------------------

// cetz anchor for a label on the given compass side of its fix.
#let label-anchor = (
  N: "south", NE: "south-west", E: "west", SE: "north-west",
  S: "north", SW: "north-east", W: "east", NW: "south-east",
)

// Bounding box of all SIDs and runways: the same frame for every runway.
#let sid-bounds(data) = {
  let pts = data.sids.map(s => s.points).flatten().chunks(2)
  pts += data.runways.map(r => r.ends.map(e => e.pos)).flatten().chunks(2)
  let (xs, ys) = (pts.map(p => p.at(0)), pts.map(p => p.at(1)))
  (calc.min(..xs), calc.min(..ys), calc.max(..xs), calc.max(..ys))
}

/// The SIDs of one runway, in the frame of all SIDs (`sid-bounds`). Every leg
/// is drawn once: grey where SIDs to different exit fixes share it, else in
/// the exit fix colour; dashed where only non-standard SIDs fly it.
///
/// -> content
#let sid-plot(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Runway id.
  /// -> str
  runway,
  /// Length of one NM (see `sid-plot-unit`).
  /// -> length
  unit: 2pt,
) = {
  let colors = exit-colors(data)
  let (x0, y0, x1, y1) = sid-bounds(data)
  let pt = 1pt / unit
  let sids = data.sids.filter(s => s.runway == runway and not s.oid)
  let standard = (:)
  for s in sids { standard.insert(s.name, s.standard) }
  let diagram = data.sid_diagrams.at(runway, default: (lines: (), branches: ()))
  let lines = diagram.lines.map(l => l + (standard: l.sids.any(n => standard.at(n, default: true))))

  cetz.canvas(length: unit, {
    import cetz.draw: *
    rect((x0, y0), (x1, y1), stroke: none)

    // Dashed first, shared grey last: on top where lines meet
    for l in lines.sorted(key: l => int(l.standard) + 2 * int(l.exit_fix == none)) {
      line(..l.points, stroke: (
        paint: if l.exit_fix == none { trunk-color } else { colors.at(l.exit_fix, default: black) },
        thickness: if l.exit_fix == none { 1.2pt } else { 1pt },
        dash: if l.standard { none } else { (1.8pt, 1.2pt) },
        join: "miter",
        cap: if l.standard { "round" } else { "butt" },
      ))
    }
    draw-runways(data.runways, active: (runway,), width: 2.5pt)

    // Where SIDs leave or join a shared leg
    for b in diagram.branches {
      circle(b, radius: 1.3 * pt, fill: white, stroke: 0.8pt + trunk-color)
    }

    // One label per exit fix with all its SIDs
    let exits = (:)
    for s in sids.filter(s => s.exit != none) {
      exits.insert(s.exit_fix, exits.at(s.exit_fix, default: ()) + (s,))
    }
    for (fix, group) in exits {
      let (c, e, dir) = (colors.at(fix, default: black), group.first().exit, group.first().direction)
      circle(e, radius: 1.8 * pt, fill: c, stroke: 0.5pt + white)
      let names = group.sorted(key: s => not s.standard).map(s => {
        if s.standard { strong(designator(s.name)) } else { emph("(" + designator(s.name) + ")") }
      })
      content(e, anchor: label-anchor.at(dir, default: "south"), padding: 2.5 * pt,
        halo(text(size.label)[#text(fill: c, weight: "bold", fix) #names.join(" ")]))
    }
  })
}

/// Largest length of one NM at which the diagrams of all runways (labels
/// included) fit into the given size. Labels have a fixed size, so their
/// overhang beyond the route frame is measured once and subtracted. Needs
/// context.
///
/// -> length
#let sid-plot-unit(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Runway ids.
  /// -> array
  runways,
  /// Available width per diagram.
  /// -> length
  width,
  /// Available height per diagram (auto: the width decides).
  /// -> auto | length
  height: auto,
) = {
  let (x0, y0, x1, y1) = sid-bounds(data)
  let (span-x, span-y) = (x1 - x0, y1 - y0)
  let probe = 2pt
  let sizes = runways.map(rw => measure(sid-plot(data, rw, unit: probe)))
  let unit = (width - calc.max(..sizes.map(m => m.width - span-x * probe))) / span-x
  if height != auto {
    unit = calc.min(unit, (height - calc.max(..sizes.map(m => m.height - span-y * probe))) / span-y)
  }
  unit
}
