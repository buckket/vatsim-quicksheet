// EDDW Bremen: settings of the quicksheet.
// `make eddw` -> build/pdf/eddw.pdf. Every setting is listed with the value
// used; details: `quicksheet` in src/lib.typ or the manual (`make docs`).
// For changes the settings do not cover, edit sheets/eddw.typ by hand.

#import "/src/lib.typ": quicksheet

#quicksheet(
  json("/data/EDDW.json"),

  // Runways in the tables (always ordered by number, then L, C, R);
  // 05/23 (698 m) has no SIDs: tables only for the main runway
  runways: ("08", "26"),

  sids: (
    // Left: 08 configuration, right: 26 configuration
    grid: (("08", "26"),),
    // Drawing height: as large as possible while the sheet fits on one page
    height: "fit",
    // Label side of an exit fix where the default (away from the airport)
    // collides with another label, e.g. (GERGA: "N")
    labels: (:),
    // Z SIDs are preferred where they exist; the others are on request
    preferred: ("Z",),
  ),

  ctr: (
    // Height of the control zone map (always the full column width)
    height: 40mm,
    // VRPs of the airport (N, S1, S2, W), all current
    vrps: auto,
    // Move the visible part (east, north) in NM, e.g. for a cut-off VRP label
    shift: (0, 0),
    // MVA label (text as shown) -> offset (east, north) in NM, for a label
    // covering a VRP, e.g. ("2000/2300": (-1.2, 0))
    mva-shift: (:),
  ),

  // One station per position: no primary stations, all IDs bold
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
    // Sections top to bottom; a section without content is left out
    // STARs and holdings side by side under the SIDs
    left: ("departures", "sids", ("stars", "holdings")),
    // Control zone top right
    // Control zone top right
    right: ("ctr", "stations", "approaches", "missed", "sops"),
  ),

  // A4 landscape; fail if the sheet needs a second page
  paper: (size: "a4", flipped: true, one-page: true),
  // Base font and size (all other text sizes are relative to it)
  style: (font: ("IBM Plex Sans", "DejaVu Sans"), size: 7pt),
)
