// Generated from the user's source/hiyoko.svg and source/niwatori.svg.
// Run tools/GenerateMascot.py; do not hand-edit the geometry.
import SwiftUI

enum TankeiArtwork {
    private struct VectorShape {
        let path: Path
        let fill: Color?
        let usesBaseColor: Bool
        let stroke: Color?
        let style: StrokeStyle
    }

    private static func draw(_ shapes: [VectorShape], in context: inout GraphicsContext, baseColor: Color?) {
        for shape in shapes {
            if let fill = (shape.usesBaseColor ? baseColor : nil) ?? shape.fill { context.fill(shape.path, with: .color(fill)) }
            if let stroke = shape.stroke { context.stroke(shape.path, with: .color(stroke), style: shape.style) }
        }
    }

    static func chickFeet(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickFeetShapes, in: &context, baseColor: baseColor) }
    private static let chickFeetShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 104, y: 195))
            path.addLine(to: CGPoint(x: 95, y: 210))
            path.addLine(to: CGPoint(x: 115, y: 210))
            path.addQuadCurve(to: CGPoint(x: 120, y: 205), control: CGPoint(x: 120, y: 210))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 242 / 255.0, green: 181 / 255.0, blue: 68 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 152, y: 195))
            path.addLine(to: CGPoint(x: 161, y: 210))
            path.addLine(to: CGPoint(x: 141, y: 210))
            path.addQuadCurve(to: CGPoint(x: 136, y: 205), control: CGPoint(x: 136, y: 210))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 242 / 255.0, green: 181 / 255.0, blue: 68 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickWingLeft(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickWingLeftShapes, in: &context, baseColor: baseColor) }
    private static let chickWingLeftShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 80, y: 135))
            path.addQuadCurve(to: CGPoint(x: 52, y: 162), control: CGPoint(x: 48, y: 142))
            path.addQuadCurve(to: CGPoint(x: 80, y: 158), control: CGPoint(x: 64, y: 174))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 226 / 255.0, blue: 89 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickWingRight(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickWingRightShapes, in: &context, baseColor: baseColor) }
    private static let chickWingRightShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 176, y: 135))
            path.addQuadCurve(to: CGPoint(x: 204, y: 162), control: CGPoint(x: 208, y: 142))
            path.addQuadCurve(to: CGPoint(x: 176, y: 158), control: CGPoint(x: 192, y: 174))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 226 / 255.0, blue: 89 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickBody(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickBodyShapes, in: &context, baseColor: baseColor) }
    private static let chickBodyShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 128, y: 78))
            path.addQuadCurve(to: CGPoint(x: 184, y: 135), control: CGPoint(x: 182, y: 78))
            path.addQuadCurve(to: CGPoint(x: 128, y: 195), control: CGPoint(x: 186, y: 195))
            path.addQuadCurve(to: CGPoint(x: 72, y: 135), control: CGPoint(x: 70, y: 195))
            path.addQuadCurve(to: CGPoint(x: 128, y: 78), control: CGPoint(x: 74, y: 78))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 226 / 255.0, blue: 89 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickFluff(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickFluffShapes, in: &context, baseColor: baseColor) }
    private static let chickFluffShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 125, y: 78))
            path.addQuadCurve(to: CGPoint(x: 116, y: 60), control: CGPoint(x: 121, y: 64))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 128, y: 78))
            path.addQuadCurve(to: CGPoint(x: 139, y: 59), control: CGPoint(x: 132, y: 63))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickEyes(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickEyesShapes, in: &context, baseColor: baseColor) }
    private static let chickEyesShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            let path = Path(ellipseIn: CGRect(x: 109.5, y: 119.5, width: 9, height: 9))
            shapes.append(VectorShape(path: path, fill: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        do {
            let path = Path(ellipseIn: CGRect(x: 137.5, y: 119.5, width: 9, height: 9))
            shapes.append(VectorShape(path: path, fill: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickCheeks(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickCheeksShapes, in: &context, baseColor: baseColor) }
    private static let chickCheeksShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            let path = Path(ellipseIn: CGRect(x: 96, y: 127, width: 12, height: 12))
            shapes.append(VectorShape(path: path, fill: Color(red: 247 / 255.0, green: 163 / 255.0, blue: 141 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        do {
            let path = Path(ellipseIn: CGRect(x: 148, y: 127, width: 12, height: 12))
            shapes.append(VectorShape(path: path, fill: Color(red: 247 / 255.0, green: 163 / 255.0, blue: 141 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickBeak(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickBeakShapes, in: &context, baseColor: baseColor) }
    private static let chickBeakShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 115, y: 132))
            path.addQuadCurve(to: CGPoint(x: 141, y: 132), control: CGPoint(x: 128, y: 123))
            path.addQuadCurve(to: CGPoint(x: 115, y: 132), control: CGPoint(x: 128, y: 141))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 242 / 255.0, green: 181 / 255.0, blue: 68 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 5, lineCap: .butt, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickMouth(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickMouthShapes, in: &context, baseColor: baseColor) }
    private static let chickMouthShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 121, y: 143))
            path.addQuadCurve(to: CGPoint(x: 135, y: 143), control: CGPoint(x: 128, y: 148))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickenTail(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenTailShapes, in: &context, baseColor: baseColor) }
    private static let chickenTailShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 174, y: 158))
            path.addQuadCurve(to: CGPoint(x: 191, y: 161), control: CGPoint(x: 188, y: 151))
            path.addQuadCurve(to: CGPoint(x: 178, y: 178), control: CGPoint(x: 193, y: 173))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenLegs(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenLegsShapes, in: &context, baseColor: baseColor) }
    private static let chickenLegsShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 108, y: 188))
            path.addQuadCurve(to: CGPoint(x: 101, y: 211), control: CGPoint(x: 99, y: 196))
            path.addLine(to: CGPoint(x: 114, y: 211))
            path.addQuadCurve(to: CGPoint(x: 119, y: 191), control: CGPoint(x: 115, y: 199))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 148, y: 188))
            path.addQuadCurve(to: CGPoint(x: 155, y: 211), control: CGPoint(x: 157, y: 196))
            path.addLine(to: CGPoint(x: 142, y: 211))
            path.addQuadCurve(to: CGPoint(x: 137, y: 191), control: CGPoint(x: 141, y: 199))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenFeet(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenFeetShapes, in: &context, baseColor: baseColor) }
    private static let chickenFeetShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 100, y: 211))
            path.addLine(to: CGPoint(x: 95, y: 225))
            path.addLine(to: CGPoint(x: 114, y: 225))
            path.addQuadCurve(to: CGPoint(x: 120, y: 221), control: CGPoint(x: 120, y: 225))
            path.addQuadCurve(to: CGPoint(x: 113, y: 215), control: CGPoint(x: 120, y: 217))
            path.addLine(to: CGPoint(x: 109, y: 211))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 242 / 255.0, green: 181 / 255.0, blue: 68 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 156, y: 211))
            path.addLine(to: CGPoint(x: 161, y: 225))
            path.addLine(to: CGPoint(x: 142, y: 225))
            path.addQuadCurve(to: CGPoint(x: 136, y: 221), control: CGPoint(x: 136, y: 225))
            path.addQuadCurve(to: CGPoint(x: 143, y: 215), control: CGPoint(x: 136, y: 217))
            path.addLine(to: CGPoint(x: 147, y: 211))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 242 / 255.0, green: 181 / 255.0, blue: 68 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenBody(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenBodyShapes, in: &context, baseColor: baseColor) }
    private static let chickenBodyShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 89, y: 112))
            path.addQuadCurve(to: CGPoint(x: 128, y: 98), control: CGPoint(x: 100, y: 98))
            path.addQuadCurve(to: CGPoint(x: 167, y: 112), control: CGPoint(x: 156, y: 98))
            path.addQuadCurve(to: CGPoint(x: 177, y: 149), control: CGPoint(x: 177, y: 124))
            path.addQuadCurve(to: CGPoint(x: 164, y: 191), control: CGPoint(x: 177, y: 176))
            path.addQuadCurve(to: CGPoint(x: 128, y: 206), control: CGPoint(x: 151, y: 206))
            path.addQuadCurve(to: CGPoint(x: 92, y: 191), control: CGPoint(x: 105, y: 206))
            path.addQuadCurve(to: CGPoint(x: 79, y: 149), control: CGPoint(x: 79, y: 176))
            path.addQuadCurve(to: CGPoint(x: 89, y: 112), control: CGPoint(x: 79, y: 124))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenShoulderLeft(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenShoulderLeftShapes, in: &context, baseColor: baseColor) }
    private static let chickenShoulderLeftShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 57, y: 121))
            path.addQuadCurve(to: CGPoint(x: 59, y: 101), control: CGPoint(x: 53, y: 110))
            path.addQuadCurve(to: CGPoint(x: 82, y: 94), control: CGPoint(x: 67, y: 91))
            path.addQuadCurve(to: CGPoint(x: 100, y: 110), control: CGPoint(x: 96, y: 97))
            path.addQuadCurve(to: CGPoint(x: 94, y: 129), control: CGPoint(x: 103, y: 122))
            path.addQuadCurve(to: CGPoint(x: 74, y: 132), control: CGPoint(x: 85, y: 135))
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenShoulderRight(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenShoulderRightShapes, in: &context, baseColor: baseColor) }
    private static let chickenShoulderRightShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 199, y: 121))
            path.addQuadCurve(to: CGPoint(x: 197, y: 101), control: CGPoint(x: 203, y: 110))
            path.addQuadCurve(to: CGPoint(x: 174, y: 94), control: CGPoint(x: 189, y: 91))
            path.addQuadCurve(to: CGPoint(x: 156, y: 110), control: CGPoint(x: 160, y: 97))
            path.addQuadCurve(to: CGPoint(x: 162, y: 129), control: CGPoint(x: 153, y: 122))
            path.addQuadCurve(to: CGPoint(x: 182, y: 132), control: CGPoint(x: 171, y: 135))
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenForearmLeft(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenForearmLeftShapes, in: &context, baseColor: baseColor) }
    private static let chickenForearmLeftShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 89, y: 126))
            path.addQuadCurve(to: CGPoint(x: 57, y: 121), control: CGPoint(x: 72, y: 114))
            path.addQuadCurve(to: CGPoint(x: 43, y: 145), control: CGPoint(x: 42, y: 129))
            path.addQuadCurve(to: CGPoint(x: 58, y: 169), control: CGPoint(x: 44, y: 161))
            path.addQuadCurve(to: CGPoint(x: 89, y: 168), control: CGPoint(x: 74, y: 177))
            path.addQuadCurve(to: CGPoint(x: 101, y: 151), control: CGPoint(x: 98, y: 162))
            path.addQuadCurve(to: CGPoint(x: 97, y: 132), control: CGPoint(x: 104, y: 140))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenForearmRight(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenForearmRightShapes, in: &context, baseColor: baseColor) }
    private static let chickenForearmRightShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 167, y: 126))
            path.addQuadCurve(to: CGPoint(x: 199, y: 121), control: CGPoint(x: 184, y: 114))
            path.addQuadCurve(to: CGPoint(x: 213, y: 145), control: CGPoint(x: 214, y: 129))
            path.addQuadCurve(to: CGPoint(x: 198, y: 169), control: CGPoint(x: 212, y: 161))
            path.addQuadCurve(to: CGPoint(x: 167, y: 168), control: CGPoint(x: 182, y: 177))
            path.addQuadCurve(to: CGPoint(x: 155, y: 151), control: CGPoint(x: 158, y: 162))
            path.addQuadCurve(to: CGPoint(x: 159, y: 132), control: CGPoint(x: 152, y: 140))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenChest(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenChestShapes, in: &context, baseColor: baseColor) }
    private static let chickenChestShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 104, y: 139))
            path.addQuadCurve(to: CGPoint(x: 124, y: 139), control: CGPoint(x: 114, y: 132))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .miter)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 132, y: 139))
            path.addQuadCurve(to: CGPoint(x: 152, y: 139), control: CGPoint(x: 142, y: 132))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickenAbs(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenAbsShapes, in: &context, baseColor: baseColor) }
    private static let chickenAbsShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 128, y: 149))
            path.addLine(to: CGPoint(x: 128, y: 181))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 231 / 255.0, green: 211 / 255.0, blue: 174 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 114, y: 159))
            path.addQuadCurve(to: CGPoint(x: 142, y: 159), control: CGPoint(x: 128, y: 155))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 231 / 255.0, green: 211 / 255.0, blue: 174 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        do {
            var path = Path()
            path.move(to: CGPoint(x: 114, y: 173))
            path.addQuadCurve(to: CGPoint(x: 142, y: 173), control: CGPoint(x: 128, y: 169))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 231 / 255.0, green: 211 / 255.0, blue: 174 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickenHead(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenHeadShapes, in: &context, baseColor: baseColor) }
    private static let chickenHeadShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 93, y: 67))
            path.addQuadCurve(to: CGPoint(x: 128, y: 45), control: CGPoint(x: 96, y: 45))
            path.addQuadCurve(to: CGPoint(x: 163, y: 67), control: CGPoint(x: 160, y: 45))
            path.addLine(to: CGPoint(x: 165, y: 94))
            path.addQuadCurve(to: CGPoint(x: 150, y: 121), control: CGPoint(x: 165, y: 114))
            path.addQuadCurve(to: CGPoint(x: 128, y: 126), control: CGPoint(x: 139, y: 126))
            path.addQuadCurve(to: CGPoint(x: 106, y: 121), control: CGPoint(x: 117, y: 126))
            path.addQuadCurve(to: CGPoint(x: 91, y: 94), control: CGPoint(x: 91, y: 114))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 255 / 255.0, green: 243 / 255.0, blue: 218 / 255.0), usesBaseColor: true, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenComb(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenCombShapes, in: &context, baseColor: baseColor) }
    private static let chickenCombShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 106, y: 49))
            path.addQuadCurve(to: CGPoint(x: 108, y: 31), control: CGPoint(x: 101, y: 36))
            path.addQuadCurve(to: CGPoint(x: 122, y: 37), control: CGPoint(x: 116, y: 26))
            path.addLine(to: CGPoint(x: 124, y: 25))
            path.addQuadCurve(to: CGPoint(x: 135, y: 18), control: CGPoint(x: 126, y: 16))
            path.addQuadCurve(to: CGPoint(x: 143, y: 30), control: CGPoint(x: 144, y: 20))
            path.addLine(to: CGPoint(x: 142, y: 41))
            path.addQuadCurve(to: CGPoint(x: 158, y: 34), control: CGPoint(x: 149, y: 31))
            path.addQuadCurve(to: CGPoint(x: 162, y: 47), control: CGPoint(x: 166, y: 37))
            path.addLine(to: CGPoint(x: 156, y: 56))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 240 / 255.0, green: 109 / 255.0, blue: 94 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenEyes(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenEyesShapes, in: &context, baseColor: baseColor) }
    private static let chickenEyesShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            let path = Path(ellipseIn: CGRect(x: 110.5, y: 82.5, width: 9, height: 9))
            shapes.append(VectorShape(path: path, fill: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        do {
            let path = Path(ellipseIn: CGRect(x: 136.5, y: 82.5, width: 9, height: 9))
            shapes.append(VectorShape(path: path, fill: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickenCheeks(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenCheeksShapes, in: &context, baseColor: baseColor) }
    private static let chickenCheeksShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            let path = Path(ellipseIn: CGRect(x: 97.5, y: 90.5, width: 11, height: 11))
            shapes.append(VectorShape(path: path, fill: Color(red: 247 / 255.0, green: 163 / 255.0, blue: 141 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        do {
            let path = Path(ellipseIn: CGRect(x: 147.5, y: 90.5, width: 11, height: 11))
            shapes.append(VectorShape(path: path, fill: Color(red: 247 / 255.0, green: 163 / 255.0, blue: 141 / 255.0), usesBaseColor: false, stroke: nil, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)))
        }
        return shapes
    }()

    static func chickenBeak(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenBeakShapes, in: &context, baseColor: baseColor) }
    private static let chickenBeakShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 115, y: 95))
            path.addQuadCurve(to: CGPoint(x: 141, y: 95), control: CGPoint(x: 128, y: 86))
            path.addQuadCurve(to: CGPoint(x: 115, y: 95), control: CGPoint(x: 128, y: 104))
            path.closeSubpath()
            shapes.append(VectorShape(path: path, fill: Color(red: 242 / 255.0, green: 181 / 255.0, blue: 68 / 255.0), usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 5, lineCap: .butt, lineJoin: .round)))
        }
        return shapes
    }()

    static func chickenMouth(_ context: inout GraphicsContext, baseColor: Color? = nil) { draw(chickenMouthShapes, in: &context, baseColor: baseColor) }
    private static let chickenMouthShapes: [VectorShape] = {
        var shapes: [VectorShape] = []
        do {
            var path = Path()
            path.move(to: CGPoint(x: 121, y: 106))
            path.addQuadCurve(to: CGPoint(x: 135, y: 106), control: CGPoint(x: 128, y: 111))
            shapes.append(VectorShape(path: path, fill: nil, usesBaseColor: false, stroke: Color(red: 36 / 255.0, green: 59 / 255.0, blue: 58 / 255.0), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .miter)))
        }
        return shapes
    }()

    static func proportions(_ stage: TankeiStage) -> (scale: CGFloat, wingScale: CGFloat, absOpacity: Double) {
        switch stage {
        case .chick: (1, 1, 0)
        case .growingChick: (1.1, 1.18, 0)
        case .youngChicken: (0.92, 0.85, 0.45)
        case .chicken: (1, 1, 1)
        }
    }

    static func pose(_ state: TankeiState) -> (wing: Double, head: Double, eyes: CGFloat, gaze: CGFloat) {
        switch state {
        case .ready: (0, 0, 1, 0)
        case .encourage: (4, 2, 0.85, 0)
        case .celebrate: (8, -3, 0.72, 0)
        case .review: (0, -5, 1, 2)
        case .recover: (0, 2, 1, 0)
        case .rest: (-2, 0, 0.12, 0)
        }
    }
}
