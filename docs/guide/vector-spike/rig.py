"""Kinematics for the boy: forward kinematics, two-bone IK, grounding."""
import math

import geom as G
import boy as B

FLOOR_Y = 1690.0


def part_state(pose, name):
    st = {'r': 0.0, 'dx': 0.0, 'dy': 0.0, 'sx': 1.0, 'sy': 1.0, 'v': None, 'z': None}
    st.update(pose.get('parts', {}).get(name, {}))
    return st


def world_matrices(pose):
    rx, ry = pose['root']
    M = {'root': G.mul(G.translate(rx, ry), G.mul(G.rotate(pose.get('rootRot', 0.0)),
                                                   G.translate(-B.HIP[0], -B.HIP[1])))}

    def solve(name):
        if name in M:
            return M[name]
        parent, pivot, group, z = B.PARTS[name]
        pm = solve(parent)
        if name in B.FAR_ROOTS:
            pm = G.mul(G.translate(*B.FAR_ROOTS[name]), pm)
        st = part_state(pose, name)
        px, py = pivot
        local = G.mul(G.translate(px + st['dx'], py + st['dy']),
                      G.mul(G.rotate(st['r']), G.mul(G.scale(st['sx'], st['sy']), G.translate(-px, -py))))
        M[name] = G.mul(pm, local)
        return M[name]

    for n in B.PARTS:
        solve(n)
    return M


def mrot(m):
    return math.degrees(math.atan2(m[1], m[0]))


def ang(v):
    return math.degrees(math.atan2(v[1], v[0]))


CHAINS = {
    'near_arm': ('near_upper_arm', 'near_forearm', B.SHOULDER, B.ELBOW, B.WRIST),
    'far_arm': ('far_upper_arm', 'far_forearm', B.SHOULDER, B.ELBOW, B.WRIST),
    'near_leg': ('near_thigh', 'near_shin', B.HIP, B.KNEE, B.ANKLE),
    'far_leg': ('far_thigh', 'far_shin', B.HIP, B.KNEE, B.ANKLE),
}


def ik(pose, chain, target, bend=1, sy2=1.0, sy1=1.0):
    """Set the two rotations of a chain so its end reaches target (world).

    bend=+1 bends one way, -1 the other. sy2 foreshortens the second bone.
    """
    a_name, b_name, p0, p1, p2 = CHAINS[chain]
    parts = pose.setdefault('parts', {})
    parts.setdefault(a_name, {})['r'] = 0.0
    parts.setdefault(b_name, {})['r'] = 0.0
    parts[b_name]['sy'] = sy2
    parts[a_name]['sy'] = sy1
    M = world_matrices(pose)
    P = G.apply(M[a_name], p0)          # joint in world (rotation 0 leaves the pivot in place)
    L1 = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * sy1
    L2 = math.hypot(p2[0] - p1[0], p2[1] - p1[1]) * sy2
    dx, dy = target[0] - P[0], target[1] - P[1]
    d = max(abs(L1 - L2) + 1e-3, min(L1 + L2 - 1e-3, math.hypot(dx, dy)))
    alpha = math.degrees(math.acos(max(-1, min(1, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))))
    w1 = ang((dx, dy)) + bend * alpha
    E = (P[0] + L1 * math.cos(math.radians(w1)), P[1] + L1 * math.sin(math.radians(w1)))
    w2 = ang((target[0] - E[0], target[1] - E[1]))
    parent_rot = mrot(M[a_name])        # world rotation of the parent (part at r=0)
    r1 = w1 - ang((p1[0] - p0[0], p1[1] - p0[1])) - parent_rot
    r2 = w2 - ang((p2[0] - p1[0], p2[1] - p1[1])) - (parent_rot + r1)
    parts[a_name]['r'] = norm(r1)
    parts[b_name]['r'] = norm(r2)
    return pose


def norm(a):
    while a > 180:
        a -= 360
    while a < -180:
        a += 360
    return a


def world_rot(pose, name):
    return mrot(world_matrices(pose)[name])


def set_world_rot(pose, name, w):
    """Set a part's rotation so its world rotation equals w degrees."""
    parts = pose.setdefault('parts', {})
    parts.setdefault(name, {})['r'] = 0.0
    base = world_rot(pose, name)
    parts[name]['r'] = norm(w - base)
    return pose


# Points that can carry weight on the floor, in rest coordinates.
CONTACTS = {
    'foot': [(28, -2), (0, 0), (-40, 0), (-62, 1), (-94, -6), (-100, -14), (-76, -40), (-72, -48),
             (-30, -58), (0, -72), (30, -40)],
    'shin': [(-52, -220), (-52, -150), (-50, -90), (-46, -76), (0, -74), (50, -80), (52, -150)],
    'thigh': [(-6 + 47 * math.cos(math.radians(a)), -262 + 47 * math.sin(math.radians(a)))
              for a in range(0, 360, 30)],
}


def contact_points(pose, M=None, sides=('near', 'far')):
    if M is None:
        M = world_matrices(pose)
    out = []
    for side in sides:
        lift = B.FAR_LEG[1] if side == 'far' else 0.0
        for kind, pts in CONTACTS.items():
            m = M['%s_%s' % (side, kind)]
            for p in pts:
                q = G.apply(m, p)
                out.append((q[0], q[1] - lift, side, kind, p))
    return out


def ground(pose):
    """Shift the root vertically so the lowest support point sits on the floor."""
    pts = contact_points(pose)
    low = max(p[1] for p in pts)
    pose['root'][1] += FLOOR_Y - low
    return pose


def lowest(pose, M=None):
    pts = contact_points(pose, M)
    return max(p[1] for p in pts)


def skirt_points(pose, M=None, clamp=True):
    """Skinned skirt control points in world space (plus per-pose offsets)."""
    if M is None:
        M = world_matrices(pose)
    offs = pose.get('skirt', {})
    pts = []
    for i, (p, weights, corner) in enumerate(B.SKIRT):
        x = y = 0.0
        for bone, w in weights.items():
            q = G.apply(M[bone], p)
            x += w * q[0]
            y += w * q[1]
        o = offs.get(str(i), (0, 0))
        x += o[0]
        y += o[1]
        if clamp:
            y = min(y, FLOOR_Y - 2)
        pts.append((x, y, 'c') if corner else (x, y))
    return pts
