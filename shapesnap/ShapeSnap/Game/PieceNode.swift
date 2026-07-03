import SpriteKit
import SwiftUI

/// A draggable puzzle piece with rounded styling, soft shadow and mechanic states.
final class PieceNode: SKNode {

    let definition: PieceDefinition
    var isPlaced = false
    var isLocked = false
    var currentRotation: Int
    var currentFlipped: Bool
    private(set) var movesUsed = 0

    private let body: SKShapeNode
    private let shadow: SKShapeNode
    private let unit: CGFloat
    private var lockIcon: SKLabelNode?
    private var crackHits: [CGPoint] = []

    var canBeMoved: Bool { !isPlaced }

    /// Approximate radius for obstacle/collectible collision, honoring the
    /// current animated scale (pulsing pieces shrink/grow their footprint).
    var collisionRadius: CGFloat {
        let frame = body.frame
        return max(frame.width, frame.height) / 2 * max(abs(xScale), abs(yScale)) * 0.8
    }

    /// The piece's actual outline in scene space (rotation, flip and animated
    /// scale included), slightly shrunk so collisions feel forgiving. Used for
    /// obstacle checks so empty corners of the bounding box never snag.
    func collisionPolygon(at position: CGPoint) -> [CGPoint] {
        let scale = max(abs(xScale), abs(yScale)) * 0.94
        let flip: CGFloat = body.xScale < 0 ? -1 : 1
        let cosA = cos(zRotation)
        let sinA = sin(zRotation)
        return definition.shape.unitPoints.map { point in
            let x = (point.x - 0.5) * unit * flip * scale
            let y = (point.y - 0.5) * unit * scale
            return CGPoint(x: position.x + x * cosA - y * sinA,
                           y: position.y + x * sinA + y * cosA)
        }
    }

    init(definition: PieceDefinition, theme: Theme, unit: CGFloat) {
        self.definition = definition
        self.unit = unit
        self.currentRotation = definition.spawnRotation
        self.currentFlipped = definition.spawnFlipped

        let path = CGMutablePath()
        let points = definition.shape.unitPoints.map {
            CGPoint(x: ($0.x - 0.5) * unit, y: ($0.y - 0.5) * unit)
        }
        path.addLines(between: points)
        path.closeSubpath()

        body = SKShapeNode(path: path)
        let color = UIColor(theme.pieceColors[definition.id % theme.pieceColors.count])
        body.fillColor = color
        body.strokeColor = color.withAlphaComponent(0.7)
        body.lineWidth = 1.5
        body.lineJoin = .round

        shadow = SKShapeNode(path: path)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -4)
        shadow.zPosition = -1

        super.init()
        addChild(shadow)
        addChild(body)

