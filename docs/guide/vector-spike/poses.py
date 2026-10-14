"""The ten held postures, authored with a little IK and stored as per-part
transforms (rotation in degrees about each part's pivot relative to its
parent, optional dx/dy/sx/sy, variant 'v', layer override 'z').

Positive rotation is clockwise on screen. For a limb hanging down, positive
swings it forward (toward screen left, where the boy faces). Root is the hip
position on the 1080x1920 canvas. Importing this module writes poses.json.
"""
import copy
import json
import os

import geom as G
import boy as B
from rig import FLOOR_Y, ik, set_world_rot, world_matrices, ground, skirt_points
from head import skin_outline

KNEE_X = 618.0    # kneeling postures share this knee position (knees stay put)
# Standing hip x, chosen so the knees land about 120 px in front of where the
# toes stood: kneeling down then needs no backward slide of the feet.
X0 = KNEE_X + 120.0 + 70.0
STANDING_FAMILY = ('standing', 'takbir', 'bowing', 'rising')


def wp(pose, part, p):
    return G.apply(world_matrices(pose)[part], p)


def head_m(pose):
    return G.mul(world_matrices(pose)['head'], G.mul(G.translate(*B.HEAD_CENTER), G.scale(B.HEAD_SCALE)))


def head_point(pose, p):
    return G.apply(head_m(pose), p)


def head_low(pose):
    """Lowest world y of the head silhouette (forehead/nose when bowed)."""
    m = head_m(pose)
    yaw = pose.get('head', {}).get('yaw', -64)
    return max(G.apply(m, p)[1] for p in skin_outline(yaw))


def base(root):
    return {'root': list(root), 'parts': {}, 'head': {'yaw': -58, 'eyes': 0.0, 'smile': 0.6}, 'skirt': {}}


def set_part(pose, name, **kv):
    pose['parts'].setdefault(name, {}).update(kv)


def skirt_to(pose, targets):
    """Store skirt offsets so control point i lands at world targets[i]."""
    pose['skirt'] = {}
    pts = skirt_points(pose, clamp=False)
    for i, t in targets.items():
        pose['skirt'][str(i)] = (t[0] - pts[i][0], t[1] - pts[i][1])


# ------------------------------------------------------------------ standing family
def upright(head_r=-13, neck_r=-4, yaw=-58):
    pose = base((X0, FLOOR_Y - 478))
    set_part(pose, 'torso', r=-1)
    set_part(pose, 'neck', r=neck_r)
    set_part(pose, 'head', r=head_r)
    pose['head']['yaw'] = yaw
    for side in ('near', 'far'):
        set_part(pose, side + '_foot', v='flat')
    return pose


def rising():
    pose = upright()
    for side, k in (('near', 0), ('far', 2)):
        set_part(pose, side + '_upper_arm', r=5 + k)
        set_part(pose, side + '_forearm', r=9 + k / 2)
        set_part(pose, side + '_hand', r=4, v='relaxed')
    return pose


def standing():
    pose = upright(head_r=-15)
    # left (near) forearm across the chest, right (far) hand over the left wrist
    ik(pose, 'near_arm', (X0 - 74, FLOOR_Y - 740), bend=-1, sy2=0.66)
    set_world_rot(pose, 'near_hand', 86)
    set_part(pose, 'near_hand', v='clasp')
    ik(pose, 'far_arm', (X0 - 96, FLOOR_Y - 752), bend=-1, sy2=0.64)
    set_world_rot(pose, 'far_hand', 86)
    set_part(pose, 'far_hand', v='none')
    return pose


