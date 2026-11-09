#!/usr/bin/env python3
"""Extract quicksheet data for one or more airports into JSON files for Typst.

Data sources (local, in input/, licensed for personal use, not in the repository):
  * EuroScope package (euroscope.py): .sct / .ese, vSID configs, TopSky maps
      -> runways, fixes, stations, sectors, SIDs, control zone, MVA, topography
  * Navigraph X-Plane 12 navdata (navigraph.py): CIFP, earth_*.dat
      -> STARs, approaches, holdings, ILS data, fallback fix coordinates

Coordinates are projected to a local plane centred on the airport reference
point (geometry.py): x = east, y = north, both in nautical miles. That keeps
the Typst/cetz side free of any geodesy.

Usage (see the Makefile):
  python3 tools/extract.py EDDB EDDV EDDW [--euroscope input/EDWW]
      [--navdata input/xplane12-native-2611-r4] [--out data]
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from itertools import pairwise
from pathlib import Path

import euroscope as es
import navigraph as nav
from geometry import (
    Projection,
    bearing_deg,
    chain,
    clip_polygon,
    clip_segment,
    closed_parts,
    distance_nm,
    es_coords,
    in_outline,
    is_float,
    on_segment,
)

COMPASS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
STATION_ORDER = {"ATIS": 0, "DEL": 1, "GND": 2, "TWR": 3, "APP": 4, "DEP": 5, "CTR": 6}


def nearest(fixes: dict, name: str, near: tuple[float, float], region: str | None = None):
    """(lat, lon) of the fix `name` nearest to `near` (names are not unique),
    preferring the given region; None if unknown."""
    cands = fixes.get(name, [])
    if region:
        cands = [c for c in cands if c[2] in (region, None)] or cands
    if not cands:
        return None
    lat, lon, _ = min(cands, key=lambda c: distance_nm(*near, c[0], c[1]))
    return lat, lon


def sid_diagrams(sids: list[dict]) -> dict[str, dict]:
    """SID diagram per runway (see `runway_diagram`)."""
    by_runway: dict[str, list[dict]] = defaultdict(list)
    for s in sids:
        if len(s["points"]) >= 2:
            by_runway[s["runway"]].append(s)
    return {runway: runway_diagram(group) for runway, group in by_runway.items()}


def runway_diagram(sids: list[dict]) -> dict:
    """The SIDs of one runway with every leg once, as lines ready to draw.

    A line lists the SIDs flying it; `exit_fix` is null where SIDs to more
    than one exit fix share it (drawn neutral). `branches`: positions of the
    fixes where SIDs split off or join a shared line.
    """
    pos = {n: tuple(p) for s in sids for n, p in zip(s["fixes"], s["points"], strict=True)}

    # Legs, split where another route's fix lies on them (A->C vs A->B->C)
    users: dict[frozenset, list[dict]] = defaultdict(list)
    # Legs in flight direction (as first flown): a frozenset's own order
    # depends on Python's string hashing, which changes from run to run
    direction: dict[frozenset, tuple[str, str]] = {}
    for s in sids:
        seq = s["fixes"][:1]
        for a, b in pairwise(s["fixes"]):
            inner = sorted(
                (t, v) for v in pos if v not in (a, b) and (t := on_segment(pos[v], pos[a], pos[b])) is not None
            )
            seq += [v for _, v in inner] + [b]
        for a, b in pairwise(seq):
            leg = frozenset((a, b))
            direction.setdefault(leg, (a, b))
            if a != b and s not in users[leg]:
                users[leg].append(s)

    def sid_names(leg):
        return tuple(sorted(s["name"] for s in users[leg]))

    def exit_fix(leg):
        exits = {s["exit_fix"] for s in users[leg]}
        return exits.pop() if len(exits) == 1 else None

    # Legs flown by the same SIDs form continuous lines
    by_sids: dict[tuple, list] = defaultdict(list)
    for leg in users:
        by_sids[sid_names(leg)].append(leg)
    lines = [
        {"points": line, "exit_fix": exit_fix(legs[0]), "sids": list(names)}
        for names, legs in by_sids.items()
        for line in chain([(pos[a], pos[b]) for a, b in map(direction.get, legs)])
    ]

    ends = {s["fixes"][0] for s in sids} | {s["fixes"][-1] for s in sids}
    touching: dict[str, list[frozenset]] = defaultdict(list)
    for leg in users:
        for v in leg:
            touching[v].append(leg)
    branches = [
        list(pos[v])
        for v, legs in sorted(touching.items())
        if v not in ends and any(exit_fix(leg) is None for leg in legs) and len({sid_names(leg) for leg in legs}) > 1
    ]
    return {"lines": lines, "branches": branches}


def _single(directory: Path, pattern: str) -> Path:
    matches = sorted(directory.glob(pattern))
    if not matches:
        raise SystemExit(f"no {pattern} file found in {directory}")
    if len(matches) > 1:
        print(f"warning: several {pattern} files, using {matches[-1].name}", file=sys.stderr)
    return matches[-1]


def magnetic_variation(ils_variations: list[float], sct_info: list[str]) -> float | None:
    """East positive: mean of the airport's ILS (true - magnetic course), else
    the sector file's single value for the whole FIR (west positive there)."""
    if ils_variations:
        return round(sum(ils_variations) / len(ils_variations), 1)
    if len(sct_info) > 7 and is_float(sct_info[7]):
        return round(-float(sct_info[7]), 1)
    return None


