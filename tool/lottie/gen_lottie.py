"""Sprichst Lottie animations (bodymovin 5.7 JSON), generated from the design-system tokens.

usage: gen_lottie.py <out dir>
Writes <name>_light.json and <name>_dark.json for every animation. Backgrounds are transparent.
"""
import json, math, os, re, sys

OUT = sys.argv[1]
FPS = 60

PALETTE = {
    'light': dict(canvas='f2eae1', surface='fbf7f2', panel='363433', ink='2a2826', muted='645b54', coral='e45347',
                  tint='f3b5ac', soft='fbe6e1', success='22706a', success_soft='d7eeea', danger='a11d3a',
                  danger_soft='f6dee2', line='8e8379', mark='3d3a38', on_panel='f5eee6', on_panel_accent='f2877c'),
    'dark': dict(canvas='1f1d1c', surface='2a2827', panel='3a3735', ink='f3ece4', muted='b5aba2', coral='d9625a',
                 tint='5a302b', soft='4a2724', success='6cc9bc', success_soft='173a37', danger='f49aa6',
                 danger_soft='4a1e27', line='7d736b', mark='9a9088', on_panel='f5eee6', on_panel_accent='f08a7f'),
}

# ---------------------------------------------------------------- primitives
EASE = {
    'standard': ([0.2], [0.0], [0.0], [1.0]),   # cubic-bezier(0.2, 0, 0, 1)  (ease-standard token)
    'exit': ([0.3], [0.0], [1.0], [1.0]),       # cubic-bezier(0.3, 0, 1, 1)  (ease-exit token)
    'linear': ([0.0], [0.0], [1.0], [1.0]),
    'in_out': ([0.4], [0.0], [0.2], [1.0]),
}

def rgb(h):
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [1]

def val(v):
    return {'a': 0, 'k': v}

def anim(keys, ease='standard'):
    """keys: [(frame, value)] or [(frame, value, ease)]; ease applies to the segment leaving that key."""
    out = []
    for i, key in enumerate(keys):
        t, v = key[0], key[1]
        e = key[2] if len(key) > 2 else ease
        s = v if isinstance(v, list) else [v]
        k = {'t': t, 's': s}
        if i < len(keys) - 1:
            ox, oy, ix, iy = EASE[e]
            n = len(s)
            k['o'] = {'x': ox * n, 'y': oy * n}
            k['i'] = {'x': ix * n, 'y': iy * n}
        out.append(k)
    return {'a': 1, 'k': out}

def prop(v):
    return v if isinstance(v, dict) else val(v)

def tr(p=(0, 0), a=(0, 0), s=(100, 100), r=0, o=100):
    return {'ty': 'tr', 'p': prop(list(p) if not isinstance(p, dict) else p), 'a': prop(list(a)),
            's': prop(list(s) if not isinstance(s, dict) else s), 'r': prop(r), 'o': prop(o),
            'sk': val(0), 'sa': val(0), 'nm': 'Transform'}

def group(name, items, t=None):
    return {'ty': 'gr', 'nm': name, 'it': items + [t or tr()]}

def ellipse(d, c=(0, 0)):
    return {'ty': 'el', 'd': 1, 'p': val(list(c)), 's': prop(d if isinstance(d, dict) else [d, d]), 'nm': 'Ellipse'}

def rect(w, h, r=0, c=(0, 0)):
    size = w if isinstance(w, dict) else val([w, h])   # a dict is an animated [w, h]
    return {'ty': 'rc', 'd': 1, 'p': val(list(c)), 's': size, 'r': val(r), 'nm': 'Rect'}

def shape(v, i=None, o=None, closed=False):
    n = len(v)
    return {'ty': 'sh', 'd': 1, 'nm': 'Path', 'ks': val({'v': [list(p) for p in v], 'i': i or [[0, 0]] * n,
                                                        'o': o or [[0, 0]] * n, 'c': closed})}

def fill(hex_, o=100):
    return {'ty': 'fl', 'c': val(rgb(hex_)), 'o': prop(o), 'r': 1, 'nm': 'Fill'}

def stroke(hex_, w, o=100, cap=2):
    return {'ty': 'st', 'c': val(rgb(hex_)), 'o': prop(o), 'w': prop(w), 'lc': cap, 'lj': 2, 'ml': 4, 'nm': 'Stroke'}

def trim(e, s=0):
    return {'ty': 'tm', 's': prop(s), 'e': prop(e), 'o': val(0), 'm': 1, 'nm': 'Trim'}

