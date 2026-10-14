#!/usr/bin/env python3
"""Render the vector boy: stills, contact sheet, frames, walkthrough video.

    python3 render.py all          # everything (stills, sheets, frames, mp4)
    python3 render.py stills       # ten held postures over the room
    python3 render.py sheets       # contact-sheet.png and motion-sheet.png
    python3 render.py video        # frames + walkthrough.mp4
    python3 render.py pose NAME    # one posture to out/pose-NAME.png

Standard library only. Uses rsvg-convert and ffmpeg.
"""
import json
import math
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import geom as G
import boy as B
import style as S
import hands as HD
from head import head_layers
from poses import POSES, SEQUENCE, VIA

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
WORK = os.path.join(HERE, 'work')
W, H = 1080, 1920
FPS = 24
TRANSITION = 1.2
SWAP_FADE = 0.3
TEXTURE = os.environ.get('TEXTURE', '1') == '1'
ROUGH = float(os.environ.get('ROUGH', '0'))
# Paper grain over the whole boy, fixed to the page like ink on textured
# paper. ROUGH > 0 adds a pencil wobble (displacement); it is off by default
# because a page-fixed wobble makes moving edges shimmer.
_WOBBLE = ('<feImage href="wobble.png" x="0" y="0" width="256" height="256" result="w"/>'
           '<feTile in="w" result="n"/>'
           '<feDisplacementMap in="SourceGraphic" in2="n" scale="%.2f" xChannelSelector="R" '
           'yChannelSelector="G" result="d"/>' % ROUGH) if ROUGH > 0 else '<feOffset in="SourceGraphic" result="d"/>'
PAPER_FILTER = (
    '<filter id="paper" x="-4%" y="-4%" width="108%" height="108%">' + _WOBBLE +
    '<feImage href="grain.png" x="0" y="0" width="256" height="256" result="g"/>'
    '<feTile in="g" result="t"/>'
    '<feComposite in="t" in2="d" operator="in" result="tm"/>'
    '<feComposite in="tm" in2="d" operator="over"/>'
    '</filter>')

_cache = {}


# ------------------------------------------------------------ drawings
def part_drawing(name, var):
    key = (name, var)
    if key in _cache:
        return _cache[key]
    far = name.startswith('far_')
    kind = name.split('_', 1)[1] if '_' in name else name
    if name == 'torso':
        d = B.torso()
    elif name == 'neck':
        d = B.neck()
    elif kind == 'thigh':
        d = B.thigh(far)
    elif kind == 'shin':
        d = B.shin(far)
    elif kind == 'foot':
        d = B.foot(far, var or 'flat')
    elif kind == 'upper_arm':
        d = B.upper_arm(far)
    elif kind == 'forearm':
        d = B.forearm(far)
    elif kind == 'hand':
        d = B.hand(far, var or 'relaxed')
    else:
        raise KeyError(name)
    _cache[key] = d
    return d


# ------------------------------------------------------------ kinematics
from rig import part_state, world_matrices, skirt_points, contact_points, FLOOR_Y


# ------------------------------------------------------------ svg assembly
def el_drawing(d, M, alpha, uid, name=None):
    """Return (outline_svg, body_svg) for one part drawing."""
    if not d['shape']:
        return '', ''
    t = G.mstr(M)
    op = '' if alpha >= 0.999 else ' opacity="%.3f"' % alpha
    if name:
        op += ' data-part="%s"' % name
    outline = ''
    if d['outline']:
        outline = '<path transform="%s" d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"%s/>' % (
            t, d['shape'], d['line'], S.LW * 2, op)
    body = ['<g transform="%s"%s>' % (t, op)]
    fade = d.get('fade')
    if fade:
        y0, y1 = fade
        body.append('<linearGradient id="%s-fg" gradientUnits="userSpaceOnUse" x1="0" y1="%.1f" x2="0" y2="%.1f">'
                    '<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>'
                    '<mask id="%s-fm" maskUnits="userSpaceOnUse" x="-400" y="-1200" width="800" height="1000">'
                    '<rect x="-400" y="-1200" width="800" height="1000" fill="url(#%s-fg)"/></mask>'
                    '<g mask="url(#%s-fm)">' % (uid, y0, y1, uid, uid, uid))
    body.append('<path d="%s" fill="%s"/>' % (d['shape'], d['fill']))
    if d['over']:
        body.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (uid, d['shape']))
        body.append('<g clip-path="url(#%s)"><g filter="url(#shadeblur)">%s</g></g>' % (uid, ''.join(d['over'])))
    if fade:
        body.append('</g>')
    body.extend(d['detail'])
    body.extend(d['edges'])
    body.append('</g>')
    return outline, ''.join(body)


