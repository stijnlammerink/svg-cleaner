import Foundation

struct PluginDef: Identifiable {
    let name: String
    let label: String
    let description: String
    let defaultEnabled: Bool

    var id: String { name }
}

struct PluginCategory: Identifiable {
    let id: String
    let label: String
    let plugins: [PluginDef]
}

/// Mirrors the svgomg.net toggles. Defaults follow SVGO's preset-default, except removeViewBox (breaks scaling).
enum PluginCatalog {
    static let categories: [PluginCategory] = [
        PluginCategory(id: "cleanup", label: "Cleanup", plugins: [
            PluginDef(name: "cleanupAttrs", label: "Clean up attribute whitespace", description: "Collapse newlines and repeated spaces in attributes.", defaultEnabled: true),
            PluginDef(name: "cleanupIds", label: "Minify IDs", description: "Remove unused and shorten used element IDs.", defaultEnabled: true),
            PluginDef(name: "cleanupNumericValues", label: "Round/rewrite numbers", description: "Round numeric values to the precision and drop default units.", defaultEnabled: true),
            PluginDef(name: "cleanupEnableBackground", label: "Clean up enable-background", description: "Remove or fix the deprecated enable-background attribute.", defaultEnabled: true),
            PluginDef(name: "convertColors", label: "Minify colors", description: "Convert colors to shorter forms (e.g. #ffffff to #fff).", defaultEnabled: true),
            PluginDef(name: "minifyStyles", label: "Minify styles", description: "Minify <style> contents with CSSO.", defaultEnabled: true),
            PluginDef(name: "inlineStyles", label: "Inline styles", description: "Move <style> rules onto matching element style attributes.", defaultEnabled: true),
            PluginDef(name: "mergeStyles", label: "Merge styles", description: "Merge multiple <style> elements into one.", defaultEnabled: true),
            PluginDef(name: "cleanupListOfValues", label: "Round list values", description: "Round numbers in attributes that hold value lists.", defaultEnabled: false),
        ]),
        PluginCategory(id: "convert", label: "Convert", plugins: [
            PluginDef(name: "convertPathData", label: "Optimize path data", description: "Round and compact path coordinates and commands.", defaultEnabled: true),
            PluginDef(name: "convertTransform", label: "Collapse transforms", description: "Collapse multiple transforms into one and shorten them.", defaultEnabled: true),
            PluginDef(name: "convertShapeToPath", label: "Shapes to paths", description: "Convert basic shapes (rect, line…) to <path>.", defaultEnabled: true),
            PluginDef(name: "convertEllipseToCircle", label: "Ellipse to circle", description: "Convert non-eccentric ellipses to circles.", defaultEnabled: true),
            PluginDef(name: "convertStyleToAttrs", label: "Style to attributes", description: "Convert inline style properties to presentation attributes.", defaultEnabled: false),
        ]),
        PluginCategory(id: "structure", label: "Structure", plugins: [
            PluginDef(name: "collapseGroups", label: "Collapse useless groups", description: "Merge or drop groups that add no value.", defaultEnabled: true),
            PluginDef(name: "mergePaths", label: "Merge paths", description: "Merge adjacent paths that share styling.", defaultEnabled: true),
            PluginDef(name: "moveElemsAttrsToGroup", label: "Move attrs to group", description: "Hoist common attributes onto a parent group.", defaultEnabled: true),
            PluginDef(name: "moveGroupAttrsToElems", label: "Move group attrs to elements", description: "Push group attributes down onto children.", defaultEnabled: true),
            PluginDef(name: "reusePaths", label: "Reuse paths", description: "Replace duplicate paths with <use> references.", defaultEnabled: false),
            PluginDef(name: "sortAttrs", label: "Sort attributes", description: "Sort element attributes for better gzip compression.", defaultEnabled: true),
            PluginDef(name: "sortDefsChildren", label: "Sort <defs> children", description: "Sort children of <defs> for better compression.", defaultEnabled: true),
            PluginDef(name: "prefixIds", label: "Prefix IDs & classes", description: "Prefix IDs/classes to avoid clashes when inlining.", defaultEnabled: false),
        ]),
        PluginCategory(id: "remove", label: "Remove", plugins: [
            PluginDef(name: "removeDoctype", label: "Remove doctype", description: "Remove the <!DOCTYPE> declaration.", defaultEnabled: true),
            PluginDef(name: "removeXMLProcInst", label: "Remove XML instructions", description: "Remove the <?xml?> processing instruction.", defaultEnabled: true),
            PluginDef(name: "removeComments", label: "Remove comments", description: "Remove <!-- --> comments.", defaultEnabled: true),
            PluginDef(name: "removeMetadata", label: "Remove metadata", description: "Remove <metadata> elements.", defaultEnabled: true),
            PluginDef(name: "removeEditorsNSData", label: "Remove editor data", description: "Remove editor namespaces, elements and attributes.", defaultEnabled: true),
            PluginDef(name: "removeTitle", label: "Remove title", description: "Remove <title> elements.", defaultEnabled: true),
            PluginDef(name: "removeDesc", label: "Remove description", description: "Remove <desc> elements.", defaultEnabled: true),
            PluginDef(name: "removeUselessDefs", label: "Remove useless defs", description: "Remove <defs> without IDs.", defaultEnabled: true),
            PluginDef(name: "removeEmptyAttrs", label: "Remove empty attributes", description: "Remove attributes with empty values.", defaultEnabled: true),
            PluginDef(name: "removeHiddenElems", label: "Remove hidden elements", description: "Remove elements hidden by display or zero size.", defaultEnabled: true),
            PluginDef(name: "removeEmptyText", label: "Remove empty text", description: "Remove empty text elements.", defaultEnabled: true),
            PluginDef(name: "removeEmptyContainers", label: "Remove empty containers", description: "Remove containers with no children.", defaultEnabled: true),
            PluginDef(name: "removeUnknownsAndDefaults", label: "Remove unknowns & defaults", description: "Remove unknown elements/attrs and default values.", defaultEnabled: true),
            PluginDef(name: "removeNonInheritableGroupAttrs", label: "Remove non-inheritable group attrs", description: "Remove non-inheritable presentation attrs from groups.", defaultEnabled: true),
            PluginDef(name: "removeUselessStrokeAndFill", label: "Remove useless stroke & fill", description: "Remove stroke/fill attributes that have no effect.", defaultEnabled: true),
            PluginDef(name: "removeUnusedNS", label: "Remove unused namespaces", description: "Remove unused namespace declarations.", defaultEnabled: true),
            PluginDef(name: "removeViewBox", label: "Remove viewBox", description: "Remove viewBox when it matches width/height. Off by default, breaks scaling.", defaultEnabled: false),
            PluginDef(name: "removeDimensions", label: "Prefer viewBox to width/height", description: "Remove hardcoded width/height and keep (or derive) a viewBox so the SVG scales.", defaultEnabled: true),
            PluginDef(name: "removeOffCanvasPaths", label: "Remove off-canvas paths", description: "Remove path shapes outside the viewBox.", defaultEnabled: false),
            PluginDef(name: "removeScriptElement", label: "Remove scripts", description: "Remove <script> elements.", defaultEnabled: false),
            PluginDef(name: "removeStyleElement", label: "Remove style elements", description: "Remove all <style> elements.", defaultEnabled: false),
            PluginDef(name: "removeRasterImages", label: "Remove raster images", description: "Remove embedded raster images (JPEG/PNG…).", defaultEnabled: false),
            PluginDef(name: "removeXMLNS", label: "Remove xmlns", description: "Remove the xmlns attribute (only for inline SVG).", defaultEnabled: false),
        ]),
    ]

    static let all: [PluginDef] = categories.flatMap(\.plugins)

    static let defaultState: [String: Bool] = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0.defaultEnabled) })

    /// Plugins bundled in SVGO 3.3's preset-default; toggled through its overrides instead of listed separately.
    static let presetDefault: Set<String> = [
        "removeDoctype", "removeXMLProcInst", "removeComments", "removeMetadata", "removeEditorsNSData",
        "cleanupAttrs", "mergeStyles", "inlineStyles", "minifyStyles", "cleanupIds", "removeUselessDefs",
        "cleanupNumericValues", "convertColors", "removeUnknownsAndDefaults", "removeNonInheritableGroupAttrs",
        "removeUselessStrokeAndFill", "removeViewBox", "cleanupEnableBackground", "removeHiddenElems",
        "removeEmptyText", "convertShapeToPath", "convertEllipseToCircle", "moveElemsAttrsToGroup",
        "moveGroupAttrsToElems", "collapseGroups", "convertPathData", "convertTransform", "removeEmptyAttrs",
        "removeEmptyContainers", "mergePaths", "removeUnusedNS", "sortAttrs", "sortDefsChildren", "removeTitle",
        "removeDesc",
    ]
}
