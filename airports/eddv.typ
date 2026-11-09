// EDDV Hannover: settings of the quicksheet.
// `make eddv` -> build/pdf/eddv.pdf. Every setting is listed with the value
// used; details: `quicksheet` in src/lib.typ or the manual (`make docs`).
// For changes the settings do not cover, edit sheets/eddv.typ by hand.
//
// Hand edits in sheets/eddv.typ (make diff-eddv): one holding row per fix
// (the navdata lists them several times, rows checked against the charts)
// and a control zone map of 70mm.

#import "/src/lib.typ": quicksheet

#quicksheet(
  json("/data/EDDV.json"),

  // Runways in the tables (always ordered by number, then L, C, R);
  // 09C/27C (short GA runway) has no SIDs and no approaches
  runways: ("09L", "09R", "27L", "27R"),

  sids: (
    // Left half 09 configuration, right half 27 (north runway on top)
    grid: (("09L", "27R"), ("09R", "27L")),
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
    height: 70mm,
    // VRPs of EDDV only (the area also contains DW-, NW- and VE-...)
    vrps: auto,
    // Visible part 2 NM to the east, so VRP E1's label is not cut off
    shift: (2, 0),
    // MVA label (text as shown) -> offset (east, north) in NM, for a label
    // covering a VRP, e.g. ("2000/2300": (-1.2, 0))
    mva-shift: (:),
  ),

  // Stations to staff first, bold in the table (none set: all IDs bold)
  stations: (primary: ()),

  // Airport specific SOPs worth noting, as (topic, text) pairs; written by
  // hand, the section is left out while this is empty. Example:
  //   (("DEL", [SIDs by northern/southern area]), ("TWR", [...]))
  sops: (),

  // Lines under a section's table or diagram, by section name (as in
  // `columns`); written by hand. Runway assignment from the vACC SOPs
  notes: (sids: [Heavies and northbound departures: 09L/27R · RWY 09: VAXEV departures from 09L]),

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
