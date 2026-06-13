import AppKit
import SpriteKit

private enum BubbleColor: Int, CaseIterable {
    case blue = 0
    case green
    case red
    case yellow
    case purple
    case cyan
    case orange
    case white
}

private struct GridPoint: Hashable {
    var column: Int
    var row: Int
}

private struct Bubble {
    var color: BubbleColor
    var node: SKSpriteNode
}

private struct MovingBubble {
    var color: BubbleColor
    var node: SKSpriteNode
    var velocity: CGVector
}

private enum GameState {
    case menu
    case credits
    case playing
    case won
    case lost
}

private enum MenuItem: CaseIterable {
    case resume
    case newGame
    case sound
    case music
    case colorBlind
    case rushMe
    case credits
    case quit
}

private enum PenguinState {
    case idle
    case turnLeft
    case turnRight
    case fire
    case won
    case lost
}

final class GameScene: SKScene {
    private let columns = 8
    private let visibleRows = 12
    private let gridRows = 13
    private let bubbleSize: CGFloat = 32
    private let columnSpacing: CGFloat = 32
    private let rowSpacing: CGFloat = 28
    private let originX: CGFloat = 190
    private let originTopY: CGFloat = 44
    private let shooterPosition = CGPoint(x: 318, y: 74)
    private let shotSpeed: CGFloat = 480
    private let collisionDistanceSquared: CGFloat = 29 * 29
    private let leftWallCenterX: CGFloat = 206
    private let rightWallCenterX: CGFloat = 430
    private let loseCenterY: CGFloat = 480 - 380 - 16
    private let aimSpeed: CGFloat = 24
    private let hurryWarningRows: CGFloat = 3
    private let startingLives = 5

    private var grid: [[Bubble?]] = []
    private var textures: [BubbleColor: SKTexture] = [:]
    private var colorBlindTextures: [BubbleColor: SKTexture] = [:]
    private var frozenTextures: [BubbleColor: SKTexture] = [:]
    private var currentColor: BubbleColor = .blue
    private var nextColor: BubbleColor = .green
    private var movingBubble: MovingBubble?
    private var lastUpdateTime: TimeInterval = 0
    private var aimIndex: CGFloat = 20
    private var pressedKeyCodes: Set<UInt16> = []
    private var loadedLevels: [[[BubbleColor?]]] = []
    private var levelIndex = 0
    private var state: GameState = .playing
    private var shotsUntilDrop = 8
    private var boardDropOffset: CGFloat = 0
    private var hurryWarningCooldown: TimeInterval = 0
    private var levelScore = 0
    private var runScore = 0
    private var shotsFired = 0
    private var lives = 5
    private var compressorHeadTopY: CGFloat = -7
    private var idleTime: TimeInterval = 0
    private var rushWarningIssued = false
    private var selectedMenuIndex = 0
    private var penguinFrames: [SKTexture] = []
    private var penguinState: PenguinState = .idle
    private var penguinStateTime: TimeInterval = 0
    private var hudFontTexture: SKTexture?
    private let soundPlayer = SoundPlayer()
    private let preferences = GamePreferences.shared