class Extractor:
    """Reads all sources once; `extract(icao)` assembles one airport."""

    def __init__(self, es_dir: Path, nav_dir: Path):
        self.es_dir, self.nav_dir = es_dir, nav_dir
        sct_path, ese_path = _single(es_dir, "*.sct"), _single(es_dir, "*.ese")
        print(f"reading {sct_path.name}, {ese_path.name}", file=sys.stderr)
        self.sct = es.read_sections(sct_path)
        self.ese = es.read_sections(ese_path)
        self.sources = {
            "euroscope": self.sct.get("INFO", [""])[0].strip(),
            "navigraph_airac": nav.read_cycle(nav_dir),
        }
        self.sct_fixes = es.sct_fixes(self.sct)
        self.nav_fixes = nav.navigraph_fixes(nav_dir)
        self.holds = nav.load_holds(nav_dir)
        # TopSky: CTR outlines ("<ICAO> CTR") are only in the EDWW profile;
        # MVA, topography and its colours (as EuroScope draws them) in PHX DAY
        self.ctr_maps, _ = es.read_topsky(es_dir, "TOPSKY EDWW")
        self.phx_maps, self.topo_colors = es.read_topsky(es_dir, "TOPSKY PHX DAY")
        self.topography = es.topsky_shapes(self.phx_maps.get("TOPOGRAPHY", []))
        self.regions = es.read_sct_regions(self.sct.get("REGIONS", []))
        self.sectors = es.read_ese_sectors(self.ese.get("AIRSPACE", []))
        self.airport_names = es.airport_names(es_dir)

    def resolve(self, name: str, ref):
        """Fix lookup: EuroScope first (same source as the procedures)."""
        return nearest(self.sct_fixes, name, ref) or nearest(self.nav_fixes, name, ref)

    def extract(self, icao: str) -> dict:
        meta = nav.load_airport_meta(self.nav_dir, icao)
        ref = nearest(self.sct_fixes, icao, (meta.get("lat", 0), meta.get("lon", 0)))
        if ref is None:
            if not meta:
                raise SystemExit(f"{icao}: airport not found in sector file or navdata")
            ref = (meta["lat"], meta["lon"])
        proj = Projection(*ref)
        vsid = es.load_vsid(self.es_dir, icao)
        cifp = nav.read_cifp(self.nav_dir / "CIFP" / f"{icao}.dat")
        ta = vsid.get("transAlt", meta.get("transition_altitude"))

        runways = self._runways(icao, proj, nav.ils_categories(cifp))
        stations = self._stations(icao)
        app_ids = {s["id"] for s in stations if s["type"] in ("APP", "DEP")}
        # Airports without DEP stations hand departures over to APP
        dep_ids = {s["id"] for s in stations if s["type"] == "DEP"} or {s["id"] for s in stations if s["type"] == "APP"}
        sids = self._sids(icao, runways, vsid, dep_ids, proj)
        stars = self._stars(cifp, runways, app_ids, proj)
        ils, variations = nav.load_ils(self.nav_dir, icao)
        approaches = nav.approaches(cifp, ils, ta)
        holdings = self._holdings(icao, stars, approaches, app_ids, proj)
        diagrams = sid_diagrams(sids)

        # Only needed here (diagrams, holdings), not on the sheet
        for items, key in ((sids, "fixes"), (stars, "fixes"), (approaches, "transitions")):
            for item in items:
                del item[key]
        return {
            "icao": icao,
            "name": self.airport_names.get(icao),
            "sources": self.sources,
            "elevation": vsid.get("elevation", meta.get("elevation")),
            "transition_altitude": ta,
            "magnetic_variation": magnetic_variation(variations, self.sct.get("INFO", [])),
            "runways": runways,
            "stations": stations,
            "sids": sids,
            "sid_diagrams": diagrams,
            "stars": stars,
            "holdings": holdings,
            "approaches": approaches,
            "ctr": self._ctr(icao, proj),
        }

    def _runways(self, icao: str, proj: Projection, ils_categories: dict) -> list[dict]:
        """Runways from the sector file (for drawing), ILS category per end."""
        runways = []
        for line in self.sct.get("RUNWAY", []):
            t = line.split()
            if len(t) < 9 or t[8] != icao or len(ends := es_coords(t[4:8])) != 2:
                continue
            ids = [t[0], t[1]]
            runways.append(
                {
                    "ids": ids,
                    "ends": [
                        {"id": ids[k], "pos": proj.xy(*end), "ils_category": ils_categories.get(ids[k])}
                        for k, end in enumerate(ends)
                    ],
                }
            )
        return runways

    def _stations(self, icao: str) -> list[dict]:
        stations = []
        for line in self.ese.get("POSITIONS", []):
            t = line.split(":")
            if len(t) >= 7 and t[5] == icao:
                stations.append({"callsign": t[0], "name": t[1], "frequency": t[2], "id": t[3], "type": t[6]})
        stations.sort(key=lambda s: (STATION_ORDER.get(s["type"], 9), s["name"], s["callsign"]))
        return stations

    def _sids(self, icao, runways, vsid, dep_ids, proj) -> list[dict]:
        """SIDs from the .ese ("SID:<icao>:<runway>:<name>:<fixes>"), with the
        vSID data and the departure station(s)."""
        sids = []
        for line in self.ese.get("SIDSSTARS", []):
            t = line.split(":")
            if len(t) >= 5 and t[0] == "SID" and t[1] == icao:
                sid = self._sid(icao, t[2], t[3], t[4].split(), runways, vsid, proj)
                sid["dep"] = self._dep_stations(icao, sid, dep_ids, proj.ref)
                sids.append(sid)
        return sids

    def _sid(self, icao, runway, name, waypoints, runways, vsid, proj) -> dict:
        exit_fix = waypoints[-1] if waypoints else None
        # Omnidirectional departure (OID), e.g. "EDDB1B": coded without fixes
        # (runway heading to an altitude, then radar vectors)
        oid = exit_fix == icao
        named = []  # (fix, [x, y])
        exit_pos = None
        if not oid:
            # From the departure end of the runway (= threshold of the opposite direction)
            for rwy in runways:
                if runway in rwy["ids"]:
                    end = rwy["ends"][1 - rwy["ids"].index(runway)]
                    named.append((f"RW{runway}", end["pos"]))
            named += [(w, proj.xy(*p)) for w in waypoints if (p := self.resolve(w, proj.ref))]
            exit_pos = self.resolve(exit_fix, proj.ref)
        bearing = bearing_deg(*proj.ref, *exit_pos) if exit_pos else None
        return {
            "name": name,
            "runway": runway,
            "exit_fix": exit_fix,
            "exit": proj.xy(*exit_pos) if exit_pos else None,
            "bearing": None if bearing is None else round(bearing),
            # Side of the exit fix label (away from the airport)
            "direction": None if bearing is None else COMPASS[int((bearing + 22.5) // 45) % 8],
            "oid": oid,
            "fixes": [n for n, _ in named],
            "points": [xy for _, xy in named] if len(named) >= 2 else [],
            **es.vsid_info(vsid, name, runway),
        }

    def _stars(self, cifp, runways, app_ids, proj) -> list[dict]:
        """STARs from the CIFP, with the bearing of the entry fix and the APP
        sector(s) there at the entry level (or anywhere in a level window)."""
        stars = nav.stars(cifp, [i for r in runways for i in r["ids"]])
        for s in stars:
            pos = self.resolve(s["entry_fix"], proj.ref)
            level = s["entry_level"] or {"rule": "", "alt": 0, "lower": None}
            lower = level["lower"] if level["rule"] == "B" else None
            s["bearing"] = round(bearing_deg(*proj.ref, *pos)) if pos else None
            s["app"] = self._app_stations(pos, level["alt"], app_ids, lower)[0] if pos else []
        return stars

    def _sectors_at(self, pos, owners: set[str]) -> list[dict]:
        """Sectors containing `pos` whose responsible station (first OWNER) is
        one of `owners`."""
        return [
            sec
            for sec in self.sectors
            if sec["owners"] and sec["owners"][0] in owners and in_outline(sec["outline"], *pos)
        ]

    def _app_stations(self, pos, alt: int, app_ids: set[str], lower: int | None = None) -> tuple[list[str], int | None]:
        """APP/DEP stations of the airport whose sectors contain `pos` at
        `alt`, or anywhere in `lower`..`alt` if given, and - if exactly one -
        the highest level below that sector's ceiling (13500 ft -> FL130)."""
        bottom = alt if lower is None else lower
        sectors = [sec for sec in self._sectors_at(pos, app_ids) if sec["lower"] <= alt and bottom <= sec["upper"]]
        owners = sorted({sec["owners"][0] for sec in sectors})
        ceiling = (sectors[0]["upper"] - 500) // 1000 * 1000 if len(owners) == 1 else None
        return owners, ceiling

    def _dep_stations(self, icao: str, sid: dict, dep_ids: set[str], ref) -> list[str]:
        """Departure station of a SID: first owner of the lowest departure
        sector containing the first fix after the runway. Sectors tied to
        runways (ACTIVE lines) count for the runway direction of the SID, i.e.
        with all parallel runways of that direction in use."""
        if len(sid["fixes"]) < 2 or (pos := self.resolve(sid["fixes"][1], ref)) is None:
            return []

        def active(sec):
            own = [rwy for apt, rwy in sec["active"] if apt == icao]
            return not sec["active"] or any(rwy[:2] == sid["runway"][:2] for rwy in own)

        sectors = [sec for sec in self._sectors_at(pos, dep_ids) if active(sec)]
        lowest = min((sec["lower"] for sec in sectors), default=None)
        return sorted({sec["owners"][0] for sec in sectors if sec["lower"] == lowest})

    def _holdings(self, icao, stars, approaches, app_ids, proj, max_dist=80) -> list[dict]:
        """Holds at STAR fixes, approach (transition) fixes, or tagged with the
        airport, with the APP station(s) at the holding altitude and the
        highest level of that sector (`app_max_alt`, see `_app_stations`)."""
        relevant = {f for s in stars for f in s["fixes"]}
        relevant |= {t for a in approaches for t in a["transitions"]}
        relevant |= {a["faf"]["fix"] for a in approaches if a["faf"]}
        result, seen = [], set()
        for h in self.holds:
            if h["airport"] != icao and h["fix"] not in relevant:
                continue
            pos = nearest(self.nav_fixes, h["fix"], proj.ref, h["region"])
            if pos is None or distance_nm(*proj.ref, *pos) > max_dist:
                continue
            hold = {k: v for k, v in h.items() if k not in ("region", "airport")}
            hold["app"], hold["app_max_alt"] = self._app_stations(pos, h["min_alt"] or 0, app_ids)
            if repr(hold) not in seen:  # The navdata lists some holds several times
                seen.add(repr(hold))
                result.append(hold)
        return sorted(result, key=lambda h: h["fix"])

    def _ctr(self, icao: str, proj: Projection, margin: float = 0.12, extra: float = 0.6) -> dict | None:
        """Control zone diagram data around the CTR (see `bounds` / `area`).

        CTR boundary, MVA and topography come from the TopSky maps; VRPs
        (fixes named like "DB-N") and built-up areas from the sector file.
        """
        ctr_map = self.ctr_maps.get(f"{icao} CTR")
        if ctr_map is None:
            return None

        def xy_segs(segs):
            return [(proj.xy(*a), proj.xy(*b)) for a, b in segs]

        # CTR maps may also contain extended centrelines and distance ticks:
        # keep only what is part of a closed outline
        segments = xy_segs(es.topsky_segments(ctr_map))
        boundary = chain(closed_parts(segments)) or chain(segments)
        xs = [pt[0] for line in boundary for pt in line]
        ys = [pt[1] for line in boundary for pt in line]
        size = max(max(xs) - min(xs), max(ys) - min(ys))
        pad = margin * size
        # `bounds`: the CTR plus a margin, always fully visible. `area`: what the
        # map content covers, wider and centred on the CTR, so the diagram can
        # fill any width by showing more of the surroundings.
        bounds = (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)
        cx, cy = (bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2
        half = max(bounds[2] - bounds[0], bounds[3] - bounds[1]) / 2 + extra * size
        box = (cx - half, cy - half, cx + half, cy + half)

        def clipped(segs):
            return chain([c for a, b in xy_segs(segs) if (c := clip_segment(a, b, box))])

        def clipped_polygons(polys):
            return [c for poly in polys if len(c := clip_polygon([proj.xy(*p) for p in poly], box)) >= 3]

        def inside(x, y):
            return box[0] <= x <= box[2] and box[1] <= y <= box[3]

        # MVA: summer and winter share the sector boundaries, only the altitudes differ
        mva_lines, labels = [], {}
        for season in ("summer", "winter"):
            m = self.phx_maps.get(f"{season.upper()}_MVA")
            if m is None:
                continue
            mva_lines = mva_lines or clipped(es.topsky_segments(m))
            for (lat, lon), text in es.topsky_texts(m).items():
                x, y = proj.xy(lat, lon)
                if inside(x, y) and text.isdigit():
                    labels.setdefault((x, y), {"pos": [x, y]})[season] = int(text) * 100

        # Topography (TopSky TOPOGRAPHY map): motorways, rivers/canals, lakes
        topo = [shape for shape in self.topography if any(inside(*proj.xy(*p)) for p in shape[2])]

        def topo_lines(color):
            return clipped([seg for c, kind, pts in topo if c == color and kind != "polygon" for seg in pairwise(pts)])

        vrps = []
        for line in self.sct.get("FIXES", []):
            t = line.split()
            if re.match(r"^[A-Z]{2}-[A-Z0-9]+$", t[0]) and (c := es_coords(t[1:3])):
                x, y = proj.xy(*c[0])
                if inside(x, y):
                    vrps.append({"fix": t[0], "label": t[0].split("-", 1)[1], "pos": [x, y]})

        return {
            "bounds": [round(v, 3) for v in bounds],
            "area": [round(v, 3) for v in box],
            "boundary": boundary,
            "vrps": sorted(vrps, key=lambda v: v["fix"]),
            "mva": {"lines": mva_lines, "labels": list(labels.values())},
            "highways": topo_lines("Highway"),
            "rivers": topo_lines("River"),
            "lakes": clipped_polygons(pts for _, kind, pts in topo if kind == "polygon"),
            # Topography colours as drawn in EuroScope
            "colors": {k.lower(): self.topo_colors[k] for k in ("Highway", "River", "City")},
            "city": clipped_polygons(
                poly for name, polys in self.regions.items() if "city" in name.lower() for poly in polys
            ),
        }


def to_json(value, indent: str = "") -> str:
    """JSON with one point, list of values or polyline per line (readable
    diffs); objects and other lists are indented, one entry per line."""

    def scalar(v) -> bool:
        return not isinstance(v, dict | list)

    # A list of values or of points (lists of values): one line
    if isinstance(value, list) and all(scalar(v) or (isinstance(v, list) and all(map(scalar, v))) for v in value):
        return json.dumps(value, ensure_ascii=False, separators=(", ", ": "))
    if not isinstance(value, dict | list):
        return json.dumps(value, ensure_ascii=False)
    inner = indent + " "
    if isinstance(value, dict):
        items = [f"{inner}{json.dumps(k)}: {to_json(v, inner)}" for k, v in value.items()]
        brackets = "{}"
    else:
        items = [inner + to_json(v, inner) for v in value]
        brackets = "[]"
    if not items:
        return brackets
    return brackets[0] + "\n" + ",\n".join(items) + "\n" + indent + brackets[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("airports", nargs="+", help="ICAO codes, e.g. EDDB EDDH")
    newest_navdata = max(Path("input").glob("xplane12-native-*"), default=None)
    parser.add_argument(
        "--euroscope", type=Path, default=Path("input/EDWW"), help="EuroScope package directory with the .sct/.ese"
    )
    parser.add_argument(
        "--navdata", type=Path, default=newest_navdata, help="Navigraph X-Plane 12 navdata (default: newest in input/)"
    )
    parser.add_argument("--out", type=Path, default=Path("data"), help="output directory")
    args = parser.parse_args()

    extractor = Extractor(args.euroscope, args.navdata)
    args.out.mkdir(parents=True, exist_ok=True)
    for icao in (a.upper() for a in args.airports):
        data = extractor.extract(icao)
        out = args.out / f"{icao}.json"
        out.write_text(to_json(data) + "\n", encoding="utf-8")
        print(
            f"{icao}: {len(data['runways'])} runways, {len(data['stations'])} stations, "
            f"{len(data['sids'])} SIDs, {len(data['stars'])} STARs, "
            f"{len(data['holdings'])} holdings, {len(data['approaches'])} approaches -> {out}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