        if definition.spawnFlipped {
            body.xScale = -1
            shadow.xScale = -1
        }
    }

    /// Flip is applied to the body (not the node) so node-level scale
    /// animations — drag pop, pulsing, snapping — can never wipe it out.
    func setFlipped(_ flipped: Bool, animated: Bool = true) {
        let scaleX: CGFloat = flipped ? -1 : 1
        if animated {
            body.run(.scaleX(to: scaleX, duration: 0.18))
            shadow.run(.scaleX(to: scaleX, duration: 0.18))
        } else {
            body.xScale = scaleX
            shadow.xScale = scaleX
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func containsTouch(at scenePoint: CGPoint) -> Bool {
        guard let scene else { return false }
        let local = convert(scenePoint, from: scene)
        let touchScale: CGFloat = GameSettings.shared.largePieceHandles ? 1.5 : 1.15
        var transform = CGAffineTransform(scaleX: touchScale, y: touchScale)
        guard let scaled = body.path?.copy(using: &transform) else { return false }
        return scaled.contains(local)
    }

    func beginDrag() {
        movesUsed += 1
        if definition.mechanics.contains(.pulsing) == false {
            run(.scale(to: 1.06, duration: 0.1))
        }
        zPosition = 40
        shadow.run(.moveBy(x: 0, y: -4, duration: 0.1))
    }

    func endDrag() {
        if definition.mechanics.contains(.pulsing) == false {
            run(.scale(to: 1.0, duration: 0.1))
        }
        zPosition = 10
        shadow.run(.moveBy(x: 0, y: 4, duration: 0.1))
    }

    // MARK: - Mechanic states

    func applyLockedState() {
        isLocked = true
        body.alpha = 0.55
        let icon = SKLabelNode(text: "🔒")
        icon.fontSize = 20
        icon.verticalAlignmentMode = .center
        addChild(icon)
        lockIcon = icon
    }

    func unlock() {
        isLocked = false
        body.alpha = 1
        lockIcon?.run(.sequence([.scale(to: 1.4, duration: 0.15), .fadeOut(withDuration: 0.15), .removeFromParent()]))
        HapticsManager.shared.medium()
        AudioManager.shared.play(.unlock)
    }

    func shakeLock() {
        lockIcon?.run(.sequence([.rotate(byAngle: 0.2, duration: 0.05),
                                 .rotate(byAngle: -0.4, duration: 0.1),
                                 .rotate(byAngle: 0.2, duration: 0.05)]))
    }

    func flashDamage() {
        let shape = body
        let originalColor = shape.fillColor
        shape.run(.sequence([
            .run { shape.fillColor = .systemRed },
            .wait(forDuration: 0.18),
            .run { shape.fillColor = originalColor },
        ]))
        run(.sequence([.moveBy(x: 6, y: 0, duration: 0.04),
                       .moveBy(x: -12, y: 0, duration: 0.08),
                       .moveBy(x: 6, y: 0, duration: 0.04)]))
    }

    /// Final-boss damage: each hit leaves a crack where the shot landed, a
    /// shard flies off, and a third hit in the same area punches a hole.
    /// Returns true when a hole formed (worth an extra score penalty).
    @discardableResult
    func applyCrack(atSceneAt scenePoint: CGPoint) -> Bool {
        let extent = max(body.frame.width, body.frame.height) / 2
        var origin: CGPoint
        if let scene {
            let local = convert(scenePoint, from: scene)
            origin = CGPoint(x: min(max(local.x, -extent * 0.7), extent * 0.7),
                             y: min(max(local.y, -extent * 0.7), extent * 0.7))
        } else {
            origin = CGPoint(x: CGFloat.random(in: -extent * 0.5...extent * 0.5),
                             y: CGFloat.random(in: -extent * 0.5...extent * 0.5))
        }
        crackHits.append(origin)
        let nearby = crackHits.filter { hypot($0.x - origin.x, $0.y - origin.y) < extent * 0.45 }

        let crackPath = CGMutablePath()
        crackPath.move(to: origin)
        var point = origin
        for _ in 0..<3 {
            point = CGPoint(x: point.x + CGFloat.random(in: -extent * 0.35...extent * 0.35),
                            y: point.y + CGFloat.random(in: -extent * 0.35...extent * 0.35))
            crackPath.addLine(to: point)
        }
        let crack = SKShapeNode(path: crackPath)
        crack.strokeColor = UIColor.black.withAlphaComponent(0.55)
        crack.lineWidth = 2
        crack.zPosition = 2
        addChild(crack)

        let shardSize = extent * 0.35
        let shardPath = CGMutablePath()
        shardPath.addLines(between: [CGPoint(x: 0, y: shardSize),
                                     CGPoint(x: shardSize * 0.8, y: -shardSize * 0.5),
                                     CGPoint(x: -shardSize * 0.7, y: -shardSize * 0.4)])
        shardPath.closeSubpath()
        let shard = SKShapeNode(path: shardPath)
        shard.fillColor = body.fillColor
        shard.strokeColor = .clear
        shard.position = origin
        shard.zPosition = 3
        addChild(shard)
        let direction = CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: 40...90))
        shard.run(.group([
            .move(by: direction, duration: 0.7),
            .rotate(byAngle: CGFloat.random(in: -3...3), duration: 0.7),
            .fadeOut(withDuration: 0.7),
        ])) { shard.removeFromParent() }

        body.alpha = max(0.65, body.alpha - 0.08)

        if nearby.count >= 3 {
            // Third hit in the same area: that spot breaks into a hole.
            let holeRadius = extent * 0.28
            let hole = SKShapeNode(circleOfRadius: holeRadius)
            hole.fillColor = UIColor.black.withAlphaComponent(0.7)
            hole.strokeColor = UIColor.black.withAlphaComponent(0.9)
            hole.lineWidth = 1.5
            hole.position = origin
            hole.zPosition = 3
            hole.setScale(0.1)
            addChild(hole)
            hole.run(.scale(to: 1.0, duration: 0.15))
            crackHits.removeAll { hypot($0.x - origin.x, $0.y - origin.y) < extent * 0.45 }
            return true
        }
        return false
    }

    /// Brief green confirmation so the player knows the piece is locked in.
    func showPlacedConfirmation() {
        let original = body.strokeColor
        let originalWidth = body.lineWidth
        body.strokeColor = UIColor.systemGreen
        body.lineWidth = 3
        let shape = body
        run(.sequence([.wait(forDuration: 0.5), .run {
            shape.strokeColor = original
            shape.lineWidth = originalWidth
        }]))
    }

    func startBlinking() {
        let blink = SKAction.sequence([
            .wait(forDuration: 2.2),
            .fadeAlpha(to: 0.06, duration: 0.5),
            .wait(forDuration: 1.4),
            .fadeAlpha(to: 1.0, duration: 0.4),
        ])
        run(.repeatForever(blink), withKey: "blink")
    }

    /// Rhythmic grow/shrink cycle; time the shrink to slip through obstacle gaps.
    func startPulsing() {
        let cycle = SKAction.sequence([
            .scale(to: 1.35, duration: 1.1),
            .wait(forDuration: 0.35),
            .scale(to: 0.7, duration: 1.1),
            .wait(forDuration: 0.35),
        ])
        cycle.timingMode = .easeInEaseOut
        run(.repeatForever(cycle), withKey: "pulse")
    }

    func startShapeShifting() {
        let morph = SKAction.sequence([
            .wait(forDuration: 3.0),
            .scaleX(to: 1.25, y: 0.8, duration: 0.4),
            .wait(forDuration: 3.0),
            .scaleX(to: 1.0, y: 1.0, duration: 0.4),
        ])
        run(.repeatForever(morph), withKey: "morph")
    }

    func enableGravity() {
        guard let path = body.path else { return }
        physicsBody = SKPhysicsBody(polygonFrom: path)
        physicsBody?.restitution = 0.15
        physicsBody?.allowsRotation = false
        physicsBody?.linearDamping = 1.2
    }

    func disableGravity() { physicsBody = nil }

    func emitSnapParticles(theme: Theme) {
        guard !GameSettings.shared.reduceMotion,
              let emitter = ParticleFactory.snapBurst(theme: theme, colorIndex: definition.id) else { return }
        emitter.position = .zero
        emitter.zPosition = 5
        addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    }
}