def variant_layers(pose, name):
    """List of (variant, alpha, on_top) for a part (handles crossfades)."""
    st = part_state(pose, name)
    fade = pose.get('_fade', {}).get(name)
    if fade:
        old, new, s = fade
        a_new = min(1.0, 2 * s)
        a_old = min(1.0, 2 * (1 - s))
        out = []
        if a_new > 0.001:
            out.append((new, a_new))
        if a_old > 0.001:
            out.append((old, a_old))
        return out
    return [(st['v'], 1.0)]


def head_svg(pose, M, uid):
    hp = pose.get('head', {})
    L = head_layers(yaw=hp.get('yaw', -68.0), eyes=hp.get('eyes', 0.0), smile=hp.get('smile', 0.6),
                    look=hp.get('look', 0.0), ids=uid)
    m = G.mul(M['head'], G.mul(G.translate(*B.HEAD_CENTER), G.scale(B.HEAD_SCALE)))
    return '<g id="head" transform="%s">%s%s</g>' % (G.mstr(m), L['back'], L['front'])


def skirt_svg(pose, M):
    pts = skirt_points(pose, M)
    d = G.spline(pts, k=0.9)
    P = [(p[0], p[1]) for p in pts]
    out = ['<g id="skirt">']
    out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
        d, S.THOBE, S.LINE_THOBE, S.LW))
    out.append('<clipPath id="skirt-clip"><path d="%s"/></clipPath><g clip-path="url(#skirt-clip)">' % d)
    out.append('<g filter="url(#shadeblur)">')
    # back shading: a band that follows the back edge (points 7..11)
    back = P[7:12]
    inner = [G.lerp_pt(p, q, 0.28) for p, q in zip(back, [P[6], P[5], P[1], P[1], P[0]])]
    out.append('<path d="%s" fill="%s"/>' % (G.spline(back + list(reversed(inner)), k=0.7), S.THOBE_SHADE))
    # hem shadow band
    hem = [P[4], P[5], P[6], P[7]]
    band = hem + [(p[0], p[1] - 22) for p in reversed(hem)]
    out.append('<path d="%s" fill="%s" opacity=".35"/>' % (G.spline(band, k=0.6), S.THOBE_DEEP))
    out.append('</g></g>')
    # side slit at the side seam: a short seam rising from the hem toward the
    # waist, with the two flaps parted a little at the bottom
    hem_a, hem_b = P[5], P[6]
    base = G.lerp_pt(hem_a, hem_b, 0.78)
    top_ref = G.lerp_pt(P[0], P[11], 0.62)
    vx, vy = top_ref[0] - base[0], top_ref[1] - base[1]
    L = math.hypot(vx, vy) or 1.0
    ux, uy = vx / L, vy / L
    up = (base[0] + ux * 110, base[1] + uy * 110)
    nx, ny = -uy, ux
    slit_op = G.smoothstep(0.55, 0.85, -uy)
    if slit_op < 0.01:
        out.append('</g>')
        return ''.join(out)
    out.append('<g opacity="%.3f">' % slit_op)
    gap = [(base[0] + nx * 7, base[1] + ny * 7), (base[0] + ux * 30, base[1] + uy * 30),
           (base[0] - nx * 7, base[1] - ny * 7)]
    out.append('<path d="M%sL%sL%sZ" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (
        G.fmt(gap[0]), G.fmt(gap[1]), G.fmt(gap[2]), S.TROUSER_SHADE, S.LINE_THOBE))
    out.append('<path d="M%sL%s" stroke="%s" stroke-width="1.7" stroke-linecap="round" opacity=".85"/>' % (
        G.fmt(gap[1]), G.fmt(up), S.LINE_THOBE))
    out.append('</g></g>')
    return ''.join(out)


