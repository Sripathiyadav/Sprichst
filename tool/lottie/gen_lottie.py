"""Sprichst Lottie animations (bodymovin 5.7 JSON), generated from the design-system tokens.

usage: gen_lottie.py <out dir>
Writes <name>_light.json and <name>_dark.json for every animation. Backgrounds are transparent.
"""
import json, math, os, sys

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
def welcome_intro(c):
    """The app mark assembles: sun, orbit, the S, the speech bubble, the book pages, the gate. 2.2 s."""
    op = 132
    KS = {'a': [570, 504, 0], 'p': [256, 260, 0], 's': [53, 53, 100]}   # icon space -> 512 canvas
    S = join(arc(430, 392, 128, -14, -270), arc(430, 648, 128, -90, 118))
    layers = []
    # satellite ring
    layers.append(layer(0, 'satellite', [group('sat', [ellipse(68, (834.7, 233.6)), fill(c['canvas']), stroke(c['coral'], 7)],
                                                tr(p=(834.7, 233.6), a=(834.7, 233.6), s=anim([(96, [0, 0]), (110, [115, 115]), (118, [100, 100])])))], op, KS))
    # bubble + dots
    dots = [group(f'dot{j}', [ellipse(30, (x, 379)), fill(c['ink'])], tr(o=anim([(72 + 5 * j, 0), (80 + 5 * j, 100)]))) for j, x in enumerate((384, 430, 476))]
    bubble = group('bubble', [rect(188, 130, 42, (430, 379)), shape([[436, 444], [372, 482], [392, 444]], closed=True), fill(c['canvas'])])
    layers.append(layer(0, 'bubble', [group('bubble all', dots + [bubble], tr(p=(430, 390), a=(430, 390), s=anim([(54, [0, 0]), (68, [108, 108]), (74, [100, 100])])))], op, KS))
    # pages fan out from the spine
    spine = (392, 806)
    leaves = [((196, 706), (208, 650), (214, 840), (300, 736), 'ink'), ((210, 642), (234, 592), (228, 796), (318, 694), 'coral'),
              ((254, 594), (290, 560), (266, 764), (350, 668), 'surface'), ((318, 574), (358, 562), (318, 734), (382, 664), 'coral')]
    items = []
    for j, (t1, t2, ou, inn, col) in reversed(list(enumerate(leaves))):
        st = 58 + 6 * j
        items.append(group(f'leaf{j}', [quad_leaf(spine, t1, t2, ou, inn), stroke(c['ink'], 10), fill(c[col])],
                           tr(p=spine, a=spine, r=anim([(st, -55), (st + 22, 0)]), o=anim([(st, 0), (st + 6, 100)]))))
    layers.append(layer(0, 'pages', items, op, KS))
    # the S: paper halo then ink stroke, drawn on
    draw = anim([(18, 0), (62, 100)], 'in_out')
    layers.append(layer(0, 'S', [group('S ink', [S, trim(draw), stroke(c['ink'], 124, cap=1)]),
                                 group('S halo', [S, trim(draw), stroke(c['canvas'], 176, cap=1)])], op, KS))
    # gate, clipped to the sun
    gate_rects = [(590, 668, 300, 14), (614, 564, 20, 104), (648, 564, 20, 104), (682, 564, 20, 104), (746, 564, 20, 104),
                  (780, 564, 20, 104), (814, 564, 20, 104), (600, 540, 262, 26), (658, 514, 146, 28), (691, 498, 80, 16),
                  (694, 482, 9, 18), (712, 482, 9, 18), (742, 482, 9, 18), (760, 482, 9, 18), (727, 460, 8, 40)]
    g_items = [rect(w, h, 0, (x + w / 2, y + h / 2)) for (x, y, w, h) in gate_rects]
    g_items += [shape([[707, 454], [731, 466], [755, 454], [755, 464], [731, 476], [707, 464]], closed=True), ellipse(16, (731, 450)), fill(c['panel'])]
    layers.append(layer(0, 'gate', [group('gate', g_items, tr(p=anim([(70, [0, 90]), (100, [0, 0])]), o=anim([(0, 0, 'linear'), (70, 0), (84, 100)])))], op, KS,
                        masks=[{'inv': False, 'mode': 'a', 'pt': val(circle_path(668, 492, 214)), 'o': val(100), 'x': val(0), 'nm': 'sun'}]))
    # sun
    layers.append(layer(0, 'sun', [group('sun', [ellipse(428, (668, 492)), fill(c['coral'])],
                                         tr(p=(668, 492), a=(668, 492), s=anim([(0, [0, 0]), (26, [104, 104]), (34, [100, 100])])))], op, KS))
    # orbit
    ov, oi, oo = arc(650, 470, 300, -150, 110)
    layers.append(layer(0, 'orbit', [group('orbit', [shape(ov, oi, oo), trim(anim([(10, 0), (70, 100)], 'in_out')), stroke(c['coral'], 7)])], op, KS))
    return comp('Sprichst — welcome intro', 512, 512, op, layers)

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

