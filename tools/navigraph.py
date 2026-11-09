"""Navigraph X-Plane 12 navdata: CIFP procedures, earth_*.dat files."""

import re
from collections import defaultdict
from pathlib import Path

from geometry import is_float


def read_lines(path: Path):
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            yield line.split()


def read_cycle(nav_dir: Path) -> str | None:
    info = nav_dir / "cycle_info.txt"
    m = info.exists() and re.search(r"AIRAC cycle\s*:\s*(\d+)", info.read_text(errors="replace"))
    return m.group(1) if m else None


def load_airport_meta(nav_dir: Path, icao: str) -> dict:
    for t in read_lines(nav_dir / "earth_aptmeta.dat"):
        if t and t[0] == icao and len(t) >= 9:
            return {"lat": float(t[2]), "lon": float(t[3]), "elevation": int(t[4]), "transition_altitude": int(t[8])}
    return {}


def navigraph_fixes(nav_dir: Path) -> dict[str, list]:
    """{name: [(lat, lon, region)]} of all fixes, VORs and NDBs."""
    fixes = defaultdict(list)
    for t in read_lines(nav_dir / "earth_fix.dat"):
        if len(t) >= 5 and is_float(t[0]) and is_float(t[1]):
            fixes[t[2]].append((float(t[0]), float(t[1]), t[4]))
    for t in read_lines(nav_dir / "earth_nav.dat"):
        if len(t) >= 10 and t[0] in ("2", "3"):  # NDB, VOR
            fixes[t[7]].append((float(t[1]), float(t[2]), t[9]))
    return fixes


