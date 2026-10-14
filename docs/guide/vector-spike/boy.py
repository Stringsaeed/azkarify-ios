"""The boy rig: skeleton, parts and their drawings, all in rest coordinates.

Rest pose is standing upright with arms hanging (the 'rising' posture).
Origin is the floor point under the hip, x to the right, y down (so the
figure lives at negative y). The boy faces screen LEFT (-x); the viewer
sees his LEFT side. The far limbs are nudged forward a little (a 3/4
cheat, like the reference paintings) so both feet and hands read.
"""
import math

from geom import spline, fmt, ellipse_d, circle_pts
from shapes import capsule_pts, poly_d, path_el, line, hatch
import style as S

# ---------------------------------------------------------------- skeleton
HIP = (0.0, -478.0)
SHOULDER = (6.0, -852.0)
NECK_BASE = (-16.0, -890.0)
HEAD_PIVOT = (-18.0, -950.0)
HEAD_CENTER = (-34.0, -1030.0)
HEAD_SCALE = 1.13
ELBOW = (12.0, -690.0)
WRIST = (6.0, -534.0)
KNEE = (-6.0, -262.0)
ANKLE = (6.0, -62.0)

# screen-space depth cue for the far limbs (applied after posing)
FAR_ARM = (-24.0, -6.0)
FAR_LEG = (-34.0, -22.0)
FAR_ROOTS = {'far_upper_arm': FAR_ARM, 'far_thigh': FAR_LEG}


def add(p, o):
    return (p[0] + o[0], p[1] + o[1])


# name: (parent, pivot, group, z)
PARTS = {
    'far_upper_arm': ('torso', SHOULDER, 'farArm', 10),
    'far_hand': ('far_forearm', WRIST, 'farArm', 11),
    'far_forearm': ('far_upper_arm', ELBOW, 'farArm', 12),
    'far_foot': ('far_shin', ANKLE, 'farLeg', 19),
    'far_thigh': ('root', HIP, 'farLeg', 20),
    'far_shin': ('far_thigh', KNEE, 'farLeg', 21),
    'near_foot': ('near_shin', ANKLE, 'nearLeg', 29),
    'near_thigh': ('root', HIP, 'nearLeg', 30),
    'near_shin': ('near_thigh', KNEE, 'nearLeg', 31),
    'skirt': ('root', HIP, 'skirt', 40),
    'neck': ('torso', NECK_BASE, 'neck', 45),
    'torso': ('root', HIP, 'torso', 50),
    'head': ('neck', HEAD_PIVOT, 'head', 60),
    'near_upper_arm': ('torso', SHOULDER, 'nearArm', 70),
    'near_hand': ('near_forearm', WRIST, 'nearArm', 71),
    'near_forearm': ('near_upper_arm', ELBOW, 'nearArm', 72),
}

ORDER = ['torso', 'neck', 'head',
         'near_upper_arm', 'near_forearm', 'near_hand',
         'far_upper_arm', 'far_forearm', 'far_hand',
         'near_thigh', 'near_shin', 'near_foot',
         'far_thigh', 'far_shin', 'far_foot', 'skirt']


def pal(far):
    if far:
        return dict(thobe=S.THOBE_FAR, thobe_shade=S.THOBE_FAR_SHADE, trouser=S.TROUSER_FAR,
                    trouser_shade=S.TROUSER_FAR_SHADE, skin=S.SKIN_FAR, skin_shade=S.SKIN_DEEP)
    return dict(thobe=S.THOBE, thobe_shade=S.THOBE_SHADE, trouser=S.TROUSER,
                trouser_shade=S.TROUSER_SHADE, skin=S.SKIN, skin_shade=S.SKIN_SHADE)


def drawing(shape, fill, line_c, over=(), detail=(), edges=(), outline=True):
    return dict(shape=shape, fill=fill, line=line_c, over=list(over), detail=list(detail),
                edges=list(edges), outline=outline)


def shifted(pts, o):
    return [(p[0] + o[0], p[1] + o[1]) + tuple(p[2:]) for p in pts]