def loading(c):
    """Coral arc travelling around a hairline ring. 1 s loop."""
    op = 60
    return comp('Sprichst — loading', 88, 88, op, [
        layer(0, 'arc', [group('arc', [ellipse(84), trim(28), stroke(c['coral'], 3)])], op, {'p': [44, 44, 0], 'r': anim([(0, 0), (60, 360)], 'linear')}),
        layer(0, 'ring', [group('ring', [ellipse(84), stroke(c['line'], 1)])], op, {'p': [44, 44, 0]}),
    ])

# ---------------------------------------------------------------- tour illustrations (240 x 180, 3 s, play once and hold)
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

def tour_review(c):
    """Spaced review: each return comes later than the last, so the arcs grow."""
    xs = [32, 66, 112, 168, 212]
    y = 112
    L = []
    for j in range(4):
        r = (xs[j + 1] - xs[j]) / 2
        v, i, o = arc((xs[j] + xs[j + 1]) / 2, y, r, 180, 360)
        t0 = 14 + 24 * j
        L.append(layer(0, f'gap {j}', [group('gap', [shape(v, i, o), trim(anim([(t0, 0), (t0 + 22, 100)])), stroke(c['coral'] if j == 3 else c['line'], 2.5)])],
                       TOUR_OP, {'o': _loop()}))
    L.append(layer(0, 'baseline', [group('baseline', [shape([[xs[0], y], [xs[-1], y]]), trim(anim([(0, 0), (100, 100)], 'in_out')), stroke(c['line'], 1.5)])],
                   TOUR_OP, {'o': _loop()}))
    dots = []
    for j, x in enumerate(xs):
        t0 = 4 + 24 * j
        last = j == len(xs) - 1
        dots.append(group(f'dot{j}', [ellipse(14 + 2 * j, (x, y)), fill(c['coral'] if last else c['mark'])],
                          tr(p=(x, y), a=(x, y), s=anim([(t0, [0, 0]), (t0 + 10, [118, 118]), (t0 + 16, [100, 100])]))))
    L.append(layer(0, 'dots', dots, TOUR_OP, {'o': _loop()}))
    return comp('Sprichst — tour: spaced review', TOUR_W, TOUR_H, TOUR_OP, L)

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

def tour_design(c):
    """The design: a few plain shapes, one coral accent, settling into place."""
    L = []
    spec = [('square', [-70, 100], [96, 98], 'ink'), ('circle', [310, 84], [138, 86], 'coral'), ('triangle', [120, -40], [180, 108], 'success')]
    for k, (kind, p0, p1, col) in enumerate(spec):
        t0 = 6 + 12 * k
        if kind == 'square':
            geo = [rect(58, 58, 10)]
        elif kind == 'circle':
            geo = [ellipse(62)]
        else:
            geo = [shape([[0, -30], [30, 24], [-30, 24]], closed=True)]
        L.append(layer(0, kind, [group(kind, geo + [fill(c[col])])], TOUR_OP,
                       {'p': anim([(t0, p0 + [0]), (t0 + 30, p1 + [0])]), 'r': anim([(t0, -120 if k != 1 else 0), (t0 + 30, 0)]), 'o': _loop(4)}))
    L.append(layer(0, 'ring', [group('ring', [ellipse(anim([(48, [60, 60]), (110, [120, 120])])), stroke(c['coral'], 1.5, o=anim([(0, 0, 'linear'), (47, 0, 'linear'), (48, 80, 'linear'), (110, 0)]))])],
                   TOUR_OP, {'p': [138, 86, 0]}))
    L.append(layer(0, 'baseline', [group('baseline', [shape([[40, 150], [200, 150]]), trim(anim([(30, 0), (90, 100)], 'in_out')), stroke(c['line'], 1.5)])],
                   TOUR_OP, {'o': _loop()}))
    return comp('Sprichst — tour: design', TOUR_W, TOUR_H, TOUR_OP, L)

ANIMS = {'welcome_intro': welcome_intro, 'nav_indicator': nav_indicator, 'lesson_complete': lesson_complete,
         'achievement_unlocked': achievement_unlocked, 'streak_kept': streak_kept, 'answer_correct': answer_correct,
         'answer_incorrect': answer_incorrect, 'loading': loading,
         'tour_lessons': tour_lessons, 'tour_coach': tour_coach, 'tour_review': tour_review,
         'tour_private': tour_private, 'tour_design': tour_design}

os.makedirs(OUT, exist_ok=True)
for name, fn in ANIMS.items():
    for theme, c in PALETTE.items():
        data = fn(c)
        with open(os.path.join(OUT, f'{name}_{theme}.json'), 'w') as f:
            json.dump(data, f, separators=(',', ':'))
print(len(ANIMS) * 2, 'files')
