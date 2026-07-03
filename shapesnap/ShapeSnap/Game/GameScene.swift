import SpriteKit
import SwiftUI

protocol GameSceneDelegate: AnyObject {
    func sceneDidPlacePiece(accuracy: Double, placed: Int, total: Int)
    func sceneDidCompleteLevel(accuracy: Double)
    func sceneDidUseMove()
    func sceneDidRejectPiece()
    func sceneDidCollectBonus()
    func sceneDidTouchHazard()
    func sceneDidTakeBossHit()
}

/// SpriteKit scene that renders the board, target silhouette and draggable pieces,
/// and implements all special mechanics (gravity, rotation, teleporters, ...).
final class GameScene: SKScene {

    weak var gameDelegate: GameSceneDelegate?

    private let level: LevelDefinition
    private let theme: Theme
    private let settings = GameSettings.shared

    private var boardNode = SKNode()
    private var pieceNodes: [PieceNode] = []
    private var socketNodes: [SKShapeNode] = []
    private var portalNodes: [SKShapeNode] = []
    private var obstacleNodes: [SKShapeNode] = []
    private var collectibleNodes: [SKShapeNode] = []
    private var darknessMask: SKShapeNode?

    private var activePiece: PieceNode?
    private var dragOffset: CGPoint = .zero
    private var lastHazardHit: CFTimeInterval = 0
    private var bossNode: SKNode?
    private var projectileNodes: [SKShapeNode] = []
    private var laserNode: SKShapeNode?
    private var lastBossHit: CFTimeInterval = 0
    private weak var lastTouchedPiece: PieceNode?
    private var placedCount = 0
    private var accuracySamples: [Double] = []
    private var boardAngle: CGFloat = 0

    private var snapDistance: CGFloat { min(size.width, size.height) * 0.075 }
    private var boardRect: CGRect {
        CGRect(x: size.width * BoardLayout.rect.minX, y: size.height * BoardLayout.rect.minY,
               width: size.width * BoardLayout.rect.width, height: size.height * BoardLayout.rect.height)
    }

    init(level: LevelDefinition, theme: Theme, size: CGSize) {
        self.level = level
        self.theme = theme
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        setupBoard()
        setupSockets()
        setupPieces()
        setupPortals()
        setupObstacles()
        setupCollectibles()
        startBoardMechanics()
        if level.isBoss { setupBoss() }
    }

    // MARK: - Boss fights

    /// Boss levels get a hovering enemy that fires aimed projectiles and
    /// periodically sweeps a horizontal laser across the board.
    private func setupBoss() {
        let boss = SKNode()
        let body = SKShapeNode(circleOfRadius: 24)
        body.fillColor = UIColor.systemIndigo
        body.strokeColor = UIColor.systemPurple
        body.lineWidth = 3
        body.glowWidth = 6
        boss.addChild(body)
        for dx in [-9.0, 9.0] {
            let eye = SKShapeNode(circleOfRadius: 4)
            eye.fillColor = .white
            eye.strokeColor = .clear
            eye.position = CGPoint(x: dx, y: 5)
            boss.addChild(eye)
        }
        boss.position = CGPoint(x: boardRect.midX, y: boardRect.maxY - 30)
        boss.zPosition = 30
        addChild(boss)
        bossNode = boss

        let hover = SKAction.sequence([
            .moveBy(x: 60, y: 0, duration: 1.8),
            .moveBy(x: -120, y: 0, duration: 3.6),
            .moveBy(x: 60, y: 0, duration: 1.8),
        ])
        hover.timingMode = .easeInEaseOut
        boss.run(.repeatForever(hover))

        let difficulty = min(1.0, Double(level.world) / 10.0)
        let fireInterval = max(1.4, 2.8 - difficulty * 1.4)
        boss.run(.repeatForever(.sequence([
            .wait(forDuration: fireInterval),
            .run { [weak self] in self?.fireProjectile() },
        ])), withKey: "fire")
        boss.run(.repeatForever(.sequence([
            .wait(forDuration: max(5.0, 8.0 - difficulty * 3.0)),
            .run { [weak self] in self?.fireLaser() },
        ])), withKey: "laser")
    }