# ------------------------------------------------------------------ legs
def thigh(far=False):
    o = (0, 0)
    c = pal(far)
    h, k = add(HIP, o), add(KNEE, o)
    pts = capsule_pts(h, 60, k, 47, n=12)
    shade = [path_el(spline([add(p, o) for p in [(30, -520), (64, -470), (60, -330), (44, -250), (22, -300), (26, -420)]]),
                     fill=c['trouser_shade'], opacity=.9)]
    det = [line([add(p, o) for p in [(-40, -330), (-20, -318), (6, -322)]], S.LINE_TROUSER, 1.3, .5)]
    return drawing(poly_d(pts), c['trouser'], S.LINE_TROUSER, shade, det)


def shin(far=False):
    o = (0, 0)
    c = pal(far)
    kx, ky = add(KNEE, o)
    pts = []
    for i in range(13):
        a = math.radians(8 - (196 * i / 12.0))
        pts.append((kx + 47 * math.cos(a), ky + 47 * math.sin(a)))
    pts += [add(p, o) for p in [(-54, -200), (-54, -140), (-56, -92), (-52, -76), (-20, -71),
                                (14, -71), (46, -74), (56, -80), (54, -140), (48, -220)]]
    shade = [path_el(spline([add(p, o) for p in [(20, -290), (52, -270), (56, -150), (56, -70),
                                                   (30, -60), (26, -150)]]), fill=c['trouser_shade'], opacity=.95),
             hatch(o[0] + 26, o[1] - 230, o[0] + 50, o[1] - 100, 7, 92, 40, S.LINE_TROUSER, 1.0, .28, seed=3)]
    det = [line([add(p, o) for p in [(-40, -96), (-28, -88), (-12, -86)]], S.LINE_TROUSER, 1.3, .55),
           line([add(p, o) for p in [(30, -100), (36, -86), (44, -82)]], S.LINE_TROUSER, 1.2, .5),
           line([add(p, o) for p in [(-26, -250), (-34, -236)]], S.LINE_TROUSER, 1.2, .45)]
    return drawing(poly_d(pts), c['trouser'], S.LINE_TROUSER, shade, det)


FOOT_FLAT = [(26, -112), (34, -60), (38, -34), (34, -10), (22, 0), (-10, 1), (-50, 1), (-82, 0),
             (-96, -2), (-103, -8), (-104, -16), (-98, -21), (-92, -19, 'c'), (-87, -25), (-79, -26),
             (-75, -24, 'c'), (-69, -30), (-61, -32), (-57, -30, 'c'), (-46, -40), (-34, -52),
             (-24, -64), (-22, -112)]
FOOT_TUCK = [(26, -112), (34, -60), (36, -34), (32, -10), (20, 0), (-10, 1), (-44, 1), (-60, 2),
             (-72, -4), (-78, -18), (-79, -36), (-75, -50), (-66, -52), (-58, -44), (-46, -50),
             (-34, -58), (-24, -66), (-22, -112)]


def foot(far=False, var='flat'):
    o = (0, 0)
    c = pal(far)
    base = FOOT_FLAT if var == 'flat' else FOOT_TUCK
    import geom as G
    fk = 1.12
    big = lambda P: [(ANKLE[0] + (p[0] - ANKLE[0]) * fk, ANKLE[1] + (p[1] - ANKLE[1]) * fk) + tuple(p[2:]) for p in P]
    pts = big(base)
    # keep the sole on the floor after scaling about the ankle
    dy = -max(p[1] for p in pts)
    pts = [(p[0], p[1] + dy) + tuple(p[2:]) for p in pts]
    o = (0, dy)
    shp = spline(pts, k=0.9)
    shade = [path_el(ellipse_d(o[0] + 34, o[1] - 20, 22, 28), fill=c['skin_shade'], opacity=.55),
             path_el(spline(shifted([(-90, -2), (-40, 4), (20, 4), (30, -6), (-40, -8)], o)),
                     fill=c['skin_shade'], opacity=.5)]
    det = []
    if var == 'flat':
        for seg in ([(-92, -19), (-95, -7)], [(-75, -24), (-79, -9)], [(-57, -30), (-63, -14)]):
            det.append(line(shifted(big(seg), o), S.LINE_SKIN, 1.4, .6))
    else:
        for ty in (-38, -24):
            det.append(line(shifted([(-78, ty), (-68, ty + 2), (-60, ty - 1)], o), S.LINE_SKIN, 1.4, .5))
    det.append(line(shifted([(10, -70), (14, -62), (10, -54)], o), S.LINE_SKIN, 1.3, .45))
    return drawing(shp, c['skin'], S.LINE_SKIN, shade, det)


