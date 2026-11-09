// EDDH Hamburg: settings of the quicksheet.
// `make eddh` -> build/pdf/eddh.pdf. Every setting is listed with the value
// used; details: `quicksheet` in src/lib.typ or the manual (`make docs`).
// For changes the settings do not cover, edit sheets/eddh.typ by hand.
//
// Crossing runways 05/23 and 15/33 (preferred: 23 arrivals, 33 departures).
// No DEP stations: DEP FREQ is the APP sector (HAM, HAMW).
// Not checked yet against the current charts and vACC SOPs.

#import "/src/lib.typ": quicksheet

#quicksheet(
  json("/data/EDDH.json"),

  // Runways in the tables (auto: all); always ordered by number, then L, C, R
  runways: auto,

  sids: (
    // Top row 05 and 15, bottom row the opposite directions 23 and 33
    grid: (("05", "15"), ("23", "33")),
    // Drawing height: as large as possible while the sheet fits on one page
    // ("fit"), auto (the width decides) or a length (maximum)
    height: "fit",
    // IDEKO label below its fix (collided with HABFU)
    labels: (IDEKO: "SE"),
    // Variant letters preferred where several SIDs serve one exit fix, e.g.
    // ("Z",); the other SIDs are shown as on request
    preferred: (),
  ),

  ctr: (
    // Height of the control zone map (always the full column width)
    height: 40mm,
    // VRPs shown (auto: the airport's own), e.g. ("DB-N", "DB-M")
    vrps: auto,
    // Move the visible part (east, north) in NM, e.g. for a cut-off VRP label
    shift: (0, 0),
    // MVA label "2000/2300" moved west, it covered VRP D
    mva-shift: ("2000/2300": (-1.2, 0)),
  ),

  // Stations to staff first, bold in the table (none: all IDs bold)
  stations: (primary: ()),

  // Airport specific SOPs worth noting, as (topic, text) pairs; written by
  // hand, the section is left out while this is empty. Example:
  //   (("DEL", [SIDs by northern/southern area]), ("TWR", [...]))
  sops: (),

  // Lines under a section's table or diagram, by section name (as in
  // `columns`); written by hand. From the vACC SOPs and quicksheet
  notes: (
    sids: [HAM + HAMW split only, departure frequency with the clearance: AMLUH, LUGEG, SOKWO, RAMAR 120.540 · ELSOB, IDEKO, HABFU, WSN 134.255],
    approaches: [RWY 33 only at very strong winds (RNP path over the city) · arrivals via E1, hold short of 23],
  ),

  columns: (
    // Left column (SIDs) twice as wide as the right one
    widths: (2fr, 1fr),
    // Spread the shorter column so both end at the same height
    balance: true,
    // Sections top to bottom; a section without content is left out
    left: ("departures", "sids", "stars"),
    // Control zone top right
    right: ("ctr", "stations", "holdings", "approaches", "missed", "sops"),
  ),

  // A4 landscape; fail if the sheet needs a second page
  paper: (size: "a4", flipped: true, one-page: true),
  // Base font and size (all other text sizes are relative to it)
  style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt),
)
