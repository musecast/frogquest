"""The ending's flight home, as keys for player.tscn's "end" position track: down the tree, then on past the
sign, down through the underground and into his bedroom (the route it used to take, its corners rounded),
eased in at the start and out at the end with no jump in speed between. Keys every STEP of animation time
(it plays at 0.12), on a cubic track: dense and evenly timed, so the curve can't bulge.
Prints the keys, and writes them into the track with --write:  python tools/ending_flight.py [--write]
(P: the route, as the camera's own offsets from Froggy up at the top; ROUND: how wide each corner
turns. Run tools/validate_story.gd after.)"""
import math
import os
import re
import sys

TSCN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "player.tscn")
END = 14.033334  # (the last key: the win screen comes then)
TURN = 10.0  # (down the tree till here, as before; the underground after)
STEP = 0.2
P = [(0.0, 0.0), (0.0, 6350.0), (-2380.0, 6700.0), (-2300.0, 7100.0), (-1260.67, 7204.0)]
ROUND = [None, 600.0, 200.0, 200.0, None]  # (how wide each corner turns)


def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def length(a): return math.hypot(a[0], a[1])
def unit(a): return mul(a, 1.0 / length(a))


# The path, as fine points: straight legs, and each corner a quadratic curve from r before it to r after.
pts = [P[0]]
for i in range(1, len(P) - 1):
    d_in = unit(sub(P[i], P[i - 1]))
    d_out = unit(sub(P[i + 1], P[i]))
    a = sub(P[i], mul(d_in, ROUND[i]))
    b = add(P[i], mul(d_out, ROUND[i]))
    pts.append(a)
    for k in range(1, 40):
        t = k / 40.0
        q = add(add(mul(a, (1 - t) ** 2), mul(P[i], 2 * (1 - t) * t)), mul(b, t * t))
        pts.append(q)
    pts.append(b)
pts.append(P[-1])
dist = [0.0]
for i in range(1, len(pts)):
    dist.append(dist[-1] + length(sub(pts[i], pts[i - 1])))
L = dist[-1]


def at(s):
    s = max(0.0, min(L, s))
    for i in range(1, len(dist)):
        if dist[i] >= s:
            f = (s - dist[i - 1]) / max(1e-9, dist[i] - dist[i - 1])
            return add(pts[i - 1], mul(sub(pts[i], pts[i - 1]), f))
    return pts[-1]


# The first corner's middle: where the flight turns from the tree to the underground, at TURN.
c1_a = 6350.0 - ROUND[1]
s_turn = None
for i in range(len(pts)):
    if pts[i][1] >= 6350.0 - ROUND[1] and s_turn is None:
        s_turn = dist[i]
# (half way round the first corner)
corner_len = 0.0
for i in range(len(pts)):
    if dist[i] > s_turn and pts[i][0] > -ROUND[1] * 0.99 and pts[i][1] < 6350.0 + 200:
        corner_len = dist[i] - s_turn
s_turn += corner_len * 0.5
# Down the tree eased in: s = s_turn (t/TURN)^2, so it arrives at speed 2 s_turn / TURN. After, eased out
# over what's left: s = s_turn + rest (1 - (1 - u)^m), m chosen so the speed carries straight on.
rest = L - s_turn
span = END - TURN
v_turn = 2.0 * s_turn / TURN
m = v_turn * span / rest


def s_of(t):
    if t <= TURN:
        return s_turn * (t / TURN) ** 2
    u = min(1.0, (t - TURN) / span)
    return s_turn + rest * (1.0 - (1.0 - u) ** m)


times = []
t = 0.0
while t < END - 1e-6:
    times.append(round(t, 6))
    t += STEP
times.append(END)
values = [at(s_of(t)) for t in times]
values[-1] = P[-1]
print("path %.0f long, turn at %.0f, ease-out exponent %.3f, %d keys" % (L, s_turn, m, len(times)))
for t, v in list(zip(times, values))[::5] + [(times[-1], values[-1])]:
    g = (2804 + v[0] * 1.2, -8382 + v[1] * 1.2)
    print("  t %6.2f  local (%8.1f, %7.1f)  global (%7.0f, %6.0f)" % (t, v[0], v[1], g[0], g[1]))

if "--write" in sys.argv:
    s = open(TSCN, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in s else "\n"
    start = s.index('[sub_resource type="Animation" id="Animation_vtklk"]')
    block_end = s.index("tracks/1/type", start)
    block = s[start:block_end]
    keys = ('tracks/0/keys = {' + nl
            + '"times": PackedFloat32Array(' + ", ".join("%g" % t for t in times) + '),' + nl
            + '"transitions": PackedFloat32Array(' + ", ".join("1" for _ in times) + '),' + nl
            + '"update": 0,' + nl
            + '"values": [' + ", ".join("Vector2(%g, %g)" % (round(v[0], 2), round(v[1], 2)) for v in values) + ']' + nl
            + '}' + nl)
    new_block = re.sub(r'tracks/0/interp = \d', 'tracks/0/interp = 2', block)
    new_block = re.sub(r'tracks/0/keys = \{.*?\n\}\r?\n', lambda _m: keys, new_block, flags=re.S)
    assert new_block != block
    s = s[:start] + new_block + s[block_end:]
    open(TSCN, "w", encoding="utf-8", newline="").write(s)
    print("written")