# ------------------------------------------------------------------ torso
TORSO = [(-56, -884), (-78, -868), (-94, -836), (-102, -780), (-106, -700), (-108, -620),
         (-110, -540), (-112, -466, 'c'), (100, -466, 'c'), (96, -560), (92, -650), (90, -740),
         (84, -800), (70, -846), (44, -876), (12, -892), (-14, -896)]
TORSO_FRONT = [(-56, -884), (-78, -868), (-94, -836), (-102, -780), (-106, -700), (-108, -620),
               (-110, -540), (-111, -500)]
TORSO_BACK = [(-14, -896), (12, -892), (44, -876), (70, -846), (84, -800), (90, -740), (92, -650),
              (96, -560), (98, -510)]


def torso():
    shp = spline(TORSO, k=0.9)
    over = [
        # back shadow
        path_el(spline([(30, -884), (80, -846), (96, -760), (100, -466), (50, -466), (56, -620), (56, -780)]),
                fill=S.THOBE_SHADE),
        hatch(60, -760, 92, -520, 9, 95, 60, S.LINE_THOBE, 1.0, .22, seed=11),
        # chest/front light
        path_el(spline([(-100, -790), (-86, -830), (-66, -760), (-70, -600), (-100, -540)]), fill=S.THOBE_LIGHT,
                opacity=.8),
        # under-collar shade
        path_el(spline([(-60, -882), (-20, -868), (24, -882), (0, -896)]), fill=S.THOBE_SHADE, opacity=.8),
    ]
    det = [
        # collar band
        path_el(spline([(-60, -882), (-56, -904, 'c'), (-20, -914), (12, -910), (14, -894, 'c'), (-20, -886)]),
                fill=S.THOBE, stroke=S.LINE_THOBE, width=S.LW),
        # placket and buttons
        line([(-74, -870), (-78, -820), (-80, -770)], S.LINE_THOBE, 1.6, .9),
        line([(-60, -874), (-64, -820), (-66, -772)], S.LINE_THOBE, 1.4, .6),
        line([(-80, -770), (-73, -766), (-66, -772)], S.LINE_THOBE, 1.4, .8),
        path_el(ellipse_d(-70, -846, 2.6, 2.6), fill=S.LINE_THOBE, opacity=.65),
        path_el(ellipse_d(-72, -806, 2.6, 2.6), fill=S.LINE_THOBE, opacity=.65),
        # pocket welt
        path_el(spline([(-58, -788, 'c'), (-26, -790, 'c'), (-26, -780, 'c'), (-58, -778, 'c')]),
                stroke=S.LINE_THOBE, width=1.4, opacity=.7),
        # soft folds at the waist
        line([(-96, -540), (-80, -530), (-64, -534)], S.LINE_THOBE, 1.3, .45),
    ]
    edges = [line(TORSO_FRONT, S.LINE_THOBE, S.LW), line(TORSO_BACK, S.LINE_THOBE, S.LW)]
    d = drawing(shp, S.THOBE, S.LINE_THOBE, over, det, edges, outline=False)
    d['fade'] = (-540.0, -474.0)   # dissolve the waist into the skirt below
    return d


def neck():
    pts = capsule_pts((-14, -880), 31, (-20, -975), 31, n=10)
    over = [path_el(spline([(-60, -930), (-20, -905), (24, -930), (24, -870), (-60, -870)]),
                    fill=S.SKIN_SHADE, opacity=.9),
            hatch(-36, -930, 10, -896, 6, 70, 18, S.LINE_SKIN, 1.0, .3, seed=5)]
    return drawing(poly_d(pts), S.SKIN, S.LINE_SKIN, over)


# ------------------------------------------------------------------ arms
def upper_arm(far=False):
    o = (0, 0)
    c = pal(far)
    s, e = add(SHOULDER, o), add(ELBOW, o)
    pts = capsule_pts(s, 43, e, 36, n=12)
    shade = [path_el(spline(shifted([(22, -860), (54, -830), (54, -690), (30, -680), (30, -800)], o)),
                     fill=c['thobe_shade'])]
    edges = [line(shifted([(-34, -830), (-30, -760), (-26, -700)], o), S.LINE_THOBE, S.LW),
             line(shifted([(46, -836), (50, -760), (50, -700)], o), S.LINE_THOBE, S.LW)]
    return drawing(poly_d(pts), c['thobe'], S.LINE_THOBE, shade, [], edges, outline=False)