/// Programmatic particle emitters — no bundled assets required.
enum ParticleFactory {
    private static func dotTexture(color: UIColor, diameter: CGFloat = 8) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        }
        return SKTexture(image: image)
    }

    static func snapBurst(theme: Theme, colorIndex: Int) -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleTexture = dotTexture(color: UIColor(theme.pieceColors[colorIndex % theme.pieceColors.count]))
        emitter.numParticlesToEmit = 18
        emitter.particleBirthRate = 300
        emitter.particleLifetime = 0.6
        emitter.particleSpeed = 90
        emitter.particleSpeedRange = 60
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlphaSpeed = -1.6
        emitter.particleScale = 0.5
        emitter.particleScaleSpeed = -0.6
        return emitter
    }

    static func confetti(theme: Theme, size: CGSize) -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleTexture = dotTexture(color: .white)
        emitter.numParticlesToEmit = 120
        emitter.particleBirthRate = 200
        emitter.particleLifetime = 3
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 10)
        emitter.emissionAngle = -.pi / 2
        emitter.particleSpeed = 220
        emitter.particleSpeedRange = 120
        emitter.yAcceleration = -320
        emitter.particleScale = 0.6
        emitter.particleScaleRange = 0.35
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: theme.pieceColors.map { UIColor($0) },
            times: theme.pieceColors.enumerated().map { NSNumber(value: Double($0.offset) / Double(theme.pieceColors.count)) })
        emitter.particleRotationSpeed = 4
        return emitter
    }
}
