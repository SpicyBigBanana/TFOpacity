import Cocoa

let yabaiPath = "/opt/homebrew/bin/yabai"

struct WinItem {
    let id: Int
    let app: String
    let title: String
    let opacity: Double
    var label: String {
        let shown: String
        if opacity <= 0 || opacity >= 0.995 {
            shown = ""
        } else if opacity < 0.015 {
            shown = "0%"
        } else {
            shown = "\(Int((opacity * 100).rounded()))%"
        }
        return shown.isEmpty ? "\(app)  —  \(title)" : "\(app)  —  \(title)  ·  \(shown)"
    }
}

func runYabai(_ args: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: yabaiPath)
    process.arguments = ["-m"] + args
    let out = Pipe()
    let err = Pipe()
    process.standardOutput = out
    process.standardError = err
    try process.run()
    process.waitUntilExit()
    let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let error = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
        let message = error.isEmpty ? output : error
        throw NSError(domain: "yabai", code: Int(process.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
    }
    return output
}

final class App: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let window = NSWindow(
        contentRect: NSRect(x: 80, y: 80, width: 460, height: 560),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    let table = NSTableView()
    let slider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    let opacityLabel = NSTextField(labelWithString: "不透明度 100%")
    let status = NSTextField(wrappingLabelWithString: "")
    var items: [WinItem] = []
    var keepID: Int?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "TFOpacity"
        window.level = .normal
        window.minSize = NSSize(width: 420, height: 480)
        window.isReleasedWhenClosed = false

        let title = NSTextField(labelWithString: "选择一个窗口")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 24
        table.usesAlternatingRowBackgroundColors = true
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        slider.target = self
        slider.action = #selector(slideChanged)
        slider.isContinuous = true

        let hint = NSTextField(labelWithString: "0% 完全透明　　100% 完全不透明")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 12)

        let apply = NSButton(title: "应用", target: self, action: #selector(applyOpacity))
        let reset = NSButton(title: "恢复", target: self, action: #selector(resetOpacity))
        let refreshButton = NSButton(title: "刷新列表", target: self, action: #selector(refreshClicked))
        apply.bezelStyle = .rounded
        reset.bezelStyle = .rounded
        refreshButton.bezelStyle = .rounded

        let buttons = NSStackView(views: [apply, reset, NSView(), refreshButton])
        buttons.orientation = .horizontal
        buttons.distribution = .fill

        status.maximumNumberOfLines = 3
        status.font = NSFont.systemFont(ofSize: 12)

        let root = NSStackView(views: [title, scroll, opacityLabel, slider, hint, buttons, status])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        buttons.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = NSView()
        window.contentView?.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32),
            slider.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32),
            buttons.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32),
            status.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32),
        ])

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reload(keep: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField
            ?? NSTextField(labelWithString: "")
        cell.identifier = id
        cell.stringValue = items[row].label
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard table.selectedRow >= 0, table.selectedRow < items.count else { return }
        let current = items[table.selectedRow].opacity
        let percent: Double
        if current <= 0 { percent = 100 }
        else if current < 0.015 { percent = 0 }
        else { percent = (current * 100).rounded() }
        slider.doubleValue = min(100, max(0, percent))
        slideChanged()
    }

    @objc func slideChanged() {
        opacityLabel.stringValue = "不透明度 \(Int(slider.doubleValue.rounded()))%"
    }

    @objc func refreshClicked() { reload(keep: selected()?.id) }

    func selected() -> WinItem? {
        guard table.selectedRow >= 0, table.selectedRow < items.count else { return nil }
        return items[table.selectedRow]
    }

    func reload(keep: Int?) {
        keepID = keep
        do {
            let raw = try runYabai(["query", "--windows"])
            let data = Data(raw.utf8)
            let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            items = list.compactMap { item in
                let role = item["role"] as? String ?? ""
                if !role.isEmpty && role != "AXWindow" { return nil }
                if let visible = item["is-visible"] as? Bool, !visible { return nil }
                let app = (item["app"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "未命名应用"
                let title = ((item["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if app == "TFOpacity" || title == "TFOpacity" { return nil }
                let id = (item["id"] as? NSNumber)?.intValue ?? 0
                let opacity = (item["opacity"] as? NSNumber)?.doubleValue ?? 1
                return WinItem(id: id, app: app, title: title.isEmpty ? "无标题" : title, opacity: opacity)
            }
        } catch {
            items = []
            status.stringValue = "还读不到窗口：\(error.localizedDescription)"
            table.reloadData()
            return
        }
        table.reloadData()
        if items.isEmpty {
            status.stringValue = "没有可操作的窗口。"
            return
        }
        var row = 0
        if let keep, let index = items.firstIndex(where: { $0.id == keep }) { row = index }
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
        status.stringValue = "共 \(items.count) 个窗口。选中后点「应用」。"
    }

    @objc func applyOpacity() {
        guard let item = selected() else {
            status.stringValue = "先在列表里选一个窗口。"
            return
        }
        let percent = min(100, max(0, Int(slider.doubleValue.rounded())))
        let value = percent == 0 ? 0.01 : Double(percent) / 100
        do {
            _ = try runYabai(["window", String(item.id), "--opacity", String(format: "%.2f", value)])
            status.stringValue = "已把「\(item.app)」设为不透明度 \(percent)%。"
            reload(keep: item.id)
        } catch {
            status.stringValue = "没有改成功：\(error.localizedDescription)"
        }
    }

    @objc func resetOpacity() {
        guard let item = selected() else {
            status.stringValue = "先在列表里选一个窗口。"
            return
        }
        do {
            _ = try runYabai(["window", String(item.id), "--opacity", "0.0"])
            slider.doubleValue = 100
            slideChanged()
            status.stringValue = "已恢复「\(item.app)」为完全不透明。"
            reload(keep: item.id)
        } catch {
            status.stringValue = "没有恢复成功：\(error.localizedDescription)"
        }
    }
}

let app = NSApplication.shared
let delegate = App()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
