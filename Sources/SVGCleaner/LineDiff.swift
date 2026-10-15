import Foundation

struct DiffLine: Identifiable {
    enum Kind: Equatable {
        case context, removed, added
        case collapsed(Int)
    }

    let id: Int
    let kind: Kind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String
}

struct LineDiffResult {
    let lines: [DiffLine]
    let removed: Int
    let added: Int

    var hasChanges: Bool { removed > 0 || added > 0 }
    var maxLineNumber: Int { lines.compactMap { $0.oldNumber ?? $0.newNumber }.max() ?? 0 }
    var maxLineLength: Int { lines.map(\.text.count).max() ?? 0 }
}

/// Line-based diff in git style: removals before insertions, long unchanged runs collapsed.
enum LineDiff {
    static func compute(old: String, new: String, context: Int = 3) -> LineDiffResult {
        let oldLines = splitLines(old)
        let newLines = splitLines(new)

        var removedOffsets = Set<Int>()
        var insertedOffsets = Set<Int>()
        for change in newLines.difference(from: oldLines) {
            switch change {
            case .remove(let offset, _, _): removedOffsets.insert(offset)
            case .insert(let offset, _, _): insertedOffsets.insert(offset)
            }
        }

        var rows: [(kind: DiffLine.Kind, old: Int?, new: Int?, text: String)] = []
        var i = 0
        var j = 0
        while i < oldLines.count || j < newLines.count {
            if i < oldLines.count, removedOffsets.contains(i) {
                rows.append((.removed, i + 1, nil, oldLines[i]))
                i += 1
            } else if j < newLines.count, insertedOffsets.contains(j) {
                rows.append((.added, nil, j + 1, newLines[j]))
                j += 1
            } else if i < oldLines.count, j < newLines.count {
                rows.append((.context, i + 1, j + 1, newLines[j]))
                i += 1
                j += 1
            } else {
                break
            }
        }

        var lines: [DiffLine] = []
        var index = 0
        while index < rows.count {
            guard rows[index].kind == .context else {
                let row = rows[index]
                lines.append(DiffLine(id: lines.count, kind: row.kind, oldNumber: row.old, newNumber: row.new, text: row.text))
                index += 1
                continue
            }
            var end = index
            while end < rows.count, rows[end].kind == .context { end += 1 }

            let keepBefore = index == 0 ? 0 : context
            let keepAfter = end == rows.count ? 0 : context
            let hidden = (end - index) - keepBefore - keepAfter
            for (offset, row) in rows[index..<end].enumerated() {
                let position = index + offset
                let isHidden = hidden > 1 && position >= index + keepBefore && position < end - keepAfter
                if isHidden {
                    if position == index + keepBefore {
                        lines.append(DiffLine(id: lines.count, kind: .collapsed(hidden), oldNumber: nil, newNumber: nil, text: ""))
                    }
                } else {
                    lines.append(DiffLine(id: lines.count, kind: .context, oldNumber: row.old, newNumber: row.new, text: row.text))
                }
            }
            index = end
        }

        return LineDiffResult(lines: lines, removed: removedOffsets.count, added: insertedOffsets.count)
    }

    private static func splitLines(_ text: String) -> [String] {
        let trimmed = text.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .newlines)
        return trimmed.isEmpty ? [] : trimmed.components(separatedBy: "\n")
    }
}
