import SwiftUI

/// The drawing that goes with the timer's moment, with the move's word above and the tip below.
struct ExerciseFigure: View {
    enum Mode: Equatable {
        /// The marcha, looping on its own (before starting, and during its minute).
        case loop
        /// A change: the next drill's first pose, held.
        case ready(Fig)
        /// A drill following the routine's clock.
        case guided(step: Int)
    }

    let fig: Fig
    let mode: Mode
    /// Seconds into the routine at a given moment; nil before starting.
    let elapsed: (Date) -> Double?
    let moving: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineView(.animation(paused: !animates)) { t in
                let frame = self.frame(at: t.date)
                VStack(alignment: .leading, spacing: 0) {
                    Text(frame.label)
                        .font(.display(18, relativeTo: .headline, weight: .bold))
                        .foregroundStyle(.ink)
                        .frame(minHeight: 22, alignment: .leading)
                    FigureCanvas(spec: FigSpec.of(fig), params: frame.params, trails: frame.trails)
                        .aspectRatio(2, contentMode: .fit)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle().fill(Color.sky).frame(width: 10, height: 10)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(fig.tip)
                    .font(.reading(16, relativeTo: .subheadline).bold())
                    .foregroundStyle(.ink)
                    // Always two lines, so the buttons below never jump between drills.
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.surface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var animates: Bool {
        guard !reduceMotion else { return false }
        switch mode {
        case .loop: return true
        case .ready: return false
        case .guided: return moving
        }
    }

    private struct Frame {
        var params: FigParams
        var label: String
        var trails: Double
    }

    private func frame(at date: Date) -> Frame {
        let spec = FigSpec.of(fig)
        if case .ready = mode { return Frame(params: spec.start, label: "Prepárate", trails: 0) }
        if reduceMotion { return Frame(params: spec.still, label: "Así se hace", trails: 1) }
        switch mode {
        case .loop:
            return Frame(params: FigMotion.march(date.timeIntervalSinceReferenceDate), label: "Sube una rodilla, luego la otra", trails: 0)
        case let .guided(i):
            guard let plan = GuidePlan(step: i), let el = elapsed(date) else {
                return Frame(params: spec.still, label: "Así se hace", trails: 1)
            }
            let t = el - Runs.stepStart(Exercise.runSteps, i) - plan.guide.lead
            guard t >= 0 else { return Frame(params: spec.start, label: "Prepárate", trails: 1) }
            let rep = Int(t / plan.cycle), tc = t - Double(rep) * plan.cycle
            var p = FigMotion.rep(fig, plan.d, min(tc, plan.cycle), start: spec.start)
            if plan.guide.sides { p.side = rep % 2 == 1 ? -1 : 1 }
            return Frame(params: p, label: plan.guide.phases[plan.phase(at: tc)].word, trails: 1)
        case .ready:
            return Frame(params: spec.start, label: "Prepárate", trails: 0)
        }
    }
}

/// The pictogram itself: floor, chair, dotted paths, far limbs, body, head, near limbs.
private struct FigureCanvas: View {
    let spec: FigSpec
    let params: FigParams
    /// How much the dotted paths show, 0…1.
    let trails: Double

    var body: some View {
        Canvas { ctx, size in
            let v = spec.view
            let k = size.width / v.w
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -v.x, y: -v.y)
            draw(&ctx)
        }
        .accessibilityHidden(true)
    }

    private func line(_ pts: [FigGeo.P]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: CGPoint(x: first.x, y: first.y))
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.x, y: q.y)) }
        return p
    }

    private func round(_ w: Double) -> StrokeStyle { StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }

    private func draw(_ ctx: inout GraphicsContext) {
        typealias G = FigGeo
        let v = spec.view, f = spec.pose(params), d = spec.far
        ctx.stroke(line([G.P(v.x + 6, G.floorY), G.P(v.x + v.w - 6, G.floorY)]), with: .color(.floor), style: round(3))
        if let b = spec.back {
            ctx.stroke(line([G.P(b.0, G.floorY), G.P(b.1, G.floorY)]), with: .color(.sky), style: round(3))
        }
        if let c = spec.chair {
            let bottom = 116 - G.w.chair / 2
            let chair = round(G.w.chair)
            ctx.stroke(line([G.P(c.x0 + 2, c.y), G.P(c.x0 + 2, bottom)]), with: .color(.chair), style: chair)
            ctx.stroke(line([G.P(c.x1 - 2, c.y), G.P(c.x1 - 2, bottom)]), with: .color(.chair), style: chair)
            ctx.stroke(line([G.P(c.backAt, c.y), G.P(c.backAt, c.back)]), with: .color(.chair), style: chair)
            ctx.stroke(line([G.P(c.x0, c.y), G.P(c.x1, c.y)]), with: .color(f.seatOn > 0.5 ? .sky : .chair), style: chair)
        }
        // The dotted paths follow the limbs that move on this side.
        if trails > 0 {
            for (i, fn) in f.trails.enumerated() {
                let far = f.moving.contains(i == 0 ? .farArm : .farLeg)
                let pts = (0...24).map { j in fn(Double(j) / 24) + (far ? d : .zero) }
                var c = ctx
                c.opacity = trails * 0.7
                c.stroke(line(pts), with: .color(.sky), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [0, 5.5]))
            }
        }
        func limb(_ pts: [G.P]?, _ w: Double, near: Bool, moving: Bool) {
            guard let pts, pts.count > 1 else { return }
            let path = line(pts)
            if near { ctx.stroke(path, with: .color(.surface), style: round(w + G.w.gap)) }
            var c = ctx
            if !near { c.opacity = moving ? 0.5 : 0.3 }
            c.stroke(path, with: .color(moving ? .sky : .ink), style: round(w))
        }
        let farLeg = f.farLeg.shifted(d)
        limb(farLeg.pts, G.w.leg, near: false, moving: f.moving.contains(.farLeg))
        limb(farLeg.foot, G.w.foot, near: false, moving: f.moving.contains(.farLeg))
        limb(f.farArm?.map { $0 + d }, G.w.arm, near: false, moving: f.moving.contains(.farArm))
        ctx.stroke(line([f.s, f.h]), with: .color(.ink), style: round(G.w.torso))
        // Breathing: the belly fills (a little thicker, tinted blue) and empties, still resting on the floor.
        if let breath = f.breath {
            let grow = 3 * breath, y = f.s.y - grow / 2
            let belly = line([G.P(G.lerp(f.s.x, f.h.x, 0.35), y), G.P(G.lerp(f.s.x, f.h.x, 0.85), y)])
            ctx.stroke(belly, with: .color(.ink), style: round(G.w.torso + grow))
            var c = ctx
            c.opacity = 0.45 * breath
            c.stroke(belly, with: .color(.sky), style: round(G.w.torso + grow))
        }
        let ko = G.w.head + G.w.gap / 2
        ctx.fill(Path(ellipseIn: CGRect(x: f.head.x - ko, y: f.head.y - ko, width: 2 * ko, height: 2 * ko)), with: .color(.surface))
        ctx.fill(Path(ellipseIn: CGRect(x: f.head.x - G.w.head, y: f.head.y - G.w.head, width: 2 * G.w.head, height: 2 * G.w.head)), with: .color(.ink))
        limb(f.nearLeg.pts, G.w.leg, near: true, moving: f.moving.contains(.nearLeg))
        limb(f.nearLeg.foot, G.w.foot, near: true, moving: f.moving.contains(.nearLeg))
        limb(f.nearArm, G.w.arm, near: true, moving: f.moving.contains(.nearArm))
    }
}