def layer(ind, name, shapes, op, ks=None, masks=None):
    k = ks or {}
    L = {'ddd': 0, 'ind': ind, 'ty': 4, 'nm': name, 'sr': 1, 'ao': 0, 'ip': 0, 'op': op, 'st': 0, 'bm': 0,
         'ks': {'o': prop(k.get('o', 100)), 'r': prop(k.get('r', 0)), 'p': prop(k.get('p', [0, 0, 0])),
                'a': prop(k.get('a', [0, 0, 0])), 's': prop(k.get('s', [100, 100, 100]))},
         'shapes': shapes}
    if masks:
        L['hasMask'] = True
        L['masksProperties'] = masks
    return L

def comp(name, w, h, op, layers):
    for i, L in enumerate(layers):
        L['ind'] = i + 1
    return {'v': '5.7.4', 'fr': FPS, 'ip': 0, 'op': op, 'w': w, 'h': h, 'nm': name, 'ddd': 0, 'assets': [],
            'layers': layers, 'markers': []}

# ---------------------------------------------------------------- geometry helpers
def arc(cx, cy, r, a0, a1):
    """Bezier vertices for a circular arc from a0 to a1 degrees (y-down, like SVG)."""
    span = a1 - a0
    n = max(1, int(math.ceil(abs(span) / 90.0)))
    step = math.radians(span / n)
    k = 4 / 3 * math.tan(step / 4)
    v, ins, outs = [], [], []
    for j in range(n + 1):
        a = math.radians(a0) + step * j
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        tx, ty = -math.sin(a) * r * k, math.cos(a) * r * k     # tangent scaled
        v.append([x, y]); ins.append([-tx, -ty]); outs.append([tx, ty])
    ins[0] = [0, 0]; outs[-1] = [0, 0]
    return v, ins, outs

def join(*arcs):
    v, ins, outs = [], [], []
    for (av, ai, ao) in arcs:
        if v:  # shared vertex: keep previous in-tangent, take next out-tangent
            outs[-1] = ao[0]; av, ai, ao = av[1:], ai[1:], ao[1:]
        v += av; ins += ai; outs += ao
    return shape(v, ins, outs)

def quad_leaf(spine, t1, t2, outer, inner):
    c1 = [spine[0] + 2 / 3 * (outer[0] - spine[0]), spine[1] + 2 / 3 * (outer[1] - spine[1])]
    c2 = [t1[0] + 2 / 3 * (outer[0] - t1[0]), t1[1] + 2 / 3 * (outer[1] - t1[1])]
    d1 = [t2[0] + 2 / 3 * (inner[0] - t2[0]), t2[1] + 2 / 3 * (inner[1] - t2[1])]
    d2 = [spine[0] + 2 / 3 * (inner[0] - spine[0]), spine[1] + 2 / 3 * (inner[1] - spine[1])]
    v = [spine, t1, t2]
    o = [[c1[0] - spine[0], c1[1] - spine[1]], [0, 0], [d1[0] - t2[0], d1[1] - t2[1]]]
    i = [[d2[0] - spine[0], d2[1] - spine[1]], [c2[0] - t1[0], c2[1] - t1[1]], [0, 0]]
    return shape(v, i, o, closed=True)

def circle_path(cx, cy, r):
    k = 0.5523 * r
    v = [[cx, cy - r], [cx + r, cy], [cx, cy + r], [cx - r, cy]]
    o = [[k, 0], [0, k], [-k, 0], [0, -k]]
    i = [[-k, 0], [0, -k], [k, 0], [0, k]]
    return {'v': v, 'i': i, 'o': o, 'c': True}

def star(cx, cy, r_out, r_in, n=5):
    pts = []
    for j in range(2 * n):
        r = r_out if j % 2 == 0 else r_in
        a = -math.pi / 2 + j * math.pi / n
        pts.append([cx + r * math.cos(a), cy + r * math.sin(a)])
    return shape(pts, closed=True)

