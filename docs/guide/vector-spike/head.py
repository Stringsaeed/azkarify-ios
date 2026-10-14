"""The boy's head, drawn from a tiny 2.5D model so it can turn smoothly.

Head-local coordinates: origin at the cranium centre, x right, y down,
units are canvas pixels at 1080 width. The head is a union of soft spheres
(cranium, face mass, nose, chin) seen orthographically. Features sit on
the surface at fixed (side, y, forward) positions and slide with yaw.

yaw is the direction the face points: 0 = at the viewer, -90 = screen
left (pure profile), -180 = away. The default 3/4 profile is about -68.
"""
import math

from geom import spline, fmt, smoothstep, ellipse_d, circle_pts
import style as S

R = 112.0          # cranium radius
FACE = (0.0, 40.0, 58.0, 58.0)    # side, y, forward, radius (sphere for features)
# ellipsoids for the silhouette: (side, y, forward, a_side, b_vert, c_fwd)
FACE_E = (0.0, 40.0, 58.0, 50.0, 57.0, 56.0)
CHIN_E = (0.0, 82.0, 66.0, 30.0, 28.0, 32.0)
OCCIPUT_E = (0.0, 22.0, -30.0, 64.0, 60.0, 60.0)
NOSE = (0.0, 22.0, 126.0, 12.5)
HAIR_R = R + 5.0
KUFI_R = R + 7.0


def hull(points):
    pts = sorted(set((round(p[0], 3), round(p[1], 3)) for p in points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def resample(poly, step=9.0):
    """Resample a closed polygon to roughly even spacing (for smooth splines)."""
    out = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        k = max(1, int(L / step))
        for j in range(k):
            t = j / k
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def proj(s, y, f, yaw):
    c, si = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    x = s * c + f * si
    z = -s * si + f * c
    return x, y, z


def facing(alpha, yaw):
    """z component of a surface normal with head-local azimuth alpha."""
    return math.cos(math.radians(alpha + yaw))


def sph(alpha, el, r):
    """Point on a sphere: azimuth alpha (0 = forward, + = near side)."""
    a, e = math.radians(alpha), math.radians(el)
    return (r * math.cos(e) * math.sin(a), -r * math.sin(e), r * math.cos(e) * math.cos(a))


def cap_region(boundary, r, yaw, step=1.5, top_bulge=None):
    """Projected visible region of the sphere cap above boundary(alpha).

    boundary(alpha) -> elevation in degrees, for alpha in [-180, 180).
    Returns a list of 2D points (closed polygon) and the visible boundary
    run (open polyline) separately.
    """
    if callable(boundary):
        n = int(round(360 / step))
        loop = [(-180 + i * step, boundary(-180 + i * step)) for i in range(n)]
    else:
        loop = boundary
        n = len(loop)
    samples = []
    for al, el in loop:
        s, y, f = sph(al, el, r)
        x, y2, z = proj(s, y, f, yaw)
        samples.append((x, y2, z))
    # find entry (z goes from <0 to >=0) when walking forward
    start = None
    for i in range(n):
        if samples[i - 1][2] < 0 <= samples[i][2]:
            start = i
            break
    if start is None:
        return None, None
    run = []
    p0 = samples[start - 1]
    p1 = samples[start]
    t = -p0[2] / (p1[2] - p0[2])
    run.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t))
    i = start
    while True:
        p = samples[i % n]
        q = samples[(i + 1) % n]
        run.append((p[0], p[1]))
        if q[2] < 0:
            t = p[2] / (p[2] - q[2])
            run.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
            break
        i += 1
        if i - start > n:
            break
    # limb arc from exit back to entry, over the top
    ex, ey = run[-1]
    sx, sy = run[0]
    ta = math.atan2(-ey, ex)
    tb = math.atan2(-sy, sx)
    # go the way that passes through the top (angle pi/2)
    if ta < -math.pi / 2:
        ta += 2 * math.pi
    if tb < -math.pi / 2:
        tb += 2 * math.pi
    arc = []
    m = 28
    for k in range(1, m):
        th = ta + (tb - ta) * k / m
        rr = r
        if top_bulge:
            rr = r + top_bulge(th)
        arc.append((rr * math.cos(th), -rr * math.sin(th)))
    return run + arc, run