def takbir():
    pose = upright(head_r=-8)
    # elbows forward under the chin, forearms up, open palms by the ears
    # the elbows swing out to the sides, so in side view the upper arm is
    # foreshortened and the elbow sits just below the shoulder
    for bend in (1, -1):
        ik(pose, 'near_arm', (X0 - 18, FLOOR_Y - 948), bend=bend, sy1=0.6, sy2=0.9)
        if wp(pose, 'near_forearm', B.ELBOW)[1] > FLOOR_Y - 852:
            break
    set_world_rot(pose, 'near_hand', -172)
    set_part(pose, 'near_hand', v='open')
    for bend in (1, -1):
        ik(pose, 'far_arm', (X0 - 70, FLOOR_Y - 950), bend=bend, sy1=0.62, sy2=0.9)
        if wp(pose, 'far_forearm', B.ELBOW)[1] > FLOOR_Y - 852:
            break
    set_world_rot(pose, 'far_hand', -168)
    set_part(pose, 'far_hand', v='open')
    return pose


def bowing():
    pose = base((X0 + 46, FLOOR_Y - 470))
    set_part(pose, 'torso', r=-92)
    set_part(pose, 'neck', r=-2)
    set_part(pose, 'head', r=6)
    for side in ('near', 'far'):
        set_part(pose, side + '_foot', v='flat')
    # legs: ankles stay where they were when standing
    ik(pose, 'near_leg', (X0 + 6, FLOOR_Y - 62), bend=1)
    ik(pose, 'far_leg', (X0 + 6 + B.FAR_LEG[0], FLOOR_Y - 62 + B.FAR_LEG[1]), bend=1)
    for side in ('near', 'far'):
        set_world_rot(pose, side + '_foot', 0)
    knee = wp(pose, 'near_shin', (-26, -262))
    ik(pose, 'near_arm', (knee[0] + 4, knee[1] - 24), bend=1)
    set_world_rot(pose, 'near_hand', 6)
    set_part(pose, 'near_hand', v='grip')
    fknee = wp(pose, 'far_shin', (-26, -262))
    ik(pose, 'far_arm', (fknee[0] + 4, fknee[1] - 26), bend=1)
    set_world_rot(pose, 'far_hand', 6)
    set_part(pose, 'far_hand', v='grip')
    return pose


# ------------------------------------------------------------------ floor family
def kneel_legs(pose, thigh_w, shin_w, near_foot='laid'):
    for side in ('near', 'far'):
        set_world_rot(pose, side + '_thigh', thigh_w)
        set_world_rot(pose, side + '_shin', shin_w)
    if near_foot == 'laid':
        set_world_rot(pose, 'near_foot', 180)
        set_part(pose, 'near_foot', v='flat')
    else:
        set_world_rot(pose, 'near_foot', shin_w + 4)
        set_part(pose, 'near_foot', v='tuck')
    set_world_rot(pose, 'far_foot', shin_w + 4)
    set_part(pose, 'far_foot', v='tuck')


def prostrating():
    pose = base((X0 + 30, FLOOR_Y - 250))
    pose['head']['yaw'] = -62
    kneel_legs(pose, 10, -100, near_foot='tuck')
    ground(pose)
    set_part(pose, 'neck', r=14)
    set_part(pose, 'head', r=16)
    # a child's back rounds in sujood; a slightly shorter torso reads that way
    set_part(pose, 'torso', sy=0.9)
    # tip the torso until the forehead and nose rest on the mat
    lo, hi = -150.0, -95.0
    for _ in range(40):
        mid = (lo + hi) / 2
        set_part(pose, 'torso', r=mid)
        if head_low(pose) > FLOOR_Y:
            lo = mid
        else:
            hi = mid
    set_part(pose, 'torso', r=hi)
    # palms flat beside the head, elbows lifted
    hc = head_point(pose, (0, 0))
    # the near arm tucks behind the head (as in the reference) so the face reads
    ik(pose, 'near_arm', (hc[0] - 40, FLOOR_Y - 22), bend=1)
    set_world_rot(pose, 'near_hand', 88)
    set_part(pose, 'near_hand', v='flat', z=57)
    set_part(pose, 'near_upper_arm', z=55)
    set_part(pose, 'near_forearm', z=56)
    ik(pose, 'far_arm', (hc[0] - 40 + B.FAR_ARM[0], FLOOR_Y - 22 + B.FAR_LEG[1]), bend=1)
    set_world_rot(pose, 'far_hand', 88)
    set_part(pose, 'far_hand', v='flat')
    return pose