# ---------------------------------------------------------------- animations
# The orbit mark (same geometry as the design system's AppIcon): the S body, three hairline orbit segments, the disc.
ORBIT_S = 'M725 327l-5-9-4-8-4-8-5-7-4-7-4-6-5-6-5-6-4-5-5-5-5-5-5-5-6-4-5-5-6-4-6-4-6-4-7-3-6-3-7-4-6-3-7-3-7-3-8-2-7-2-8-2-8-1-8-1-8-1-8 0-8 0-8 0-8 1-9 1-8 1-8 2-8 2-8 3-8 2-8 4-8 3-8 4-8 4-8 5-7 4-8 5-7 6-8 5-7 6-6 6-7 7-8 5-7 6-7 6-8 6-7 7-6 7-7 7-6 7-6 8-6 8-6 8-4 9-5 9-3 10-3 10-2 11 0 11 1 11 3 11 3 11 6 10 7 9 7 9 8 8 8 7 10 6 9 6 10 5 10 6 10 4 10 5 11 5 11 4 11 4 11 4 11 4 11 5 11 3 11 4 11 4 11 4 11 4 10 4 10 4 10 4 9 5 9 4 8 4 8 4 7 5 7 4 5 4 5 4 4 4 4 3 2 4 3 3 2 2 1 2 2 2 2 3 2 3 1 3 2 4 1 5 0 6-1 5-1 7-2 6-3 7-3 6-3 7-5 7-4 7-5 6-5 7-5 6-6 6-7 4-7 5-7 4-6 4-8 4-6 3-7 3-7 4-7 3-7 2-7 3-7 2-7 2-6 2-7 2-7 2-6 1-7 1-7 1-6 1-7 0-6 1-7 0-6 0-6 0-7-1-6 0-6-1-7-1-6-1-7-2-6-1-6-2-6-2-6-2-6-2-6-3-5-2-6-4-5-3-5-3-5-4-5-4-6-5-4-5-5-5-5-5-4-7-5-7-5-8-4-8-8 4 4 9 5 8 4 8 4 7 4 7 5 6 4 6 5 6 5 5 5 5 5 5 5 5 5 4 6 5 6 4 5 4 7 4 6 3 7 3 6 4 6 3 7 3 8 3 7 2 8 2 7 2 8 1 8 1 8 1 8 0 8 0 8 0 9-1 8-1 8-1 9-2 8-2 8-3 8-2 8-4 8-3 8-4 8-4 7-5 8-4 7-5 8-6 7-5 7-6 7-6 7-7 7-5 8-6 7-6 7-6 7-7 7-7 7-7 6-7 6-8 6-8 5-8 5-9 4-9 4-10 3-10 1-11 1-11-1-11-3-11-4-11-5-10-7-9-7-9-8-8-9-7-9-6-9-6-10-5-10-6-11-4-10-5-11-5-11-4-10-4-11-4-12-4-11-5-11-3-11-4-11-4-11-4-10-4-11-4-10-4-9-4-9-5-10-4-8-4-8-4-7-5-6-4-6-4-5-4-4-4-3-3-3-4-2-3-2-2-2-2-2-2-2-3-1-3-2-3-1-4-1-5 0-6 0-5 2-7 2-6 2-7 3-6 4-7 4-7 4-7 5-6 5-7 6-6 6-6 6-4 7-5 7-4 7-4 7-4 7-3 7-3 7-4 7-3 6-2 8-3 6-2 7-2 7-2 7-2 7-2 6-1 7-1 6-1 7-1 6 0 7-1 6 0 7 0 6 0 6 1 6 0 7 1 6 1 6 1 7 2 6 1 7 2 5 2 6 2 6 2 6 3 5 2 6 4 5 3 6 3 5 4 5 4 5 5 5 5 5 5 4 5 5 7 4 7 5 8 4 8z'
ORBIT_SEGMENTS = ['M725 327l3 8 3 8 3 8 2 8 2 9 3 9 2 8 1 9 1 9 1 9 1 9-9 1-1-9-1-9-1-9-2-8-1-9-2-8-2-8-3-8-2-8-3-8-4-7z', 'M736 536l-3 10-2 10-4 9-3 9-4 10-3 9-5 10-4 9-4 9-4 10-4 9-4 10-4 9-4 9-4 10-5 9-6 8-24-18 6-7 7-7 7-8 6-7 7-7 6-8 6-8 5-8 5-9 4-9 4-9 4-9 3-9 3-10 4-9 2-10 3-9z', 'M266 697l-4-8-2-8-3-8-3-8-2-9-2-9-2-8-1-9-2-9-1-9-1-9 0-10 0-9 0-10 0-9 1-10 0-9 1-10 2-10 1-9 2-10 2-10 2-9 3-10 3-10 3-9 4-9 3-10 4-9 4-10 4-9 4-9 5-10 3-9 5-10 3-9 4-9 5-10 5-9 6-8 23 18-6 7-7 7-6 8-7 7-7 7-6 8-5 8-6 8-4 9-5 9-3 9-4 9-4 9-3 10-3 9-3 10-2 9-3 9-2 10-2 9-1 10-2 9 0 10-1 9-1 9 0 9 0 10 0 9 0 9 1 9 1 9 1 9 2 8 2 9 2 8 2 8 2 8 3 8 3 8 3 7z']
ORBIT_DISC = (741, 481, 39.8)

