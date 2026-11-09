// EDDV quicksheet, generated from airports/eddv.typ by `make`. This
// file is what is built; edit it by hand where the settings do not cover
// something. `make` merges later changes (settings, data, template) into
// it and keeps the hand edits; they are listed by `make diff-eddv`.
// Tables are written out cell by cell, diagrams read the data.
// Cells: #empty (grey dash), #small[...], *bold*, #via[...] (climb via
// SID), #steps[...][...] (missed approach), #swatch(colors.at("FIX")).
// Data: AIRAC 2611, EuroScope Bremen 2611/1-1 EDWW 20261029

#import "/src/lib.typ": *

#let data = prepare(
  json("/data/EDDV.json"),
  preferred: (),
  labels: (:),
)
#let colors = exit-colors(data)

#show: sheet.with(data, paper: (size: "a4", flipped: true, one-page: true), style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt))

#page-columns(
  widths: (2fr, 1fr),
  balance: true,
  left: (
    departures(data, (("09L", "27R"), ("09R", "27L")), height: "fit"),
    section[SIDs][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      header: ([SID], [09L], [09R], [27L], [27R], ),
      [#swatch(colors.at("CEL")) CEL], [#via[7Y]], [#via[1G]], [#via[9F]], [#via[7S]],
      [#swatch(colors.at("POVEL")) POVEL], [#via[3Y]], [#via[3H]], [#via[4F]], [#via[4S]],
      [#swatch(colors.at("WERRA")) WERRA], [*4Y*], [*4G*], [*4F*], [*4S*],
      [#swatch(colors.at("TOLTA")) TOLTA], [#via[1Y]], [#via[1G]], [#via[1F]], [#via[1S]],
      [#swatch(colors.at("VAXEV")) VAXEV], [#via[2Y]], [#via[2G]], [#via[2F]], [#via[2S]],
      [#swatch(colors.at("NIE")) NIE], [#via[2Y]], [#via[8G]], [#via[8F]], [#via[1S]],
      [OID], [EDDV1Y], [EDDV1G], [EDDV1F], [EDDV1S],
      [INIT CLB], [4000 ft], [4000 ft], [4000 ft], [4000 ft],
      [DEP FREQ], [119.490], [119.490], [119.490], [119.490],
    )
      #note[Heavies and northbound departures: 09L/27R · RWY 09: VAXEV departures from 09L]],
    section[STARs][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
      header: ([STAR], [09L], [09R], [27L], [27R], [APP freq], [Level at], ),
      [CEL], [1L], [1L], [1R], [1R], [COORD], [≥5000 ft],
      [SAS], [#empty], [#empty], [1R], [1R], [119.490], [≥5000 ft],
      [ROBEG], [1L], [1L], [#empty], [#empty], [119.490], [≥5000 ft],
      [NIE], [1L], [1L], [1R], [1R], [COORD], [≥5000 ft],
    )],
    section[Missed approach][#sheet-table(
      columns: (auto, auto, 1fr),
      header: ([RWY], [APP], [Missed approach], ),
      [09L], [#small[ILS Z]], [#steps[088° to DV635][LT DV636 ≤195 kt][DV637][NIE 4000 ft, hold]],
      [09R], [#small[ILS Z]], [#steps[088° to DV153][RT DV155 ≤210 kt][SAS][ROBEG 4000 ft, hold]],
      [27L], [#small[ILS Z]], [#steps[268° to DV607][LT DV608 ≤185 kt][SAS 4000 ft, hold]],
      [27R], [#small[ILS Z]], [#steps[268° to DV250][RT DV609 ≤185 kt][DV617 ≤210 kt][CEL 4000 ft, hold]],
    )],
  ),
  right: (
    section[Control zone][#ctr-diagram(data, height: 70mm, vrps: auto, shift: (2, 0), mva-shift: (:))],
    section[Communication][#sheet-table(
      columns: (auto, auto, 1fr, auto),
      header: ([ID], [Freq], [Callsign], [Position], ),
      breaks: (1, 2, 3, 4, 5),
      [ADV], [136.575], [Hannover ATIS], [#small[EDDV\_ATIS]],
      [DVL], [120.405], [Hannover Delivery], [#small[EDDV\_DEL]],
      [DVG], [121.955], [Hannover Ground], [#small[EDDV\_GND]],
      [DVT], [120.180], [Hannover Tower], [#small[EDDV\_TWR]],
      [HAN], [119.490], [Bremen Radar], [#small[EDDV\_APP]],
      [DVAT], [119.605], [Hannover Arrival], [#small[EDDV\_A\_APP]],
    )],
    section[Holdings][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
      header: ([Fix], [Inbd \[Turn\]], [MHA], [Max], [Spd], [Leg], [APP], ),
      [CEL], [257 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [COORD],
      [NIE], [181 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [COORD],
      [ROBEG], [007 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [COORD],
      [SAS], [088 \[L\]], [4000 ft], [FL100], [≤230 kt], [1 min], [COORD],
    )],
    section[Approach procedures][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      header: ([RWY], [09L], [09R], [27L], [27R], ),
      [APP], [*ILS Z*], [*ILS Z*], [*ILS Z*], [*ILS Z*],
      [ID], [IHNE], [IHSE], [IHSW], [IHNW],
      [FREQ], [108.30], [108.70], [109.95], [108.90],
      [CAT], [III], [I], [I], [III],
      [CRS], [088], [088], [268], [268],
      [FAP], [DESIM], [PIXEL], [ODINI], [XAVER],
      [ALT], [3000 ft], [3000 ft], [3000 ft], [3000 ft],
      [OTHER], [#small[ILS X, LOC, RNP]], [#small[ILS X, LOC, RNP]], [#small[ILS X, ILS Y, LOC, RNP]], [#small[ILS X, ILS Y, LOC, RNP]],
    )],
  ),
)
