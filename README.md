# VATSIM airport quicksheets

One-page A4 quicksheets for controlling the airports of the Bremen FIR (EDWW)
on [VATSIM](https://vatsim.net): SIDs, STARs, approaches, holdings,
frequencies and a control zone map. Currently EDDB, EDDH, EDDV and EDDW.

> [!IMPORTANT]
> For flight simulation use only. Unofficial; not affiliated with VATSIM,
> VATSIM Germany or Navigraph.

**Download:** the PDFs for the current AIRAC cycle are on the
[Releases](https://github.com/buckket/vatsim-quicksheet/releases) page.

## Building

Requires [Typst](https://github.com/typst/typst) 0.15, the font
[IBM Plex Sans](https://github.com/IBM/plex), GNU make and Python 3.12+.

```sh
make              # build all sheets -> build/pdf/
make eddb         # build one sheet
```

The data (`data/`) is extracted from the EuroScope package for EDWW and
Navigraph navdata for X-Plane 12. Both are licensed for personal use and not
included: to update the data, put them into `input/EDWW/` and
`input/xplane12-native-<cycle>/` and run `make`.

## Editing a sheet

Each airport has two files:

- `airports/<icao>.typ` holds the settings (layout, VRPs, notes, ...). Change
  these first; `make docs` documents all of them.
- `sheets/<icao>.typ` is the full sheet that `make` generates from the
  settings, and the file that is actually built. Edit it directly for
  anything the settings cannot do.

When the settings, data or template change, `make` merges the update into the
sheet like a git merge: hand edits are kept, conflicts are resolved in the
file. `make diff-<icao>` shows the hand edits.

Commit `sheets/` together with the change; CI fails if it is out of date.

## Adding an airport

On a branch, `make new-<icao>` creates the settings from a template,
extracts the data and builds a first draft. Adapt it, check it against the
current charts and SOPs, and open a pull request. Every airport on `main` is
released.

## Releasing

Tag the commit with the AIRAC cycle (`2611.1` etc. for a re-release); CI
publishes the release:

```sh
git tag -m "AIRAC 2611" 2611 && git push origin 2611
```

## License

The code is licensed under the [MIT License](LICENSE). The data in `data/`
and `sheets/` and the released PDFs are derived from the EuroScope package
(AeroNav/GNG) and Navigraph navdata, are not covered by it, and are for
flight simulation use only.
