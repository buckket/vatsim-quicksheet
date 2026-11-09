// Control zone diagram: CTR boundary, VRPs, MVA (summer/winter) and
// topography for orientation.

#import "@preview/cetz:0.4.2"
#import "util.typ": *
#import "plot.typ": draw-runways

#let ctr-color = rgb("#1f4e9c") // Airspace D (CTR)
#let mva-color = rgb("#9b5a1a")

/// Control zone drawing over the whole data area (`ctr.area`), the CTR in its
/// centre; `ctr-diagram` frames and clips it. Needs context.
///
/// -> content
#let ctr-plot(
  /// Prepared airport data.
  /// -> dictionary
  data,
  /// Length of one NM.
  /// -> length
  unit: 2pt,
  /// VRPs shown, e.g. `("DB-N", "DB-M")` (auto: the airport's own,
  /// "DB-..." at EDDB).
  /// -> auto | array
  vrps: auto,
  /// `(x0, y0, x1, y1)` in NM actually visible (auto: the whole area); MVA
  /// labels are moved inside it, or left out if their position is not
  /// visible.
  /// -> auto | array
  view: auto,
  /// MVA label text -> `(east, north)` offset in NM, e.g.
  /// `("2000/2300": (0, -1.5))`, for a label that covers a VRP.
  /// -> dictionary
  mva-shift: (:),
) = {
  let ctr = data.ctr
  let pt = 1pt / unit
  let thin(paint, thickness, ..extra) = (paint: paint, thickness: thickness, join: "round", ..extra.named())
  // Topography colours as in EuroScope (TopSky profile)
  let (highway, river, city) = (rgb(..ctr.colors.highway), rgb(..ctr.colors.river), rgb(..ctr.colors.city))

  cetz.canvas(length: unit, {
    import cetz.draw: *
    // Invisible frame of the whole area: keeps the CTR in the canvas centre
    let (x0, y0, x1, y1) = ctr.area
    rect((x0, y0), (x1, y1), stroke: none)

    // Topography as in EuroScope: built-up areas and lakes filled, rivers and
    // motorways as thin lines (1 px there)
    for poly in ctr.city { line(..poly, close: true, fill: city, stroke: none) }
    for poly in ctr.lakes { line(..poly, close: true, fill: river, stroke: thin(river, 0.5pt)) }
    for l in ctr.rivers { line(..l, stroke: thin(river, 0.6pt)) }
    for l in ctr.highways { line(..l, stroke: thin(highway, 0.7pt)) }

    // MVA sector limits (dotted)
    for l in ctr.mva.lines { line(..l, stroke: thin(mva-color, 0.6pt, dash: (1.5pt, 1.2pt))) }
    for l in ctr.boundary { line(..l, stroke: thin(ctr-color, 1.4pt, cap: "round")) }
    draw-runways(data.runways)

    // Visual reporting points, chart style: black triangle in a circle
    let own = data.icao.slice(2) + "-"
    let shown-vrps = ctr.vrps.filter(v => if vrps == auto { v.fix.starts-with(own) } else { v.fix in vrps })
    // (the triangle's thin outline lets PDF viewers smooth its edges)
    let r = 3.2 * pt // Circle radius
    for v in shown-vrps {
      let t = 2.1 * pt // Triangle: centre to corner
      let (x, y) = v.pos
      circle(v.pos, radius: r, fill: white, stroke: 0.6pt + black)
      line((x, y + t), (x - 0.87 * t, y - 0.5 * t), (x + 0.87 * t, y - 0.5 * t),
        close: true, fill: black, stroke: (paint: black, thickness: 0.3pt, join: "round"))
    }

    // Labels last, so no line is drawn over them
    let (vx0, vy0, vx1, vy1) = if view == auto { ctr.area } else { view }
    for m in ctr.mva.labels {
      let label = mva-text(m)
      let (dx, dy) = mva-shift.at(label, default: (0, 0))
      let (mx, my) = (m.pos.at(0) + dx, m.pos.at(1) + dy)
      if mx < vx0 or mx > vx1 or my < vy0 or my > vy1 { continue }
      let body = halo(text(size.tiny, fill: mva-color, weight: "bold", label))
      let dims = measure(body) // Keep the label inside the visible area
      let (hw, hh) = (dims.width / 2 / unit, dims.height / 2 / unit)
      let x = calc.max(vx0 + hw, calc.min(vx1 - hw, mx))
      let y = calc.max(vy0 + hh, calc.min(vy1 - hh, my))
      content((x, y), body)
    }
    for v in shown-vrps {
      content((v.pos.at(0) + r, v.pos.at(1)), anchor: "west", padding: 1.5 * pt, halo(text(size.label, weight: "bold", v.label)))
    }
  })
}
