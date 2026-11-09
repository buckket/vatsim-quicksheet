// {ICAO}: settings of the quicksheet.
// `make {icao}` -> build/pdf/{icao}.pdf. Every setting is listed with the value
// used; details: `quicksheet` in src/lib.typ or the manual (`make docs`).
// For changes the settings do not cover, edit sheets/{icao}.typ by hand.
//
// New airport, not checked yet: compare the sheet with the current charts,
// vSID configuration and vACC SOPs, adapt the settings below and replace
// the generic comments with airport-specific ones where a value is changed.

#import "/src/lib.typ": quicksheet

#quicksheet(
  json("/data/{ICAO}.json"),

  // Runways in the tables (auto: all); always ordered by number, then L, C, R
  runways: auto,

  sids: (
    // Rows of runways for the SID diagrams (auto: the table runways, two per
    // row), e.g. (("06L", "24R"), ("06R", "24L"))
    grid: auto,
    // Drawing height: as large as possible while the sheet fits on one page
    // ("fit"), auto (the width decides) or a length (maximum)
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
    height: 40mm,
    // VRPs shown (auto: the airport's own), e.g. ("DB-N", "DB-M")
    vrps: auto,
    // Move the visible part (east, north) in NM, e.g. for a cut-off VRP label
    shift: (0, 0),
    // MVA label (text as shown) -> offset (east, north) in NM, for a label
    // covering a VRP, e.g. ("2000/2300": (-1.2, 0))
    mva-shift: (:),
  ),

  // Stations to staff first, bold in the table (none: all IDs bold)
  stations: (primary: ()),

  // Airport specific SOPs worth noting, as (topic, text) pairs; written by
  // hand, the section is left out while this is empty. Example:
  //   (("DEL", [SIDs by northern/southern area]), ("TWR", [...]))
  sops: (),

  // Lines under a section's table or diagram, by section name (as in
  // `columns`); written by hand. Example: (sids: [Release required ...])
  notes: (:),

  columns: (
    // Left column (SIDs) twice as wide as the right one
    widths: (2fr, 1fr),
    // Spread the shorter column so both end at the same height
    balance: true,
    // Sections top to bottom; a section without content is left out; an
    // array puts sections side by side, e.g. ("stars", "holdings")
    left: ("departures", "sids", "holdings"),
    // Control zone top right
    right: ("ctr", "stations", "approaches", "missed", "stars", "sops"),
  ),

  // A4 landscape; fail if the sheet needs a second page
  paper: (size: "a4", flipped: true, one-page: true),
  // Base font and size (all other text sizes are relative to it)
  style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt),
)
