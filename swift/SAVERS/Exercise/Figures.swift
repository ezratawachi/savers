import Foundation

/// The exercise pictograms: round strokes, jointed, the same geometry as the web.
/// Angles are degrees from straight up, clockwise; every joint comes from the one before it.
enum FigGeo {
    typealias P = SIMD2<Double>

    static let floorY = 117.5
    static let w = (torso: 17.0, arm: 8.5, leg: 10.5, foot: 8.0, head: 10.5, chair: 5.0, gap: 4.5)
    static let l = (torso: 66.0, neck: 25.0, upper: 25.0, fore: 23.0, thigh: 38.0, shin: 36.0, foot: 11.0)
    static let onFloor = (torso: 116 - w.torso / 2, arm: 116 - w.arm / 2, leg: 116 - w.leg / 2, foot: 116 - w.foot / 2, head: 116 - w.head)

    static func pt(_ o: P, _ len: Double, _ deg: Double) -> P {
        let r = deg * .pi / 180
        return P(o.x + len * sin(r), o.y - len * cos(r))
    }

    static func ang(_ a: P, _ b: P) -> Double { atan2(b.x - a.x, a.y - b.y) * 180 / .pi }

    static func lerp(_ a: Double, _ b: Double, _ k: Double) -> Double { a + (b - a) * k }

    /// The knee between a fixed hip and ankle, bent forward (or up, lying down).
    static func ik(_ a: P, _ c: P, _ l1: Double, _ l2: Double) -> P {
        let d = min(hypot(c.x - a.x, c.y - a.y), l1 + l2 - 0.01)
        let cosv = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
        return pt(a, l1, ang(a, c) - acos(max(-1, min(1, cosv))) * 180 / .pi)
    }

    static func arm(_ s: P, _ a: Double, _ bend: Double = 0) -> [P] {
        let e = pt(s, l.upper, a)
        return [s, e, pt(e, l.fore, a + bend)]
    }

    struct Leg {
        var pts: [P]
        var foot: [P]?

        func shifted(_ d: P) -> Leg { Leg(pts: pts.map { $0 + d }, foot: foot?.map { $0 + d }) }
    }

    static func legFK(_ h: P, _ t: Double, _ sAbs: Double, _ fAbs: Double? = nil) -> Leg {
        let k = pt(h, l.thigh, t), an = pt(k, l.shin, sAbs)
        return Leg(pts: [h, k, an], foot: fAbs.map { [an, pt(an, l.foot, $0)] })
    }

    static func legIK(_ h: P, _ an: P, _ toe: P?) -> Leg {
        Leg(pts: [h, ik(h, an, l.thigh, l.shin), an], foot: toe.map { [an, $0] })
    }

    // The top of the bridge: where shoulders, hips and knees line up.
    static let bridgeS = P(92, onFloor.torso), bridgeA = P(206, onFloor.foot - 2)
    static let bridgeTop: Double = {
        var best = 1e9, top = 0.0
        for a in stride(from: 0.0, through: 45, by: 0.25) {
            let h = pt(bridgeS, l.torso, 90 - a), k = ik(h, bridgeA, l.thigh, l.shin)
            let d = abs(ang(bridgeS, h) - ang(h, k))
            if d < best { best = d; top = a }
        }
        return top
    }()

    // The squat's hip goes back first, then down, until it reaches the seat.
    static let squatTop = P(158, 37), squatLow = P(124, 80)
    static func squatHip(_ k: Double) -> P {
        P(lerp(squatTop.x, squatLow.x, pow(k, 0.8)), lerp(squatTop.y, squatLow.y, pow(k, 1.25)))
    }

    static func armOnFloor(_ s: P) -> [P] { arm(s, ang(s, P(s.x + 47.8, onFloor.arm))) }
}

/// Where a pictogram's joints are at one moment.
struct FigPose {
    enum Limb { case nearArm, farArm, nearLeg, farLeg }

    var s: FigGeo.P
    var h: FigGeo.P
    var head: FigGeo.P
    var nearArm: [FigGeo.P]?
    var farArm: [FigGeo.P]?
    var nearLeg: FigGeo.Leg
    var farLeg: FigGeo.Leg
    var moving: Set<Limb> = []
    /// Hand and foot paths of the moving pair, 0…1.
    var trails: [(Double) -> FigGeo.P] = []
    var seatOn = 0.0
    var breath: Double?
}

/// The numbers that move a pictogram.
struct FigParams {
    var lift = 0.0, side = 1.0
    var arm = 0.0, thigh = 0.0, shin = 0.0
    var down = 0.0, touch = 0.0, breath = 0.0
}

/// What a figure looks like and how it moves.
struct FigSpec {
    /// x, y, width of the view box; its height is half the width.
    var view: (x: Double, y: Double, w: Double)
    /// How far the far limbs sit from the near ones.
    var far: FigGeo.P
    /// A sky stretch of floor under the lower back.
    var back: (Double, Double)?
    var chair: (x0: Double, x1: Double, y: Double, back: Double, backAt: Double)?
    var start: FigParams
    var still: FigParams
    var pose: (FigParams) -> FigPose