def forearm(far=False):
    o = (0, 0)
    c = pal(far)
    ex, ey = add(ELBOW, o)
    pts = []
    for i in range(13):
        a = math.radians(-10 - 160 * i / 12.0)
        pts.append((ex + 38 * math.cos(a), ey + 38 * math.sin(a)))
    pts += shifted([(-36, -640), (-40, -580), (-44, -540), (-30, -530), (0, -526), (30, -530),
                    (54, -540), (52, -600), (50, -660)], o)
    shp = spline(pts, k=0.7)
    cuff = shifted([(-44, -542), (-20, -534), (10, -532), (40, -536), (54, -544)], o)
    shade = [path_el(spline(shifted([(24, -700), (52, -680), (58, -540), (34, -536), (30, -620)], o)),
                     fill=c['thobe_shade']),
             hatch(o[0] + 28, o[1] - 650, o[0] + 52, o[1] - 560, 5, 100, 34, S.LINE_THOBE, 1.0, .22, seed=7)]
    det = [line(cuff, S.LINE_THOBE, 1.5, .8),
           line(shifted([(-30, -600), (-14, -588), (2, -592)], o), S.LINE_THOBE, 1.2, .4)]
    return drawing(shp, c['thobe'], S.LINE_THOBE, shade, det)


HAND_SCALE = 1.12


def hand(far=False, var='relaxed'):
    import hands as HD
    import geom as G
    spec = HD.HANDS.get(var or 'relaxed', HD.HANDS['relaxed'])
    c = pal(far)
    if not spec['pts']:
        return drawing('', c['skin'], S.LINE_SKIN, outline=False)
    m = G.mul(G.translate(*WRIST), G.mul(G.rotate(-spec['rot']), G.scale(HAND_SCALE)))
    tf = lambda P: [G.apply(m, p) for p in P]
    shp = spline(tf(spec['pts']), k=0.85)
    shade = [path_el(spline(tf(spec['shade'])), fill=c['skin_shade'], opacity=.75)] if spec.get('shade') else []
    det = [line(tf(seg), S.LINE_SKIN, 1.5, .65) for seg in spec.get('lines', [])]
    top = spec.get('top')
    if top:
        tshp = spline(tf(top['pts']), k=0.85)
        cid = 'clasp-top-%d' % int(far)
        det.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
            tshp, c['skin'], S.LINE_SKIN, S.LW))
        det.append('<clipPath id="%s"><path d="%s"/></clipPath><g clip-path="url(#%s)">%s</g>' % (
            cid, tshp, cid, path_el(spline(tf(top['shade'])), fill=c['skin_shade'], opacity=.7)))
        det += [line(tf(seg), S.LINE_SKIN, 1.5, .65) for seg in top.get('lines', [])]
    return drawing(shp, c['skin'], S.LINE_SKIN, shade, det)


# ------------------------------------------------------------------ skirt
# Skinned control points: (rest x, rest y, {bone: weight}, corner?)
SKIRT = [
    ((-110, -560), {'torso': 1.0}, True),
    ((-111, -480), {'torso': 0.55, 'far_thigh': 0.45}, False),
    ((-114, -390), {'far_thigh': 1.0}, False),
    ((-116, -300), {'far_thigh': 1.0}, False),
    ((-120, -244), {'far_thigh': 1.0}, True),
    ((-50, -238), {'far_thigh': 0.6, 'near_thigh': 0.4}, False),
    ((16, -240), {'near_thigh': 0.6, 'root': 0.4}, False),
    ((116, -248), {'root': 1.0}, True),
    ((112, -330), {'root': 1.0}, False),
    ((104, -420), {'root': 0.6, 'torso': 0.4}, False),
    ((98, -500), {'torso': 1.0}, False),
    ((96, -560), {'torso': 1.0}, True),
]
SKIRT_SLIT = 6     # the hem point where the side slit opens (index into SKIRT)