def parse_poly(d):
    """'M x y l dx dy ... z' (absolute move, relative lines) -> absolute vertices."""
    nums = [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', d)]
    x, y = nums[0], nums[1]
    pts = [[x, y]]
    for k in range(2, len(nums) - 1, 2):
        x += nums[k]; y += nums[k + 1]
        pts.append([x, y])
    return pts

def nav_indicator(c):
    """Navigation indicator pill grows behind the selected tab icon. 0.4 s."""
    op = 24
    pill = group('pill', [rect(56, 32, 16, (32, 20)), fill(c['soft'])],
                 tr(p=(32, 20), a=(32, 20), s=anim([(0, [40, 70]), (14, [104, 100]), (20, [100, 100])]), o=anim([(0, 0), (8, 100)])))
    return comp('Sprichst — nav indicator', 64, 40, op, [layer(0, 'indicator', [pill], op)])

def lesson_complete(c):
    """Coral disc, cream check drawn on, a ring and six marks radiating. 1.4 s."""
    op = 84
    C = (100, 100)
    layers = []
    check = shape([[-26, 2], [-8, 20], [28, -18]])
    layers.append(layer(0, 'check', [group('check', [check, trim(anim([(18, 0), (40, 100)])), stroke(c['canvas'], 10)])], op, {'p': [100, 100, 0]}))
    layers.append(layer(0, 'disc', [group('disc', [ellipse(128), fill(c['coral'])], tr(s=anim([(0, [0, 0]), (20, [108, 108]), (28, [100, 100])])))], op, {'p': [100, 100, 0]}))
    layers.append(layer(0, 'ring', [group('ring', [ellipse(anim([(18, [128, 128]), (60, [184, 184])])), stroke(c['coral'], 2, o=anim([(0, 0, 'linear'), (17, 0, 'linear'), (18, 100), (60, 0)]))])], op, {'p': [100, 100, 0]}))
    marks = []
    for j in range(6):
        a = math.radians(-90 + j * 60)
        p0 = [math.cos(a) * 78, math.sin(a) * 78]; p1 = [math.cos(a) * 92, math.sin(a) * 92]
        marks.append(group(f'm{j}', [shape([p0, p1]), trim(anim([(24, 0), (38, 100)]), s=anim([(38, 0), (58, 100)])), stroke(c['coral'] if j % 2 == 0 else c['tint'], 4)]))
    layers.append(layer(0, 'marks', marks, op, {'p': [100, 100, 0]}))
    layers.append(layer(0, 'hairline', [group('hairline', [ellipse(184), stroke(c['line'], 1, o=anim([(0, 0), (20, 100)]))])], op, {'p': [100, 100, 0]}))
    return comp('Sprichst — lesson complete', 200, 200, op, layers)

def achievement_unlocked(c):
    """Badge pops on a coral disc, a star turns in, rays and rings burst. 1.6 s."""
    op = 96
    L = []
    L.append(layer(0, 'star', [group('star', [star(0, 0, 22, 10), fill(c['on_panel_accent'])],
                                     tr(s=anim([(30, [0, 0]), (46, [110, 110]), (52, [100, 100])]), r=anim([(30, -40), (52, 0)])))], op, {'p': [100, 100, 0]}))
    L.append(layer(0, 'inner ring', [group('inner', [ellipse(84), trim(anim([(24, 0), (50, 100)])), stroke(c['on_panel_accent'], 1.5)])], op, {'p': [100, 100, 0], 'r': -90}))
    L.append(layer(0, 'badge', [group('badge', [ellipse(104), fill(c['panel'])], tr(s=anim([(10, [0, 0]), (30, [112, 112]), (38, [100, 100])])))], op, {'p': [100, 100, 0]}))
    rays = []
    for j in range(8):
        a = math.radians(-90 + j * 45)
        rays.append(group(f'r{j}', [shape([[math.cos(a) * 86, math.sin(a) * 86], [math.cos(a) * 100, math.sin(a) * 100]]),
                                    trim(anim([(34, 0), (48, 100)]), s=anim([(50, 0), (72, 100)])), stroke(c['coral'], 3)]))
    L.append(layer(0, 'rays', rays, op, {'p': [100, 100, 0]}))
    L.append(layer(0, 'disc', [group('disc', [ellipse(160), fill(c['coral'])], tr(s=anim([(0, [0, 0]), (24, [100, 100])])))], op, {'p': [100, 100, 0]}))
    for j, st in enumerate((30, 42)):
        L.append(layer(0, f'pulse {j}', [group('pulse', [ellipse(anim([(st, [160, 160]), (st + 40, [196, 196])])), stroke(c['coral'], 1.5, o=anim([(0, 0, 'linear'), (st - 1, 0, 'linear'), (st, 90), (st + 40, 0)]))])], op, {'p': [100, 100, 0]}))
    return comp('Sprichst — achievement unlocked', 200, 200, op, L)

def streak_kept(c):
    """Seven day marks: six already filled, today's pops in coral with a pulse. 1.6 s."""
    op = 96
    xs = [30 + j * 30 for j in range(7)]
    L = []
    L.append(layer(0, 'today', [group('today', [ellipse(22, (xs[6], 60)), fill(c['coral'])],
                                      tr(p=(xs[6], 60), a=(xs[6], 60), s=anim([(30, [0, 0]), (46, [132, 132]), (54, [100, 100])])))], op))
    L.append(layer(0, 'pulse', [group('pulse', [ellipse(anim([(40, [22, 22]), (84, [56, 56])]), (xs[6], 60)), stroke(c['coral'], 2, o=anim([(0, 0, 'linear'), (39, 0, 'linear'), (40, 100), (84, 0)]))])], op))
    past = [group(f'd{j}', [ellipse(18, (x, 60)), fill(c['mark'])], tr(p=(x, 60), a=(x, 60), s=anim([(2 * j, [0, 0]), (2 * j + 12, [100, 100])]))) for j, x in enumerate(xs[:6])]
    L.append(layer(0, 'past days', past, op))
    L.append(layer(0, 'line', [group('line', [shape([[xs[0], 60], [xs[6], 60]]), trim(anim([(0, 0), (34, 100)])), stroke(c['line'], 1.5)])], op))
    return comp('Sprichst — streak kept', 240, 120, op, L)

def answer_correct(c):
    op = 36
    return comp('Sprichst — answer correct', 48, 48, op, [
        layer(0, 'check', [group('check', [shape([[-9, 0], [-3, 6], [9, -6]]), trim(anim([(8, 0), (22, 100)])), stroke(c['success'], 3.5)])], op, {'p': [24, 24, 0]}),
        layer(0, 'disc', [group('disc', [ellipse(44), fill(c['success_soft'])], tr(s=anim([(0, [0, 0]), (12, [110, 110]), (18, [100, 100])])))], op, {'p': [24, 24, 0]}),
    ])

def answer_incorrect(c):
    op = 36
    shake = anim([(14, [24, 24]), (18, [20, 24]), (22, [28, 24]), (26, [21, 24]), (30, [26, 24]), (34, [24, 24])], 'in_out')
    xg = group('x', [shape([[-7, -7], [7, 7]]), shape([[7, -7], [-7, 7]]), trim(anim([(6, 0), (16, 100)])), stroke(c['danger'], 3.5)])
    return comp('Sprichst — answer incorrect', 48, 48, op, [
        layer(0, 'x', [xg], op, {'p': shake}),
        layer(0, 'disc', [group('disc', [ellipse(44), fill(c['danger_soft'])], tr(s=anim([(0, [0, 0]), (10, [100, 100])])))], op, {'p': shake}),
    ])

# ---------------------------------------------------------------- tour illustrations (240 x 180, 3 s each)
TOUR_W, TOUR_H, TOUR_OP = 240, 180, 180

def _loop(fade_in=6):
    """Layer opacity: fades in, then holds. The tour pictures play once and stay on their last frame."""
    return anim([(0, 0, 'linear'), (fade_in, 100, 'linear'), (TOUR_OP, 100)])

def tour_lessons(c):
    """Three lesson cards slide in one after another; the first gets its check. One next step at a time."""
    L = []
    for j in range(3):
        y = 40 + 42 * j
        t0 = 8 + 14 * j
        slide = anim([(t0, [150, y]), (t0 + 18, [120, y])])
        fade = anim([(0, 0, 'linear'), (t0, 0, 'linear'), (t0 + 10, 100, 'linear'), (TOUR_OP, 100)])
        items = [group('card', [rect(176, 36, 12), fill(c['surface']), stroke(c['line'], 1.5)]),
                 group('bar', [rect(86, 8, 4, (-14, -5)), fill(c['line'])]),
                 group('bar2', [rect(54, 8, 4, (-30, 9)), fill(c['tint'] if j else c['soft'])])]
        if j == 0:
            items.append(group('check', [ellipse(22, (-66, 0)), fill(c['success_soft'])]))
            items.append(group('tick', [shape([[-72, 0], [-67, 5], [-59, -4]]), trim(anim([(56, 0), (72, 100)])), stroke(c['success'], 3)]))
        else:
            items.append(group('dot', [ellipse(22, (-66, 0)), fill(c['coral'] if j == 1 else c['soft'])]))
        # Lottie draws the first shape on top, so the card (the base) goes last.
        L.append(layer(0, f'card {j}', items[::-1], TOUR_OP, {'p': slide, 'o': fade}))
    # the one primary action
    L.append(layer(0, 'next', [group('next', [rect(70, 22, 11), fill(c['coral'])],
                                     tr(s=anim([(70, [0, 0]), (84, [108, 108]), (92, [100, 100])]))),
                               group('arrow', [shape([[-10, 0], [10, 0]]), shape([[4, -6], [10, 0], [4, 6]]), stroke(c['canvas'], 2.5)],
                                     tr(s=anim([(74, [0, 0]), (86, [100, 100])])))],
                   TOUR_OP, {'p': [120, 166, 0], 'o': anim([(0, 0, 'linear'), (70, 0, 'linear'), (76, 100, 'linear'), (TOUR_OP, 100)])}))
    return comp('Sprichst — tour: lessons', TOUR_W, TOUR_H, TOUR_OP, L)

def tour_coach(c):
    """A conversation: the coach asks, the learner answers, the coach is typing."""
    def bubble(name, cx, cy, w, h, fill_hex, line_hex, t0, tail_left, bars, bar_hex):
        tail = [[-w / 2 + 12, h / 2 - 2], [-w / 2 + 4, h / 2 + 10], [-w / 2 + 26, h / 2 - 2]] if tail_left else \
               [[w / 2 - 12, h / 2 - 2], [w / 2 - 4, h / 2 + 10], [w / 2 - 26, h / 2 - 2]]
        items = [group('body', [rect(w, h, 16), shape(tail, closed=True), fill(fill_hex)] + ([stroke(line_hex, 1.5)] if line_hex else []))]
        for k, bw in enumerate(bars):
            items.append(group('line', [rect(bw, 8, 4, (-w / 2 + 16 + bw / 2, -6 + 14 * k)), fill(bar_hex)]))
        pop = tr(p=(cx, cy), s=anim([(t0, [0, 0]), (t0 + 12, [106, 106]), (t0 + 18, [100, 100])]))
        return layer(0, name, [group(name, items[::-1], pop)], TOUR_OP, {'o': _loop()})
    L = []
    L.append(bubble('coach asks', 98, 40, 150, 44, c['surface'], c['line'], 6, True, [96, 60], c['line']))
    L.append(bubble('learner', 148, 98, 132, 36, c['coral'], None, 34, False, [88], c['canvas']))
    # typing bubble with three bouncing dots
    typing = [group('body', [rect(64, 32, 16), shape([[-20, 14], [-28, 26], [-6, 14]], closed=True), fill(c['surface']), stroke(c['line'], 1.5)])]
    for k in range(3):
        x = -16 + 16 * k
        typing.append(group('dot', [ellipse(8, (x, 0)), fill(c['muted'])],
                            tr(p=anim([(70 + 5 * k, [0, 0], 'in_out'), (78 + 5 * k, [0, -6], 'in_out'), (86 + 5 * k, [0, 0], 'in_out'),
                                       (110 + 5 * k, [0, 0], 'in_out'), (118 + 5 * k, [0, -6], 'in_out'), (126 + 5 * k, [0, 0], 'in_out')]))))
    L.append(layer(0, 'typing', [group('typing', typing[::-1], tr(p=(78, 148), s=anim([(64, [0, 0]), (76, [106, 106]), (82, [100, 100])])))], TOUR_OP, {'o': _loop()}))
    return comp('Sprichst — tour: coach', TOUR_W, TOUR_H, TOUR_OP, L)

def tour_private(c):
    """The phone with its lock: what you type stays on the phone unless you choose otherwise."""
    L = []
    for j, t0 in enumerate((34, 76)):
        L.append(layer(0, f'pulse {j}', [group('pulse', [rect(anim([(t0, [84, 136]), (t0 + 50, [132, 184])]), 0, 18),
                                                          stroke(c['success'], 2, o=anim([(0, 0, 'linear'), (t0 - 1, 0, 'linear'), (t0, 80, 'linear'), (t0 + 50, 0)]))])],
                       TOUR_OP, {'p': [120, 90, 0]}))
    v, i, o = arc(0, -12, 13, 180, 360)
    L.append(layer(0, 'lock', [group('keyhole', [ellipse(7, (0, 2)), fill(c['canvas'])]),
                               group('body', [rect(38, 30, 8, (0, 4)), fill(c['coral'])]),
                               group('shackle', [shape(v, i, o), stroke(c['ink'], 4.5)])],
                   TOUR_OP, {'p': [120, 96, 0], 'o': _loop(), 's': anim([(10, [0, 0, 100]), (24, [108, 108, 100]), (32, [100, 100, 100])])}))
    L.append(layer(0, 'phone', [group('speaker', [rect(22, 5, 2.5, (0, -56)), fill(c['line'])]),
                                group('phone', [rect(84, 136, 18), fill(c['surface']), stroke(c['ink'], 4)])],
                   TOUR_OP, {'p': [120, 90, 0], 'o': _loop(), 's': anim([(0, [92, 92, 100]), (16, [100, 100, 100])])}))
    return comp('Sprichst — tour: private', TOUR_W, TOUR_H, TOUR_OP, L)

def _state_frame(c, glyph_layers, op=72):
    """96 x 96: hairline ring, coral disc at the upper right, and the glyph. Lottie draws the first layer on top."""
    L = list(glyph_layers)
    L.append(layer(0, 'disc', [group('disc', [ellipse(26, (78, 18)), fill(c['coral'])],
                                     tr(p=(78, 18), a=(78, 18), s=anim([(8, [0, 0]), (22, [118, 118]), (30, [100, 100])])))], op))
    L.append(layer(0, 'ring', [group('ring', [ellipse(88, (48, 48)), stroke(c['line'], 1.5, o=anim([(0, 0), (14, 100)]))])], op))
    return L

def empty_state(c):
    """An open book whose pages settle: nothing here yet, but there will be. 1.2 s, once."""
    op = 72
    left = shape([[48, 66], [48, 34], [26, 30], [26, 62]], closed=True)
    right = shape([[48, 66], [48, 34], [70, 30], [70, 62]], closed=True)
    glyph = layer(0, 'book', [group('lines', [shape([[32, 42], [42, 44]]), shape([[32, 50], [42, 52]]), shape([[54, 44], [64, 42]]), shape([[54, 52], [64, 50]]),
                                              trim(anim([(30, 0), (46, 100)])), stroke(c['line'], 2)]),
                              group('right', [right, fill(c['surface']), stroke(c['ink'], 3)],
                                    tr(p=(48, 66), a=(48, 66), r=anim([(12, 24), (30, 0)]), o=anim([(12, 0), (20, 100)]))),
                              group('left', [left, fill(c['surface']), stroke(c['ink'], 3)],
                                    tr(p=(48, 66), a=(48, 66), r=anim([(12, -24), (30, 0)]), o=anim([(12, 0), (20, 100)])))], op)
    return comp('Sprichst - empty state', 96, 96, op, _state_frame(c, [glyph], op))

def error_state(c):
    """A warning triangle that shakes once: something went wrong, and the words say what. 1.2 s, once."""
    op = 72
    tri = shape([[48, 26], [70, 66], [26, 66]], closed=True)
    x = anim([(24, [0, 0]), (28, [-3, 0]), (32, [3, 0]), (36, [-2, 0]), (40, [2, 0]), (44, [0, 0])], 'in_out')
    glyph = layer(0, 'warning', [group('mark', [shape([[48, 40], [48, 54]]), stroke(c['danger'], 3.5)], tr(o=anim([(20, 0), (26, 100)]))),
                                 group('dot', [ellipse(4.5, (48, 60)), fill(c['danger'])], tr(o=anim([(20, 0), (26, 100)]))),
                                 group('triangle', [tri, trim(anim([(8, 0), (30, 100)])), stroke(c['danger'], 3.5)])], op, {'p': x})
    return comp('Sprichst - error state', 96, 96, op, _state_frame(c, [glyph], op))

def offline_state(c):
    """A cloud with a line drawn through it: no connection. 1.2 s, once."""
    op = 72
    cloud = [ellipse(26, (38, 54)), ellipse(34, (54, 48)), ellipse(24, (66, 56)), rect(44, 18, 9, (52, 60))]
    glyph = layer(0, 'cloud', [group('slash', [shape([[28, 28], [70, 70]]), trim(anim([(24, 0), (40, 100)])), stroke(c['ink'], 4)]),
                               group('slash halo', [shape([[28, 28], [70, 70]]), trim(anim([(24, 0), (40, 100)])), stroke(c['canvas'], 9)]),
                               group('cloud', cloud + [fill(c['surface'])], tr(p=(48, 52), a=(48, 52), s=anim([(6, [60, 60]), (20, [104, 104]), (26, [100, 100])]), o=anim([(6, 0), (14, 100)]))),
                               group('cloud line', cloud + [stroke(c['mark'], 3)], tr(p=(48, 52), a=(48, 52), s=anim([(6, [60, 60]), (20, [104, 104]), (26, [100, 100])]), o=anim([(6, 0), (14, 100)])))], op)
    return comp('Sprichst - offline state', 96, 96, op, _state_frame(c, [glyph], op))

def level_up(c):
    """A coral disc with an arrow rising out of it and a ring that fades away. 1.2 s, once."""
    op = 72
    return comp('Sprichst - level up', 72, 72, op, [
        layer(0, 'arrow', [group('arrow', [shape([[0, 12], [0, -12]]), shape([[-10, -2], [0, -12], [10, -2]]),
                                           trim(anim([(18, 0), (34, 100)])), stroke(c['canvas'], 5)])], op, {'p': [36, 36, 0]}),
        layer(0, 'disc', [group('disc', [ellipse(52), fill(c['coral'])], tr(s=anim([(0, [0, 0]), (16, [108, 108]), (24, [100, 100])])))], op, {'p': [36, 36, 0]}),
        layer(0, 'ring', [group('ring', [ellipse(anim([(16, [52, 52]), (60, [72, 72])])), stroke(c['coral'], 2, o=anim([(0, 0, 'linear'), (15, 0, 'linear'), (16, 100), (60, 0)]))])], op, {'p': [36, 36, 0]}),
    ])

def coach_thinking(c):
    """Three dots in a row, bouncing in turn: the coach is writing. 1.2 s loop."""
    op = 72
    dots = []
    for k in range(3):
        d = 6 * k
        dots.append(group(f'dot{k}', [ellipse(8, (12 + 16 * k, 14)), fill(c['muted'])],
                          tr(p=anim([(d, [0, 0], 'in_out'), (d + 12, [0, -6], 'in_out'), (d + 24, [0, 0], 'in_out'), (72, [0, 0])]))))
    return comp('Sprichst - coach thinking', 56, 28, op, [layer(0, 'dots', dots, op)])

def download_model(c):
    """An arrow dropping into a tray, again and again: a model is downloading. 1 s loop."""
    op = 60
    return comp('Sprichst - download', 40, 40, op, [
        layer(0, 'arrow', [group('arrow', [shape([[0, -9], [0, 5]]), shape([[-6, -1], [0, 5], [6, -1]]), stroke(c['coral'], 3)])], op,
              {'p': anim([(0, [20, 10, 0]), (36, [20, 18, 0]), (60, [20, 18, 0])], 'in_out'), 'o': anim([(0, 0, 'linear'), (8, 100, 'linear'), (40, 100, 'linear'), (54, 0)])}),
        layer(0, 'tray', [group('tray', [shape([[8, 26], [8, 32], [32, 32], [32, 26]]), stroke(c['ink'], 3)])], op),
    ])

def tour(c):
    """The whole tour in one file: lessons, coach, private, 3 s each, looping. Each
    scene's layers are shifted in time (st) and shown only in their own window (ip/op)."""
    L = []
    for k, scene in enumerate([tour_lessons, tour_coach, tour_private]):
        for layer_ in scene(c)['layers']:
            layer_.update(ip=k * TOUR_OP, op=(k + 1) * TOUR_OP, st=k * TOUR_OP)
            L.append(layer_)
    return comp('Sprichst — tour', TOUR_W, TOUR_H, 3 * TOUR_OP, L)

ANIMS = {'nav_indicator': nav_indicator, 'lesson_complete': lesson_complete,
         'achievement_unlocked': achievement_unlocked, 'streak_kept': streak_kept, 'answer_correct': answer_correct,
         'answer_incorrect': answer_incorrect,
         'tour': tour,
         'empty_state': empty_state, 'error_state': error_state, 'offline_state': offline_state,
         'level_up': level_up, 'coach_thinking': coach_thinking, 'download_model': download_model}

os.makedirs(OUT, exist_ok=True)
for name, fn in ANIMS.items():
    for theme, c in PALETTE.items():
        data = fn(c)
        with open(os.path.join(OUT, f'{name}_{theme}.json'), 'w') as f:
            json.dump(data, f, separators=(',', ':'))
print(len(ANIMS) * 2, 'files')