# Hairline control points (azimuth, elevation) on the near side. 'c' marks a
# pointed lock tip. Mirrored for the far side.
HAIR_NEAR = [
    (0, 21), (1, 11), (3, 6, 'c'), (8, 11), (14, 17), (19, 21),
    (21, 10), (24, 4, 'c'), (30, 9), (36, 15), (40, 18),
    (42, 11), (45, 7, 'c'), (50, 11), (55, 14),
    (57, 4), (60, -4, 'c'), (64, 3), (68, 6),
    (71, -6), (75, -18, 'c'), (79, -8), (84, 2),
    (90, 6), (97, -16), (106, -30), (116, -40), (126, -46),
    (133, -50), (139, -58, 'c'), (143, -50), (149, -54), (155, -64, 'c'),
    (160, -56), (166, -58), (171, -66, 'c'), (176, -60), (180, -60)]


def _hairline_table():
    near = HAIR_NEAR
    far = [(-p[0], p[1]) + tuple(p[2:]) for p in reversed(near) if 0 < p[0] < 180]
    ctrl = far + near[:-1]
    # Catmull-Rom in (alpha, el), periodic, corners kept sharp
    n = len(ctrl)
    out = []
    for i in range(n):
        p0 = ctrl[(i - 1) % n]
        p1 = ctrl[i]
        p2 = ctrl[(i + 1) % n]
        p3 = ctrl[(i + 2) % n]

        def unwrap(a, ref):
            while a - ref > 180:
                a -= 360
            while a - ref < -180:
                a += 360
            return a
        a1 = p1[0]
        a0 = unwrap(p0[0], a1)
        a2 = unwrap(p2[0], a1)
        a3 = unwrap(p3[0], a2)
        c1 = len(p1) > 2
        c2 = len(p2) > 2
        t1 = (0.0, 0.0) if c1 else ((a2 - a0) / 6.0, (p2[1] - p0[1]) / 6.0)
        t2 = (0.0, 0.0) if c2 else ((a3 - a1) / 6.0, (p3[1] - p1[1]) / 6.0)
        b0 = (a1, p1[1])
        b1 = (a1 + t1[0], p1[1] + t1[1])
        b2 = (a2 - t2[0], p2[1] - t2[1])
        b3 = (a2, p2[1])
        for k in range(12):
            t = k / 12.0
            mt = 1 - t
            x = mt ** 3 * b0[0] + 3 * mt * mt * t * b1[0] + 3 * mt * t * t * b2[0] + t ** 3 * b3[0]
            y = mt ** 3 * b0[1] + 3 * mt * mt * t * b1[1] + 3 * mt * t * t * b2[1] + t ** 3 * b3[1]
            out.append((x, y))
    return out


_HL = _hairline_table()


def hair_samples():
    return _HL


def hairline(alpha):
    best = None
    for (a0, e0), (a1, e1) in zip(_HL, _HL[1:]):
        if min(a0, a1) <= alpha <= max(a0, a1) and a1 != a0:
            e = e0 + (e1 - e0) * (alpha - a0) / (a1 - a0)
            if best is None or e > best:
                best = e
    return best if best is not None else 0.0


def brim(alpha):
    return 15.0 + 7.0 * math.cos(math.radians(alpha))


def _feature_tf(pos, alpha_n, yaw, lift=0.0):
    """Return (px, py, cx, vis) for a flat feature on the surface."""
    s, y, f = pos
    x, y2, z = proj(s, y, f, yaw)
    th = math.radians(alpha_n + yaw)
    cx = math.cos(th)
    x += lift * math.sin(th)
    return x, y2, cx, smoothstep(0.02, 0.32, cx)


def _tf_pts(pts, px, py, cx, skew=0.0):
    return [(px + u * cx + skew * u, py + v) + tuple(p[2:]) for (u, v, *rest) in pts
            for p in [(u, v, *rest)]]


def _g(content, opacity=1.0):
    if opacity >= 0.999:
        return content
    if opacity <= 0.001:
        return ''
    return '<g opacity="%.3f">%s</g>' % (opacity, content)