    private func fireProjectile() {
        guard let boss = bossNode, placedCount < level.pieces.count else { return }
        let projectile = SKShapeNode(circleOfRadius: 7)
        projectile.fillColor = UIColor.systemRed
        projectile.strokeColor = UIColor.systemOrange
        projectile.glowWidth = 4
        projectile.position = boss.position
        projectile.zPosition = 29
        addChild(projectile)
        projectileNodes.append(projectile)

        let targetX = activePiece?.position.x
            ?? pieceNodes.first(where: { !$0.isPlaced })?.position.x
            ?? boardRect.midX
        let destination = CGPoint(x: targetX, y: -30)
        let distance = hypot(destination.x - projectile.position.x, destination.y - projectile.position.y)
        AudioManager.shared.play(.rotate)
        projectile.run(.sequence([
            .move(to: destination, duration: TimeInterval(distance / 320)),
            .removeFromParent(),
        ]))
    }

    private func fireLaser() {
        guard laserNode == nil, placedCount < level.pieces.count else { return }
        let y = boardRect.minY + boardRect.height * CGFloat.random(in: 0.15...0.55)

        // Telegraph: a thin warning line, then the beam sweeps right-to-left and back.
        let warning = SKShapeNode(rect: CGRect(x: 0, y: y - 1.5, width: size.width, height: 3))
        warning.fillColor = UIColor.systemRed.withAlphaComponent(0.35)
        warning.strokeColor = .clear
        warning.zPosition = 28
        addChild(warning)
        warning.run(.sequence([
            .repeat(.sequence([.fadeAlpha(to: 0.15, duration: 0.15), .fadeAlpha(to: 0.6, duration: 0.15)]), count: 3),
            .removeFromParent(),
        ]))
        HapticsManager.shared.warning()

        let beamWidth: CGFloat = 90
        let beam = SKShapeNode(rect: CGRect(x: -beamWidth / 2, y: -5, width: beamWidth, height: 10),
                               cornerRadius: 5)
        beam.fillColor = UIColor.systemRed
        beam.strokeColor = UIColor.systemOrange
        beam.glowWidth = 8
        beam.position = CGPoint(x: size.width + beamWidth, y: y)
        beam.zPosition = 29
        laserNode = beam

        run(.sequence([.wait(forDuration: 0.95), .run { [weak self] in
            guard let self else { return }
            self.addChild(beam)
            AudioManager.shared.play(.reject)
            beam.run(.sequence([
                .moveTo(x: -beamWidth, duration: 1.3),
                .moveTo(x: self.size.width + beamWidth, duration: 1.3),
                .removeFromParent(),
                .run { [weak self] in self?.laserNode = nil },
            ]))
        }]))
    }

    override func update(_ currentTime: TimeInterval) {
        guard level.isBoss, currentTime - lastBossHit > 1.0 else { return }
        projectileNodes.removeAll { $0.parent == nil }

        for piece in pieceNodes where !piece.isPlaced {
            let radius = piece.collisionRadius * 0.8
            for projectile in projectileNodes {
                if hypot(projectile.position.x - piece.position.x,
                         projectile.position.y - piece.position.y) < radius + 7 {
                    projectile.removeFromParent()
                    registerBossHit(on: piece)
                    return
                }
            }
            if let beam = laserNode, beam.parent != nil,
               abs(beam.position.y - piece.position.y) < radius + 5,
               abs(beam.position.x - piece.position.x) < radius + 45 {
                registerBossHit(on: piece)
                return
            }
        }
    }

    private func registerBossHit(on piece: PieceNode) {
        lastBossHit = CACurrentMediaTime()
        piece.flashDamage()
        if level.id == LevelCatalog.totalLevels {
            piece.applyCrack()
            showBadge("crack!", above: piece)
        } else {
            showBadge("-\u{2764}\u{FE0F}", above: piece)
        }
        HapticsManager.shared.error()
        AudioManager.shared.play(.fail)
        gameDelegate?.sceneDidTakeBossHit()
    }

    // MARK: - Setup

    private func setupBoard() {
        let board = SKShapeNode(rect: CGRect(origin: CGPoint(x: -boardRect.width / 2, y: -boardRect.height / 2),
                                             size: boardRect.size), cornerRadius: 28)
        board.fillColor = UIColor(theme.boardLight).withAlphaComponent(0.5)
        board.strokeColor = UIColor.separator.withAlphaComponent(0.4)
        board.lineWidth = 1
        boardNode.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        boardNode.addChild(board)
        addChild(boardNode)
    }

