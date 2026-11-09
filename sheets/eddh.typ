// EDDH quicksheet, generated from airports/eddh.typ by `make`. This
// file is what is built; edit it by hand where the settings do not cover
// something. `make` merges later changes (settings, data, template) into
// it and keeps the hand edits; they are listed by `make diff-eddh`.
// Tables are written out cell by cell, diagrams read the data.
// Cells: #empty (grey dash), #small[...], *bold*, #via[...] (climb via
// SID), #steps[...][...] (missed approach), #swatch(colors.at("FIX")).
// Data: AIRAC 2611, EuroScope Bremen 2611/1-1 EDWW 20261029

#import "/src/lib.typ": *

#let data = prepare(
  json("/data/EDDH.json"),
  preferred: (),
  labels: (IDEKO: "SE"),
)
#let colors = exit-colors(data)

#show: sheet.with(data, paper: (size: "a4", flipped: true, one-page: true), style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt))

#page-columns(
  widths: (2fr, 1fr),
  balance: true,
  left: (
    departures(data, (("05", "15"), ("23", "33")), height: "fit"),
    section[SIDs][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      header: ([SID], [05], [15], [23], [33], ),
      [#swatch(colors.at("SOKWO")) SOKWO], [#via[1C]], [#via[1D]], [#via[1B]], [#via[1G]],
      [#swatch(colors.at("LUGEG")) LUGEG], [#via[3C]], [#via[3D]], [#via[3B]], [#via[3G]],
      [#swatch(colors.at("RAMAR")) RAMAR], [#via[6C]], [#via[6D]], [#via[6B]], [#via[6G]],
      [#swatch(colors.at("AMLUH")) AMLUH], [#via[2C]], [#via[2D]], [#via[3B]], [#via[2G]],
      [#swatch(colors.at("IDEKO")) IDEKO], [#via[8C]], [#via[9D]], [#via[8B]], [#via[7G]],
      [#swatch(colors.at("HABFU")) HABFU], [#via[1C]], [#via[1D]], [#via[1B]], [#via[1G]],
      [#swatch(colors.at("WSN")) WSN], [#via[5C]], [#via[4D]], [#via[4B]], [#via[5G]],
      [#swatch(colors.at("ELSOB")) ELSOB], [#via[3C]], [#via[3D]], [#via[3B]], [#via[3G]],
      [OID], [EDDH1C], [EDDH1D], [EDDH1B], [EDDH1G],
      [INIT CLB], [5000 ft], [5000 ft], [5000 ft], [5000 ft],
      [DEP FREQ], [120.540], [120.540], [120.540], [120.540],
    )
      #note[HAM \+ HAMW split only, departure frequency with the clearance: AMLUH, LUGEG, SOKWO, RAMAR 120.540 · ELSOB, IDEKO, HABFU, WSN 134.255]],
    section[STARs][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
      header: ([STAR], [05], [15], [23], [33], [APP freq], [Level at], ),
      [BOGMU], [3N 5A], [3D], [3P], [3S], [120.540], [4000 ft–FL110],
      [RARUP], [6A], [3D], [3P], [3S], [120.540], [4000 ft–FL110],
      [NOLGO], [6A], [3D 3W], [3P], [3S], [120.540], [4000 ft–FL110],
      [RIBSO], [7A], [3D], [3P], [3S], [134.255], [4000 ft–FL110],
    )],
  ),
  right: (
    section[Control zone][#ctr-diagram(data, height: 40mm, vrps: auto, shift: (0, 0), mva-shift: ("2000/2300": (-1.2, 0)))],
    section[Communication][#sheet-table(
      columns: (auto, auto, 1fr, auto),
      header: ([ID], [Freq], [Callsign], [Position], ),
      breaks: (1, 2, 4, 6, 8),
      [ADH], [124.325], [Hamburg ATIS], [#small[EDDH\_ATIS]],
      [DHL], [121.805], [Hamburg Ground], [#small[EDDH\_DEL]],
      [DHG], [121.705], [Hamburg Apron], [#small[EDDH\_E\_GND]],
      [DHW], [121.980], [Hamburg Apron], [#small[EDDH\_W\_GND]],
      [DHT], [126.855], [Hamburg Tower], [#small[EDDH\_TWR]],
      [DHR], [121.280], [Hamburg Tower], [#small[EDDH\_VFR\_TWR]],
      [HAM], [120.540], [Bremen Radar], [#small[EDDH\_APP]],
      [HAMW], [134.255], [Bremen Radar], [#small[EDDH\_W\_APP]],
      [DHAT], [118.205], [Hamburg Arrival], [#small[EDDH\_A\_APP]],
    )],
    section[Holdings][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
      header: ([Fix], [Inbd \[Turn\]], [MHA], [Max], [Spd], [Leg], [APP], ),
      [BOGMU], [228 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [HAM],
      [HAM], [005 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [HAM],
      [NOLGO], [004 \[L\]], [4000 ft], [FL100], [≤230 kt], [1 min], [HAM],
      [RARUP], [274 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [HAM],
      [RIBSO], [026 \[R\]], [4000 ft], [FL100], [≤230 kt], [1 min], [HAMW],
    )],
    section[Approach procedures][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      header: ([RWY], [05], [15], [23], [33], ),
      [APP], [*ILS*], [*ILS*], [*ILS*], [*RNP*],
      [ID], [IHHE], [IHHS], [IHHW], [#empty],
      [FREQ], [110.50], [109.55], [111.30], [#empty],
      [CAT], [I], [I], [III], [#empty],
      [CRS], [046], [149], [226], [329],
      [FAP], [ANEXI], [DEVOD], [PISAS], [SOSAX],
      [ALT], [3000 ft], [3000 ft], [3000 ft], [3000 ft],
      [OTHER], [#small[RNP]], [#small[RNP]], [#small[RNP]], [#small[]],
    )
      #note[RWY 33 only at very strong winds (RNP path over the city) · arrivals via E1, hold short of 23]],
    section[Missed approach][#sheet-table(
      columns: (auto, auto, 1fr),
      header: ([RWY], [APP], [Missed approach], ),
      [05], [#small[ILS]], [#steps[046° intercept][091° to HAM][091° to D3.5 HAM][RT HAM 4000 ft ≤230 kt, hold]],
      [15], [#small[ILS]], [#steps[149° to D3 ALF][LT HAM 4000 ft, hold]],
      [23], [#small[ILS]], [#steps[226° to D5.5 ALF][LT HAM 4000 ft, hold]],
      [33], [#small[RNP]], [#steps[329° to DH089][RT HAM 4000 ft ≤230 kt, hold]],
    )],
  ),
)