def _eye(side, yaw, openness, look):
    """One eye. side=+1 near, -1 far. Returns svg."""
    alpha_n = 32 * side
    pos = (52 * side, 8.0, 98.0)
    px, py, cx, vis = _feature_tf(pos, alpha_n, yaw)
    if vis <= 0.001:
        return ''
    cx = max(cx, 0.0)
    o = openness
    # lid: closed is a downward smile curve, open is an upper lid arch
    d = side  # outer corner direction in u
    closed = [(-16 * d, -3), (-7 * d, 4.5), (3 * d, 6.0), (12 * d, 2.0), (18 * d, -3.5)]
    opened = [(-15 * d, -2), (-7 * d, -10), (3 * d, -11.5), (12 * d, -8), (18 * d, -2)]
    lid = [(a[0] + (b[0] - a[0]) * o, a[1] + (b[1] - a[1]) * o) for a, b in zip(closed, opened)]
    lid_w = [(px + u * cx, py + v) for u, v in lid]
    out = []
    if o > 0.05:
        # iris: dark oval, scaled by openness, then a sparkle
        ix = px + (2 + look * 4) * d * cx
        iy = py + 1.5
        rx = 7.5 * max(cx, 0.15)
        ry = 9.5 * o
        out.append('<path d="%s" fill="%s"/>' % (ellipse_d(ix, iy, rx, ry), S.EYE))
        out.append('<path d="%s" fill="#fffaf0" opacity="%.2f"/>' % (
            ellipse_d(ix - 2.2 * cx, iy - 3.5 * o, 2.4 * max(cx, .3), 2.4 * o), o))
    lw = 3.8 - 1.0 * o
    out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round"/>' % (
        spline(lid_w, closed=False), S.EYE, lw))
    # lashes at the outer corner, only when closed-ish and facing us
    if o < 0.6 and cx > 0.25:
        k = (1 - o / 0.6)
        lx, ly = lid_w[-1]
        lash = [(lx, ly), (lx + 5 * d * cx, ly - 2.5)]
        out.append('<path d="M%sL%s" stroke="%s" stroke-width="2.4" stroke-linecap="round" opacity="%.2f"/>' % (
            fmt(lash[0]), fmt(lash[1]), S.EYE, k))
        mx, my = lid_w[2]
        out.append('<path d="M%sL%s" stroke="%s" stroke-width="1.8" stroke-linecap="round" opacity="%.2f"/>' % (
            fmt((mx + 4 * d * cx, my + 0.5)), fmt((mx + 6 * d * cx, my + 5)), S.EYE, k * .8))
        out.append('<path d="M%sL%s" stroke="%s" stroke-width="1.8" stroke-linecap="round" opacity="%.2f"/>' % (
            fmt((mx - 3 * d * cx, my + 0.8)), fmt((mx - 4 * d * cx, my + 5.5)), S.EYE, k * .7))
    # brow
    bpos = (54 * side, -15.0, 98.0)
    bx, by, bcx, _ = _feature_tf(bpos, 34 * side, yaw)
    brow = [(-14 * d, 2.5), (0, -2 - 1.5 * o), (14 * d, 2.5)]
    bw = [(bx + u * bcx, by + v) for u, v in brow]
    out.append('<path d="%s" fill="none" stroke="%s" stroke-width="4.2" stroke-linecap="round" opacity=".9"/>' % (
        spline(bw, closed=False), S.BROW))
    return _g(''.join(out), vis)


def _ear(side, yaw):
    """Returns (svg, in_front)."""
    alpha_n = 90 * side
    pos = (104 * side, 12.0, 4.0)
    s, y, f = pos
    x, y2, z = proj(s, y, f, yaw)
    th = math.radians(alpha_n + yaw)
    co, si = math.cos(th), math.sin(th)
    d = side
    # u runs toward the back of the head for the near ear
    shape = [(-12, -22), (0, -32), (14, -27), (23, -9), (22, 10), (13, 26), (0, 31),
             (-10, 24), (-14, 6)]
    inner = [(-1, -15), (9, -11), (12, 1), (8, 12), (2, 16)]

    def tfp(u, v):
        uu = u * d
        lift = 0.36 * (u + 12)
        return (x + uu * co * d * d + lift * si * d * 0 + uu * 0, y2 + v) if False else (
            x + u * co + lift * si, y2 + v)

    pts = [tfp(u, v) for u, v in shape]
    ipts = [tfp(u, v) for u, v in inner]
    vis_inner = smoothstep(0.15, 0.45, co)
    out = ['<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
        spline(pts), S.SKIN, S.LINE_SKIN, S.LW)]
    if vis_inner > 0.01:
        out.append('<path d="%s" fill="%s" opacity="%.2f"/>' % (
            spline([tfp(u, v) for u, v in [(-2, -14), (10, -12), (14, 2), (9, 16), (0, 18), (-4, 4)]]),
            S.SKIN_EAR, 0.8 * vis_inner))
        out.append('<path d="%s" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" opacity="%.2f"/>' % (
            spline(ipts, closed=False), S.LINE_SKIN, vis_inner))
    return ''.join(out), co > 0.12