    private func setupSockets() {
        for piece in level.pieces {
            let socket = makeShapeNode(for: piece, filled: false)
            socket.position = boardPoint(from: piece.targetPosition)
            socket.zRotation = CGFloat(piece.targetRotation) * .pi / 2
            socket.fillColor = UIColor.label.withAlphaComponent(0.06)
            socket.strokeColor = UIColor.label.withAlphaComponent(0.18)
            socket.lineWidth = 2
            socket.name = "socket-\(piece.id)"
            boardNode.addChild(socket)
            socketNodes.append(socket)

            if level.boardMechanics.contains(.movingTargets) {
                let drift = SKAction.sequence([
                    .moveBy(x: 26, y: 0, duration: 1.6),
                    .moveBy(x: -52, y: 0, duration: 3.2),
                    .moveBy(x: 26, y: 0, duration: 1.6),
                ])
                drift.timingMode = .easeInEaseOut
                socket.run(.repeatForever(drift))
            }
        }

        if level.boardMechanics.contains(.darkness) {
            let cover = SKShapeNode(rect: CGRect(origin: .zero, size: size))
            cover.fillColor = UIColor.black.withAlphaComponent(0.86)
            cover.strokeColor = .clear
            cover.zPosition = 50
            cover.name = "darkness"
            addChild(cover)
            darknessMask = cover
        }
    }

    private func setupPieces() {
        for piece in level.pieces {
            let node = PieceNode(definition: piece, theme: theme, unit: pieceUnit(for: piece))
            node.position = CGPoint(x: piece.spawnPosition.x * size.width,
                                    y: piece.spawnPosition.y * size.height)
            node.zRotation = CGFloat(piece.spawnRotation) * .pi / 2
            node.zPosition = 10 + CGFloat(piece.layer * 5)
            addChild(node)
            pieceNodes.append(node)

            if piece.mechanics.contains(.locked) { node.applyLockedState() }
            if piece.mechanics.contains(.invisible) { node.startBlinking() }
            if piece.mechanics.contains(.shapeShifting) { node.startShapeShifting() }
            if piece.mechanics.contains(.pulsing) { node.startPulsing() }
        }
    }

