"""Shape builders used by the part drawings."""
import math

from geom import spline, fmt


def capsule_pts(p0, r0, p1, r1, n=10):
    """Outline points of the hull of two circles (a tapered capsule)."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    # angle offset for tangent lines of unequal circles
    s = (r0 - r1) / L
    s = max(-0.99, min(0.99, s))
    phi = math.asin(s)
    base = math.atan2(uy, ux)
    pts = []
    # arc around p1 (far end), from one tangent to the other
    a0 = base - math.pi / 2 - phi
    a1 = base + math.pi / 2 + phi
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        pts.append((p1[0] + r1 * math.cos(a), p1[1] + r1 * math.sin(a)))
    b0 = base + math.pi / 2 + phi
    b1 = base + 3 * math.pi / 2 - phi
    for i in range(n + 1):
        a = b0 + (b1 - b0) * i / n
        pts.append((p0[0] + r0 * math.cos(a), p0[1] + r0 * math.sin(a)))
    return pts


def poly_d(pts):
    return 'M' + 'L'.join(fmt(p) for p in pts) + 'Z'


def path_el(d, fill='none', stroke=None, width=None, opacity=None, extra=''):
    a = ['d="%s"' % d, 'fill="%s"' % fill]
    if stroke:
        a.append('stroke="%s"' % stroke)
        a.append('stroke-width="%.2f"' % (width or 2))
        a.append('stroke-linecap="round" stroke-linejoin="round"')
    if opacity is not None and opacity < 1:
        a.append('opacity="%.3f"' % opacity)
    if extra:
        a.append(extra)
    return '<path %s/>' % ' '.join(a)


def line(pts, color, width, opacity=None, k=1.0):
    return path_el(spline(pts, closed=False, k=k), stroke=color, width=width, opacity=opacity)


def hatch(x0, y0, x1, y1, n, angle, length, color, width=1.1, opacity=0.35, seed=1):
    """Short parallel pencil strokes scattered in a box (deterministic)."""
    import random
    rnd = random.Random(seed)
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)
    segs = []
    for i in range(n):
        cx = x0 + (x1 - x0) * (i + rnd.random() * 0.8) / n
        cy = y0 + (y1 - y0) * rnd.random()
        L = length * (0.6 + 0.6 * rnd.random())
        segs.append('M%sL%s' % (fmt((cx - ca * L / 2, cy - sa * L / 2)), fmt((cx + ca * L / 2, cy + sa * L / 2))))
    return '<path d="%s" stroke="%s" stroke-width="%.2f" stroke-linecap="round" opacity="%.2f"/>' % (
        ''.join(segs), color, width, opacity)
