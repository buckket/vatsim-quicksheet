#!/usr/bin/env python3
"""Prepare the release files: the sheets under their release names, the
release notes and the asset labels.

  <out>/<ICAO>-AIRAC<cycle>.pdf  one per airport (data/<ICAO>.json)
  <out>/notes.md                 release text: table of the airports and their PDFs
  <out>/assets.txt               one `file#label` per line for `gh release create`
                                 (GitHub shows the label)

Usage: python3 tools/release.py --pdf build/pdf --data data --out build/publish
         [--tag 2611] [--repo owner/name]
"""

import argparse
import json
import shutil
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--pdf", type=Path, required=True, help="built sheets (<icao>.pdf)")
    parser.add_argument("--data", type=Path, required=True, help="extracted data (<ICAO>.json)")
    parser.add_argument("--out", type=Path, required=True, help="output folder (emptied first)")
    parser.add_argument("--tag", default="", help="release tag (default: the AIRAC cycle)")
    parser.add_argument("--repo", default="buckket/vatsim-quicksheet", help="GitHub owner/name")
    args = parser.parse_args()

    airports = [json.loads(p.read_text()) for p in sorted(args.data.glob("*.json"))]
    if not airports:
        sys.exit(f"no data in {args.data}")
    # All sheets of a release come from one data set
    sources = {json.dumps(a["sources"], sort_keys=True) for a in airports}
    if len(sources) != 1:
        sys.exit("the airports were extracted from different data: " + ", ".join(sorted(sources)))
    airac = airports[0]["sources"]["navigraph_airac"]
    tag = args.tag or airac
    url = f"https://github.com/{args.repo}/releases/download/{tag}"

    if args.out.exists():
        shutil.rmtree(args.out)
    args.out.mkdir(parents=True)

    assets, rows = [], []
    for a in airports:
        icao, name = a["icao"], a["name"].title()
        file = f"{icao}-AIRAC{airac}.pdf"
        shutil.copyfile(args.pdf / f"{icao.lower()}.pdf", args.out / file)
        assets.append(f"{file}#{icao} {name}")
        rows.append(f"| {icao} | {name} | [{file}]({url}/{file}) |")

    notes = ["| ICAO | Airport | Sheet |", "|---|---|---|", *rows]
    (args.out / "notes.md").write_text("\n".join(notes) + "\n")
    (args.out / "assets.txt").write_text("\n".join(assets) + "\n")
    print(f"{args.out}: {len(airports)} sheets, AIRAC {airac}, tag {tag}")


if __name__ == "__main__":
    main()