CRANIUM_BOTTOM = 62.0


def skin_outline(yaw, k=0.08, step=4.0):
    blobs = []
    co, si = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    for (s, y, f, a, b, c) in (FACE_E, OCCIPUT_E):
        x, y2, z = proj(s, y, f, yaw)
        blobs.append((x, y2, math.sqrt((a * co) ** 2 + (c * si) ** 2), b))
    pts = []
    n = int(360 / step)
    for i in range(n):
        th = math.radians(i * step)
        dx, dy = math.cos(th), math.sin(th)
        b = CRANIUM_BOTTOM if dy > 0 else R
        ts = [1.0 / math.sqrt((dx / R) ** 2 + (dy / b) ** 2)]
        for cx, cy, ea, eb in blobs:
            # ray from origin vs axis-aligned ellipse: scale to unit circle
            ux, uy = dx / ea, dy / eb
            qx, qy = cx / ea, cy / eb
            A = ux * ux + uy * uy
            Bq = ux * qx + uy * qy
            C = qx * qx + qy * qy - 1
            disc = Bq * Bq - A * C
            if disc > 0:
                ts.append((Bq + math.sqrt(disc)) / A)
        m = max(ts)
        t = m + math.log(sum(math.exp(k * (v - m)) for v in ts)) / k
        pts.append((t * dx, t * dy))
    return pts


def _nose_path(yaw):
    """Small upturned nose: a profile curve extruded sideways, hulled."""
    s0, y0, f0 = NOSE[0], NOSE[1], NOSE[2] - 8
    prof = [(-5, -27), (3, -15), (13, -3), (19, 5), (17, 11), (8, 13), (-3, 13)]
    si, co = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
    pts = []
    for fo, yo in prof:
        for side in (-6.5, 6.5):
            x, y, z = proj(s0 + side, y0 + yo, f0 + fo, yaw)
            pts.append((x, y))
    h = hull(pts)
    return spline(h, k=0.7)