def contact_shadow(M):
    # soft ellipses under points that are near the floor
    cands = []
    for name, pts in (('near_foot', [(-90, -2), (-40, 0), (20, 0)]), ('far_foot', [(-120, -24), (-60, -22), (-14, -22)]),
                      ('near_shin', [(-30, -260), (0, -80), (-46, -220)]), ('near_thigh', [(-40, -262)])):
        for p in pts:
            q = G.apply(M[name], p)
            cands.append(q)
    blobs = []
    for x, y in cands:
        gap = FLOOR_Y - y
        if gap < 60:
            k = max(0.0, 1 - gap / 60.0)
            blobs.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" opacity="%.2f"/>' % (
                x, FLOOR_Y + 2, 70 * (0.6 + 0.4 * k), 12, 0.22 * k))
    if not blobs:
        return ''
    return '<g fill="%s" filter="url(#soft)">%s</g>' % (S.SHADOW, ''.join(blobs))


def build_svg(pose, background=True, uid='f', texture=None):
    texture = TEXTURE if texture is None else texture
    M = world_matrices(pose)
    items = []
    for name, (parent, pivot, group, z) in B.PARTS.items():
        st = part_state(pose, name)
        zz = st['z'] if st['z'] is not None else z
        items.append((zz, name, group))
    items.sort()
    # group consecutive same-group parts
    groups = []
    for zz, name, group in items:
        if groups and groups[-1][0] == group:
            groups[-1][1].append(name)
        else:
            groups.append((group, [name]))
    body = []
    for group, names in groups:
        if group == 'head':
            body.append(head_svg(pose, M, uid + 'h'))
            continue
        if group == 'skirt':
            body.append(skirt_svg(pose, M))
            continue
        outlines, fills = [], []
        for name in names:
            for k, (var, alpha) in enumerate(variant_layers(pose, name)):
                d = part_drawing(name, var)
                o, f = el_drawing(d, M[name], alpha, '%s-%s-%d' % (uid, name, k), name)
                outlines.append(o)
                fills.append(f)
        body.append('<g id="%s">%s%s</g>' % (group, ''.join(outlines), ''.join(fills)))
    bg = ''
    if background:
        bg = '<image href="room1080.jpg" x="0" y="-8" width="1080" height="1936" preserveAspectRatio="none"/>'
    defs = ('<defs><filter id="soft" x="-50%" y="-200%" width="200%" height="500%">'
            '<feGaussianBlur stdDeviation="10"/></filter>'
            '<filter id="shadeblur" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="3.2"/></filter>'
            + PAPER_FILTER + '</defs>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            'width="%d" height="%d" viewBox="0 0 %d %d">%s%s%s<g id="boy"%s>%s</g></svg>' % (
                W, H, W, H, defs, bg, contact_shadow(M), ' filter="url(#paper)"' if texture else '', ''.join(body)))


# ------------------------------------------------------------ interpolation
_anchor_cache = {}


_anchor_cache = {}


def anchor_for(a_name, b_name):
    """The support point to pin between two keys, or None.

    Among leg contact points touching the mat in both keys, the one that moves
    least is pinned (it slides linearly if the keys disagree, zero for planted
    feet or knees). None means: just keep the lowest point on the mat.
    """
    key = (a_name, b_name)
    if key in _anchor_cache:
        return _anchor_cache[key]
    A = contact_points(POSES[a_name])
    Bp = contact_points(POSES[b_name])
    best = None
    for pa, pb in zip(A, Bp):
        if FLOOR_Y - pa[1] < 6 and FLOOR_Y - pb[1] < 6:
            d = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
            if d < 120 and (best is None or d < best[0]):
                best = (d, '%s_%s' % (pa[2], pa[3]), pa[4], pa[2], 'pin')
    if best is None:
        # knees resting (or nearly) in both keys: keep the knee's x on its line
        ka = G.apply(world_matrices(POSES[a_name])['near_shin'], B.KNEE)
        kb = G.apply(world_matrices(POSES[b_name])['near_shin'], B.KNEE)
        if FLOOR_Y - ka[1] < 90 and FLOOR_Y - kb[1] < 90:
            best = (abs(ka[0] - kb[0]), 'near_shin', B.KNEE, 'near', 'kneex')
    _anchor_cache[key] = best
    return best


def short(a, b):
    d = (b - a + 180.0) % 360.0 - 180.0
    return a + d