def sitting_base(torso_r=-5, head_r=-15, yaw=-58):
    pose = base((X0 + 70, FLOOR_Y - 170))
    kneel_legs(pose, 74, -94, near_foot='laid')
    for side in ('near', 'far'):
        set_part(pose, side + '_thigh', sy=1.22)
    # cheat: a longer far shin puts the upright right foot behind the seat
    set_part(pose, 'far_shin', sy=1.3)
    ground(pose)
    set_part(pose, 'torso', r=torso_r)
    set_part(pose, 'neck', r=-4)
    set_part(pose, 'head', r=head_r)
    pose['head']['yaw'] = yaw
    # hands resting on the thighs
    knee = wp(pose, 'near_shin', (-6, -262))
    ik(pose, 'near_arm', (knee[0] + 58, knee[1] - 66), bend=-1)
    set_world_rot(pose, 'near_hand', 100)
    set_part(pose, 'near_hand', v='flat')
    fknee = wp(pose, 'far_shin', (-6, -262))
    ik(pose, 'far_arm', (fknee[0] + 50, fknee[1] - 66), bend=-1)
    set_world_rot(pose, 'far_hand', 98)
    set_part(pose, 'far_hand', v='flat')
    sit_skirt(pose)
    return pose


def sit_skirt(pose):
    M = world_matrices(pose)
    kn = G.apply(M['far_shin'], (-6, -262))
    hip = G.apply(M['root'], B.HIP)
    skirt_to(pose, {
        2: (G.lerp(hip[0], kn[0], 0.5), kn[1] - 112),
        3: (kn[0] + 10, kn[1] - 100),
        4: (kn[0] - 30, kn[1] - 58),
        5: (kn[0] + 64, kn[1] - 44),
        6: (G.lerp(hip[0], kn[0], 0.3), kn[1] - 34),
        7: (hip[0] + 92, FLOOR_Y - 58),
        8: (hip[0] + 118, hip[1] + 6),
    })


def sitting():
    return sitting_base()


def tashahhud():
    pose = sitting_base(head_r=-10)
    set_part(pose, 'far_hand', v='point')
    set_world_rot(pose, 'far_hand', 80)
    return pose


def salam_right():
    pose = sitting_base(head_r=-2, yaw=-150)
    pose['head']['eyes'] = 0.6
    return pose


def salam_left():
    pose = sitting_base(head_r=-2, yaw=-16)
    pose['head']['eyes'] = 1.0
    pose['head']['smile'] = 1.0
    return pose


def after():
    pose = sitting_base(head_r=-10, yaw=-60)
    pose['head']['smile'] = 0.9
    hc = head_point(pose, (0, 0))
    ik(pose, 'near_arm', (hc[0] - 150, hc[1] + 210), bend=-1)
    set_world_rot(pose, 'near_hand', 150)
    set_part(pose, 'near_hand', v='cup')
    ik(pose, 'far_arm', (hc[0] - 170, hc[1] + 214), bend=-1)
    set_world_rot(pose, 'far_hand', 150)
    set_part(pose, 'far_hand', v='cup')
    return pose


# ------------------------------------------------------------------ breakdowns
# In-between keys used inside a transition (not held postures).
def kneel_down():
    """High kneel on the way down to prostration: knees land, hands reach."""
    pose = base((X0, FLOOR_Y - 300))
    kneel_legs(pose, 6, -100, near_foot='tuck')
    ground(pose)
    set_part(pose, 'torso', r=-34)
    set_part(pose, 'neck', r=-2)
    set_part(pose, 'head', r=-14)
    for side, k in (('near', 0), ('far', 4)):
        set_part(pose, side + '_upper_arm', r=46 + k)
        set_part(pose, side + '_forearm', r=34)
        set_part(pose, side + '_hand', r=30, v='relaxed')
    return pose


