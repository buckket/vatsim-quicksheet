// EDDW quicksheet, generated from airports/eddw.typ by `make`. This
// file is what is built; edit it by hand where the settings do not cover
// something. `make` merges later changes (settings, data, template) into
// it and keeps the hand edits; they are listed by `make diff-eddw`.
// Tables are written out cell by cell, diagrams read the data.
// Cells: #empty (grey dash), #small[...], *bold*, #via[...] (climb via
// SID), #steps[...][...] (missed approach), #swatch(colors.at("FIX")).
// Data: AIRAC 2611, EuroScope Bremen 2611/1-1 EDWW 20261029

#import "/src/lib.typ": *

#let data = prepare(
  json("/data/EDDW.json"),
  preferred: ("Z",),
  labels: (:),
)
#let colors = exit-colors(data)

#show: sheet.with(data, paper: (size: "a4", flipped: true, one-page: true), style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt))

#page-columns(
  widths: (2fr, 1fr),
  balance: true,
  left: (
    departures(data, (("08", "26"),), height: "fit"),
    section[SIDs][#sheet-table(
      columns: (auto, 1fr, 1fr),
      header: ([SID], [08], [26], ),
      [#swatch(colors.at("WSN")) WSN], [*2M*], [*2L*],
      [#swatch(colors.at("GESTO")) GESTO], [*9M*], [*2Z* #emph[(2L)]],
      [#swatch(colors.at("NIE")) NIE], [*3M*], [*7Z* #emph[(3L)]],
      [#swatch(colors.at("WIMCI")) WIMCI], [*2M*], [*2Z* #emph[(2L)]],
      [#swatch(colors.at("ABDIM")) ABDIM], [*1M*], [*1L*],
      [#swatch(colors.at("OKWEL")) OKWEL], [*2M*], [*2L*],
      [INIT CLB], [4000 ft], [4000 ft],
      [DEP FREQ], [124.800], [124.800],
    )],
    (
      section[STARs][#sheet-table(
        columns: (auto, 1fr, 1fr, 1fr, 1fr),
        header: ([STAR], [08], [26], [APP freq], [Level at], ),
        [EKROV], [3P], [3P], [124.800], [#empty],
        [VERED], [4P], [4P], [124.800], [#empty],
        [PIXUR], [4P], [4P], [124.800], [#empty],
        [GIBMA], [3P], [3P], [124.800], [#empty],
      )],
      section[Holdings][#sheet-table(
        columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
        header: ([Fix], [Inbd \[Turn\]], [MHA], [Max], [Spd], [Leg], [APP], ),
        [BMN], [175 \[R\]], [3000 ft], [FL100], [#empty], [1 min], [FRI],
        [BMN], [175 \[R\]], [3000 ft], [FL100], [≤230 kt], [1 min], [FRI],
        [EKROV], [252 \[R\]], [4000 ft], [FL100], [#empty], [1 min], [FRI],
        [GIBMA], [178 \[R\]], [4000 ft], [FL100], [#empty], [1 min], [FRI],
        [PIXUR], [345 \[L\]], [4000 ft], [FL100], [#empty], [1 min], [FRI],
        [VERED], [295 \[R\]], [4000 ft], [FL100], [#empty], [1 min], [FRI],
      )],
    ),
  ),
  right: (
    section[Control zone][#ctr-diagram(data, height: 40mm, vrps: auto, shift: (0, 0), mva-shift: (:))],
    section[Communication][#sheet-table(
      columns: (auto, auto, 1fr, auto),
      header: ([ID], [Freq], [Callsign], [Position], ),
      breaks: (1, 2, 3),
      [ADW], [132.380], [Bremen ATIS], [#small[EDDW\_ATIS]],
      [DWG], [121.755], [Bremen Ground], [#small[EDDW\_GND]],
      [DWT], [120.330], [Bremen Tower], [#small[EDDW\_TWR]],
      [FRI], [124.800], [Bremen Radar], [#small[EDDW\_APP]],
    )],
    section[Approach procedures][#sheet-table(
      columns: (auto, 1fr, 1fr),
      header: ([RWY], [08], [26], ),
      [APP], [*ILS Z*], [*ILS Z*],
      [ID], [IBRE], [IBRW],
      [FREQ], [110.30], [110.90],
      [CAT], [III], [III],
      [CRS], [084], [264],
      [FAP], [IBUTI], [ROGBO],
      [ALT], [3000 ft], [3000 ft],
      [OTHER], [#small[ILS Y, RNP, VOR/DME]], [#small[ILS Y, RNP, VOR/DME]],
    )],
    section[Missed approach][#sheet-table(
      columns: (auto, auto, 1fr),
      header: ([RWY], [APP], [Missed approach], ),
      [08], [#small[ILS Z]], [#steps[084° to HIG][RT BMN 3000 ft, hold]],
      [26], [#small[ILS Z]], [#steps[264° to D264B][LT BMN 3000 ft, hold]],
    )],
  ),
)