    static func of(_ fig: Fig) -> FigSpec {
        typealias G = FigGeo
        typealias P = G.P
        switch fig {
        case .marcha:
            return FigSpec(view: (-36, -66, 372), far: P(4, 0), start: FigParams(lift: 0, side: 1), still: FigParams(lift: 1, side: 1)) { p in
                let h = P(150, 36.5), s = G.pt(h, G.l.torso, 2), head = G.pt(s, G.l.neck, 2)
                let stand = G.legIK(h, P(150, G.onFloor.foot - 1.5), P(150 + G.l.foot, G.onFloor.foot))
                let up = G.legFK(h, 180 - 82 * p.lift, 180, 90 + 30 * p.lift)
                // The arm opposite the knee swings forward.
                let fw = 180 - 34 * p.lift, bk = 180 + 26 * p.lift
                let a = p.side == 1
                return FigPose(s: s, h: h, head: head,
                               nearArm: G.arm(s, a ? bk : fw, a ? 10 * p.lift : -80 * p.lift),
                               farArm: G.arm(s, a ? fw : bk, a ? -80 * p.lift : 10 * p.lift),
                               nearLeg: a ? up : stand, farLeg: a ? stand : up,
                               moving: a ? [.nearLeg, .farArm] : [.farLeg, .nearArm])
            }
        case .birddog:
            return FigSpec(view: (36, 20, 210), far: P(4, 0), start: FigParams(side: 1, arm: 180, thigh: 180), still: FigParams(side: 1, arm: 86, thigh: 270)) { p in
                let k = P(118, G.onFloor.leg), h = P(118, k.y - G.l.thigh), sy = G.onFloor.arm - G.l.upper - G.l.fore
                let s = P(h.x + (G.l.torso * G.l.torso - pow(h.y - sy, 2)).squareRoot(), sy), head = G.pt(s, G.l.neck, G.ang(h, s))
                let a = p.side == 1, move = G.arm(s, p.arm), rest = G.arm(s, 180)
                let legMove = G.legFK(h, p.thigh, 270), legRest = G.legFK(h, 180, 270)
                return FigPose(s: s, h: h, head: head, nearArm: a ? move : rest, farArm: a ? rest : move,
                               nearLeg: a ? legRest : legMove, farLeg: a ? legMove : legRest,
                               moving: a ? [.nearArm, .farLeg] : [.farArm, .nearLeg],
                               trails: [{ G.arm(s, G.lerp(180, 86, $0))[2] }, { G.legFK(h, G.lerp(180, 270, $0), 270).pts[2] }])
            }
        case .deadbug:
            return FigSpec(view: (22, 6, 236), far: P(5, -3.5), back: (120, 148), start: FigParams(side: 1), still: FigParams(side: 1, arm: -86, thigh: 80, shin: -90)) { p in
                let s = P(88, G.onFloor.torso), h = P(154, G.onFloor.torso), head = P(s.x - G.l.neck, G.onFloor.head)
                let a = p.side == 1, up = G.legFK(h, 0, 90), down = G.legFK(h, p.thigh, 90 + p.thigh + p.shin)
                return FigPose(s: s, h: h, head: head, nearArm: G.arm(s, a ? p.arm : 0), farArm: G.arm(s, a ? 0 : p.arm),
                               nearLeg: a ? up : down, farLeg: a ? down : up,
                               moving: a ? [.nearArm, .farLeg] : [.farArm, .nearLeg],
                               trails: [{ G.arm(s, -86 * $0)[2] }, { G.legFK(h, 80 * $0, 90 - 10 * $0).pts[2] }])
            }
        case .puente:
            return FigSpec(view: (40, 24, 200), far: P(4, 0), start: FigParams(lift: 0), still: FigParams(lift: 1)) { p in
                let s = G.bridgeS, an = G.bridgeA, toe = P(an.x + G.l.foot, G.onFloor.foot)
                let h = G.pt(s, G.l.torso, 90 - G.bridgeTop * p.lift)
                let leg = G.legIK(h, an, toe)
                // The arms rest on the floor behind the body.
                return FigPose(s: s, h: h, head: P(s.x - G.l.neck, G.onFloor.head), nearArm: nil, farArm: G.armOnFloor(s),
                               nearLeg: leg, farLeg: leg, trails: [{ G.pt(s, G.l.torso, 90 - G.bridgeTop * $0) }])
            }
        case .sentadilla:
            return FigSpec(view: (-24, -70, 376), far: P(4, 0),
                           chair: (98, 136, G.squatLow.y + G.w.torso / 2 + G.w.chair / 2 + 0.5, 50, 98),
                           start: FigParams(), still: FigParams(down: 1, touch: 1)) { p in
                let an = P(160, G.onFloor.foot - 1.5), toe = P(an.x + G.l.foot + 1, G.onFloor.foot)
                let h = G.squatHip(p.down), lean = 38 * p.down, s = G.pt(h, G.l.torso, lean), a = G.lerp(180, 96, p.down)
                let leg = G.legIK(h, an, toe)
                return FigPose(s: s, h: h, head: G.pt(s, G.l.neck, lean), nearArm: G.arm(s, a), farArm: G.arm(s, a),
                               nearLeg: leg, farLeg: leg, trails: [G.squatHip], seatOn: p.touch)
            }
        case .descanso:
            return FigSpec(view: (36, 22, 200), far: P(4, 0),
                           chair: (164, 204, G.onFloor.torso - G.l.thigh + G.w.leg / 2 + G.w.chair / 2, 40, 204),
                           start: FigParams(), still: FigParams(breath: 1)) { p in
                let s = P(92, G.onFloor.torso), h = P(158, G.onFloor.torso), leg = G.legFK(h, 0, 90, 22)
                return FigPose(s: s, h: h, head: P(s.x - G.l.neck, G.onFloor.head), nearArm: nil, farArm: G.armOnFloor(s),
                               nearLeg: leg, farLeg: leg, breath: p.breath)
            }
        }
    }
}