def head_layers(yaw=-68.0, eyes=0.0, smile=0.6, look=0.0, ids='h'):
    """Return dict with 'back' and 'front' svg strings in head-local coords."""
    back = []
    front = []
    # far side ear first
    for side in (-1, 1):
        svg, in_front = _ear(side, yaw)
        if not in_front:
            back.append(svg)

    # --- skin: smooth union of egg cranium, face mass and chin, plus nose ---
    skin_poly = skin_outline(yaw)
    skin_d = spline(skin_poly)
    nose_d = _nose_path(yaw)
    front.append('<path d="%s%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
        skin_d, nose_d, S.LINE_SKIN, S.LW * 2))
    clip_id = ids + '-skin'
    front.append('<filter id="%s-sblur" x="-10%%" y="-10%%" width="120%%" height="120%%">'
                 '<feGaussianBlur stdDeviation="4"/></filter>' % ids)
    front.append('<clipPath id="%s"><path d="%s%s"/></clipPath>' % (clip_id, skin_d, nose_d))
    front.append('<path d="%s%s" fill="%s"/>' % (skin_d, nose_d, S.SKIN))
    # soft form shading: shade colour, then the lit face mass on top
    lx, ly = -0.30, -0.35
    front.append('<g clip-path="url(#%s)"><g filter="url(#%s-sblur)">' % (clip_id, ids))
    front.append('<path d="%s" fill="%s" opacity=".6"/>' % (
        ellipse_d(R * 0.62, R * 0.62, R * 1.1, R * 1.0), S.SKIN_SHADE))
    fx, fy, fz = proj(FACE[0], FACE[1], FACE[2], yaw)
    front.append('<path d="%s" fill="%s"/>' % (
        ellipse_d(fx + lx * 34, fy + ly * 30, FACE[3] * 1.05, FACE[3] * 1.0), S.SKIN))
    front.append('<path d="%s" fill="%s"/>' % (
        ellipse_d(-14, -18, R * 0.92, R * 0.86), S.SKIN))
    front.append('</g></g>')
    nx, ny, nz = proj(NOSE[0], NOSE[1], NOSE[2], yaw)

    # nose detail line (nostril) and bridge hint
    nvis = smoothstep(-0.2, 0.25, math.cos(math.radians(yaw)))
    ncx = math.cos(math.radians(yaw))
    nsi = math.sin(math.radians(yaw))
    nl = [(nx + 6 * ncx - 3 * abs(nsi), ny + 6), (nx + 1.5 * ncx, ny + 9.5),
          (nx - 5 * ncx + 2 * abs(nsi), ny + 7.5)]
    if nvis > 0.01:
        front.append('<path d="%s" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" opacity="%.2f"/>' % (
            spline(nl, closed=False), S.LINE_SKIN, 0.8 * nvis))

    front.append('<filter id="%s-blur" x="-50%%" y="-50%%" width="200%%" height="200%%">'
                 '<feGaussianBlur stdDeviation="5"/></filter>' % ids)
    # cheeks (blush)
    for side in (1, -1):
        bx, by, bcx, bvis = _feature_tf((58 * side, 44.0, 84.0), 40 * side, yaw)
        if bvis > 0.01:
            front.append('<g clip-path="url(#%s)"><path d="%s" fill="%s" opacity="%.2f" filter="url(#%s-blur)"/></g>' % (
                clip_id, ellipse_d(bx, by, 22 * max(bcx, 0.25), 14), S.BLUSH, 0.5 * bvis, ids))

    # mouth: points on the face sphere so it wraps round the cheek
    fs, fyc, ff, fr = FACE
    mpts = []
    mz = []
    curve = 2.5 + 3.5 * smile
    for al, dy in ((-9, -0.5), (-1, curve * 0.8), (8, curve), (16, curve * 0.45), (23, -2.5)):
        yy = 54.0 + dy
        rr = math.sqrt(max(fr * fr - (yy - fyc) ** 2, 1.0))
        a = math.radians(al)
        s, f = rr * math.sin(a), ff + rr * math.cos(a)
        x, y2, z = proj(s, yy, f, yaw)
        mpts.append((x, y2))
        mz.append(z)
    vis_pts = [p for p, z in zip(mpts, mz) if z > -2]
    mo = smoothstep(-0.2, 0.15, math.cos(math.radians(yaw + 10)))
    if len(vis_pts) >= 2 and mo > 0.01:
        front.append('<path d="%s" fill="none" stroke="%s" stroke-width="2.6" stroke-linecap="round" opacity="%.2f"/>' % (
            spline(vis_pts, closed=False), S.MOUTH, mo))

    # eyes and brows
    front.append(_eye(-1, yaw, eyes, look))
    front.append(_eye(1, yaw, eyes, look))

    # --- hair ---
    hair_poly, hair_run = cap_region(_HL, HAIR_R, yaw)
    if hair_poly:
        hd = spline(hair_poly, k=0.5)
        hid = ids + '-hair'
        egg = ids + '-egg'
        egg_pts = []
        for (x, y) in skin_poly:
            r = math.hypot(x, y) or 1.0
            grow = 4.0 if y > 0 else 8.0
            egg_pts.append((x * (r + grow) / r, y * (r + grow) / r))
        front.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (egg, spline(egg_pts)))
        front.append('<g clip-path="url(#%s)"><path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/></g>' % (
            egg, hd, S.HAIR, S.LINE_HAIR, S.LW))
        front.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (hid, hd))
        # sheen: lighter band near the light side
        sheen_poly, _ = cap_region([(a, e + 10) for a, e in _HL], HAIR_R, yaw)
        if sheen_poly:
            front.append('<g clip-path="url(#%s)"><path d="%s" fill="%s" opacity=".55" transform="translate(-7 -6)"/></g>' % (
                hid, spline(sheen_poly, k=0.5), S.HAIR_LIGHT))
            front.append('<g clip-path="url(#%s)"><path d="%s" fill="%s" transform="translate(-3 -2)"/></g>' % (
                hid, spline(sheen_poly, k=0.5), S.HAIR))
        # strand flicks along the visible hairline
        strands = []
        for al in (-44, -30, -14, 2, 16, 28, 38, 52, 64, 100, 116, 132, 146, 160):
            base = hairline(al)
            pts3 = [sph(al - 2, base + 20, HAIR_R), sph(al - 0.5, base + 12, HAIR_R), sph(al + 1.5, base + 5, HAIR_R)]
            pp = [proj(*q, yaw) for q in pts3]
            if all(q[2] > 10 for q in pp):
                strands.append(spline([q[:2] for q in pp], closed=False))
        if strands:
            front.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.7" stroke-linecap="round" opacity=".8" clip-path="url(#%s)"/>' % (
                ''.join(strands), S.HAIR_LIGHT, hid))

    # near ear goes over the hair
    for side in (-1, 1):
        svg, in_front = _ear(side, yaw)
        if in_front:
            front.append(svg)

    # --- kufi ---
    kpoly, krun = cap_region(brim, KUFI_R, yaw, top_bulge=lambda th: 22.0 * max(0.0, math.sin(th)) ** 2.5)
    if kpoly:
        kd = spline(kpoly, k=0.5)
        kid = ids + '-kufi'
        front.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (kid, kd))
        front.append('<path d="%s" fill="%s"/>' % (kd, S.KUFI))
        # shade on the side away from the light (light comes from upper left)
        front.append('<g clip-path="url(#%s)">' % kid)
        front.append('<path d="%s" fill="%s"/>' % (ellipse_d(R * 0.9, 10, R * 0.75, R * 1.3), S.KUFI_SHADE))
        front.append('<path d="%s" fill="%s"/>' % (ellipse_d(-18, -20, KUFI_R * 1.0, KUFI_R * 1.0), S.KUFI))
        # ribs: meridians
        ribs = []
        for k in range(36):
            al = -180 + k * 10 + 5
            seg = []
            for j in range(16):
                el = brim(al) + 9 + (86 - brim(al) - 9) * j / 15
                s, y, f = sph(al, el, KUFI_R)
                x, y2, z = proj(s, y, f, yaw)
                if z < 0:
                    if len(seg) > 1:
                        ribs.append(seg)
                    seg = []
                    continue
                seg.append((x, y2))
            if len(seg) > 1:
                ribs.append(seg)
        rib_d = ''.join('M' + 'L'.join(fmt(p) for p in seg) for seg in ribs)
        dots = []
        for k in range(36):
            al = -180 + k * 10
            for j in range(1, 9):
                el = brim(al) + 12 + (80 - brim(al) - 12) * j / 9.0
                s, y, f = sph(al, el, KUFI_R)
                x, y2, z = proj(s, y, f, yaw)
                if z > 12:
                    dots.append('M%sh0.01' % fmt((x, y2)))
        if dots:
            front.append('<path d="%s" stroke="%s" stroke-width="2.2" stroke-linecap="round" opacity=".45"/>' % (
                ''.join(dots), S.KUFI_RIB))
        front.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.5" stroke-linecap="round"/>' % (
            rib_d, S.KUFI_RIB))
        # band line above the brim
        band = []
        for i in range(181):
            al = -180 + i * 2
            s, y, f = sph(al, brim(al) + 8, KUFI_R)
            x, y2, z = proj(s, y, f, yaw)
            band.append((x, y2, z))
        segs = []
        cur = []
        for x, y2, z in band:
            if z >= 0:
                cur.append((x, y2))
            elif cur:
                segs.append(cur)
                cur = []
        if cur:
            segs.append(cur)
        band_d = ''.join('M' + 'L'.join(fmt(p) for p in s_) for s_ in segs if len(s_) > 1)
        front.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.8"/>' % (band_d, S.KUFI_BAND))
        front.append('</g>')
        front.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
            kd, S.LINE_KUFI, S.LW))

    return {'back': ''.join(back), 'front': ''.join(front)}