def hermite_keys(keys, t):
    """C1 cubic through (time, value) keys (Catmull-Rom tangents), at t."""
    n = len(keys)
    if n == 2:
        (t0, v0), (t1, v1) = keys
        return G.lerp(v0, v1, (t - t0) / (t1 - t0))
    i = 0
    while i < n - 2 and t > keys[i + 1][0]:
        i += 1
    t0, v0 = keys[i]
    t1, v1 = keys[i + 1]

    def tangent(j):
        if j == 0:
            return (keys[1][1] - keys[0][1]) / (keys[1][0] - keys[0][0])
        if j == n - 1:
            return (keys[-1][1] - keys[-2][1]) / (keys[-1][0] - keys[-2][0])
        return (keys[j + 1][1] - keys[j - 1][1]) / (keys[j + 1][0] - keys[j - 1][0])
    m0, m1 = tangent(i), tangent(i + 1)
    h = t1 - t0
    s = (t - t0) / h
    h00 = 2 * s ** 3 - 3 * s ** 2 + 1
    h10 = s ** 3 - 2 * s ** 2 + s
    h01 = -2 * s ** 3 + 3 * s ** 2
    h11 = s ** 3 - s ** 2
    return h00 * v0 + h10 * h * m0 + h01 * v1 + h11 * h * m1


# Overlapping action: parts further from the body's core start and settle a
# little later, as a fraction of the transition. The core leads and lands
# early by the largest lag, so every part still arrives by the end.
LAG = {'neck': 0.03, 'head': 0.07,
       'near_upper_arm': 0.03, 'far_upper_arm': 0.04,
       'near_forearm': 0.06, 'far_forearm': 0.07,
       'near_hand': 0.09, 'far_hand': 0.10}
LAG_MAX = max(LAG.values())


def lagged(u, lag):
    return max(0.0, min(1.0, (u - lag) / (1.0 - LAG_MAX)))


def interp(a, b, u, names=None):
    return interp_core(a, b, u, names)


def interp_core(a, b, u, names=None):
    """Blend posture a into b at eased parameter u (0..1).

    Breakdown keys listed in poses.VIA are threaded through with a C1 spline.
    Variant swaps crossfade over the last SWAP_FADE seconds.
    """
    e = G.ease(lagged(u, 0.0))
    keys = [(0.0, a)]
    if names and tuple(names) in VIA:
        for via_name, tv in VIA[tuple(names)]:
            keys.append((tv, POSES[via_name]))
    keys.append((1.0, b))

    def chan(get, angle=False, ee=None):
        vals = []
        prev = None
        for t, p in keys:
            v = get(p)
            if angle and prev is not None:
                v = short(prev, v)
            vals.append((t, v))
            prev = v
        return hermite_keys(vals, e if ee is None else ee)

    out = {'root': [chan(lambda p: p['root'][0]), chan(lambda p: p['root'][1])],
           'rootRot': chan(lambda p: p.get('rootRot', 0.0)),
           'parts': {}, 'head': {}, 'skirt': {}, '_fade': {}}
    fade_start = 1.0 - SWAP_FADE / TRANSITION
    for name in B.PARTS:
        sa, sb = part_state(a, name), part_state(b, name)
        ep = G.ease(lagged(u, LAG.get(name, 0.0)))
        st = {'r': chan(lambda p: part_state(p, name)['r'], angle=True, ee=ep)}
        for k in ('dx', 'dy', 'sx', 'sy'):
            st[k] = chan(lambda p: part_state(p, name)[k], ee=ep)
        st['z'] = sa['z'] if u < 0.5 else sb['z']
        w = SWAP_FADE / TRANSITION
        if sa['v'] in HD.CONTACT and sa['v'] != sb['v']:
            w0, w1 = 0.0, w            # hands part: swap right away
        else:
            w0, w1 = 1.0 - w, 1.0      # otherwise swap as the posture lands
        st['v'] = sa['v'] if u < w1 else sb['v']
        if sa['v'] != sb['v'] and w0 <= u < w1:
            out['_fade'][name] = (sa['v'], sb['v'], G.ease((u - w0) / (w1 - w0)))
        out['parts'][name] = st
    eh = G.ease(lagged(u, LAG['head']))
    for k, dflt in (('yaw', -58.0), ('eyes', 0.0), ('smile', 0.6), ('look', 0.0)):
        out['head'][k] = chan(lambda p: p.get('head', {}).get(k, dflt), ee=eh)
    for i in range(len(B.SKIRT)):
        for j in (0, 1):
            pass
        out['skirt'][str(i)] = (chan(lambda p: p.get('skirt', {}).get(str(i), (0, 0))[0]),
                                chan(lambda p: p.get('skirt', {}).get(str(i), (0, 0))[1]))
    out['_root0'] = list(out['root'])
    if names and 0.0 < u < 1.0:
        knames = [names[0]] + [v for v, _ in VIA.get(tuple(names), [])] + [names[1]]
        ktimes = [0.0] + [t for _, t in VIA.get(tuple(names), [])] + [1.0]
        i = 0
        while i < len(ktimes) - 2 and e > ktimes[i + 1]:
            i += 1
        s_loc = (e - ktimes[i]) / (ktimes[i + 1] - ktimes[i])
        anc = anchor_for(knames[i], knames[i + 1])
        if anc:
            _, part, rest_pt, side, mode = anc
            pa = G.apply(world_matrices(POSES[knames[i]])[part], rest_pt)
            pb = G.apply(world_matrices(POSES[knames[i + 1]])[part], rest_pt)
            want = G.lerp_pt(pa, pb, max(0.0, min(1.0, s_loc)))
            cur = G.apply(world_matrices(out)[part], rest_pt)
            out['root'][0] += want[0] - cur[0]
            if mode == 'pin':
                out['root'][1] += want[1] - cur[1]
            else:
                low = max(p[1] for p in contact_points(out))
                out['root'][1] += FLOOR_Y - low
        else:
            low = max(p[1] for p in contact_points(out))
            out['root'][1] += FLOOR_Y - low
        low = max(p[1] for p in contact_points(out))
        if low > FLOOR_Y:
            out['root'][1] -= low - FLOOR_Y
    return out


