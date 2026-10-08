#!/usr/bin/env python3
"""Compile the USER'S SVG originals into a SwiftUI vector rig and reference poses.

python3 tools/GenerateMascot.py --import-source path/to/originals
python3 tools/GenerateMascot.py
python3 tools/GenerateMascot.py --check

The import copies the two originals byte-for-byte; it NEVER edits the input files.
Supports nested groups, inherited paint, circles and absolute M/L/C/Q/Z paths.
No runtime parser, raster images, dependencies, or invented character contours.
"""
import argparse
import copy
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "design-system/exammaster/mascot"
SOURCE = BASE / "source"
NS = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", NS[1:-1])
PARTS = {
    "chick": {
        "chickFeet": ["chick_feet"], "chickWingLeft": ["wing_left"], "chickWingRight": ["wing_right"],
        "chickBody": ["chick_body"], "chickFluff": ["chick_fluff"],
        "chickEyes": ["eye_left", "eye_right"], "chickCheeks": ["cheek_left", "cheek_right"],
        "chickBeak": ["beak"], "chickMouth": ["mouth"],
    },
    "chicken": {
        "chickenTail": ["tail"], "chickenLegs": ["legs"], "chickenFeet": ["feet"],
        "chickenBody": ["body"], "chickenShoulderLeft": ["shoulder_left"],
        "chickenShoulderRight": ["shoulder_right"], "chickenForearmLeft": ["forearm_left"],
        "chickenForearmRight": ["forearm_right"], "chickenChest": ["chest"], "chickenAbs": ["abs"],
        "chickenHead": ["head"], "chickenComb": ["comb"],
        "chickenEyes": ["eye_left", "eye_right"], "chickenCheeks": ["cheek_left", "cheek_right"],
        "chickenBeak": ["beak"], "chickenMouth": ["mouth"],
    },
}
# Intermediate stages transform original parts only; the endpoint shapes are untouched.
STAGES = {
    "chick": {"kind": "chick", "scale": 1, "wingScale": 1, "absOpacity": 0},
    "growingChick": {"kind": "chick", "scale": 1.1, "wingScale": 1.18, "absOpacity": 0},
    "youngChicken": {"kind": "chicken", "scale": 0.92, "wingScale": 0.85, "absOpacity": 0.45},
    "chicken": {"kind": "chicken", "scale": 1, "wingScale": 1, "absOpacity": 1},
}
POSES = {
    "ready": (0, 0, 1, 0),
    "encourage": (4, 2, 0.85, 0),
    "celebrate": (8, -3, 0.72, 0),
    "review": (0, -5, 1, 2),
    "recover": (0, 2, 1, 0),
    "rest": (-2, 0, 0.12, 0),
}
PAINT = ("fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "opacity")
CHICKEN_BASE_FILL = "#FFF3DA"
FACE_PARTS = ("chickenHead", "chickenComb", "chickenEyes", "chickenCheeks", "chickenBeak", "chickenMouth")


def commands(data):
    tokens = re.findall(r"[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|[A-Za-z]", data)
    index = 0
    for_count = {"M": 2, "L": 2, "Q": 4, "C": 6, "Z": 0}
    while index < len(tokens):
        op = tokens[index]
        if op not in for_count: raise ValueError(f"Unsupported/implicit SVG command: {op}")
        count = for_count[op]
        values = tokens[index + 1:index + 1 + count]
        if len(values) != count: raise ValueError("Incomplete SVG path")
        yield op, values
        index += count + 1


def read_parts(file, mapping):
    root = ET.parse(file).getroot()
    if root.attrib.get("viewBox") != "0 0 256 256": raise ValueError(f"Unexpected artboard: {file}")
    nodes = {}

    def visit(node, inherited):
        tag = node.tag.removeprefix(NS)
        if tag not in {"svg", "g", "path", "circle", "title", "desc"}: raise ValueError(f"Unsupported SVG element: {tag}")
        if "transform" in node.attrib: raise ValueError("Source transforms require explicit compiler support")
        attrs = {**inherited, **{k: v for k, v in node.attrib.items() if k in PAINT}}
        shapes = []
        if tag in {"path", "circle"}:
            shape = copy.deepcopy(node)
            shape.attrib.update(attrs)
            shapes.append(shape)
        for child in node: shapes.extend(visit(child, attrs))
        if "id" in node.attrib:
            if node.attrib["id"] in nodes: raise ValueError("Duplicate source ID")
            nodes[node.attrib["id"]] = shapes
        return shapes

    visit(root, {"fill": "black", "stroke": "none"})
    return {name: [copy.deepcopy(shape) for ident in ids for shape in nodes[ident]] for name, ids in mapping.items()}


def native_path(shape):
    attrs = shape.attrib
    if shape.tag == f"{NS}circle":
        x, y, r = (float(attrs[key]) for key in ("cx", "cy", "r"))
        return [f"            let path = Path(ellipseIn: CGRect(x: {x-r:g}, y: {y-r:g}, width: {r*2:g}, height: {r*2:g}))"]
    lines = ["            var path = Path()"]
    for op, v in commands(attrs["d"]):
        point = lambda i: f"CGPoint(x: {v[i]}, y: {v[i+1]})"
        if op == "M": lines.append(f"            path.move(to: {point(0)})")
        elif op == "L": lines.append(f"            path.addLine(to: {point(0)})")
        elif op == "Q": lines.append(f"            path.addQuadCurve(to: {point(2)}, control: {point(0)})")
        elif op == "C": lines.append(f"            path.addCurve(to: {point(4)}, control1: {point(0)}, control2: {point(2)})")
        else: lines.append("            path.closeSubpath()")
    return lines


def native_color(value):
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", value): raise ValueError(f"Unsupported source paint: {value}")
    channels = [int(value[i:i+2], 16) for i in (1, 3, 5)]
    return f"Color(red: {channels[0]} / 255.0, green: {channels[1]} / 255.0, blue: {channels[2]} / 255.0)"


def native_source(parts):
    lines = ["// Generated from the user's source/hiyoko.svg and source/niwatori.svg.",
             "// Run tools/GenerateMascot.py; do not hand-edit the geometry.", "import SwiftUI", "", "enum TankeiArtwork {",
             "    private struct VectorShape {", "        let path: Path", "        let fill: Color?", "        let usesBaseColor: Bool", "        let stroke: Color?", "        let style: StrokeStyle", "    }", "",
             "    private static func draw(_ shapes: [VectorShape], in context: inout GraphicsContext, baseColor: Color?) {",
             "        for shape in shapes {", "            if let fill = (shape.usesBaseColor ? baseColor : nil) ?? shape.fill { context.fill(shape.path, with: .color(fill)) }",
             "            if let stroke = shape.stroke { context.stroke(shape.path, with: .color(stroke), style: shape.style) }", "        }", "    }", ""]
    for mapping in parts.values():
        for name, shapes in mapping.items():
            lines += [f"    static func {name}(_ context: inout GraphicsContext, baseColor: Color? = nil) {{ draw({name}Shapes, in: &context, baseColor: baseColor) }}",
                      f"    private static let {name}Shapes: [VectorShape] = {{", "        var shapes: [VectorShape] = []"]
            for shape in shapes:
                a = shape.attrib
                lines += ["        do {"] + native_path(shape)
                paints = {key: "nil" if a.get(key, "none") == "none" else native_color(a[key]) for key in ("fill", "stroke")}
                cap, join = a.get("stroke-linecap", "butt"), a.get("stroke-linejoin", "miter")
                uses_base = "true" if name.startswith("chicken") and a.get("fill") == CHICKEN_BASE_FILL else "false"
                lines.append(f"            shapes.append(VectorShape(path: path, fill: {paints['fill']}, usesBaseColor: {uses_base}, stroke: {paints['stroke']}, style: StrokeStyle(lineWidth: {a.get('stroke-width', '1')}, lineCap: .{cap}, lineJoin: .{join})))")
                lines += ["        }"]
            lines += ["        return shapes", "    }()", ""]
    lines += ["    static func proportions(_ stage: TankeiStage) -> (scale: CGFloat, wingScale: CGFloat, absOpacity: Double) {", "        switch stage {"]
    for name, info in STAGES.items():
        lines.append(f"        case .{name}: ({info['scale']}, {info['wingScale']}, {info['absOpacity']})")
    lines += ["        }", "    }", "", "    static func pose(_ state: TankeiState) -> (wing: Double, head: Double, eyes: CGFloat, gaze: CGFloat) {", "        switch state {"]
    for state, values in POSES.items(): lines.append(f"        case .{state}: ({', '.join(str(v) for v in values)})")
    lines += ["        }", "    }", "}", ""]
    return "\n".join(lines)


def transformed(angle, x, y, scale=1, sy=None):
    return f"translate({x} {y}) rotate({angle}) scale({scale} {sy if sy is not None else scale}) translate({-x} {-y})"


def pose_svg(parts, stage, state, compact=False, silhouette=False):
    info = STAGES[stage]
    wing, nod, eyes, gaze = POSES[state]
    chick = info["kind"] == "chick"
    bottom = 210 if chick else 225
    root = ET.Element(f"{NS}svg", {"viewBox": "0 0 256 256", "fill": "none"})
    ET.SubElement(root, f"{NS}title").text = f"学習の相棒 / {stage} / {state}"
    rig = ET.SubElement(root, f"{NS}g", {"id": "root-rig", "transform": transformed(0, 128, bottom, info["scale"])})

    def part(name, parent=rig, transform=None, opacity=None):
        attrs = {"id": name}
        if transform: attrs["transform"] = transform
        if opacity is not None: attrs["opacity"] = str(opacity)
        group = ET.SubElement(parent, f"{NS}g", attrs)
        for original in parts[info["kind"]][name]:
            shape = copy.deepcopy(original)
            if silhouette:
                if shape.attrib.get("fill", "none") == "none": continue
                shape.set("fill", "#243B3A")
                if shape.attrib.get("stroke", "none") != "none": shape.set("stroke", "#243B3A")
            group.append(shape)
        return group

    if chick:
        part("chickFeet")
        body_rig = ET.SubElement(rig, f"{NS}g", {"id": "body-rig", "transform": transformed(nod, 128, 183)})
        part("chickWingLeft", body_rig, transformed(wing, 78, 144, info["wingScale"]))
        part("chickWingRight", body_rig, transformed(-wing, 178, 144, info["wingScale"]))
        part("chickBody", body_rig)
        part("chickFluff", body_rig)
        part("chickEyes", body_rig, f"translate(0 {gaze}) " + transformed(0, 128, 124, 1, eyes))
        if not compact: part("chickCheeks", body_rig)
        part("chickBeak", body_rig)
        part("chickMouth", body_rig)
    else:
        part("chickenTail")
        part("chickenLegs")
        part("chickenFeet")
        part("chickenBody")
        part("chickenShoulderLeft")
        part("chickenForearmLeft", transform=transformed(wing, 89, 126, info["wingScale"]))
        part("chickenShoulderRight")
        part("chickenForearmRight", transform=transformed(-wing, 167, 126, info["wingScale"]))
        if not compact:
            part("chickenChest")
            part("chickenAbs", opacity=info["absOpacity"])
        head_rig = ET.SubElement(rig, f"{NS}g", {"id": "head-rig", "transform": transformed(nod, 128, 122)})
        part("chickenHead", head_rig)
        part("chickenComb", head_rig)
        part("chickenEyes", head_rig, f"translate(0 {gaze}) " + transformed(0, 128, 87, 1, eyes))
        if not compact: part("chickenCheeks", head_rig)
        part("chickenBeak", head_rig)
        part("chickenMouth", head_rig)
    return ET.tostring(root, encoding="unicode") + "\n"


def build_outputs():
    files = {"chick": SOURCE / "hiyoko.svg", "chicken": SOURCE / "niwatori.svg"}
    parts = {kind: read_parts(file, PARTS[kind]) for kind, file in files.items()}
    outputs = {ROOT / "Views/Mascot/TankeiArtwork.swift": native_source(parts)}
    face = {"baseFill": CHICKEN_BASE_FILL, "shapes": [
        {"type": shape.tag.removeprefix(NS), **shape.attrib}
        for name in FACE_PARTS for shape in parts["chicken"][name]
    ]}
    outputs[BASE / "chicken-face.json"] = json.dumps(face, ensure_ascii=False, indent=2) + "\n"
    for stage in STAGES:
        for state in POSES:
            outputs[BASE / "growth-poses" / f"{stage}-{state}.svg"] = pose_svg(parts, stage, state)
    for stage in ("chick", "chicken"):
        outputs[BASE / f"{stage}-compact.svg"] = pose_svg(parts, stage, "ready", compact=True)
        outputs[BASE / f"{stage}-silhouette.svg"] = pose_svg(parts, stage, "ready", compact=True, silhouette=True)
    manifest = {
        "source": {file.name: hashlib.sha256(file.read_bytes()).hexdigest() for file in files.values()},
        "artboard": [256, 256], "stages": STAGES, "poses": POSES,
        "parts": PARTS,
        "pivots": {"chickRoot": [128, 210], "chickBody": [128, 183], "chickWingLeft": [78, 144],
                   "chickWingRight": [178, 144], "chickenRoot": [128, 225], "chickenHead": [128, 122],
                   "chickenForearmLeft": [89, 126], "chickenForearmRight": [167, 126]},
    }
    outputs[BASE / "rig.json"] = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--import-source", type=Path, help="Copy the two supplied SVG files, unchanged")
    args = parser.parse_args()
    if args.check and args.import_source: parser.error("--check cannot import/modify files")
    if args.import_source:
        SOURCE.mkdir(parents=True, exist_ok=True)
        for name in ("hiyoko.svg", "niwatori.svg"):
            (SOURCE / name).write_bytes((args.import_source / name).read_bytes())
    outputs = build_outputs()
    mismatches = []
    for path, content in outputs.items():
        if args.check:
            if not path.exists() or path.read_text() != content: mismatches.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    if mismatches: raise SystemExit("Generated mascot files drift: " + ", ".join(mismatches))
    print(f"{'Verified' if args.check else 'Generated'} {len(outputs)} files from the user's originals.")


if __name__ == "__main__": main()
