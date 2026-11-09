"""EuroScope package: sector file (.sct), .ese, vSID configs, TopSky maps."""

import json
import re
from collections import defaultdict
from pathlib import Path

from geometry import es_coords, parse_any_coord

ENCODING = "latin-1"  # EuroScope files are ISO-8859-1 with CRLF line endings
SID_NAME_RE = re.compile(r"^([A-Z]+?)(\d)([A-Z])$")


def read_sections(path: Path) -> dict[str, list[str]]:
    """Split a .sct/.ese file into {section: [lines]} (';' comments stripped).
    Sections that occur several times (e.g. [GROUND]) are concatenated."""
    sections: dict[str, list[str]] = defaultdict(list)
    current = "_header"
    for raw in path.read_text(encoding=ENCODING).splitlines():
        if raw.startswith("["):
            current = raw.strip("[] ").upper()
            continue
        line = raw.split(";", 1)[0].rstrip()
        if line.strip():
            sections[current].append(line)
    return sections


def sct_fixes(sct: dict[str, list[str]]) -> dict[str, list]:
    """{name: [(lat, lon, region)]} from [VOR]/[NDB]/[AIRPORT] (NAME FREQ LAT
    LON) and [FIXES] (NAME LAT LON); no regions in the sector file."""
    fixes = defaultdict(list)
    for section in ("VOR", "NDB", "AIRPORT", "FIXES"):
        for line in sct.get(section, []):
            t = line.split()
            if c := es_coords(t[1:4]):
                fixes[t[0]].append((*c[0], None))
    return fixes


def read_sct_regions(lines: list[str]) -> dict[str, list]:
    """[REGIONS]: {name: [polygon [(lat, lon), ...], ...]}."""
    result: dict[str, list] = defaultdict(list)
    name = None
    for line in lines:
        tokens = line.split()
        if tokens and tokens[0] == "REGIONNAME":
            name = " ".join(tokens[1:])
            continue
        c = es_coords(tokens)
        if name is None or not c:
            continue
        if not line[0].isspace():  # "COLOR_x lat lon" starts a new polygon
            result[name].append([])
        if result[name]:
            result[name][-1].append(c[0])
    return result


def read_ese_sectors(lines: list[str]) -> list[dict]:
    """[AIRSPACE] sectors: {name, lower, upper, owners, active, outline}.
    `owners` is the takeover order (first = responsible station); `active`
    the runways it is tied to, as (airport, runway) from ACTIVE lines (none =
    always active); `outline` are the border lines as lists of (lat, lon),
    together forming the sector's edge."""
    sector_lines: dict[str, list] = defaultdict(list)
    sectors, line_id, sector = [], None, None
    for line in lines:
        key, _, rest = line.partition(":")
        f = rest.split(":")
        if key == "SECTORLINE":
            line_id, sector = f[0], None
        elif key == "COORD" and line_id is not None:
            sector_lines[line_id] += es_coords(f[:2])
        elif key == "SECTOR" and len(f) >= 3:
            line_id = None
            sector = {"name": f[0], "lower": int(f[1]), "upper": int(f[2]), "owners": [], "active": [], "border": []}
            sectors.append(sector)
        elif key == "OWNER" and sector:
            sector["owners"] = f
        elif key == "ACTIVE" and sector and len(f) >= 2:
            sector["active"].append((f[0], f[1]))
        elif key == "BORDER" and sector:
            sector["border"] = f
    for sector in sectors:
        sector["outline"] = [sector_lines[b] for b in sector.pop("border") if b in sector_lines]
    return sectors


def airport_names(es_dir: Path) -> dict[str, str]:
    names = {}
    for path in es_dir.rglob("ICAO_Airports.txt"):
        for line in path.read_text(encoding=ENCODING).splitlines():
            t = line.split("\t")
            if len(t) >= 2 and not line.startswith(";"):
                names.setdefault(t[0].strip(), t[1].strip())
    return names