# ------------------------------------------------------------ rendering
def prep_dirs():
    for d in (OUT, WORK, os.path.join(WORK, 'svg'), os.path.join(WORK, 'frames')):
        os.makedirs(d, exist_ok=True)
    dst = os.path.join(WORK, 'svg', 'room.jpg')
    if not os.path.exists(dst):
        shutil.copy(os.path.join(HERE, 'assets', 'room.jpg'), dst)
    gpath = os.path.join(WORK, 'svg', 'grain.png')
    if not os.path.exists(gpath):
        import grain
        grain.make(gpath)
        grain.make_wobble(os.path.join(WORK, 'svg', 'wobble.png'))
    bpath = os.path.join(WORK, 'svg', 'room1080.jpg')
    if not os.path.exists(bpath):
        # pre-scale the plate once; resampling it per frame costs ~0.5 s
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', os.path.join(HERE, 'assets', 'room.jpg'),
                        '-vf', 'scale=1080:1936', '-q:v', '2', bpath], check=True)


def rasterize(svg_text, png_path, tag):
    svg_path = os.path.join(WORK, 'svg', tag + '.svg')
    with open(svg_path, 'w') as f:
        f.write(svg_text)
    subprocess.run(['rsvg-convert', '-w', str(W), '-h', str(H), svg_path, '-o', png_path], check=True)


def render_pose(name, background=True):
    prep_dirs()
    path = os.path.join(OUT, 'pose-%s.png' % name)
    rasterize(build_svg(POSES[name], background, uid=name), path, 'pose-' + name)
    return path


def sequence_frames():
    seq = SEQUENCE
    n_tr = len(seq) - 1
    total = n_tr * TRANSITION
    nframes = int(round(total * FPS)) + 1
    frames = []
    for i in range(nframes):
        t = min(i / FPS, total)
        k = min(int(t / TRANSITION), n_tr - 1)
        u = (t - k * TRANSITION) / TRANSITION
        frames.append((seq[k], seq[k + 1], u))
    return frames


def render_frames():
    prep_dirs()
    fdir = os.path.join(WORK, 'frames')
    for f in os.listdir(fdir):
        os.remove(os.path.join(fdir, f))
    frames = sequence_frames()
    t0 = time.time()

    def job(i):
        a, b, u = frames[i]
        pose = interp(POSES[a], POSES[b], u, (a, b))
        rasterize(build_svg(pose, True, uid='f%d' % i), os.path.join(fdir, 'f%04d.png' % i), 'f%04d' % i)

    with ThreadPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) - 2)) as ex:
        list(ex.map(job, range(len(frames))))
    dt = time.time() - t0
    for f in os.listdir(os.path.join(WORK, 'svg')):
        if f.startswith('f') and f.endswith('.svg'):
            os.remove(os.path.join(WORK, 'svg', f))
    return len(frames), dt


def make_video():
    out = os.path.join(OUT, 'walkthrough.mp4')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', str(FPS), '-i',
                    os.path.join(WORK, 'frames', 'f%04d.png'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
                    '-crf', '18', '-preset', 'slow', '-r', str(FPS), out], check=True)
    return out


