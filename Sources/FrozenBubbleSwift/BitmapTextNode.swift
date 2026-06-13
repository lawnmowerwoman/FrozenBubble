import SpriteKit

final class BitmapTextNode: SKNode {
    enum Alignment {
        case left
        case center
        case right
    }

    private static let characters: [Character] = [
        "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*",
        "+", ",", "-", ".", "/", "0", "1", "2", "3", "4",
        "5", "6", "7", "8", "9", ":", ";", "<", "=", ">",
        "?", "@", "a", "b", "c", "d", "e", "f", "g", "h",
        "i", "j", "k", "l", "m", "n", "o", "p", "q", "r",
        "s", "t", "u", "v", "w", "x", "y", "z", "|", "{",
        "}", "[", "]", "\\"
    ]

    private static let positions: [CGFloat] = [
        0, 9, 16, 31, 39, 54, 69, 73, 80, 88, 96, 116, 121, 131,
        137, 154, 165, 175, 187, 198, 210, 223, 234, 246, 259,
        271, 276, 282, 293, 313, 324, 336, 351, 360, 370, 381,
        390, 402, 411, 421, 435, 446, 459, 472, 483, 495, 508,
        517, 527, 538, 552, 565, 578, 589, 602, 616, 631, 645,
        663, 684, 700, 716, 732, 748, 764, 780, 796, 812
    ]

    private let texture: SKTexture
    private let textureWidth: CGFloat
    private let glyphHeight: CGFloat
    private let alignment: Alignment
    private let scale: CGFloat
    private let spacing: CGFloat
    private var textValue = ""

    init(texture: SKTexture, scale: CGFloat = 1, alignment: Alignment = .left, spacing: CGFloat = 1) {
        self.texture = texture
        self.textureWidth = texture.size().width
        self.glyphHeight = texture.size().height
        self.alignment = alignment
        self.scale = scale
        self.spacing = spacing
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String) {
        guard text != textValue else { return }
        textValue = text
        removeAllChildren()

        var glyphs: [(texture: SKTexture, width: CGFloat)] = []
        var totalWidth: CGFloat = 0

        for character in text.lowercased() {
            if character == " " {
                totalWidth += 8 * scale
                continue
            }

            guard let glyph = glyphTexture(for: character) else { continue }
            glyphs.append(glyph)
            totalWidth += glyph.width * scale + spacing
        }

        if !glyphs.isEmpty {
            totalWidth -= spacing
        }

        var cursor: CGFloat
        switch alignment {
        case .left:
            cursor = 0
        case .center:
            cursor = -totalWidth / 2
        case .right:
            cursor = -totalWidth
        }

        for character in text.lowercased() {
            if character == " " {
                cursor += 8 * scale
                continue
            }

            guard let glyph = glyphTexture(for: character) else { continue }
            let node = SKSpriteNode(texture: glyph.texture)
            node.anchorPoint = CGPoint(x: 0, y: 0.5)
            node.size = CGSize(width: glyph.width * scale, height: glyphHeight * scale)
            node.position = CGPoint(x: cursor, y: 0)
            addChild(node)
            cursor += glyph.width * scale + spacing
        }
    }

    private func glyphTexture(for character: Character) -> (texture: SKTexture, width: CGFloat)? {
        let normalized = Character(String(character).lowercased())
        guard let index = Self.characters.firstIndex(of: normalized), index + 1 < Self.positions.count else {
            return nil
        }

        let start = Self.positions[index]
        let end = Self.positions[index + 1]
        let width = end - start
        let rect = CGRect(x: start / textureWidth, y: 0, width: width / textureWidth, height: 1)
        return (SKTexture(rect: rect, in: texture), width)
    }
}