def load_vsid(es_dir: Path, icao: str) -> dict:
    for path in es_dir.rglob(f"{icao.lower()}.json"):
        if "vsid" in str(path.parent).lower():
            return json.loads(path.read_text(encoding="utf-8")).get(icao, {})
    return {}


def vsid_info(vsid: dict, sid_name: str, runway: str) -> dict:
    """Initial climb, climb-via flag and standard/on-request from the vSID config.
    vSID uses prio >= 90 for SIDs that are only assigned on request."""
    sids = vsid.get("sids", {})
    info = {"initial_climb": sids.get("initial"), "climb_via": None, "standard": True}
    m = SID_NAME_RE.match(sid_name)
    if not m or m.group(1) not in sids:
        return info
    base = sids[m.group(1)]
    info["climb_via"] = base.get("climbvia")
    options = [
        e
        for e in base.get(m.group(3), {}).values()
        if isinstance(e, dict) and runway in str(e.get("rwy", "")).split(",")
    ]
    if options:
        best = min(options, key=lambda o: o.get("prio", 99))
        info["standard"] = best.get("prio", 99) < 90
        info["initial_climb"] = best.get("initial", info["initial_climb"])
        info["climb_via"] = best.get("climbvia", info["climb_via"])
    return info


def read_topsky(es_dir: Path, profile: str) -> tuple[dict[str, list[str]], dict[str, list[int]]]:
    """One TopSky profile (folder name, e.g. "TOPSKY PHX DAY"): its maps as
    {name: lines} (comments stripped; the first map of a name) and its
    colours (COLORDEF) as {name: [r, g, b]}."""
    path = next(es_dir.rglob(f"{profile}/TopSkyMaps.txt"), None)
    if path is None:
        raise SystemExit(f"TopSky profile {profile!r} not found in {es_dir}")
    maps, colors, current = {}, {}, None
    for raw in path.read_text(encoding=ENCODING).splitlines():
        line = raw.split("//", 1)[0].strip()
        if line.startswith("MAP:"):
            name = line[4:].strip()
            current = None if name in maps else maps.setdefault(name, [])
        elif m := re.match(r"^COLORDEF:([^:]+):(\d+):(\d+):(\d+)", line):
            colors[m.group(1)] = [int(v) for v in m.groups()[1:]]
        elif current is not None and line:
            current.append(line)
    return maps, colors


def topsky_shapes(lines: list[str]) -> list[tuple[str, str, list]]:
    """All shapes of a map as (colour, kind, [(lat, lon), ...]): "segment" for
    LINE, "line" / "polygon" for COORD sequences ended by COORDLINE / COORDPOLY.
    The colour tells the categories apart (e.g. "Highway", "River")."""
    shapes, color, coords = [], "", []
    for line in lines:
        key, _, rest = line.partition(":")
        if key == "COLOR":
            color = rest.strip()
        elif key in ("LINE", "COORD"):
            c = [parse_any_coord(t) for t in rest.split(":")[: 4 if key == "LINE" else 2]]
            if None in c:
                continue
            if key == "LINE" and len(c) == 4:
                shapes.append((color, "segment", [(c[0], c[1]), (c[2], c[3])]))
            elif key == "COORD" and len(c) == 2:
                coords.append((c[0], c[1]))
        elif key in ("COORDLINE", "COORDPOLY"):
            if len(coords) >= 2:
                shapes.append((color, "line" if key == "COORDLINE" else "polygon", coords))
            coords = []
    return shapes


def topsky_segments(lines: list[str]) -> list:
    """LINE entries of a map as ((lat, lon), (lat, lon))."""
    return [tuple(pts) for _, kind, pts in topsky_shapes(lines) if kind == "segment"]


def topsky_texts(lines: list[str]) -> dict[tuple[float, float], str]:
    """TEXT:lat:lon:text entries as {(lat, lon): text}."""
    texts = {}
    for line in lines:
        if line.startswith("TEXT:"):
            t = line.split(":", 3)
            if len(t) == 4 and None not in (lat := parse_any_coord(t[1]), lon := parse_any_coord(t[2])):
                texts[(lat, lon)] = t[3].strip()
    return texts