def sheet(paths, cols, out, labels=None, cell_w=360):
    """Tile PNGs with ffmpeg (xstack)."""
    n = len(paths)
    rows = (n + cols - 1) // cols
    cell_h = int(cell_w * H / W)
    args = ['ffmpeg', '-loglevel', 'error', '-y']
    for p in paths:
        args += ['-i', p]
    filt = []
    for i in range(n):
        filt.append('[%d:v]scale=%d:%d[s%d]' % (i, cell_w, cell_h, i))
    layout = '|'.join('%d_%d' % ((i % cols) * cell_w, (i // cols) * cell_h) for i in range(n))
    filt.append('%sxstack=inputs=%d:layout=%s:fill=white[o]' % (''.join('[s%d]' % i for i in range(n)), n, layout))
    args += ['-filter_complex', ';'.join(filt), '-map', '[o]', '-frames:v', '1', out]
    subprocess.run(args, check=True)
    return out


def contact_sheet():
    names = ['standing', 'takbir', 'bowing', 'rising', 'prostrating', 'sitting', 'tashahhud',
             'salamRight', 'salamLeft', 'after']
    paths = [render_pose(n) for n in names]
    return sheet(paths, 5, os.path.join(HERE, 'contact-sheet.png'))


def motion_sheet():
    prep_dirs()
    # standing -> bowing -> rising -> prostrating, eight evenly spaced moments
    keys = [('standing', 'bowing', 0.0), ('standing', 'bowing', 0.4), ('standing', 'bowing', 0.7),
            ('standing', 'bowing', 1.0), ('rising', 'prostrating', 0.3), ('rising', 'prostrating', 0.55),
            ('rising', 'prostrating', 0.8), ('rising', 'prostrating', 1.0)]
    paths = []
    for i, (a, b, u) in enumerate(keys):
        p = os.path.join(WORK, 'motion-%d.png' % i)
        rasterize(build_svg(interp(POSES[a], POSES[b], u, (a, b)), True, uid='m%d' % i), p, 'motion-%d' % i)
        paths.append(p)
    return sheet(paths, 8, os.path.join(HERE, 'motion-sheet.png'), cell_w=270)


def main(argv):
    cmd = argv[1] if len(argv) > 1 else 'all'
    if cmd == 'pose':
        print(render_pose(argv[2]))
    elif cmd == 'stills':
        print(contact_sheet())
    elif cmd == 'sheets':
        print(contact_sheet())
        print(motion_sheet())
    elif cmd in ('video', 'all'):
        if cmd == 'all':
            main(['render.py', 'svg'])
            print(contact_sheet())
            print(motion_sheet())
        n, dt = render_frames()
        print('frames: %d in %.1fs (%.3fs per frame wall, %d workers)' % (n, dt, dt / n, max(2, (os.cpu_count() or 4) - 2)))
        out = make_video()
        shutil.copy(out, os.path.join(HERE, 'walkthrough.mp4'))
        print(os.path.join(HERE, 'walkthrough.mp4'))
    elif cmd == 'strips':
        pass
    elif cmd == 'svg':
        # the drawn boy as standalone layered SVGs (no room plate)
        for n in ('rising', 'standing'):
            with open(os.path.join(HERE, 'boy-%s.svg' % n), 'w') as f:
                f.write(build_svg(POSES[n], background=False, uid=n, texture=False))
            print(os.path.join(HERE, 'boy-%s.svg' % n))
    else:
        print(__doc__)


if __name__ == '__main__':
    main(sys.argv)


def strips(rows=None, cols=6, out_name='strips.png'):
    """Debug filmstrips: each transition sampled at evenly spaced moments."""
    prep_dirs()
    pairs = rows or list(zip(SEQUENCE, SEQUENCE[1:]))
    jobs = []
    for r, (a, b) in enumerate(pairs):
        for c in range(cols):
            u = c / (cols - 1)
            jobs.append((r, c, a, b, u))

    def job(j):
        r, c, a, b, u = j
        p = os.path.join(WORK, 'strip-%02d-%d.png' % (r, c))
        rasterize(build_svg(interp(POSES[a], POSES[b], u, (a, b)), True, uid='s%d%d' % (r, c)), p,
                  'strip-%02d-%d' % (r, c))
        return p

    with ThreadPoolExecutor(max_workers=10) as ex:
        paths = list(ex.map(job, jobs))
    return sheet(paths, cols, os.path.join(WORK, out_name), cell_w=180)


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'strips':
    print(strips())
