// EDDB Berlin Brandenburg: settings of the quicksheet.
// `make eddb` -> build/pdf/eddb.pdf. Every setting is listed with the value
// used; details: `quicksheet` in src/lib.typ or the manual (`make docs`).
// For changes the settings do not cover, edit sheets/eddb.typ by hand.
//
// Reference sheet, compared with the vACC quicksheet.

#import "/src/lib.typ": quicksheet

#quicksheet(
  json("/data/EDDB.json"),

  // Runways in the tables (auto: all); always ordered by number, then L, C, R
  runways: auto,

  sids: (
    // Left half 06 configuration, right half 24 (north runway on top)
    grid: (("06L", "24R"), ("06R", "24L")),
    // Drawing height: as large as possible while the sheet fits on one page
    height: "fit",
    // Label side of an exit fix where the default (away from the airport)
    // collides with another label, e.g. (GERGA: "N")
    labels: (:),
    // Variant letters preferred where several SIDs serve one exit fix, e.g.
    // ("Z",); the other SIDs are shown as on request
    preferred: (),
  ),

  ctr: (
    // Height of the control zone map (always the full column width)
    height: 37mm,
    // Current VRPs only (the sector file still lists older ones)
    vrps: ("DB-N", "DB-M"),
    // Move the visible part (east, north) in NM, e.g. for a cut-off VRP label
    shift: (0, 0),
    // MVA label (text as shown) -> offset (east, north) in NM, for a label
    // covering a VRP, e.g. ("2000/2300": (-1.2, 0))
    mva-shift: (:),
  ),

  // Stations to staff first (vACC quicksheet), bold in the table
  stations: (primary: ("DBC", "DBGA", "DBGS", "DBTS", "DBAST", "DBAS", "DBDS")),

  // Airport specific SOPs worth noting, as (topic, text) pairs; written by
  // hand, the section is left out while this is empty. Example:
  //   (("DEL", [SIDs by northern/southern area]), ("TWR", [...]))
  sops: (),

  // Lines under a section's table or diagram, by section name (as in
  // `columns`); written by hand. Rules from the vACC SOPs
  notes: (
    sids: (
      [Departure release required after every SID with designator K, M or Z, and for both runways with ILS X traffic on final],
      [SUKIP 3Q, KISUC 1Q: only with RFL ≥ FL120],
    ),
    departures: [Directs off the SID only above 5000 ft (jets), 3000 ft (props)],
    holdings: [KETAP, OGBER: coordinate with MAR · NUKRO, ATGUP, KLF: with FLG],
    approaches: [ILS X: 15 NM separation behind on both runways],
  ),

  columns: (
    // Left column (SIDs) twice as wide as the right one
    widths: (2fr, 1fr),
    // Spread the shorter column so both end at the same height
    balance: true,
    // Sections top to bottom; a section without content is left out
    left: ("departures", "sids", "stars", "missed"),
    // Control zone top right
    right: ("ctr", "stations", "holdings", "approaches", "sops"),
  ),

  // A4 landscape; fail if the sheet needs a second page
  paper: (size: "a4", flipped: true, one-page: true),
  // Base font and size (all other text sizes are relative to it)
  style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt),
)
