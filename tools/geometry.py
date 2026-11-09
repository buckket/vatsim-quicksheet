"""Coordinates and plane geometry: EuroScope coordinates, distances, the
local projection (NM around the airport), clipping, joining lines."""

import math
import re
from collections import defaultdict
from itertools import pairwise

ON_LINE = 0.1  # NM: a point this close to a segment lies on it (splits it)

COORD_RE = re.compile(r"^([NSEW])(\d{3})\.(\d{2})\.(\d{2}(?:\.\d+)?)$")


def parse_es_coord(token: str) -> float | None:
    """EuroScope coordinate like N053.38.20.307 -> decimal degrees."""
    m = COORD_RE.match(token)
    if not m:
        return None
    hemi, deg, minutes, sec = m.groups()
    value = int(deg) + int(minutes) / 60 + float(sec) / 3600
    return -value if hemi in "SW" else value


def is_float(s: str) -> bool:
    try:
        float(s)
        return True
    except ValueError:
        return False


def parse_any_coord(token: str) -> float | None:
    """EuroScope (N052.21.00.000) or decimal (52.35) coordinate."""
    v = parse_es_coord(token)
    return float(token) if v is None and is_float(token) else v


def es_coords(tokens: list[str]) -> list[tuple[float, float]]:
    """All (lat, lon) pairs among the EuroScope coordinate tokens of a line."""
    values = [v for t in tokens if (v := parse_es_coord(t)) is not None]
    return list(zip(values[::2], values[1::2], strict=False))  # An odd value is ignored


def distance_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * math.asin(math.sqrt(a)) * 3440.065


def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


class Projection:
    """Local equirectangular projection in NM around a reference point."""

    def __init__(self, lat0: float, lon0: float):
        self.ref = lat0, lon0
        self.k = math.cos(math.radians(lat0))

    def xy(self, lat: float, lon: float) -> list[float]:
        return [round((lon - self.ref[1]) * 60 * self.k, 3), round((lat - self.ref[0]) * 60, 3)]


def in_outline(outline: list, lat: float, lon: float) -> bool:
    """Point in an area given as border lines of (lat, lon) (even-odd rule)."""
    hits = 0
    for pts in outline:
        for (y1, x1), (y2, x2) in pairwise(pts):
            if (y1 > lat) != (y2 > lat) and lon < x1 + (lat - y1) * (x2 - x1) / (y2 - y1):
                hits += 1
    return hits % 2 == 1