def kneel_up():
    """High kneel between sitting and standing: thighs upright, toes tucked."""
    pose = base((X0, FLOOR_Y - 300))
    kneel_legs(pose, 0, -98, near_foot='tuck')
    ground(pose)
    set_part(pose, 'torso', r=-8)
    set_part(pose, 'neck', r=-4)
    set_part(pose, 'head', r=-14)
    for side, k in (('near', 0), ('far', 3)):
        set_part(pose, side + '_upper_arm', r=14 + k)
        set_part(pose, side + '_forearm', r=40)
        set_part(pose, side + '_hand', r=30)
    return pose


def squat():
    """Knees bent forward over planted feet, reaching toward the mat."""
    pose = base((X0, FLOOR_Y - 300))
    set_world_rot(pose, 'near_thigh', 62)
    set_world_rot(pose, 'far_thigh', 62)
    set_world_rot(pose, 'near_shin', -30)
    set_world_rot(pose, 'far_shin', -30)
    for side in ('near', 'far'):
        set_world_rot(pose, side + '_foot', -14)
        set_part(pose, side + '_foot', v='flat')
    ground(pose)
    set_part(pose, 'torso', r=-42)
    set_part(pose, 'neck', r=-2)
    set_part(pose, 'head', r=-10)
    for side, k in (('near', 0), ('far', 4)):
        set_part(pose, side + '_upper_arm', r=40 + k)
        set_part(pose, side + '_forearm', r=26)
        set_part(pose, side + '_hand', r=24, v='relaxed')
    # feet planted where they stood
    ball = wp(pose, 'near_foot', (-62, 1))
    pose['root'][0] += (X0 - 70.0) - ball[0]
    return pose


BREAKDOWNS = {'kneelDown': kneel_down, 'kneelUp': kneel_up, 'squat': squat}
# breakdowns that keep their own placement (not aligned on the knee)
FREE_PLACED = ('squat',)

# transition -> list of (breakdown pose, time within the transition 0..1)
VIA = {
    ('rising', 'prostrating'): [('squat', 0.32), ('kneelDown', 0.62)],
    ('sitting', 'standing'): [('kneelUp', 0.36), ('squat', 0.7)],
    ('standing', 'tashahhud'): [('squat', 0.3), ('kneelUp', 0.64)],
}

BUILDERS = {
    'standing': standing, 'takbir': takbir, 'bowing': bowing, 'rising': rising,
    'prostrating': prostrating, 'sitting': sitting, 'tashahhud': tashahhud,
    'salamRight': salam_right, 'salamLeft': salam_left, 'after': after,
}

SEQUENCE = ['standing', 'takbir', 'standing', 'bowing', 'rising', 'prostrating', 'sitting',
            'prostrating', 'sitting', 'standing', 'tashahhud', 'salamRight', 'salamLeft', 'after']


def _clean(pose):
    out = {'root': [round(v, 2) for v in pose['root']], 'parts': {}, 'head': pose['head'], 'skirt': {}}
    if pose.get('breakdown'):
        out['breakdown'] = True
    for k, v in pose['parts'].items():
        out['parts'][k] = {kk: (round(vv, 3) if isinstance(vv, float) else vv) for kk, vv in v.items()}
    for k, v in pose.get('skirt', {}).items():
        out['skirt'][k] = [round(v[0], 2), round(v[1], 2)]
    return out


def align_knees(pose):
    k = wp(pose, 'near_shin', B.KNEE)
    pose['root'][0] += KNEE_X - k[0]
    return pose


def build():
    poses = {}
    for name, fn in list(BUILDERS.items()) + list(BREAKDOWNS.items()):
        pose = fn()
        if name not in STANDING_FAMILY and name not in FREE_PLACED:
            align_knees(pose)
        if name in BREAKDOWNS:
            pose['breakdown'] = True
        poses[name] = _clean(pose)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'poses.json'), 'w') as f:
        json.dump(poses, f, indent=1)
    return poses


POSES = build()
