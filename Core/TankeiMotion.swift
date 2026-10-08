import Foundation

/// Continuous, bounded motion samples. No timer, randomness, or persisted learning state.
struct TankeiFrame: Equatable {
    var lift: CGFloat = 0
    var squash: CGFloat = 0
    var wing: Double = 0
    var nod: Double = 0
    var eyeScale: CGFloat = 1
    var tail: Double = 0
    var sway: Double = 0
    var burst: CGFloat = 0
    var gaze: CGFloat = 0

    func adding(_ other: TankeiFrame) -> TankeiFrame {
        TankeiFrame(lift: lift + other.lift, squash: squash + other.squash,
                    wing: wing + other.wing, nod: nod + other.nod,
                    eyeScale: eyeScale * other.eyeScale, tail: tail + other.tail,
                     sway: sway + other.sway, burst: burst + other.burst, gaze: gaze + other.gaze)
    }

    static func ambient(at time: TimeInterval, resting: Bool = false, expressive: Bool = false) -> TankeiFrame {
        guard time.isFinite else { return TankeiFrame() }
        let time = max(0, time)
        let breath = sin(time * 2 * .pi / 3.8)
        let blinkPhase = (time + 2.4).truncatingRemainder(dividingBy: 6.8)
        let blink = !resting && blinkPhase < 0.22 ? (1 - cos(blinkPhase / 0.22 * 2 * .pi)) / 2 : 0
        let energy = expressive ? 3.0 : 1.0
        return TankeiFrame(lift: -0.9 * energy * (1 - cos(time * 2 * .pi / 3.8)), squash: 0.007 * energy * breath,
                           wing: 1.8 * energy * sin(time * 2 * .pi / 4.2), nod: 0.7 * energy * sin(time * 2 * .pi / 5.7),
                           eyeScale: 1 - 0.88 * blink, tail: 2.5 * energy * sin(time * 2 * .pi / 4.6),
                           sway: 0.45 * energy * sin(time * 2 * .pi / 6))
    }
}

enum TankeiMotionPolicy {
    static func allowsMotion(requested: Bool, reduceMotion: Bool, lowPower: Bool,
                             active: Bool, visible: Bool, enabled: Bool) -> Bool {
        requested && !reduceMotion && !lowPower && active && visible && enabled
    }
}

/// Finite gestures layered over continuous breathing; selection never touches learning data.
enum TankeiIdleAction: String, CaseIterable {
    case flutter, flex, bounce, lookAround, nod, stretch, doze
    case wave, doubleHop, sway, bow, peek, wiggle, proud, sleepyBlink
    case tiptoe, shakeHead, shrug, dance, tailFlick

    static func candidates(state: TankeiState, stage: TankeiStage) -> [Self] {
        var energetic: [Self] = [.flutter, .bounce, .stretch, .wave, .doubleHop, .wiggle, .proud, .tiptoe, .dance, .tailFlick]
        if !stage.isChick { energetic.append(.flex) }
        switch state {
        case .ready, .encourage, .celebrate: return energetic + [.nod, .lookAround, .peek, .sway, .bow]
        case .review, .recover: return [.nod, .lookAround, .stretch, .peek, .sway, .bow, .shakeHead, .shrug, .tailFlick]
        case .rest: return [.doze, .lookAround, .stretch, .sleepyBlink, .sway, .peek, .tailFlick]
        }
    }

    static func choose(state: TankeiState, stage: TankeiStage, excluding previous: Self?) -> Self {
        let options = candidates(state: state, stage: stage).filter { $0 != previous }
        return options.randomElement() ?? .nod
    }

    func frame(at time: TimeInterval, expressive: Bool) -> TankeiFrame {
        let duration = 2.8
        guard time.isFinite, time > 0, time < duration else { return TankeiFrame() }
        let progress = time / duration
        let envelope = pow(sin(.pi * progress), 2)
        let wave = sin(2 * .pi * progress)
        let energy = expressive ? 1.25 : 0.75
        let amount = envelope * energy
        switch self {
        case .flutter:
            return TankeiFrame(lift: -6 * amount, wing: 32 * amount * sin(6 * .pi * progress), tail: 10 * amount * wave)
        case .flex:
            return TankeiFrame(squash: 0.025 * amount, wing: 24 * amount, nod: -3 * amount, tail: 5 * amount)
        case .bounce:
            return TankeiFrame(lift: -18 * amount * (0.6 + 0.4 * cos(4 * .pi * progress)),
                               squash: 0.055 * amount * sin(4 * .pi * progress), wing: 12 * amount, sway: 3 * amount * wave)
        case .lookAround:
            return TankeiFrame(nod: 7 * amount * wave, tail: 4 * amount * wave, sway: 4 * amount * wave, gaze: 3 * amount * wave)
        case .nod:
            return TankeiFrame(wing: 3 * amount, nod: 7 * amount * sin(4 * .pi * progress))
        case .stretch:
            return TankeiFrame(lift: -5 * amount, squash: -0.03 * amount, wing: -16 * amount, tail: 10 * amount)
        case .doze:
            return TankeiFrame(wing: 2 * amount, nod: 8 * amount, eyeScale: 1 - 0.65 * envelope)
        case .wave:
            return TankeiFrame(wing: 20 * amount * (0.7 + 0.3 * sin(8 * .pi * progress)), nod: -2 * amount, sway: -3 * amount)
        case .doubleHop:
            return TankeiFrame(lift: -16 * amount * pow(sin(2 * .pi * progress), 2), squash: 0.03 * amount * cos(4 * .pi * progress), wing: 16 * amount)
        case .sway:
            return TankeiFrame(nod: -3 * amount * wave, tail: 6 * amount * wave, sway: 6 * amount * wave)
        case .bow:
            return TankeiFrame(lift: 2 * amount, squash: 0.025 * amount, wing: -8 * amount, nod: 12 * amount)
        case .peek:
            return TankeiFrame(nod: -5 * amount, eyeScale: 1 - 0.2 * envelope, sway: -4 * amount, gaze: -4 * amount)
        case .wiggle:
            return TankeiFrame(wing: 8 * amount * sin(8 * .pi * progress), tail: 16 * amount * sin(6 * .pi * progress), sway: 4 * amount * sin(6 * .pi * progress))
        case .proud:
            return TankeiFrame(lift: -4 * amount, squash: -0.04 * amount, wing: 12 * amount, nod: -8 * amount)
        case .sleepyBlink:
            return TankeiFrame(squash: 0.02 * amount, nod: 3 * amount, eyeScale: 1 - 0.85 * envelope, sway: 2 * amount)
        case .tiptoe:
            return TankeiFrame(lift: -8 * amount, squash: -0.025 * amount, wing: -6 * amount, sway: 3 * amount * wave)
        case .shakeHead:
            return TankeiFrame(nod: 5 * amount * sin(6 * .pi * progress), gaze: 2 * amount * sin(6 * .pi * progress))
        case .shrug:
            return TankeiFrame(lift: -2 * amount, squash: 0.03 * amount, wing: 10 * amount, nod: 4 * amount)
        case .dance:
            return TankeiFrame(lift: -8 * amount * pow(sin(3 * .pi * progress), 2), wing: 22 * amount * wave,
                               nod: -4 * amount * wave, tail: 12 * amount * sin(6 * .pi * progress), sway: 7 * amount * sin(4 * .pi * progress))
        case .tailFlick:
            return TankeiFrame(wing: 2 * amount, tail: 22 * amount * sin(6 * .pi * progress))
        }
    }
}