def on_segment(p, a, b) -> float | None:
    """Position (0..1) of p along segment a->b if p lies on it, else None."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length2 = dx * dx + dy * dy
    if length2 == 0:
        return None
    vx, vy = p[0] - a[0], p[1] - a[1]
    t = (vx * dx + vy * dy) / length2
    dist = abs(dx * vy - dy * vx) / math.sqrt(length2)
    return t if dist < ON_LINE and 0 < t < 1 else None


def clip_segment(p, q, box):
    """Liang-Barsky: part of segment p-q inside box (x0, y0, x1, y1), or None."""
    x0, y0, x1, y1 = box
    dx, dy = q[0] - p[0], q[1] - p[1]
    t0, t1 = 0.0, 1.0
    for d, v in ((-dx, p[0] - x0), (dx, x1 - p[0]), (-dy, p[1] - y0), (dy, y1 - p[1])):
        if d == 0:
            if v < 0:
                return None
            continue
        t = v / d
        if d < 0:
            t0 = max(t0, t)
        else:
            t1 = min(t1, t)
        if t0 > t1:
            return None
    return ([p[0] + t0 * dx, p[1] + t0 * dy], [p[0] + t1 * dx, p[1] + t1 * dy])


def clip_polygon(poly, box):
    """Sutherland-Hodgman: polygon clipped to box."""
    x0, y0, x1, y1 = box
    edges = (
        (lambda p: p[0] >= x0, lambda p, q: (x0, p[1] + (q[1] - p[1]) * (x0 - p[0]) / (q[0] - p[0]))),
        (lambda p: p[0] <= x1, lambda p, q: (x1, p[1] + (q[1] - p[1]) * (x1 - p[0]) / (q[0] - p[0]))),
        (lambda p: p[1] >= y0, lambda p, q: (p[0] + (q[0] - p[0]) * (y0 - p[1]) / (q[1] - p[1]), y0)),
        (lambda p: p[1] <= y1, lambda p, q: (p[0] + (q[0] - p[0]) * (y1 - p[1]) / (q[1] - p[1]), y1)),
    )
    for inside, cut in edges:
        if not poly:
            break
        out = []
        for i, q in enumerate(poly):
            p = poly[i - 1]
            if inside(q):
                if not inside(p):
                    out.append(cut(p, q))
                out.append(q)
            elif inside(p):
                out.append(cut(p, q))
        poly = out
    return [[round(x, 3), round(y, 3)] for x, y in poly]


def _key(p):
    return round(p[0], 2), round(p[1], 2)


def chain(segments: list) -> list[list[list[float]]]:
    """Join segments that touch (in any order and direction) into polylines.

    Duplicates are dropped, including partial overlaps (a boundary drawn
    twice with different vertices): every segment is first split at the end
    points of other segments lying on it, so overlapping parts become
    identical pieces.
    """
    cell = 1.0  # NM: grid for finding points near a segment
    grid: dict[tuple, set] = defaultdict(set)
    for seg in segments:
        for pt in seg:
            grid[(int(pt[0] // cell), int(pt[1] // cell))].add(tuple(pt))

    def near_points(p, q):
        x0, x1 = sorted((p[0], q[0]))
        y0, y1 = sorted((p[1], q[1]))
        for gx in range(int((x0 - ON_LINE) // cell), int((x1 + ON_LINE) // cell) + 1):
            for gy in range(int((y0 - ON_LINE) // cell), int((y1 + ON_LINE) // cell) + 1):
                yield from grid.get((gx, gy), ())

    unique, seen = [], set()
    for p, q in segments:
        inner = sorted((t, v) for v in near_points(p, q) if (t := on_segment(v, p, q)) is not None)
        stops = [tuple(p)] + [v for _, v in inner] + [tuple(q)]
        for a, b in pairwise(stops):
            key = frozenset((_key(a), _key(b)))
            if key not in seen and math.dist(a, b) > 0.01:
                seen.add(key)
                unique.append([list(a), list(b)])

    # Walk from segment to segment via shared end points
    at: dict[tuple, set[int]] = defaultdict(set)
    for i, (a, b) in enumerate(unique):
        at[_key(a)].add(i)
        at[_key(b)].add(i)
    todo = set(range(len(unique)))

    def extend(line):
        while (nxt := next(iter(at[_key(line[-1])] & todo), None)) is not None:
            todo.discard(nxt)
            a, b = unique[nxt]
            line.append(b if _key(a) == _key(line[-1]) else a)
        return line

    result = []
    while todo:
        first = todo.pop()
        line = extend(extend(list(unique[first]))[::-1])  # One direction, then the other
        pts = [[round(x, 3), round(y, 3)] for x, y in line]
        pts = [pt for i, pt in enumerate(pts) if i == 0 or pt != pts[i - 1]]
        if len(pts) >= 2:
            result.append(pts)
    return result


def closed_parts(segments: list) -> list:
    """Segments that belong to closed outlines: pieces with a loose end
    (centrelines, ticks, ...) are removed until none is left."""
    # Drop duplicates first: a tick drawn there and back would look closed
    segs = list({frozenset((_key(a), _key(b))): (a, b) for a, b in segments}.values())
    while True:
        degree = defaultdict(int)
        for a, b in segs:
            degree[_key(a)] += 1
            degree[_key(b)] += 1
        kept = [(a, b) for a, b in segs if degree[_key(a)] > 1 and degree[_key(b)] > 1]
        if len(kept) == len(segs):
            return kept
        segs = kept
