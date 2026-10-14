"""Small 2D geometry kit: affine matrices and smooth spline paths.

Points are (x, y) tuples. A point given as (x, y, 'c') is a corner: the
spline passes through it with no tangent continuity. Matrices are 6-tuples
(a, b, c, d, e, f) in SVG order.
"""
import math

IDENT = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def mul(m, n):
    """Return m * n (apply n first, then m)."""
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + c * B, b * A + d * B,
            a * C + c * D, b * C + d * D,
            a * E + c * F + e, b * E + d * F + f)


def translate(x, y):
    return (1.0, 0.0, 0.0, 1.0, x, y)


def rotate(deg, cx=0.0, cy=0.0):
    r = math.radians(deg)
    co, si = math.cos(r), math.sin(r)
    m = (co, si, -si, co, 0.0, 0.0)
    if cx or cy:
        return mul(translate(cx, cy), mul(m, translate(-cx, -cy)))
    return m


def scale(sx, sy=None, cx=0.0, cy=0.0):
    if sy is None:
        sy = sx
    m = (sx, 0.0, 0.0, sy, 0.0, 0.0)
    if cx or cy:
        return mul(translate(cx, cy), mul(m, translate(-cx, -cy)))
    return m


def apply(m, p):
    a, b, c, d, e, f = m
    return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


def mstr(m):
    return 'matrix(%s)' % ' '.join('%.4f' % v for v in m)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_pt(p, q, t):
    return (lerp(p[0], q[0], t), lerp(p[1], q[1], t))


def ease(t):
    """Smooth ease in and out (cubic smootherstep style)."""
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ease5(t):
    t = max(0.0, min(1.0, t))
    return t * t * t * (t * (t * 6 - 15) + 10)


def smoothstep(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _f(v):
    s = '%.2f' % v
    if '.' in s:
        s = s.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def fmt(p):
    return '%s %s' % (_f(p[0]), _f(p[1]))


def spline(points, closed=True, k=1.0):
    """Catmull-Rom spline through points, as an SVG path string.

    k scales tangent length (1 = standard, lower = tighter curves).
    A point with a third element 'c' is a sharp corner.
    """
    pts = [(p[0], p[1]) for p in points]
    corner = [len(p) > 2 and p[2] == 'c' for p in points]
    n = len(pts)
    if n < 2:
        return ''
    if n == 2:
        return 'M%sL%s' % (fmt(pts[0]), fmt(pts[1]))

    def tangent(i):
        if corner[i]:
            return (0.0, 0.0)
        if closed:
            p0, p2 = pts[(i - 1) % n], pts[(i + 1) % n]
        else:
            p0 = pts[max(i - 1, 0)]
            p2 = pts[min(i + 1, n - 1)]
        return ((p2[0] - p0[0]) / 6.0 * k, (p2[1] - p0[1]) / 6.0 * k)

    tans = [tangent(i) for i in range(n)]
    out = ['M' + fmt(pts[0])]
    segs = n if closed else n - 1
    for i in range(segs):
        j = (i + 1) % n
        a, b = pts[i], pts[j]
        ta, tb = tans[i], tans[j]
        c1 = (a[0] + ta[0], a[1] + ta[1])
        c2 = (b[0] - tb[0], b[1] - tb[1])
        out.append('C%s %s %s' % (fmt(c1), fmt(c2), fmt(b)))
    if closed:
        out.append('Z')
    return ''.join(out)


def poly(points, closed=True):
    s = 'M' + 'L'.join(fmt(p) for p in points)
    return s + ('Z' if closed else '')


def circle_pts(cx, cy, rx, ry=None, n=16, a0=0.0, a1=360.0):
    if ry is None:
        ry = rx
    out = []
    full = abs(a1 - a0) >= 359.999
    cnt = n if full else n + 1
    for i in range(cnt):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return out


def ellipse_d(cx, cy, rx, ry):
    return ('M%s A%s %s 0 1 0 %s A%s %s 0 1 0 %s Z' %
            (fmt((cx - rx, cy)), _f(rx), _f(ry), fmt((cx + rx, cy)),
             _f(rx), _f(ry), fmt((cx - rx, cy))))


def offset_poly(points, dist):
    """Offset a closed polygon outward by dist using vertex normals."""
    n = len(points)
    out = []
    # signed area to know orientation
    area = 0.0
    for i in range(n):
        x0, y0 = points[i][0], points[i][1]
        x1, y1 = points[(i + 1) % n][0], points[(i + 1) % n][1]
        area += x0 * y1 - x1 * y0
    sgn = 1.0 if area > 0 else -1.0
    for i in range(n):
        p0 = points[(i - 1) % n]
        p1 = points[i]
        p2 = points[(i + 1) % n]
        tx, ty = p2[0] - p0[0], p2[1] - p0[1]
        L = math.hypot(tx, ty) or 1.0
        nx, ny = ty / L * sgn, -tx / L * sgn
        out.append((p1[0] + nx * dist, p1[1] + ny * dist))
    return out