/// The moves over time: the web's GSAP timelines as plain functions (all `sine.inOut` unless noted).
nonisolated enum FigMotion {
    private struct Tween {
        var start: Double
        var dur: Double
        var from: Double
        var to: Double
        var ease: (Double) -> Double = FigMotion.sineInOut
    }

    static func sineInOut(_ x: Double) -> Double { -(cos(.pi * x) - 1) / 2 }
    static func sineOut(_ x: Double) -> Double { sin(x * .pi / 2) }
    static func sineIn(_ x: Double) -> Double { 1 - cos(x * .pi / 2) }
    /// GSAP's default ease.
    static func power1Out(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }

    /// A value moved by tweens in order: the last one that started decides.
    private static func value(_ t: Double, _ initial: Double, _ tweens: [Tween]) -> Double {
        var v = initial
        for tw in tweens where t >= tw.start {
            let k = tw.dur <= 0 ? 1 : min(1, (t - tw.start) / tw.dur)
            v = tw.from + (tw.to - tw.from) * tw.ease(k)
        }
        return v
    }

    /// One rep of a guided drill (one side), `t` seconds in; `d` are the plan's phase lengths.
    static func rep(_ fig: Fig, _ d: [Double], _ t: Double, start: FigParams) -> FigParams {
        var p = start
        switch fig {
        case .birddog:
            let back = d[0] + d[1]
            p.arm = value(t, 180, [Tween(start: 0, dur: d[0], from: 180, to: 86), Tween(start: back, dur: d[2], from: 86, to: 180)])
            p.thigh = value(t, 180, [Tween(start: 0.1, dur: d[0] - 0.1, from: 180, to: 270), Tween(start: back + 0.08, dur: d[2] - 0.08, from: 270, to: 180)])
        case .deadbug:
            p.arm = value(t, 0, [Tween(start: 0, dur: d[0], from: 0, to: -86), Tween(start: d[0], dur: d[1], from: -86, to: 0)])
            let legOut = Tween(start: 0.12, dur: d[0] - 0.12, from: 0, to: 1), legIn = Tween(start: d[0] + 0.1, dur: d[1] - 0.1, from: 1, to: 0)
            let k = value(t, 0, [legOut, legIn])
            p.thigh = 80 * k
            p.shin = -90 * k
        case .puente:
            p.lift = value(t, 0, [Tween(start: 0, dur: d[0], from: 0, to: 1), Tween(start: d[0] + d[1], dur: d[2], from: 1, to: 0)])
        case .sentadilla:
            let tap = min(0.15, d[1] / 2), up = d[0] + d[1]
            p.down = value(t, 0, [Tween(start: 0, dur: d[0], from: 0, to: 1), Tween(start: up, dur: d[2], from: 1, to: 0)])
            p.touch = value(t, 0, [Tween(start: d[0], dur: tap, from: 0, to: 1, ease: power1Out), Tween(start: up, dur: 0.3, from: 1, to: 0, ease: power1Out)])
        case .descanso:
            p.breath = value(t, 0, [Tween(start: 0, dur: d[0], from: 0, to: 1), Tween(start: d[0], dur: d[1], from: 1, to: 0)])
        case .marcha:
            break
        }
        return p
    }

    static let marchLoop = 1.9

    /// The marcha isn't guided: it loops on its own, one knee then the other.
    static func march(_ t: Double) -> FigParams {
        let x = t.truncatingRemainder(dividingBy: marchLoop)
        let half = x < 0.95 ? x : x - 0.95
        let lift = half < 0.5 ? sineOut(half / 0.5) : 1 - sineIn((half - 0.5) / 0.45)
        return FigParams(lift: lift, side: x < 0.95 ? 1 : -1)
    }
}