    private func setupPortals() {
        for pair in level.portals {
            for (point, color) in [(pair.entry, UIColor.systemTeal), (pair.exit, UIColor.systemPurple)] {
                let portal = SKShapeNode(circleOfRadius: 22)
                portal.position = CGPoint(x: point.x * size.width, y: point.y * size.height)
                portal.strokeColor = color
                portal.lineWidth = 3
                portal.glowWidth = 6
                portal.zPosition = 5
                portal.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4)))
                addChild(portal)
                portalNodes.append(portal)
            }
        }
    }

    private func setupObstacles() {
        for obstacle in level.obstacles {
            let rect = obstacleSceneRect(obstacle)
            let node = SKShapeNode(rect: CGRect(origin: CGPoint(x: -rect.width / 2, y: -rect.height / 2),
                                                size: rect.size), cornerRadius: min(rect.width, rect.height) / 2)
            node.position = CGPoint(x: rect.midX, y: rect.midY)
            if obstacle.isHazard {
                node.fillColor = UIColor.systemRed.withAlphaComponent(0.85)
                node.strokeColor = UIColor.systemOrange
                node.lineWidth = 2.5
                node.glowWidth = 4
                let warn = SKAction.sequence([.fadeAlpha(to: 0.55, duration: 0.6),
                                              .fadeAlpha(to: 1.0, duration: 0.6)])
                warn.timingMode = .easeInEaseOut
                node.run(.repeatForever(warn))
            } else {
                node.fillColor = UIColor.label.withAlphaComponent(0.75)
                node.strokeColor = .clear
            }
            node.zPosition = 8
            addChild(node)
            obstacleNodes.append(node)
        }
    }

    private func setupCollectibles() {
        for (index, point) in level.collectibles.enumerated() {
            let node = SKShapeNode(circleOfRadius: 13)
            node.position = CGPoint(x: point.x * size.width, y: point.y * size.height)
            node.fillColor = UIColor.systemYellow
            node.strokeColor = UIColor.systemOrange
            node.lineWidth = 2
            node.glowWidth = 3
            node.zPosition = 9
            node.name = "collectible-\(index)"
            let bob = SKAction.sequence([.moveBy(x: 0, y: 6, duration: 0.8),
                                         .moveBy(x: 0, y: -6, duration: 0.8)])
            bob.timingMode = .easeInEaseOut
            node.run(.repeatForever(bob))
            addChild(node)
            collectibleNodes.append(node)
        }
    }

    private func obstacleSceneRect(_ obstacle: Obstacle) -> CGRect {
        CGRect(x: obstacle.rect.minX * size.width,
               y: obstacle.rect.minY * size.height,
               width: obstacle.rect.width * size.width,
               height: obstacle.rect.height * size.height)
    }

    private func startBoardMechanics() {
        if level.boardMechanics.contains(.rotatingBoard) && !settings.reduceMotion {
            let wait = SKAction.wait(forDuration: level.isBoss ? 2.0 : 4.0)
            let rotate = SKAction.run { [weak self] in
                guard let self else { return }
                self.boardAngle += .pi / 2
                self.boardNode.run(.rotate(toAngle: self.boardAngle, duration: 0.6, shortestUnitArc: false))
                HapticsManager.shared.soft()
            }
            boardNode.run(.repeatForever(.sequence([wait, rotate])))
        }
        if level.boardMechanics.contains(.gravity) {
            physicsWorld.gravity = CGVector(dx: 0, dy: -3.5)
            physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
            for node in pieceNodes { node.enableGravity() }
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        revealDarkness(at: location)

        guard let node = pieceNodes
            .filter({ !$0.isPlaced && $0.containsTouch(at: location) && $0.canBeMoved })
            .max(by: { $0.zPosition < $1.zPosition }) else { return }

        if node.definition.mechanics.contains(.locked) && node.isLocked {
            node.shakeLock()
            HapticsManager.shared.warning()
            if touch.tapCount >= 2 { node.unlock() }   // double-tap unlocks
            return
        }

        activePiece = node
        lastTouchedPiece = node
        dragOffset = CGPoint(x: node.position.x - location.x, y: node.position.y - location.y)
        node.beginDrag()
        HapticsManager.shared.soft()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        var location = touch.location(in: self)
        revealDarkness(at: location)
        guard let piece = activePiece else { return }

        if level.boardMechanics.contains(.mirrorControls) {
            let previous = touch.previousLocation(in: self)
            let delta = CGPoint(x: location.x - previous.x, y: location.y - previous.y)
            location = CGPoint(x: piece.position.x - dragOffset.x - delta.x,
                               y: piece.position.y - dragOffset.y + delta.y)
        }

        let proposed = CGPoint(x: location.x + dragOffset.x, y: location.y + dragOffset.y)
        if movementAllowed(for: piece, to: proposed) {
            piece.position = proposed
        } else {
            // blocked by a wall — try sliding along one axis so movement feels smooth
            let horizontal = CGPoint(x: proposed.x, y: piece.position.y)
            let vertical = CGPoint(x: piece.position.x, y: proposed.y)
            if movementAllowed(for: piece, to: horizontal) { piece.position = horizontal }
            else if movementAllowed(for: piece, to: vertical) { piece.position = vertical }
        }
        collectBonuses(around: piece)
        checkHazardContact(for: piece)
        checkPortalTravel(piece)
        applyMagnetism(to: piece)
        highlightNearestSocket(for: piece)
    }

    /// Pieces cannot pass through solid obstacle bars (hazards let them through
    /// at a cost). Pulsing pieces use their current (animated) scale, so a
    /// shrunken piece fits through gaps a grown one cannot.
    private func movementAllowed(for piece: PieceNode, to position: CGPoint) -> Bool {
        guard !level.obstacles.isEmpty else { return true }
        let polygon = piece.collisionPolygon(at: position)
        return !level.obstacles.contains { !$0.isHazard && polygonIntersectsRect(polygon, obstacleSceneRect($0)) }
    }

    /// Exact polygon-vs-rect intersection so collisions follow the piece's
    /// real outline — the empty corners of a rotated piece never snag.
    private func polygonIntersectsRect(_ polygon: [CGPoint], _ rect: CGRect) -> Bool {
        if polygon.contains(where: { rect.contains($0) }) { return true }
        let path = CGMutablePath()
        path.addLines(between: polygon)
        path.closeSubpath()
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        if corners.contains(where: { path.contains($0) }) { return true }
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            for edge in 0..<4 {
                if segmentsIntersect(a, b, corners[edge], corners[(edge + 1) % 4]) { return true }
            }
        }
        return false
    }

    private func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        let d1 = cross(p3, p4, p1)
        let d2 = cross(p3, p4, p2)
        let d3 = cross(p1, p2, p3)
        let d4 = cross(p1, p2, p4)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
               ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }

    private func checkHazardContact(for piece: PieceNode) {
        guard CACurrentMediaTime() - lastHazardHit > 1.0 else { return }
        let polygon = piece.collisionPolygon(at: piece.position)
        guard let index = level.obstacles.firstIndex(where: { $0.isHazard && polygonIntersectsRect(polygon, obstacleSceneRect($0)) })
        else { return }
        lastHazardHit = CACurrentMediaTime()
        if index < obstacleNodes.count {
            obstacleNodes[index].run(.sequence([.scale(to: 1.12, duration: 0.08), .scale(to: 1.0, duration: 0.12)]))
        }
        showBadge("-10", above: piece)
        HapticsManager.shared.error()
        AudioManager.shared.play(.reject)
        gameDelegate?.sceneDidTouchHazard()
    }

    private func collectBonuses(around piece: PieceNode) {
        for node in collectibleNodes where node.parent != nil {
            if hypot(piece.position.x - node.position.x, piece.position.y - node.position.y) < piece.collisionRadius {
                node.run(.sequence([.group([.scale(to: 1.8, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                                    .removeFromParent()]))
                HapticsManager.shared.medium()
                AudioManager.shared.play(.coin)
                gameDelegate?.sceneDidCollectBonus()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { activePiece = nil }
        guard let piece = activePiece else { return }
        piece.endDrag()
        gameDelegate?.sceneDidUseMove()
        attemptSnap(piece)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activePiece?.endDrag()
        activePiece = nil
    }

    /// Called by gesture recognizers in the hosting view.
    func rotateActiveOrNearest() {
        guard let piece = controllablePiece() else { return }
        rotate(piece: piece)
    }

    /// The piece rotate/flip should act on: the one being dragged, otherwise
    /// the last one the player touched, otherwise the first unplaced piece.
    private func controllablePiece() -> PieceNode? {
        if let piece = activePiece, !piece.isPlaced, piece.canBeMoved { return piece }
        if let piece = lastTouchedPiece, !piece.isPlaced, piece.canBeMoved { return piece }
        return pieceNodes.first(where: { !$0.isPlaced && $0.canBeMoved })
    }

    func rotate(piece: PieceNode) {
        piece.currentRotation = (piece.currentRotation + 1) % 4
        piece.run(.rotate(toAngle: CGFloat(piece.currentRotation) * .pi / 2, duration: 0.18, shortestUnitArc: true))
        gameDelegate?.sceneDidUseMove()
        HapticsManager.shared.light()
        AudioManager.shared.play(.rotate)
    }

    func flipActivePiece() {
        guard let piece = controllablePiece() else { return }
        piece.currentFlipped.toggle()
        piece.setFlipped(piece.currentFlipped)
        gameDelegate?.sceneDidUseMove()
        HapticsManager.shared.light()
        AudioManager.shared.play(.rotate)
    }

    func showHint() {
        guard let piece = pieceNodes.first(where: { !$0.isPlaced }),
              let socket = socketNodes.first(where: { $0.name == "socket-\(piece.definition.id)" }) else { return }
        if let text = orientationHintText(for: piece) {
            showBadge(text, above: piece)
        } else {
            let pulse = SKAction.sequence([.scale(to: 1.15, duration: 0.3), .scale(to: 1.0, duration: 0.3)])
            socket.run(.repeat(pulse, count: 3))
            piece.run(.repeat(pulse, count: 3))
        }
    }

    /// "↻ ×2  ⇄"-style description of the rotations/flip still needed, or nil
    /// when the piece is already correctly oriented.
    private func orientationHintText(for piece: PieceNode) -> String? {
        let step = 4 / piece.definition.shape.rotationalSymmetry
        var text = ""
        if step > 1 {
            let target = (piece.definition.targetRotation + rotationOffsetFromBoard()) % 4
            let needed = ((target - piece.currentRotation) % step + step) % step
            if needed > 0 { text = needed > 1 ? "↻ ×\(needed)" : "↻" }
        }
        if !piece.definition.shape.isFlipSymmetric && piece.currentFlipped != piece.definition.targetFlipped {
            text += text.isEmpty ? "⇄" : "  ⇄"
        }
        return text.isEmpty ? nil : text
    }

    private func showBadge(_ text: String, above node: SKNode) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 22
        label.fontColor = .label
        label.verticalAlignmentMode = .center
        let bg = SKShapeNode(rectOf: CGSize(width: max(44, label.frame.width + 24), height: 36), cornerRadius: 18)
        bg.fillColor = UIColor.systemBackground.withAlphaComponent(0.95)
        bg.strokeColor = UIColor.separator
        bg.position = CGPoint(x: node.position.x, y: node.position.y + 64)
        bg.zPosition = 90
        bg.alpha = 0
        bg.addChild(label)
        addChild(bg)
        bg.run(.sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 1.6),
                          .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: - Snapping & mechanics

    private func attemptSnap(_ piece: PieceNode) {
        guard let socket = socketNodes.first(where: { $0.name == "socket-\(piece.definition.id)" }) else { return }
        let socketScenePosition = boardNode.convert(socket.position, to: self)
        let distance = hypot(piece.position.x - socketScenePosition.x, piece.position.y - socketScenePosition.y)

        // Rotation/flip only need to match up to the shape's own symmetry, so a
        // square (or any 4-fold symmetric shape) snaps at any angle.
        let symmetryStep = 4 / piece.definition.shape.rotationalSymmetry
        let effectiveTargetRotation = (piece.definition.targetRotation + rotationOffsetFromBoard()) % 4
        let rotationMatches = symmetryStep <= 1 ||
            piece.currentRotation % symmetryStep == effectiveTargetRotation % symmetryStep
        let flipMatches = piece.definition.shape.isFlipSymmetric ||
            piece.currentFlipped == piece.definition.targetFlipped

        if distance <= snapDistance && rotationMatches && flipMatches {
            let accuracy = 1.0 - Double(distance / snapDistance) * 0.5
            place(piece, at: socketScenePosition, accuracy: accuracy)
        } else {
            if piece.definition.mechanics.contains(.frozen) {
                piece.freezeInPlace()
                HapticsManager.shared.warning()
            } else if distance <= snapDistance * 2 {
                // Dropped in the right spot but wrong orientation: tell the player
                // exactly what is missing instead of a silent reject.
                if !(rotationMatches && flipMatches), let text = orientationHintText(for: piece) {
                    showBadge(text, above: piece)
                }
                piece.run(.sequence([.moveBy(x: 8, y: 0, duration: 0.05),
                                     .moveBy(x: -16, y: 0, duration: 0.1),
                                     .moveBy(x: 8, y: 0, duration: 0.05)]))
                HapticsManager.shared.warning()
                AudioManager.shared.play(.reject)
                gameDelegate?.sceneDidRejectPiece()
            }
        }
    }

    private func place(_ piece: PieceNode, at position: CGPoint, accuracy: Double) {
        piece.isPlaced = true
        piece.removeAllActions()
        piece.setScale(1.0)
        piece.setFlipped(piece.currentFlipped, animated: false)
        piece.disableGravity()
        piece.run(.group([
            .move(to: position, duration: 0.12),
            .scale(to: 1.0, duration: 0.12),
        ]))
        piece.zRotation = CGFloat(((piece.definition.targetRotation + rotationOffsetFromBoard()) % 4)) * .pi / 2
        piece.alpha = 1
        piece.emitSnapParticles(theme: theme)

        placedCount += 1
        accuracySamples.append(accuracy)
        HapticsManager.shared.snap()
        AudioManager.shared.play(.snap)
        gameDelegate?.sceneDidPlacePiece(accuracy: accuracy, placed: placedCount, total: level.pieces.count)

        if placedCount == level.pieces.count {
            let meanAccuracy = accuracySamples.reduce(0, +) / Double(accuracySamples.count)
            run(.sequence([.wait(forDuration: 0.35), .run { [weak self] in
                self?.celebrate()
                self?.gameDelegate?.sceneDidCompleteLevel(accuracy: meanAccuracy)
            }]))
        }
    }

    private func rotationOffsetFromBoard() -> Int {
        Int((boardAngle / (.pi / 2)).rounded()) % 4
    }

    private func checkPortalTravel(_ piece: PieceNode) {
        guard let pair = level.portals.first else { return }
        let entry = CGPoint(x: pair.entry.x * size.width, y: pair.entry.y * size.height)
        if hypot(piece.position.x - entry.x, piece.position.y - entry.y) < 26 {
            let exit = CGPoint(x: pair.exit.x * size.width, y: pair.exit.y * size.height)
            piece.run(.sequence([
                .scale(to: 0.1, duration: 0.12),
                .move(to: exit, duration: 0),
                .scale(to: 1.05, duration: 0.12),
            ]))
            activePiece = nil
            HapticsManager.shared.medium()
            AudioManager.shared.play(.teleport)
        }
    }

    private func applyMagnetism(to piece: PieceNode) {
        guard piece.definition.mechanics.contains(.magnetic) else { return }
        for other in pieceNodes where other !== piece && !other.isPlaced && other.definition.mechanics.contains(.magnetic) {
            let dx = piece.position.x - other.position.x
            let dy = piece.position.y - other.position.y
            let distance = max(hypot(dx, dy), 1)
            if distance < 140 {
                let pull = 2.2 / distance
                other.position = CGPoint(x: other.position.x + dx * pull, y: other.position.y + dy * pull)
            }
        }
    }

    private func highlightNearestSocket(for piece: PieceNode) {
        guard let socket = socketNodes.first(where: { $0.name == "socket-\(piece.definition.id)" }) else { return }
        let socketScenePosition = boardNode.convert(socket.position, to: self)
        let distance = hypot(piece.position.x - socketScenePosition.x, piece.position.y - socketScenePosition.y)
        socket.fillColor = distance <= snapDistance
            ? UIColor(theme.pieceColors[piece.definition.id % theme.pieceColors.count]).withAlphaComponent(0.25)
            : UIColor.label.withAlphaComponent(0.06)
    }

    private func revealDarkness(at point: CGPoint) {
        guard let mask = darknessMask else { return }
        let hole = UIBezierPath(rect: CGRect(origin: .zero, size: size))
        hole.append(UIBezierPath(ovalIn: CGRect(x: point.x - 90, y: point.y - 90, width: 180, height: 180)).reversing())
        mask.path = hole.cgPath
    }

    private func celebrate() {
        guard !settings.reduceMotion else { return }
        for piece in pieceNodes {
            piece.run(.sequence([.scale(to: 1.08, duration: 0.15), .scale(to: 1.0, duration: 0.2)]))
        }
        if let emitter = ParticleFactory.confetti(theme: theme, size: size) {
            emitter.position = CGPoint(x: size.width / 2, y: size.height)
            emitter.zPosition = 100
            addChild(emitter)
            emitter.run(.sequence([.wait(forDuration: 2.5), .removeFromParent()]))
        }
        AudioManager.shared.play(.complete)
        HapticsManager.shared.success()
    }

    // MARK: - Geometry helpers

    private func boardPoint(from normalized: CGPoint) -> CGPoint {
        CGPoint(x: (normalized.x - 0.5) * boardRect.width,
                y: (normalized.y - 0.5) * boardRect.height)
    }

    private func pieceUnit(for piece: PieceDefinition) -> CGFloat {
        piece.size * min(boardRect.width, boardRect.height)
    }

    func makeShapeNode(for piece: PieceDefinition, filled: Bool) -> SKShapeNode {
        let unit = pieceUnit(for: piece)
        // Mirroring is baked into the path (not node xScale) so that scale
        // animations on the node can never undo the flip.
        let mirror: CGFloat = piece.targetFlipped ? -1 : 1
        let path = CGMutablePath()
        let points = piece.shape.unitPoints.map {
            CGPoint(x: ($0.x - 0.5) * unit * mirror, y: ($0.y - 0.5) * unit)
        }
        path.addLines(between: points)
        path.closeSubpath()
        return SKShapeNode(path: path)
    }
}