def load_ils(nav_dir: Path, icao: str) -> tuple[dict[str, dict], list[float]]:
    """Localizers of the airport by runway, and the magnetic variation at each
    (true minus magnetic course; magnetic courses are whole degrees). XP12
    packs the bearing field as "magnetic course * 360 + true course"."""
    result, variations = {}, []
    for t in read_lines(nav_dir / "earth_nav.dat"):
        if len(t) >= 11 and t[8] == icao and t[0] in ("4", "5"):  # LOC with / without GS
            bearing = float(t[6])
            mag = int(bearing // 360) if bearing >= 360 else None
            result[t[10]] = {"ident": t[7], "frequency": f"{int(t[4]) / 100:.2f}", "course": mag}
            if mag is not None:
                variations.append((bearing % 360 - mag + 180) % 360 - 180)
    return result, variations


def load_holds(nav_dir: Path) -> list[dict]:
    holds = []
    for t in read_lines(nav_dir / "earth_hold.dat"):
        if len(t) == 11 and is_float(t[4]):
            holds.append(
                {
                    "fix": t[0],
                    "region": t[1],
                    "airport": t[2],
                    "inbound_course": round(float(t[4])),
                    "leg_time_min": float(t[5]),
                    "leg_length_nm": float(t[6]),
                    "turn": t[7],
                    "min_alt": int(t[8]) or None,
                    "max_alt": int(t[9]) or None,
                    "max_speed": int(t[10]) or None,
                }
            )
    return holds


# --- CIFP/<ICAO>.dat ---------------------------------------------------------
#
# One record per line, "TYPE:field,field,...;extra". Fields used (counted
# after the type): 1 route type, 2 procedure ident, 3 transition, 4 fix,
# 8 waypoint description (4th char: "F" FAF, "M" missed approach point,
# "H" holding fix), 9 turn, 11 leg type, 13 navaid, 20 course (1/10 deg),
# 21 distance (1/10 NM), 22/23/24 altitude rule/value/value2,
# 26/27 speed rule/value.


def read_cifp(path: Path) -> dict[str, list[list[str]]]:
    """{record type ("APPCH", "STAR", "RWY", ...): [fields]}; empty if missing."""
    records = defaultdict(list)
    if path.exists():
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            kind, _, rest = line.partition(":")
            records[kind].append([f.strip() for f in rest.split(";")[0].split(",")])
    return records


def cifp_altitude(value: str) -> int | None:
    """CIFP altitude field: "05000" or "FL120" -> feet."""
    if value.startswith("FL") and value[2:].isdigit():
        return int(value[2:]) * 100
    return int(value) if value.isdigit() else None


def fmt_alt(ft: int, ta: int | None) -> str:
    """5000 -> "5000 ft"; above the transition altitude -> "FL080"."""
    return f"FL{ft // 100:03d}" if ta and ft > ta else f"{ft} ft"


def ils_categories(cifp: dict) -> dict[str, int]:
    """ILS category per runway from the RWY records, e.g.
    "RWY:RW06L,+0102, ,00144, ,IBNE,3, ;..." -> {"06L": 3}."""
    return {f[0].removeprefix("RW"): int(f[6]) for f in cifp["RWY"] if f[6].isdigit()}


def stars(cifp: dict, runway_ids: list[str]) -> list[dict]:
    """Published STARs, one entry per runway: {name, designator, runway,
    entry_fix, entry_level, fixes}. The entry fix is the first fix (of each
    enroute transition, if any); runways come from the runway transitions
    ("RW06L", or "RW06B" for both parallels). `entry_level`: the altitude
    restriction at the entry fix (rule "-" at or below, "+" at or above, ""
    at, "B" between: alt = upper, lower = lower limit)."""
    by_ident = defaultdict(list)
    for r in cifp["STAR"]:
        by_ident[r[2]].append(r)
    result = []
    for ident, recs in by_ident.items():
        transitions = {r[3] for r in recs}
        runways = [rw for rw in runway_ids if f"RW{rw}" in transitions or f"RW{rw[:2]}B" in transitions]
        firsts = {}  # Enroute transition -> its first fix
        for r in recs:
            if r[1] in ("1", "4", "7"):
                firsts.setdefault(r[3], r[4])
        for entry in dict.fromkeys(firsts.values() or [recs[0][4]]):
            level = next(
                (
                    {"rule": r[22], "alt": alt, "lower": cifp_altitude(r[24])}
                    for r in recs
                    if r[4] == entry and (alt := cifp_altitude(r[23])) is not None
                ),
                None,
            )
            for rw in runways:
                result.append(
                    {
                        "name": ident,
                        "designator": ident[-2:],
                        "runway": rw,
                        "entry_fix": entry,
                        "entry_level": level,
                        "fixes": sorted({r[4] for r in recs if r[4]}),
                    }
                )
    return result


APPROACH_TYPES = {
    "I": "ILS",
    "L": "LOC",
    "R": "RNP",
    "H": "RNP",
    "D": "VOR/DME",
    "V": "VOR",
    "S": "VOR",
    "N": "NDB",
    "Q": "NDB/DME",
    "P": "GPS",
    "J": "GLS",
    "X": "LDA",
    "U": "SDF",
    "B": "LOC BC",
    "G": "IGS",
    "T": "TACAN",
}
APPROACH_IDENT_RE = re.compile(r"^(\d{2}[LRC]?)-?([A-Z]?)$")


def missed_approach(records: list[list[str]], ta: int | None = None) -> list[str]:
    """Missed approach as short steps, e.g. ["244° to DB860 ≤3000 ft",
    "LT DB861 ≤190 kt", "KLF 5000 ft ≤250 kt, hold"].

    Starts after the missed approach point (first leg flagged "M"). Legs that
    end without a fix are written out (course to an altitude / DME distance,
    heading, intercept) instead of being estimated.
    """
    start = next((i for i, r in enumerate(records) if r[8].ljust(4)[3] == "M"), None)
    if start is None:
        return []

    def num(v, scale=1):
        return int(v) / scale if v.isdigit() else None

    steps = []
    for r in records[start + 1 :]:
        fix, turn, leg, navaid = r[4], r[9], r[11], r[13] or r[4]
        course = num(r[20], 10)
        crs = f"{course:03.0f}°" if course is not None else ""
        dist = num(r[21], 10)
        alt = {"+": "≥", "-": "≤", "B": "≤"}.get(r[22], "") + fmt_alt(int(r[23]), ta) if r[23].isdigit() else ""
        if r[22] == "B" and r[24].isdigit():  # Between: alt1 is the upper limit
            alt = f"{fmt_alt(int(r[24]), ta)}–{fmt_alt(int(r[23]), ta)}"
        speed = {"+": "≥", "-": "≤"}.get(r[26], "") + f"{int(r[27])} kt" if r[27].isdigit() else ""

        if leg in ("HM", "HA", "HF"):  # Hold at the fix just reached
            if steps and fix in steps[-1] and not steps[-1].endswith("hold"):
                steps[-1] += ", hold"
            elif not steps or not steps[-1].endswith("hold"):
                steps.append(f"hold {fix}")
            continue
        text = {
            "CA": f"{crs} to {alt}",
            "VA": f"HDG {crs[:-1]} to {alt}",
            "FA": f"{fix} {crs} to {alt}",
            "CD": f"{crs} to D{dist:g} {navaid}" if dist else crs,
            "FD": f"{crs} to D{dist:g} {navaid}" if dist else crs,
            "VD": f"HDG {crs[:-1]} to D{dist:g} {navaid}" if dist else f"HDG {crs[:-1]}",
            "CI": f"{crs} intercept",
            "VI": f"HDG {crs[:-1]} intercept",
            "VM": f"HDG {crs[:-1]}, vectors",
            "FM": f"{fix} {crs}, vectors",
            "CF": f"{crs} to {fix}",
        }.get(leg, fix)  # TF, DF, ...: the fix
        if leg in ("CA", "VA", "FA"):
            alt = ""  # Already part of the text
        prefix = {"L": "LT ", "R": "RT "}.get(turn, "")
        steps.append(" ".join(x for x in (prefix + text, alt, speed) if x))
        if r[8].ljust(4)[3] == "H" and r is records[-1]:  # Ends at the holding fix
            steps[-1] += ", hold"
    return steps


def approaches(cifp: dict, ils: dict[str, dict], ta: int | None = None) -> list[dict]:
    """APPCH records grouped into approaches: label ("ILS Z"), FAF, missed
    approach, transitions (route type "A")."""
    by_ident: dict[str, list[list[str]]] = defaultdict(list)
    for r in cifp["APPCH"]:
        by_ident[r[2]].append(r)

    result = []
    for ident, recs in by_ident.items():
        kind = APPROACH_TYPES.get(ident[0], ident[0])
        m = APPROACH_IDENT_RE.match(ident[1:])
        runway, suffix = (m.group(1), m.group(2)) if m else (ident[1:], "")
        faf = next(
            (
                {
                    "fix": r[4],
                    "altitude": int(r[23]) if r[23].isdigit() else None,
                    "course": int(r[20]) / 10 if r[20].isdigit() else None,
                }
                for r in recs
                if r[1] != "A" and r[8].ljust(4)[3] == "F"
            ),
            None,
        )
        result.append(
            {
                "ident": ident,
                "label": f"{kind} {suffix}".strip(),
                "type": kind,
                "runway": runway,
                "suffix": suffix or None,
                "faf": faf,
                "ils": ils.get(runway) if kind in ("ILS", "LOC") else None,
                "transitions": sorted({r[3] for r in recs if r[1] == "A" and r[3]}),
                "missed": missed_approach([r for r in recs if r[1] != "A"], ta),
            }
        )
    result.sort(key=lambda a: (a["runway"], a["type"], a["suffix"] or ""))
    return result
