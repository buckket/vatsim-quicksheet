// Reference manual of the Typst template, generated from the doc comments in
// src/ with tidy: `make docs` -> build/docs.pdf.

#import "@preview/tidy:0.4.3"

#let package = toml("/typst.toml").package

#set document(title: package.name + " " + package.version)
#set page(paper: "a4", margin: 22mm, numbering: "1")
#set text(font: ("IBM Plex Sans", "DejaVu Sans"), size: 10pt)
#set heading(numbering: "1.")
#show raw: set text(font: ("IBM Plex Mono", "DejaVu Sans Mono"))

#align(center)[
  #text(2em, weight: "bold", package.name) \
  #package.description \
  Version #package.version
]

#outline(depth: 1)

= Usage

One sheet per airport: load the extractor's JSON and pass it to `quicksheet`
with the airport's settings (see `airports/*.typ`):

```typ
#import "/src/lib.typ": quicksheet

#quicksheet(
  json("/data/EDDB.json"),
  sids: (grid: (("06L", "24R"), ("06R", "24L")), height: "fit"),
  ctr: (height: 37mm, vrps: ("DB-N", "DB-M")),
  notes: (sids: [Departure release required after every SID with designator K, M or Z]),
  columns: (
    left: ("departures", "sids", "stars", "missed"),
    right: ("ctr", "stations", "holdings", "approaches", "sops"),
  ),
)
```

`quicksheet` writes the page as Typst source and evaluates it. `make`
writes the same source to `sheets/<icao>.typ`: that is the sheet that is
built, and it may be edited by hand. It calls the parts documented below
(`sheet`, `page-columns`, `departures`, `ctr-diagram`, `section`,
`sheet-table`, ...) directly.

// One chapter per module, in the order a reader needs them
#let modules = (
  ("lib.typ", "Quicksheet"),
  ("sheet.typ", "Page parts"),
  ("tables.typ", "Tables and sections"),
  ("util.typ", "Style, formatting, data"),
  ("plot.typ", "SID diagram"),
  ("ctr.typ", "Control zone diagram"),
  ("generate.typ", "Source generation (internal)"),
)
#for (file, title) in modules {
  pagebreak(weak: true)
  heading(title + " (" + raw(file) + ")")
  let docs = tidy.parse-module(read("/src/" + file), name: file)
  tidy.show-module(docs, style: tidy.styles.default, show-module-name: false, first-heading-level: 1)
}
