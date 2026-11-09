// EDDB quicksheet, generated from airports/eddb.typ by `make`. This
// file is what is built; edit it by hand where the settings do not cover
// something. `make` merges later changes (settings, data, template) into
// it and keeps the hand edits; they are listed by `make diff-eddb`.
// Tables are written out cell by cell, diagrams read the data.
// Cells: #empty (grey dash), #small[...], *bold*, #via[...] (climb via
// SID), #steps[...][...] (missed approach), #swatch(colors.at("FIX")).
// Data: AIRAC 2611, EuroScope Bremen 2611/1-1 EDWW 20261029

#import "/src/lib.typ": *

#let data = prepare(
  json("/data/EDDB.json"),
  preferred: (),
  labels: (:),
)
#let colors = exit-colors(data)

#show: sheet.with(data, paper: (size: "a4", flipped: true, one-page: true), style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt))

#page-columns(
  widths: (2fr, 1fr),
  balance: true,
  left: (
    departures(data, (("06L", "24R"), ("06R", "24L")), height: "fit", notes: ([Directs off the SID only above 5000 ft (jets), 3000 ft (props)], )),
    section[SIDs][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      header: ([SID], [06L], [06R], [24L], [24R], ),
      [#swatch(colors.at("BIKPO")) BIKPO], [#empty], [#empty], [#empty], [#via[1A] #emph[(#via(strong: false)[1M],] #small[4000 ft]#emph[)]],
      [#swatch(colors.at("GERGA")) GERGA], [#via[4B]], [#via[3Q] #emph[(#via(strong: false)[3Z],] #small[4000 ft]#emph[)]], [#via[4N]], [#empty],
      [#swatch(colors.at("ARSAP")) ARSAP], [#via[4B]], [#via[3Q] #emph[(#via(strong: false)[3Z],] #small[4000 ft]#emph[)]], [#via[4N]], [#via[3A] #emph[(#via(strong: false)[3M],] #small[4000 ft]#emph[)]],
      [#swatch(colors.at("LUROS")) LUROS], [#via[4B]], [#via[3Q] #emph[(#via(strong: false)[3Z],] #small[4000 ft]#emph[)]], [#via[4N]], [#via[3A] #emph[(#via(strong: false)[3M],] #small[4000 ft]#emph[)]],
      [#swatch(colors.at("KISUC")) KISUC], [#via[1B] #emph[(#via(strong: false)[1K])]], [#via[1Q] #small[FL080] #emph[(#via(strong: false)[1Z],] #small[4000 ft]#emph[)]], [#via[1N]], [#via[1A]],
      [#swatch(colors.at("SUKIP")) SUKIP], [#via[4B] #emph[(#via(strong: false)[4K])]], [#via[3Q] #small[FL080] #emph[(#via(strong: false)[4Z],] #small[4000 ft]#emph[)]], [#via[4N]], [#via[3A]],
      [OID], [EDDB1B], [EDDB1Q], [EDDB1N], [EDDB1A],
      [INIT CLB], [5000 ft], [5000 ft], [5000 ft], [5000 ft],
      [DEP FREQ], [120.340], [120.630], [120.630], [120.340],
    )
      #note[Departure release required after every SID with designator K, M or Z, and for both runways with ILS X traffic on final]
      #note[SUKIP 3Q, KISUC 1Q: only with RFL ≥ FL120]],
    section[STARs][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
      header: ([STAR], [06L], [06R], [24L], [24R], [APP freq], [Level at], ),
      [KETAP], [1F], [1F], [1P], [1P], [119.630], [≤FL100],
      [NUKRO], [1F], [1F], [1P], [1P], [126.425], [≤FL120],
      [ATGUP], [1F], [1F], [1P], [1P], [126.425], [≤FL120],
      [KLF], [1F], [1F], [1P], [1P], [126.425], [≤FL120],
      [OGBER], [1F], [1F], [1P], [1P], [119.630], [≤FL120],
    )],
    section[Missed approach][#sheet-table(
      columns: (auto, auto, 1fr),
      header: ([RWY], [APP], [Missed approach], ),
      [06L], [#small[ILS Z]], [#steps[064° to DB910 ≤4000 ft][LT DB911 ≤210 kt][DB915 ≤230 kt][OGBER 5000 ft ≤250 kt, hold]],
      [06R], [#small[ILS Z]], [#steps[064° to DB960 ≤3000 ft][RT DB961 ≤210 kt][KLF 5000 ft ≤250 kt, hold]],
      [24L], [#small[ILS Z]], [#steps[244° to DB860 ≤3000 ft][LT DB861 ≤190 kt][DB862 ≤220 kt][KLF 5000 ft ≤250 kt, hold]],
      [24R], [#small[ILS Z]], [#steps[244° to DB810 ≤4000 ft][DB811 ≤210 kt][OGBER 5000 ft ≤250 kt, hold]],
    )],
  ),
  right: (
    section[Control zone][#ctr-diagram(data, height: 37mm, vrps: ("DB-N", "DB-M"), shift: (0, 0), mva-shift: (:))],
    section[Communication][#sheet-table(
      columns: (auto, auto, 1fr, auto),
      header: ([ID], [Freq], [Callsign], [Position], ),
      breaks: (1, 2, 4, 5, 7, 9, 11, 13),
      bold-labels: false,
      [ADB], [123.780], [Berlin ATIS], [#small[EDDB\_ATIS]],
      [*DBC*], [*121.605*], [*Berlin Delivery*], [#small[*EDDB\_DEL*]],
      [*DBGA*], [*121.855*], [*Berlin Apron*], [#small[*EDDB\_A\_GND*]],
      [DBGE], [129.605], [Berlin Apron], [#small[EDDB\_E\_GND]],
      [DBI], [121.665], [Berlin De-Icing], [#small[EDDB\_ICE\_GND]],
      [DBGN], [129.505], [Berlin Ground], [#small[EDDB\_N\_GND]],
      [*DBGS*], [*121.705*], [*Berlin Ground*], [#small[*EDDB\_S\_GND*]],
      [DBTN], [120.030], [Berlin Tower], [#small[EDDB\_N\_TWR]],
      [*DBTS*], [*118.805*], [*Berlin Tower*], [#small[*EDDB\_S\_TWR*]],
      [DBANT], [136.105], [Berlin Arrival], [#small[EDDB\_AN\_APP]],
      [*DBAST*], [*121.130*], [*Berlin Arrival*], [#small[*EDDB\_AS\_APP*]],
      [DBAN], [119.630], [Bremen Radar], [#small[EDDB\_N\_APP]],
      [*DBAS*], [*126.425*], [*Bremen Radar*], [#small[*EDDB\_S\_APP*]],
      [DBDN], [120.340], [Bremen Radar], [#small[EDDB\_N\_DEP]],
      [*DBDS*], [*120.630*], [*Bremen Radar*], [#small[*EDDB\_S\_DEP*]],
    )],
    section[Holdings][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
      header: ([Fix], [Inbd \[Turn\]], [MHA], [Max], [Spd], [Leg], [APP], ),
      [ATGUP], [018 \[R\]], [5000 ft], [FL130], [≤230 kt], [1 min], [DBAS],
      [BBI], [319 \[R\]], [4000 ft], [#empty], [#empty], [1 min], [COORD],
      [KETAP], [145 \[L\]], [5000 ft], [FL130], [≤230 kt], [1 min], [DBAN],
      [KLF], [018 \[R\]], [5000 ft], [FL130], [≤230 kt], [1 min], [DBAS],
      [NUKRO], [329 \[R\]], [5000 ft], [FL130], [≤230 kt], [1 min], [DBAS],
      [OGBER], [116 \[L\]], [5000 ft], [FL130], [≤230 kt], [1 min], [DBAN],
    )
      #note[KETAP, OGBER: coordinate with MAR · NUKRO, ATGUP, KLF: with FLG]],
    section[Approach procedures][#sheet-table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      header: ([RWY], [06L], [06R], [24L], [24R], ),
      [APP], [*ILS Z*], [*ILS Z*], [*ILS Z*], [*ILS Z*],
      [ID], [IBNE], [IBSE], [IBSW], [IBNW],
      [FREQ], [110.70], [109.70], [109.50], [109.90],
      [CAT], [III], [III], [III], [III],
      [CRS], [064], [064], [244], [244],
      [FAP], [ODIDO], [TEBGO], [XANIM], [UBURU],
      [ALT], [4000 ft], [3000 ft], [3000 ft], [4000 ft],
      [OTHER], [#small[ILS X, ILS Y, LOC, RNP Y, RNP Z]], [#small[ILS X, ILS Y, LOC, RNP Y, RNP Z]], [#small[ILS X, ILS Y, LOC, RNP Y, RNP Z]], [#small[ILS X, LOC, RNP Z]],
    )
      #note[ILS X: 15 NM separation behind on both runways]],
  ),
)