    private let bubbleLayer = SKNode()
    private let compressorLayer = SKNode()
    private let uiLayer = SKNode()
    private let movingLayer = SKNode()
    private let fallingLayer = SKNode()
    private let menuLayer = SKNode()
    private let aimNode = SKShapeNode()
    private let launcherNode = SKSpriteNode()
    private let currentBubbleNode = SKSpriteNode()
    private let nextBubbleNode = SKSpriteNode()
    private let compressorHeadNode = SKSpriteNode()
    private let penguinNode = SKSpriteNode()
    private var levelLabel: BitmapTextNode?
    private var scoreLabel: BitmapTextNode?
    private var bestRunLabel: BitmapTextNode?
    private var shotsLabel: BitmapTextNode?
    private var dropLabel: BitmapTextNode?
    private var levelBestLabel: BitmapTextNode?
    private var messageLabel: BitmapTextNode?
    private var lifeNodes: [SKSpriteNode] = []
    private var menuLabels: [SKLabelNode] = []
    private let menuTitleLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
    private let creditsLabel = SKLabelNode(fontNamed: "MarkerFelt-Thin")

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.11, alpha: 1)
        loadTextures()
        loadPenguinFrames()
        loadLevels()
        applyAudioPreferences()
        buildScene()
        showMenu()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if state == .menu {
            handleMenuKey(event)
            return
        }

        if state == .credits {
            if [36, 49, 53].contains(event.keyCode) {
                showMenu()
            }
            return
        }

        if event.modifierFlags.contains(.command), event.keyCode == 12 {
            NSApplication.shared.terminate(nil)
            return
        }

        switch event.keyCode {
        case 53:
            showMenu()
        case 123, 124:
            pressedKeyCodes.insert(event.keyCode)
        case 49, 126:
            guard !event.isARepeat else { return }
            if state == .won {
                startLevel(levelIndex + 1)
            } else if state == .lost, lives > 0 {
                startLevel(levelIndex)
            } else {
                fire()
            }
        case 15:
            startLevel(levelIndex)
        case 45:
            preferences.resetRun()
            startLevel(0, resetRunScore: true)
        default:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        pressedKeyCodes.remove(event.keyCode)
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard lastUpdateTime > 0 else { return }

        let delta = min(CGFloat(currentTime - lastUpdateTime), 1 / 30)
        updateAimInput(delta: delta)
        updatePenguin(delta: TimeInterval(delta))
        guard state == .playing else { return }
        updateRushMe(delta: TimeInterval(delta))
        updateHurryWarning(delta: TimeInterval(delta))
        updateMovingBubble(delta: delta)
    }

    private func buildScene() {
        removeAllChildren()

        if let background = texture(named: "background.jpg") {
            let node = SKSpriteNode(texture: background)
            node.position = CGPoint(x: size.width / 2, y: size.height / 2)
            node.zPosition = -10
            addChild(node)
        }

        addChild(compressorLayer)
        addChild(bubbleLayer)
        addChild(fallingLayer)
        addChild(movingLayer)
        addChild(uiLayer)
        addChild(menuLayer)

        buildCompressor()
        buildMenu()

        if let launcher = texture(named: "launcher.png") {
            launcherNode.texture = launcher
            launcherNode.size = CGSize(width: 100, height: 100)
        } else {
            launcherNode.color = .white
            launcherNode.size = CGSize(width: 80, height: 20)
        }
        launcherNode.position = CGPoint(x: shooterPosition.x, y: shooterPosition.y - 10)
        launcherNode.zPosition = 5
        uiLayer.addChild(launcherNode)

        currentBubbleNode.position = shooterPosition
        currentBubbleNode.size = CGSize(width: bubbleSize, height: bubbleSize)
        currentBubbleNode.zPosition = 8
        uiLayer.addChild(currentBubbleNode)

        penguinNode.size = CGSize(width: 57, height: 45)
        penguinNode.position = CGPoint(x: 388.5, y: 22.5)
        penguinNode.zPosition = 4
        uiLayer.addChild(penguinNode)

        aimNode.strokeColor = .white
        aimNode.lineWidth = 3
        aimNode.lineCap = .round
        aimNode.alpha = 0.75
        aimNode.zPosition = 6
        uiLayer.addChild(aimNode)

        nextBubbleNode.position = CGPoint(x: 318, y: 25)
        nextBubbleNode.size = CGSize(width: bubbleSize, height: bubbleSize)
        nextBubbleNode.zPosition = 7
        uiLayer.addChild(nextBubbleNode)

        buildHUDLabels()
        buildLifeNodes()
    }

    private func startLevel(_ index: Int, resetRunScore: Bool = false) {
        state = .playing
        menuLayer.isHidden = true
        applyAudioPreferences()
        soundPlayer.playMusic(.onePlayer)
        levelIndex = loadedLevels.indices.contains(index) ? index : 0
        bubbleLayer.removeAllChildren()
        movingLayer.removeAllChildren()
        fallingLayer.removeAllChildren()
        uiLayer.children.filter { $0.name == "panel" }.forEach { $0.removeFromParent() }
        movingBubble = nil
        currentBubbleNode.isHidden = false
        shotsUntilDrop = 8
        boardDropOffset = 0
        compressorHeadTopY = -7
        hurryWarningCooldown = 0
        idleTime = 0
        rushWarningIssued = false
        levelScore = 0
        if resetRunScore {
            runScore = 0
            lives = startingLives
        }
        shotsFired = 0
        setHUDText(messageLabel, "")
        resetCompressor()

        grid = Array(
            repeating: Array(repeating: nil, count: gridRows),
            count: columns
        )

        for row in 0..<visibleRows {
            for column in 0..<columns {
                guard let color = loadedLevels[levelIndex][row][column] else { continue }
                addFixedBubble(color: color, at: GridPoint(column: column, row: row))
            }
        }

        currentColor = nextAvailableColor()
        nextColor = nextAvailableColor()
        updateBubblePreview()
        updateAim()
        setPenguinState(.idle)
        updateStatus()
    }

    private func fire() {
        if state != .playing {
            startLevel(levelIndex)
            return
        }

        guard movingBubble == nil else { return }
        idleTime = 0
        rushWarningIssued = false
        let radians = aimIndex * .pi / 40
        let velocity = CGVector(
            dx: -cos(radians) * shotSpeed,
            dy: sin(radians) * shotSpeed
        )
        let node = makeBubbleNode(color: currentColor)
        node.position = shooterPosition
        node.zPosition = 20
        movingLayer.addChild(node)
        movingBubble = MovingBubble(color: currentColor, node: node, velocity: velocity)
        shotsFired += 1
        setPenguinState(.fire)
        soundPlayer.play(.launch)

        currentColor = nextColor
        nextColor = nextAvailableColor()
        updateBubblePreview()
        currentBubbleNode.isHidden = true
    }

    private func updateMovingBubble(delta: CGFloat) {
        guard var moving = movingBubble else { return }
        var position = moving.node.position
        position.x += moving.velocity.dx * delta
        position.y += moving.velocity.dy * delta

        if position.x <= leftWallCenterX {
            position.x = leftWallCenterX + (leftWallCenterX - position.x)
            moving.velocity.dx = abs(moving.velocity.dx)
            soundPlayer.play(.rebound)
        } else if position.x >= rightWallCenterX {
            position.x = rightWallCenterX - (position.x - rightWallCenterX)
            moving.velocity.dx = -abs(moving.velocity.dx)
            soundPlayer.play(.rebound)
        }

        moving.node.position = position
        let candidate = gridPoint(for: position)

        if position.y >= centerY(row: 0) || collides(at: position, around: candidate) {
            settle(moving, near: candidate)
        } else {
            movingBubble = moving
        }
    }

    private func settle(_ moving: MovingBubble, near point: GridPoint) {
        var point = nearestOpenPoint(to: point, from: moving.node.position)
        point.column = min(max(point.column, 0), columns - 1)
        point.row = min(max(point.row, 0), gridRows - 1)

        moving.node.removeFromParent()
        addFixedBubble(color: moving.color, at: point)
        movingBubble = nil
        currentBubbleNode.isHidden = false

        let group = connectedSameColor(from: point)
        if group.count >= 3 {
            addScore(group.count * 10)
            remove(group: group, animatedAsPop: true)
            let detachedCount = dropDetachedBubbles()
            addScore(detachedCount * 25)
            soundPlayer.play(.destroyGroup)
        } else {
            shotsUntilDrop -= 1
            soundPlayer.play(.stick)
            if shotsUntilDrop == 0 {
                shotsUntilDrop = 8
                dropGridOneRow()
            }
        }

        if bubbleCount == 0 {
            finish(.won)
        } else if hasBubbleBelowLimit {
            finish(.lost)
        }

        updateBubblePreview()
        updateStatus()
    }

    private func addFixedBubble(color: BubbleColor, at point: GridPoint) {
        guard contains(point) else { return }
        if let existing = grid[point.column][point.row] {
            existing.node.removeFromParent()
        }

        let node = makeBubbleNode(color: color)
        node.position = position(for: point)
        node.zPosition = CGFloat(point.row)
        bubbleLayer.addChild(node)
        grid[point.column][point.row] = Bubble(color: color, node: node)
    }

    private func makeBubbleNode(color: BubbleColor) -> SKSpriteNode {
        let node = SKSpriteNode(texture: bubbleTexture(for: color))
        node.size = CGSize(width: bubbleSize, height: bubbleSize)
        if bubbleTexture(for: color) == nil {
            node.color = fallbackColor(for: color)
            node.colorBlendFactor = 1
        }
        return node
    }

    private func position(for point: GridPoint) -> CGPoint {
        let topLeftX = originX + CGFloat(point.column) * columnSpacing - CGFloat(point.row % 2) * 16
        let topLeftY = originTopY + CGFloat(point.row) * rowSpacing + boardDropOffset
        return CGPoint(x: topLeftX + bubbleSize / 2, y: size.height - topLeftY - bubbleSize / 2)
    }

    private func gridPoint(for position: CGPoint) -> GridPoint {
        let realX = position.x - bubbleSize / 2
        let realTopY = size.height - position.y - bubbleSize / 2
        var row = Int(floor((realTopY - 28 - boardDropOffset) / rowSpacing))
        row = min(max(row, 0), gridRows - 1)
        var column = Int(floor((realX - 174) / columnSpacing + 0.5 * CGFloat(row % 2)))
        column = min(max(column, 0), columns - 1)
        return GridPoint(column: column, row: row)
    }

    private func centerY(row: Int) -> CGFloat {
        position(for: GridPoint(column: 0, row: row)).y
    }

    private func collides(at position: CGPoint, around point: GridPoint) -> Bool {
        for neighbor in neighbors(of: point) + [point] where contains(neighbor) {
            guard let bubble = grid[neighbor.column][neighbor.row] else { continue }
            let dx = bubble.node.position.x - position.x
            let dy = bubble.node.position.y - position.y
            if dx * dx + dy * dy < collisionDistanceSquared {
                return true
            }
        }
        return false
    }

    private func nearestOpenPoint(to point: GridPoint, from bubblePosition: CGPoint) -> GridPoint {
        let candidates = ([point] + neighbors(of: point))
            .filter { contains($0) && grid[$0.column][$0.row] == nil }

        return candidates.min {
            distanceSquared(bubblePosition, position(for: $0)) < distanceSquared(bubblePosition, position(for: $1))
        } ?? point
    }

    private func connectedSameColor(from start: GridPoint) -> Set<GridPoint> {
        guard contains(start), let color = grid[start.column][start.row]?.color else { return [] }
        var seen: Set<GridPoint> = []
        var queue = [start]

        while let point = queue.popLast() {
            guard !seen.contains(point), contains(point) else { continue }
            guard grid[point.column][point.row]?.color == color else { continue }
            seen.insert(point)
            queue.append(contentsOf: neighbors(of: point))
        }

        return seen
    }

    private func dropDetachedBubbles() -> Int {
        var attached: Set<GridPoint> = []
        var queue = (0..<columns).map { GridPoint(column: $0, row: 0) }

        while let point = queue.popLast() {
            guard contains(point), !attached.contains(point), grid[point.column][point.row] != nil else { continue }
            attached.insert(point)
            queue.append(contentsOf: neighbors(of: point))
        }

        var detached: Set<GridPoint> = []
        for column in 0..<columns {
            for row in 0..<gridRows {
                let point = GridPoint(column: column, row: row)
                if grid[column][row] != nil && !attached.contains(point) {
                    detached.insert(point)
                }
            }
        }
        remove(group: detached, animatedAsPop: false)
        return detached.count
    }

    private func remove(group: Set<GridPoint>, animatedAsPop: Bool) {
        for point in group {
            guard let bubble = grid[point.column][point.row] else { continue }
            grid[point.column][point.row] = nil
            if animatedAsPop {
                bubble.node.run(.sequence([
                    .group([.scale(to: 1.35, duration: 0.08), .fadeOut(withDuration: 0.08)]),
                    .removeFromParent()
                ]))
            } else {
                bubble.node.removeFromParent()
                fallingLayer.addChild(bubble.node)
                bubble.node.run(.sequence([
                    .group([
                        .moveBy(x: CGFloat.random(in: -30...30), y: -620, duration: 1.1),
                        .rotate(byAngle: CGFloat.random(in: -1...1), duration: 1.1)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func dropGridOneRow() {
        soundPlayer.play(.newRoot)
        addCompressorBody()
        boardDropOffset += rowSpacing
        compressorHeadTopY += rowSpacing
        compressorHeadNode.run(.move(to: compressorHeadPosition(), duration: 0.12))
        for row in 0..<gridRows {
            for column in 0..<columns {
                let point = GridPoint(column: column, row: row)
                grid[column][row]?.node.run(.move(to: position(for: point), duration: 0.12))
            }
        }
    }

    private func neighbors(of point: GridPoint) -> [GridPoint] {
        let even = point.row % 2 == 0
        let offsets = even
            ? [(-1, 0), (1, 0), (0, -1), (1, -1), (0, 1), (1, 1)]
            : [(-1, 0), (1, 0), (-1, -1), (0, -1), (-1, 1), (0, 1)]

        return offsets
            .map { GridPoint(column: point.column + $0.0, row: point.row + $0.1) }
            .filter(contains)
    }

    private func finish(_ newState: GameState) {
        state = newState
        setPenguinState(newState == .won ? .won : .lost)
        soundPlayer.play(newState == .won ? .applause : .lose)
        if newState == .lost {
            freezeBoardThenShowLosePanel()
            return
        }

        let completionBonus = max(0, 1_000 - shotsFired * 15)
        addScore(completionBonus)
        let nextLevel = nextLevelIndex(after: levelIndex)
        preferences.recordCompletion(level: levelIndex, levelScore: levelScore, runScore: runScore, nextLevel: nextLevel)
        showPanel(named: "win_panel.jpg")
        let best = preferences.bestScore(for: levelIndex)
        setHUDText(messageLabel, "complete bonus \(completionBonus) best \(best)")
        updateStatus()
    }

    private func showPanel(named imageName: String) {
        if let panelTexture = texture(named: imageName) {
            let panel = SKSpriteNode(texture: panelTexture)
            panel.name = "panel"
            panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            panel.zPosition = 100
            uiLayer.addChild(panel)
        }
    }

    private func freezeBoardThenShowLosePanel() {
        preferences.recordRunScore(runScore)
        lives = max(0, lives - 1)
        updateLifeNodes()
        currentBubbleNode.texture = frozenTextures[currentColor] ?? textures[currentColor]
        nextBubbleNode.texture = frozenTextures[nextColor] ?? textures[nextColor]

        var delay: TimeInterval = 0
        for row in stride(from: gridRows - 1, through: 0, by: -1) {
            for column in stride(from: columns - 1, through: 0, by: -1) {
                guard let bubble = grid[column][row] else { continue }
                guard let texture = frozenTextures[bubble.color] ?? textures[bubble.color] else { continue }
                let freeze = SKAction.sequence([
                    .wait(forDuration: delay),
                    .group([
                        .setTexture(texture, resize: true),
                        .scale(to: 1.08, duration: 0.05)
                    ]),
                    .scale(to: 1.0, duration: 0.08)
                ])
                bubble.node.run(freeze)
                delay += 0.025
            }
        }

        uiLayer.run(.sequence([
            .wait(forDuration: max(0.2, delay + 0.15)),
            .run { [weak self] in
                guard let self else { return }
                if self.lives > 0 {
                    self.setHUDText(self.messageLabel, "life lost lives \(self.lives) press space")
                } else {
                    self.showPanel(named: "lose_panel.jpg")
                    self.setHUDText(self.messageLabel, "game over press n")
                }
            }
        ]))
    }

    private func updateAim() {
        let radians = aimIndex * .pi / 40
        let end = CGPoint(
            x: shooterPosition.x - cos(radians) * 95,
            y: shooterPosition.y + sin(radians) * 95
        )
        let path = CGMutablePath()
        path.move(to: shooterPosition)
        path.addLine(to: end)
        aimNode.path = path
        launcherNode.zRotation = .pi / 2 - radians
    }

    private func updateAimInput(delta: CGFloat) {
        var direction: CGFloat = 0
        if pressedKeyCodes.contains(123) {
            direction -= 1
        }
        if pressedKeyCodes.contains(124) {
            direction += 1
        }
        guard direction != 0 else { return }

        aimIndex = min(39, max(1, aimIndex + direction * aimSpeed * delta))
        setPenguinState(direction < 0 ? .turnLeft : .turnRight)
        updateAim()
    }

    private func updateBubblePreview() {
        currentBubbleNode.texture = bubbleTexture(for: currentColor)
        currentBubbleNode.color = bubbleTexture(for: currentColor) == nil ? fallbackColor(for: currentColor) : .clear
        currentBubbleNode.colorBlendFactor = bubbleTexture(for: currentColor) == nil ? 1 : 0

        nextBubbleNode.texture = bubbleTexture(for: nextColor)
        nextBubbleNode.color = bubbleTexture(for: nextColor) == nil ? fallbackColor(for: nextColor) : .clear
        nextBubbleNode.colorBlendFactor = bubbleTexture(for: nextColor) == nil ? 1 : 0
    }

    private func setPenguinState(_ newState: PenguinState) {
        if penguinState != newState {
            penguinState = newState
            penguinStateTime = 0
        }
        updatePenguinFrame()
    }

    private func updatePenguin(delta: TimeInterval) {
        penguinStateTime += delta

        switch penguinState {
        case .fire, .turnLeft, .turnRight:
            if penguinStateTime > 0.22 {
                setPenguinState(.idle)
            }
        case .idle where penguinStateTime > 3.0:
            setPenguinFrame(index: 7)
        case .won:
            let sequence = [0, 7, 6, 15, 16, 17, 18, 19]
            setPenguinFrame(index: sequence[Int(penguinStateTime * 7) % sequence.count])
        case .lost:
            let sequence = [0, 8, 9, 10, 11, 12, 13, 14]
            setPenguinFrame(index: sequence[Int(penguinStateTime * 7) % sequence.count])
        default:
            break
        }
    }

    private func updatePenguinFrame() {
        switch penguinState {
        case .idle:
            setPenguinFrame(index: 0)
        case .turnLeft:
            setPenguinFrame(index: 3)
        case .turnRight:
            setPenguinFrame(index: 2)
        case .fire:
            setPenguinFrame(index: 1)
        case .won:
            setPenguinFrame(index: 0)
        case .lost:
            setPenguinFrame(index: 0)
        }
    }

    private func setPenguinFrame(index: Int) {
        guard penguinFrames.indices.contains(index) else { return }
        penguinNode.texture = penguinFrames[index]
    }

    private func bubbleTexture(for color: BubbleColor) -> SKTexture? {
        preferences.colorBlindEnabled ? colorBlindTextures[color] ?? textures[color] : textures[color]
    }

    private func updateStatus() {
        let best = preferences.bestScore(for: levelIndex)
        let bestRun = preferences.bestRunScore
        setHUDText(levelLabel, "\(levelIndex + 1)")
        setHUDText(scoreLabel, "score \(runScore)")
        setHUDText(bestRunLabel, "best \(bestRun)")
        setHUDText(shotsLabel, "shots \(shotsFired)")
        setHUDText(dropLabel, "drop \(shotsUntilDrop)")
        setHUDText(levelBestLabel, "lvl best \(best)")
    }

    private func buildHUDLabels() {
        guard hudFontTexture != nil else { return }

        levelLabel = makeHUDLabel(position: CGPoint(x: 198, y: 48), alignment: .center, scale: 0.95)
        scoreLabel = makeHUDLabel(position: CGPoint(x: 26, y: 346), alignment: .left, scale: 0.82)
        bestRunLabel = makeHUDLabel(position: CGPoint(x: 26, y: 322), alignment: .left, scale: 0.82)
        shotsLabel = makeHUDLabel(position: CGPoint(x: 488, y: 346), alignment: .left, scale: 0.8)
        dropLabel = makeHUDLabel(position: CGPoint(x: 488, y: 322), alignment: .left, scale: 0.8)
        levelBestLabel = makeHUDLabel(position: CGPoint(x: 488, y: 298), alignment: .left, scale: 0.74)
        messageLabel = makeHUDLabel(position: CGPoint(x: size.width / 2, y: 416), alignment: .center, scale: 0.82)

        for label in [levelLabel, scoreLabel, bestRunLabel, shotsLabel, dropLabel, levelBestLabel, messageLabel] {
            if let label {
                label.zPosition = 10
                uiLayer.addChild(label)
            }
        }
    }

    private func makeHUDLabel(position: CGPoint, alignment: BitmapTextNode.Alignment, scale: CGFloat) -> BitmapTextNode {
        let label = BitmapTextNode(texture: hudFontTexture!, scale: scale, alignment: alignment, spacing: 1)
        label.position = position
        return label
    }

    private func buildCompressor() {
        compressorLayer.zPosition = -1
        compressorHeadNode.texture = texture(named: "compressor.gif")
        compressorHeadNode.size = CGSize(width: 321, height: 51)
        compressorHeadNode.zPosition = 2
        compressorLayer.addChild(compressorHeadNode)
        resetCompressor()
    }

    private func resetCompressor() {
        compressorLayer.children
            .filter { $0.name == "compressorBody" }
            .forEach { $0.removeFromParent() }
        compressorHeadNode.position = compressorHeadPosition()
    }

    private func addCompressorBody() {
        guard let texture = texture(named: "compressorBody.gif") else { return }
        for javaX in [235, 391] {
            let body = SKSpriteNode(texture: texture)
            body.name = "compressorBody"
            body.size = CGSize(width: 13, height: 28)
            body.position = pointFromJavaTopLeft(
                x: CGFloat(javaX),
                y: compressorHeadTopY + 3,
                width: 13,
                height: 28
            )
            body.zPosition = 1
            compressorLayer.addChild(body)
        }
    }

    private func compressorHeadPosition() -> CGPoint {
        pointFromJavaTopLeft(x: 160, y: compressorHeadTopY, width: 321, height: 51)
    }

    private func pointFromJavaTopLeft(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: x + width / 2, y: size.height - y - height / 2)
    }

    private func buildLifeNodes() {
        lifeNodes.forEach { $0.removeFromParent() }
        lifeNodes = []
        for index in 0..<startingLives {
            let node = SKSpriteNode(texture: texture(named: "life.gif"))
            node.size = CGSize(width: 24, height: 24)
            node.position = CGPoint(x: 506 + CGFloat(index) * 26, y: 426)
            node.zPosition = 12
            uiLayer.addChild(node)
            lifeNodes.append(node)
        }
        updateLifeNodes()
    }

    private func buildMenu() {
        menuLayer.zPosition = 200
        menuLayer.isHidden = true

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = NSColor(calibratedWhite: 0, alpha: 0.58)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dim.zPosition = -1
        menuLayer.addChild(dim)

        menuTitleLabel.fontSize = 32
        menuTitleLabel.fontColor = .white
        menuTitleLabel.position = CGPoint(x: size.width / 2, y: 410)
        menuTitleLabel.text = "Frozen Bubble"
        menuLayer.addChild(menuTitleLabel)

        for (index, _) in MenuItem.allCases.enumerated() {
            let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
            label.fontSize = 22
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: size.width / 2, y: 350 - CGFloat(index) * 32)
            menuLayer.addChild(label)
            menuLabels.append(label)
        }

        creditsLabel.fontSize = 15
        creditsLabel.fontColor = .white
        creditsLabel.numberOfLines = 0
        creditsLabel.preferredMaxLayoutWidth = 520
        creditsLabel.horizontalAlignmentMode = .center
        creditsLabel.verticalAlignmentMode = .center
        creditsLabel.position = CGPoint(x: size.width / 2, y: 230)
        creditsLabel.isHidden = true
        menuLayer.addChild(creditsLabel)
    }

    private func showMenu() {
        state = .menu
        pressedKeyCodes.removeAll()
        movingBubble = nil
        preferences.recordRunScore(runScore)
        menuLayer.isHidden = false
        creditsLabel.isHidden = true
        menuLabels.forEach { $0.isHidden = false }
        menuTitleLabel.text = "Frozen Bubble"
        applyAudioPreferences()
        soundPlayer.playMusic(.intro)
        updateMenuLabels()
    }

    private func showCredits() {
        state = .credits
        menuLayer.isHidden = false
        menuLabels.forEach { $0.isHidden = true }
        menuTitleLabel.text = "Credits"
        creditsLabel.isHidden = false
        creditsLabel.text = """
        Design & Spielidee
        Guillaume Cottenceau

        Artwork
        Alexis Younes
        Amaury Amblard-Ladurantie

        Soundtrack
        Matthias Le Bidan

        Swift Revival
        Ministry of Code Crew
        Steffi & Codex

        press space
        """
    }

    private func handleMenuKey(_ event: NSEvent) {
        switch event.keyCode {
        case 126:
            selectedMenuIndex = (selectedMenuIndex - 1 + MenuItem.allCases.count) % MenuItem.allCases.count
            soundPlayer.play(.typewriter)
            updateMenuLabels()
        case 125:
            selectedMenuIndex = (selectedMenuIndex + 1) % MenuItem.allCases.count
            soundPlayer.play(.typewriter)
            updateMenuLabels()
        case 36, 49:
            activateSelectedMenuItem()
        case 53:
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }

    private func activateSelectedMenuItem() {
        switch MenuItem.allCases[selectedMenuIndex] {
        case .resume:
            runScore = 0
            lives = startingLives
            startLevel(preferences.lastReachedLevel, resetRunScore: true)
        case .newGame:
            preferences.resetRun()
            startLevel(0, resetRunScore: true)
        case .sound:
            preferences.soundEnabled.toggle()
            applyAudioPreferences()
            updateMenuLabels()
        case .music:
            preferences.musicEnabled.toggle()
            applyAudioPreferences()
            if preferences.musicEnabled {
                soundPlayer.playMusic(.intro, restart: true)
            }
            updateMenuLabels()
        case .colorBlind:
            preferences.colorBlindEnabled.toggle()
            updateMenuLabels()
        case .rushMe:
            preferences.rushMeEnabled.toggle()
            updateMenuLabels()
        case .credits:
            showCredits()
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }

    private func updateMenuLabels() {
        for (index, item) in MenuItem.allCases.enumerated() {
            let selected = index == selectedMenuIndex
            menuLabels[index].fontColor = selected ? .systemYellow : .white
            menuLabels[index].text = (selected ? "> " : "  ") + menuTitle(for: item)
        }
    }

    private func menuTitle(for item: MenuItem) -> String {
        switch item {
        case .resume:
            return "resume level \(preferences.lastReachedLevel + 1)"
        case .newGame:
            return "new game"
        case .sound:
            return "sound \(preferences.soundEnabled ? "on" : "off")"
        case .music:
            return "music \(preferences.musicEnabled ? "on" : "off")"
        case .colorBlind:
            return "colorblind \(preferences.colorBlindEnabled ? "on" : "off")"
        case .rushMe:
            return "rushMe \(preferences.rushMeEnabled ? "on" : "off")"
        case .credits:
            return "credits"
        case .quit:
            return "quit"
        }
    }

    private func applyAudioPreferences() {
        soundPlayer.soundEnabled = preferences.soundEnabled
        soundPlayer.musicEnabled = preferences.musicEnabled
    }

    private func updateLifeNodes() {
        for (index, node) in lifeNodes.enumerated() {
            node.alpha = index < lives ? 1 : 0.2
        }
    }

    private func addScore(_ points: Int) {
        guard points > 0 else { return }
        levelScore += points
        runScore += points
    }

    private func setHUDText(_ label: BitmapTextNode?, _ text: String) {
        label?.setText(text)
    }

    private func updateHurryWarning(delta: TimeInterval) {
        hurryWarningCooldown = max(0, hurryWarningCooldown - delta)
        guard hurryWarningCooldown == 0 else { return }
        guard lowestBubbleY <= loseCenterY + rowSpacing * hurryWarningRows else { return }

        soundPlayer.play(.hurry)
        hurryWarningCooldown = 2.2
    }

    private func updateRushMe(delta: TimeInterval) {
        guard preferences.rushMeEnabled, movingBubble == nil else { return }
        idleTime += delta

        if idleTime >= 8, !rushWarningIssued {
            soundPlayer.play(.hurry)
            setHUDText(messageLabel, "hurry")
            rushWarningIssued = true
        }

        if idleTime >= 14 {
            setHUDText(messageLabel, "")
            fire()
        }
    }

    private var bubbleCount: Int {
        grid.flatMap { $0 }.compactMap { $0 }.count
    }

    private var lowestBubbleY: CGFloat {
        var lowest = CGFloat.greatestFiniteMagnitude
        for column in 0..<columns {
            for row in 0..<gridRows where grid[column][row] != nil {
                lowest = min(lowest, position(for: GridPoint(column: column, row: row)).y)
            }
        }
        return lowest
    }

    private var hasBubbleBelowLimit: Bool {
        for column in 0..<columns {
            for row in 0..<gridRows where grid[column][row] != nil {
                if position(for: GridPoint(column: column, row: row)).y <= loseCenterY {
                    return true
                }
            }
        }
        return false
    }

    private func availableColors() -> [BubbleColor] {
        let colors = Set(grid.flatMap { $0 }.compactMap { $0?.color })
        return BubbleColor.allCases.filter { colors.contains($0) }
    }

    private func nextAvailableColor() -> BubbleColor {
        availableColors().randomElement() ?? .blue
    }

    private func nextLevelIndex(after index: Int) -> Int {
        guard !loadedLevels.isEmpty else { return 0 }
        return (index + 1) % loadedLevels.count
    }

    private func contains(_ point: GridPoint) -> Bool {
        point.column >= 0 && point.column < columns && point.row >= 0 && point.row < gridRows
    }

    private func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private func loadTextures() {
        hudFontTexture = texture(named: "bubbleFont.gif")
        for color in BubbleColor.allCases {
            textures[color] = texture(named: "bubble-\(color.rawValue + 1).gif")
            colorBlindTextures[color] = texture(named: "bubble-colourblind-\(color.rawValue + 1).gif")
            frozenTextures[color] = texture(named: "frozen-\(color.rawValue + 1).gif")
        }
    }

    private func loadPenguinFrames() {
        guard let sheet = texture(named: "penguins.jpg") else { return }
        penguinFrames = []
        for row in 0..<5 {
            for column in 0..<4 {
                let rect = CGRect(
                    x: CGFloat(column) / 4,
                    y: 1 - CGFloat(row + 1) / 5,
                    width: 1 / 4,
                    height: 1 / 5
                )
                penguinFrames.append(SKTexture(rect: rect, in: sheet))
            }
        }
    }

    private func texture(named name: String) -> SKTexture? {
        guard let url = GameResources.bundle.url(forResource: name, withExtension: nil, subdirectory: "Resources/Images"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return SKTexture(image: image)
    }

    private func loadLevels() {
        guard let url = GameResources.bundle.url(forResource: "levels", withExtension: "txt", subdirectory: "Resources/Data"),
              let text = try? String(contentsOf: url) else {
            loadedLevels = [emptyLevel()]
            return
        }

        loadedLevels = text
            .components(separatedBy: "\n\n")
            .map { parseLevel($0) }
            .filter { !$0.isEmpty }

        if loadedLevels.isEmpty {
            loadedLevels = [emptyLevel()]
        }
    }

    private func parseLevel(_ text: String) -> [[BubbleColor?]] {
        var rows = emptyLevel()
        var column = 0
        var row = 0

        for character in text {
            guard row < visibleRows else { break }

            if let value = character.wholeNumberValue, let color = BubbleColor(rawValue: value) {
                rows[row][column] = color
                column += 1
            } else if character == "-" {
                rows[row][column] = nil
                column += 1
            } else {
                continue
            }

            if column == columns {
                row += 1
                guard row < visibleRows else { break }
                column = row % 2
            }
        }

        return rows
    }

    private func emptyLevel() -> [[BubbleColor?]] {
        Array(repeating: Array(repeating: nil, count: columns), count: visibleRows)
    }

    private func fallbackColor(for color: BubbleColor) -> NSColor {
        switch color {
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .red: return .systemRed
        case .yellow: return .systemYellow
        case .purple: return .systemPurple
        case .cyan: return .systemCyan
        case .orange: return .systemOrange
        case .white: return .white
        }
    }
}
