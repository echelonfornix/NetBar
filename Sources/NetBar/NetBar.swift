import AppKit
import Foundation

struct Device: Codable {
    var id: String
    var ip: String
    var mac: String
    var interfaceName: String
    var hostname: String?
    var isPermanent: Bool
    var firstSeen: Date
    var lastSeen: Date

    var addressStatus: String {
        isPermanent ? "Static ARP entry" : "DHCP/static unknown"
    }
}

struct LocalAddressInfo {
    var interfaceName: String?
    var ip: String?
    var assignment: String
}

struct DeviceGuess {
    var label: String
    var icon: String
    var accent: NSColor
    var clue: String
    var confidence: String

    var summary: String {
        "\(label) (\(confidence))"
    }
}

enum DeviceClassifier {
    static func classify(device: Device, name: String) -> DeviceGuess {
        let text = "\(name) \(device.hostname ?? "") \(device.mac)".lowercased()
        let macInfo = macAddressInfo(device.mac)

        if device.ip.hasSuffix(".1") || device.ip.hasSuffix(".254") || text.contains("router") || text.contains("gateway") {
            return DeviceGuess(
                label: "Router",
                icon: "📡",
                accent: .systemBlue,
                clue: "Gateway-style IP/name; \(macInfo.clue)",
                confidence: "high"
            )
        }

        if text.contains("iphone") || text.contains("ipad") || text.contains("android") || text.contains("phone") || text.contains("pixel") || text.contains("galaxy") {
            return DeviceGuess(
                label: "Mobile",
                icon: "📱",
                accent: .systemIndigo,
                clue: "Device name suggests phone/tablet; \(macInfo.clue)",
                confidence: "high"
            )
        }

        if text.contains("xbox") || text.contains("playstation") || text.contains("ps5") || text.contains("ps4") || text.contains("switch") {
            return DeviceGuess(
                label: "Games",
                icon: "🎮",
                accent: .systemPurple,
                clue: "Device name suggests games console; \(macInfo.clue)",
                confidence: "high"
            )
        }

        if text.contains("macbook") || text.contains("imac") || text.contains("mac-mini") || text.contains("windows") || text.contains("laptop") || text.contains("desktop") || text.contains("pc") {
            return DeviceGuess(
                label: "Computer",
                icon: "💻",
                accent: .systemGreen,
                clue: "Device name suggests computer; \(macInfo.clue)",
                confidence: "high"
            )
        }

        if text.contains("printer") || text.contains("canon") || text.contains("epson") || text.contains("brother") || text.contains("hewlett") {
            return DeviceGuess(
                label: "Printer",
                icon: "🖨",
                accent: .systemOrange,
                clue: "Device name suggests printer; \(macInfo.clue)",
                confidence: "high"
            )
        }

        if text.contains("tv") || text.contains("roku") || text.contains("chromecast") || text.contains("firetv") || text.contains("apple-tv") {
            return DeviceGuess(
                label: "TV / Media",
                icon: "📺",
                accent: .systemRed,
                clue: "Device name suggests TV/media device; \(macInfo.clue)",
                confidence: "high"
            )
        }

        if text.contains("camera") || text.contains("ring") || text.contains("nest") || text.contains("hue") || text.contains("echo") || text.contains("alexa") {
            return DeviceGuess(
                label: "Smart Home",
                icon: "🏠",
                accent: .systemYellow,
                clue: "Device name suggests smart-home kit; \(macInfo.clue)",
                confidence: "medium"
            )
        }

        if macInfo.isLocallyAdministered {
            return DeviceGuess(
                label: "Mobile or laptop",
                icon: "📱",
                accent: .systemIndigo,
                clue: macInfo.clue,
                confidence: "medium"
            )
        }

        return DeviceGuess(
            label: "Unknown device",
            icon: "🔹",
            accent: .systemGray,
            clue: macInfo.clue,
            confidence: "low"
        )
    }

    static func macAddressInfo(_ mac: String) -> (isLocallyAdministered: Bool, clue: String) {
        let parts = mac.split(separator: ":")
        guard let firstPart = parts.first, let firstByte = UInt8(firstPart, radix: 16) else {
            return (false, "MAC address could not be interpreted")
        }

        let isMulticast = (firstByte & 0x01) == 0x01
        let isLocal = (firstByte & 0x02) == 0x02

        if isMulticast {
            return (false, "Multicast/group MAC address")
        }

        if isLocal {
            return (true, "Private/randomized MAC; often phone, tablet, laptop, or privacy mode")
        }

        let prefix = parts.prefix(3).joined(separator: ":").uppercased()
        return (false, "Vendor-assigned MAC prefix \(prefix); vendor lookup can improve this")
    }
}

struct StoredState: Codable {
    var aliases: [String: String] = [:]
    var showMacAddresses: Bool = false
}

final class StateStore {
    private let stateURL: URL
    private(set) var state = StoredState()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("NetBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.stateURL = folder.appendingPathComponent("state.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: stateURL) else { return }
        if let decoded = try? JSONDecoder().decode(StoredState.self, from: data) {
            state = decoded
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    func alias(for device: Device) -> String? {
        state.aliases[device.id]
    }

    func setAlias(_ alias: String?, for deviceID: String) {
        let trimmed = (alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            state.aliases.removeValue(forKey: deviceID)
        } else {
            state.aliases[deviceID] = trimmed
        }
        save()
    }

    func setShowMacAddresses(_ show: Bool) {
        state.showMacAddresses = show
        save()
    }

    var stateFileURL: URL {
        stateURL
    }
}

final class NetworkScanner {
    func scan(previousDevices: [String: Device]) -> [Device] {
        let now = Date()
        let output = run("/usr/sbin/arp", ["-a"])
        let devices = output
            .split(separator: "\n")
            .compactMap { parseARPLine(String($0), now: now, previousDevices: previousDevices) }

        return devices.sorted { lhs, rhs in
            compareIPv4(lhs.ip, rhs.ip)
        }
    }

    func localAddressInfo() -> LocalAddressInfo {
        let routeInterface = defaultInterface()
        let arpInterface = interfaceFromARPTable()
        let routeIP = routeInterface.flatMap { clean(run("/usr/sbin/ipconfig", ["getifaddr", $0])) }

        let interfaceName: String?
        let ip: String?
        if let routeInterface, !isTunnelInterface(routeInterface), routeIP != nil {
            interfaceName = routeInterface
            ip = routeIP
        } else {
            interfaceName = arpInterface ?? routeInterface
            ip = interfaceName.flatMap { clean(run("/usr/sbin/ipconfig", ["getifaddr", $0])) }
                ?? interfaceName.flatMap { localPermanentARPAddress(interfaceName: $0) }
                ?? localPermanentARPAddress(interfaceName: nil)
                ?? routeIP
        }

        let packet = interfaceName.map { run("/usr/sbin/ipconfig", ["getpacket", $0]) } ?? ""

        let assignment: String
        if packet.contains("lease_time") || packet.contains("server_identifier") || packet.contains("yiaddr") {
            assignment = "DHCP"
        } else if localPermanentARPAddress(interfaceName: interfaceName) == ip, ip != nil {
            assignment = "Local address; DHCP/static unknown"
        } else if ip != nil {
            assignment = "Static/manual or unknown"
        } else {
            assignment = "No active address found"
        }

        return LocalAddressInfo(interfaceName: interfaceName, ip: ip, assignment: assignment)
    }

    func gatewayIPAddress() -> String? {
        let output = run("/sbin/route", ["-n", "get", "default"])
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("gateway:") {
                return trimmed.replacingOccurrences(of: "gateway:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func parseARPLine(_ line: String, now: Date, previousDevices: [String: Device]) -> Device? {
        guard let ipRange = line.range(of: #"\((\d{1,3}(?:\.\d{1,3}){3})\)"#, options: .regularExpression) else {
            return nil
        }

        let ip = String(line[ipRange])
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))

        if isIgnoredAddress(ip) {
            return nil
        }

        guard let atRange = line.range(of: " at "),
              let onRange = line.range(of: " on ", range: atRange.upperBound..<line.endIndex) else {
            return nil
        }

        let mac = String(line[atRange.upperBound..<onRange.lowerBound]).lowercased()
        if mac == "(incomplete)" || mac == "<incomplete>" {
            return nil
        }

        let rest = String(line[onRange.upperBound...])
        let parts = rest.split(separator: " ")
        guard let interfaceName = parts.first.map(String.init) else { return nil }

        let hostPrefix = String(line[..<ipRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let hostname = hostPrefix == "?" || hostPrefix.isEmpty ? nil : hostPrefix
        let id = mac.contains(":") ? "mac:\(mac)" : "ip:\(ip)"
        let previous = previousDevices[id]

        return Device(
            id: id,
            ip: ip,
            mac: mac,
            interfaceName: interfaceName,
            hostname: hostname,
            isPermanent: line.contains(" permanent"),
            firstSeen: previous?.firstSeen ?? now,
            lastSeen: now
        )
    }

    private func defaultInterface() -> String? {
        let output = run("/sbin/route", ["-n", "get", "default"])
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed.replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return interfaceFromARPTable()
    }

    private func interfaceFromARPTable() -> String? {
        let output = run("/usr/sbin/arp", ["-a"])
        var counts: [String: Int] = [:]

        for line in output.split(separator: "\n") {
            guard let onRange = line.range(of: " on ") else { continue }
            let rest = line[onRange.upperBound...]
            guard let interfaceName = rest.split(separator: " ").first else { continue }
            counts[String(interfaceName), default: 0] += 1
        }

        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }.first?.key
    }

    private func isTunnelInterface(_ interfaceName: String) -> Bool {
        interfaceName.hasPrefix("utun")
            || interfaceName.hasPrefix("ppp")
            || interfaceName.hasPrefix("ipsec")
    }

    private func localPermanentARPAddress(interfaceName: String?) -> String? {
        let output = run("/usr/sbin/arp", ["-a"])

        for line in output.split(separator: "\n") {
            guard line.contains(" permanent"),
                  let ipRange = line.range(of: #"\((\d{1,3}(?:\.\d{1,3}){3})\)"#, options: .regularExpression),
                  let onRange = line.range(of: " on ") else {
                continue
            }

            let rest = line[onRange.upperBound...]
            let lineInterface = rest.split(separator: " ").first.map(String.init)
            if let desiredInterface = interfaceName, lineInterface != desiredInterface {
                continue
            }

            let ip = String(line[ipRange]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            if !isIgnoredAddress(ip) {
                return ip
            }
        }

        return nil
    }

    private func run(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ""
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isIgnoredAddress(_ ip: String) -> Bool {
        ip.hasPrefix("224.")
            || ip.hasPrefix("225.")
            || ip.hasPrefix("226.")
            || ip.hasPrefix("227.")
            || ip.hasPrefix("228.")
            || ip.hasPrefix("229.")
            || ip.hasPrefix("230.")
            || ip.hasPrefix("231.")
            || ip.hasPrefix("232.")
            || ip.hasPrefix("233.")
            || ip.hasPrefix("234.")
            || ip.hasPrefix("235.")
            || ip.hasPrefix("236.")
            || ip.hasPrefix("237.")
            || ip.hasPrefix("238.")
            || ip.hasPrefix("239.")
            || ip == "255.255.255.255"
    }

    private func compareIPv4(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        return left.lexicographicallyPrecedes(right)
    }
}

final class StartupManager {
    private let label = "local.netbar.status.login"

    private var launchAgentsFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    var launchAgentURL: URL {
        launchAgentsFolder.appendingPathComponent("\(label).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func ensureInstalled() throws {
        if !isInstalled {
            try install()
        }
    }

    func install() throws {
        try FileManager.default.createDirectory(at: launchAgentsFolder, withIntermediateDirectories: true)

        let appURL = Bundle.main.bundleURL
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", appURL.path],
            "RunAtLoad": true
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)
    }

    func uninstall() throws {
        if isInstalled {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
    }
}

final class SettingsWindowController: NSWindowController {
    private let store: StateStore
    private let startupManager: StartupManager
    private let onSettingsChanged: () -> Void
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch NetBar at login", target: nil, action: nil)
    private let showMACButton = NSButton(checkboxWithTitle: "Show MAC addresses in the menu", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

    init(store: StateStore, startupManager: StartupManager, onSettingsChanged: @escaping () -> Void) {
        self.store = store
        self.startupManager = startupManager
        self.onSettingsChanged = onSettingsChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NetBar Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        buildContent()
        syncControls()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "NetBar")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let credit = NSTextField(labelWithString: "Designed by Simon Stevens")
        credit.font = .systemFont(ofSize: 12)
        credit.textColor = .secondaryLabelColor
        credit.translatesAutoresizingMaskIntoConstraints = false

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(toggleLaunchAtLogin(_:))
        launchAtLoginButton.translatesAutoresizingMaskIntoConstraints = false

        showMACButton.target = self
        showMACButton.action = #selector(toggleShowMAC(_:))
        showMACButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(icon)
        contentView.addSubview(title)
        contentView.addSubview(credit)
        contentView.addSubview(launchAtLoginButton)
        contentView.addSubview(showMACButton)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            icon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            icon.widthAnchor.constraint(equalToConstant: 56),
            icon.heightAnchor.constraint(equalToConstant: 56),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            title.topAnchor.constraint(equalTo: icon.topAnchor, constant: 2),

            credit.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            credit.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            credit.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),

            launchAtLoginButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            launchAtLoginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -26),
            launchAtLoginButton.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 28),

            showMACButton.leadingAnchor.constraint(equalTo: launchAtLoginButton.leadingAnchor),
            showMACButton.trailingAnchor.constraint(equalTo: launchAtLoginButton.trailingAnchor),
            showMACButton.topAnchor.constraint(equalTo: launchAtLoginButton.bottomAnchor, constant: 12),

            statusLabel.leadingAnchor.constraint(equalTo: launchAtLoginButton.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: launchAtLoginButton.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: showMACButton.bottomAnchor, constant: 18)
        ])
    }

    func syncControls() {
        launchAtLoginButton.state = startupManager.isInstalled ? .on : .off
        showMACButton.state = store.state.showMacAddresses ? .on : .off
        statusLabel.stringValue = "Launch setting: \(startupManager.isInstalled ? "on" : "off"). MAC display: \(store.state.showMacAddresses ? "on" : "off")."
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try startupManager.install()
            } else {
                try startupManager.uninstall()
            }
        } catch {
            showError("Launch at Login could not be changed.", detail: error.localizedDescription)
        }

        syncControls()
        onSettingsChanged()
    }

    @objc private func toggleShowMAC(_ sender: NSButton) {
        store.setShowMacAddresses(sender.state == .on)
        syncControls()
        onSettingsChanged()
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window ?? NSWindow()) { _ in }
    }
}

struct NetworkMapNode {
    var title: String
    var subtitle: String
    var detail: String
    var icon: String
    var accent: NSColor
    var isNew: Bool = false
}

final class NetworkMapView: NSView {
    var routerNode = NetworkMapNode(title: "Router / Gateway", subtitle: "Not found yet", detail: "Refresh after network activity", icon: "📡", accent: .systemBlue)
    var macNode = NetworkMapNode(title: "This Mac", subtitle: "No IP", detail: "Local machine", icon: "💻", accent: .systemGreen)
    var deviceNodes: [NetworkMapNode] = []
    var footerText = ""

    private let cardSize = NSSize(width: 250, height: 94)
    private let topMargin: CGFloat = 78
    private let rowGap: CGFloat = 132
    private let columnGap: CGFloat = 30
    private let sidePadding: CGFloat = 32

    override var isFlipped: Bool {
        true
    }

    func refreshLayout(width: CGFloat) {
        let usableWidth = max(840, width)
        let columns = deviceColumns(for: usableWidth)
        let rows = max(1, Int(ceil(Double(deviceNodes.count) / Double(columns))))
        let height = topMargin + rowGap * 2 + rowGap * CGFloat(rows - 1) + cardSize.height + 70
        setFrameSize(NSSize(width: usableWidth, height: height))
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        drawHeader()

        let centerX = bounds.midX
        let routerRect = NSRect(x: centerX - cardSize.width / 2, y: topMargin, width: cardSize.width, height: cardSize.height)
        let macRect = NSRect(x: centerX - cardSize.width / 2, y: topMargin + rowGap, width: cardSize.width, height: cardSize.height)

        drawStraightConnection(from: NSPoint(x: routerRect.midX, y: routerRect.maxY), to: NSPoint(x: macRect.midX, y: macRect.minY))
        drawCard(routerNode, in: routerRect)
        drawCard(macNode, in: macRect)

        let deviceRects = layoutDeviceRects(startY: topMargin + rowGap * 2)
        drawDeviceConnectors(from: macRect, to: deviceRects)

        for (index, node) in deviceNodes.enumerated() where index < deviceRects.count {
            drawCard(node, in: deviceRects[index])
        }

        if deviceNodes.isEmpty {
            drawEmptyState(y: topMargin + rowGap * 2)
        }
    }

    private func drawHeader() {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        "Network Map".draw(at: NSPoint(x: 26, y: 22), withAttributes: titleAttributes)
        footerText.draw(at: NSPoint(x: 28, y: 52), withAttributes: subtitleAttributes)
    }

    private func layoutDeviceRects(startY: CGFloat) -> [NSRect] {
        guard !deviceNodes.isEmpty else { return [] }

        let columns = deviceColumns(for: bounds.width)
        let usedWidth = CGFloat(columns) * cardSize.width + CGFloat(columns - 1) * columnGap
        let startX = max(sidePadding, (bounds.width - usedWidth) / 2)

        return deviceNodes.indices.map { index in
            let column = index % columns
            let row = index / columns
            return NSRect(
                x: startX + CGFloat(column) * (cardSize.width + columnGap),
                y: startY + CGFloat(row) * rowGap,
                width: cardSize.width,
                height: cardSize.height
            )
        }
    }

    private func deviceColumns(for width: CGFloat) -> Int {
        max(1, min(3, Int((width - sidePadding * 2 + columnGap) / (cardSize.width + columnGap))))
    }

    private func drawStraightConnection(from start: NSPoint, to end: NSPoint) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        NSColor.separatorColor.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 1.6
        path.stroke()
    }

    private func drawDeviceConnectors(from macRect: NSRect, to deviceRects: [NSRect]) {
        guard !deviceRects.isEmpty else { return }

        let rowGroups = groupedByRow(deviceRects)
        let trunkX = macRect.midX
        var currentY = macRect.maxY

        for row in rowGroups {
            guard let first = row.first, let last = row.last else { continue }
            let busY = first.minY - 24
            drawStraightConnection(from: NSPoint(x: trunkX, y: currentY), to: NSPoint(x: trunkX, y: busY))

            let path = NSBezierPath()
            path.move(to: NSPoint(x: first.midX, y: busY))
            path.line(to: NSPoint(x: last.midX, y: busY))
            for rect in row {
                path.move(to: NSPoint(x: rect.midX, y: busY))
                path.line(to: NSPoint(x: rect.midX, y: rect.minY))
            }

            NSColor.separatorColor.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 1.6
            path.stroke()
            currentY = busY
        }
    }

    private func groupedByRow(_ rects: [NSRect]) -> [[NSRect]] {
        var rows: [[NSRect]] = []
        for rect in rects.sorted(by: { $0.minY == $1.minY ? $0.minX < $1.minX : $0.minY < $1.minY }) {
            if let lastRow = rows.indices.last, let first = rows[lastRow].first, abs(first.minY - rect.minY) < 1 {
                rows[lastRow].append(rect)
            } else {
                rows.append([rect])
            }
        }
        return rows.map { $0.sorted { $0.minX < $1.minX } }
    }

    private func drawCard(_ node: NetworkMapNode, in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 9
        shadow.set()

        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        if node.isNew {
            node.accent.withAlphaComponent(0.08).setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        node.accent.withAlphaComponent(0.20).setFill()
        NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY, width: 7, height: rect.height), xRadius: 4, yRadius: 4).fill()

        (node.isNew ? node.accent : NSColor.separatorColor).withAlphaComponent(node.isNew ? 0.95 : 0.8).setStroke()
        path.lineWidth = node.isNew ? 2.2 : 1
        path.stroke()

        if node.isNew {
            drawNewBadge(in: rect, accent: node.accent)
        }

        let badgeRect = NSRect(x: rect.minX + 20, y: rect.minY + 22, width: 42, height: 42)
        node.accent.withAlphaComponent(0.14).setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        drawText(
            node.icon,
            in: badgeRect.insetBy(dx: 4, dy: 5),
            font: NSFont.systemFont(ofSize: 21),
            color: NSColor.labelColor,
            alignment: .center
        )

        let textX = rect.minX + 78
        let textWidth = rect.maxX - textX - 18
        let titleWidth = node.isNew ? max(80, textWidth - 52) : textWidth
        drawText(
            node.title,
            in: NSRect(x: textX, y: rect.minY + 16, width: titleWidth, height: 20),
            font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            color: NSColor.labelColor
        )
        drawText(
            node.subtitle,
            in: NSRect(x: textX, y: rect.minY + 39, width: textWidth, height: 18),
            font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            color: NSColor.secondaryLabelColor
        )
        drawText(
            node.detail,
            in: NSRect(x: textX, y: rect.minY + 62, width: textWidth, height: 18),
            font: NSFont.systemFont(ofSize: 11),
            color: NSColor.tertiaryLabelColor
        )
    }

    private func drawNewBadge(in rect: NSRect, accent: NSColor) {
        let badgeRect = NSRect(x: rect.maxX - 54, y: rect.minY + 13, width: 39, height: 18)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 9, yRadius: 9)
        accent.setFill()
        badgePath.fill()
        drawText(
            "NEW",
            in: badgeRect.insetBy(dx: 5, dy: 2),
            font: NSFont.systemFont(ofSize: 9, weight: .bold),
            color: .white,
            alignment: .center
        )
    }

    private func drawEmptyState(y: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        "No other devices are visible in the ARP table yet.".draw(
            at: NSPoint(x: max(26, bounds.midX - 150), y: y + 20),
            withAttributes: attributes
        )
    }

    private func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}

final class NetworkMapWindowController: NSWindowController {
    private let store: StateStore
    private let mapView = NetworkMapView(frame: NSRect(x: 0, y: 0, width: 760, height: 620))

    init(store: StateStore) {
        self.store = store

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NetBar Network Map"
        window.isReleasedWhenClosed = false
        window.center()

        let scrollView = NSScrollView(frame: window.contentView?.bounds ?? .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = mapView
        window.contentView = scrollView

        super.init(window: window)
        mapView.refreshLayout(width: 760)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(devices: [Device], localInfo: LocalAddressInfo, gatewayIP: String?, lastRefresh: Date?, newDeviceIDs: Set<String>) {
        let localIP = localInfo.ip
        let routerDevice = findRouter(in: devices, gatewayIP: gatewayIP, localIP: localIP)
        let routerIP = routerDevice?.ip ?? gatewayIP

        if let routerDevice {
            mapView.routerNode = node(for: routerDevice, role: "Router", forcedIcon: "📡", accent: .systemBlue)
        } else {
            mapView.routerNode = NetworkMapNode(
                title: "Router / Gateway",
                subtitle: routerIP ?? "Unknown IP",
                detail: "Not visible in ARP yet",
                icon: "📡",
                accent: .systemBlue
            )
        }

        mapView.macNode = NetworkMapNode(
            title: "This Mac",
            subtitle: localIP ?? "No local IP",
            detail: localInfo.interfaceName ?? "Unknown interface",
            icon: "💻",
            accent: .systemGreen
        )

        mapView.deviceNodes = devices
            .filter { device in
                device.ip != localIP
                    && device.ip != routerIP
                    && device.id != routerDevice?.id
            }
            .map { node(for: $0, role: nil, forcedIcon: nil, accent: nil, isNew: newDeviceIDs.contains($0.id)) }

        let refreshed = lastRefresh.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? "never"
        let newCount = mapView.deviceNodes.filter(\.isNew).count
        let newText = newCount > 0 ? " - \(newCount) new" : ""
        mapView.footerText = "\(mapView.deviceNodes.count) devices below this Mac\(newText) - refreshed \(refreshed)"
        mapView.refreshLayout(width: window?.contentView?.bounds.width ?? 760)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    private func findRouter(in devices: [Device], gatewayIP: String?, localIP: String?) -> Device? {
        if let gatewayIP, let match = devices.first(where: { $0.ip == gatewayIP }) {
            return match
        }

        return devices.first { device in
            guard device.ip != localIP else { return false }
            let lowerName = displayName(for: device).lowercased()
            return lowerName.contains("router")
                || lowerName.contains("gateway")
                || device.ip.hasSuffix(".1")
                || device.ip.hasSuffix(".254")
        }
    }

    private func node(for device: Device, role: String?, forcedIcon: String?, accent: NSColor?, isNew: Bool = false) -> NetworkMapNode {
        let name = displayName(for: device)
        let classification = DeviceClassifier.classify(device: device, name: name)
        let title: String
        if let role, name == "Device" {
            title = role
        } else if name == "Device" {
            title = mapTitle(for: device, classification: classification)
        } else {
            title = name
        }

        return NetworkMapNode(
            title: title,
            subtitle: device.ip,
            detail: role ?? mapDetail(for: classification),
            icon: forcedIcon ?? classification.icon,
            accent: accent ?? classification.accent,
            isNew: isNew
        )
    }

    private func displayName(for device: Device) -> String {
        if let alias = store.alias(for: device), !alias.isEmpty {
            return alias
        }
        if let hostname = device.hostname, !hostname.isEmpty {
            return hostname
        }
        return "Device"
    }

    private func mapTitle(for device: Device, classification: DeviceGuess) -> String {
        if classification.label == "Unknown device" {
            return "Device \(lastOctet(of: device.ip))"
        }
        return classification.label
    }

    private func mapDetail(for classification: DeviceGuess) -> String {
        if classification.clue.hasPrefix("Private/randomized MAC") {
            return "Private MAC - \(classification.confidence)"
        }
        if classification.clue.hasPrefix("Vendor-assigned MAC prefix") {
            return "Vendor MAC - \(classification.confidence)"
        }
        return "\(classification.label) - \(classification.confidence)"
    }

    private func lastOctet(of ip: String) -> String {
        ip.split(separator: ".").last.map { ".\($0)" } ?? ip
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let scanner = NetworkScanner()
    private let store = StateStore()
    private let startupManager = StartupManager()
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    private var devicesByID: [String: Device] = [:]
    private var devices: [Device] = []
    private var localInfo = LocalAddressInfo(interfaceName: nil, ip: nil, assignment: "Unknown")
    private var lastRefresh: Date?
    private var hasCompletedInitialScan = false
    private var newDeviceHighlights: [String: Date] = [:]
    private var timer: Timer?
    private var startupError: String?
    private var sharingPicker: NSSharingServicePicker?
    private var settingsWindowController: SettingsWindowController?
    private var networkMapWindowController: NetworkMapWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "network", accessibilityDescription: "NetBar") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Net"
            }
        }

        do {
            try startupManager.ensureInstalled()
        } catch {
            startupError = error.localizedDescription
        }

        refresh(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh(nil)
        }
    }

    @objc private func refresh(_ sender: Any?) {
        localInfo = scanner.localAddressInfo()
        let previousIDs = Set(devicesByID.keys)
        devices = scanner.scan(previousDevices: devicesByID)
        let now = Date()

        if hasCompletedInitialScan {
            for device in devices where !previousIDs.contains(device.id) {
                newDeviceHighlights[device.id] = now
            }
        } else {
            hasCompletedInitialScan = true
        }

        devicesByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        pruneNewDeviceHighlights(now: now)
        lastRefresh = now
        rebuildMenu()
        updateNetworkMap()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "NetBar", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let refreshed = lastRefresh.map { timeFormatter.string(from: $0) } ?? "Never"
        let newCount = devices.filter { isNewDevice($0) }.count
        let newSummary = newCount > 0 ? " - \(newCount) new" : ""
        let summary = NSMenuItem(title: "\(devices.count) seen\(newSummary) - refreshed \(refreshed)", action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)

        let localTitle = localInfoText()
        let localItem = NSMenuItem(title: localTitle, action: nil, keyEquivalent: "")
        localItem.isEnabled = false
        menu.addItem(localItem)
        menu.addItem(.separator())

        if devices.isEmpty {
            let empty = NSMenuItem(title: "No ARP devices found yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for device in devices {
                menu.addItem(menuItem(for: device))
            }
        }

        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = startupManager.isInstalled ? .on : .off
        menu.addItem(launchAtLogin)

        let showMAC = NSMenuItem(title: "Show MAC addresses", action: #selector(toggleShowMacAddresses(_:)), keyEquivalent: "")
        showMAC.target = self
        showMAC.state = store.state.showMacAddresses ? .on : .off
        menu.addItem(showMAC)

        let settings = NSMenuItem(title: "Settings...", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let networkMap = NSMenuItem(title: "Network Map...", action: #selector(showNetworkMap(_:)), keyEquivalent: "m")
        networkMap.target = self
        menu.addItem(networkMap)

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refresh(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let revealState = NSMenuItem(title: "Reveal Saved Names File", action: #selector(revealStateFile(_:)), keyEquivalent: "")
        revealState.target = self
        menu.addItem(revealState)

        let shareApp = NSMenuItem(title: "Share NetBar DMG...", action: #selector(shareApp(_:)), keyEquivalent: "")
        shareApp.target = self
        menu.addItem(shareApp)

        let info = NSMenuItem(title: "About NetBar...", action: #selector(showInfoPane(_:)), keyEquivalent: "")
        info.target = self
        menu.addItem(info)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit NetBar", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func menuItem(for device: Device) -> NSMenuItem {
        let label = displayName(for: device)
        let subtitle = store.state.showMacAddresses ? "\(device.ip) - \(device.mac)" : device.ip
        let isNew = isNewDevice(device)
        let newPrefix = isNew ? "NEW  " : ""
        let item = NSMenuItem(title: "\(newPrefix)\(label)  \(subtitle)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        if isNew {
            addDisabled("Status: New connection detected", to: submenu)
        }
        addDisabled("IP: \(device.ip)", to: submenu)
        addDisabled("Interface: \(device.interfaceName)", to: submenu)
        addDisabled("Address: \(device.addressStatus)", to: submenu)
        let guess = DeviceClassifier.classify(device: device, name: label)
        addDisabled("Guessed as: \(guess.summary)", to: submenu)
        addDisabled("MAC clue: \(guess.clue)", to: submenu)
        addDisabled("First seen: \(timeFormatter.string(from: device.firstSeen))", to: submenu)
        addDisabled("Last refreshed: \(timeFormatter.string(from: device.lastSeen))", to: submenu)

        if store.state.showMacAddresses {
            addDisabled("MAC: \(device.mac)", to: submenu)
        }

        submenu.addItem(.separator())

        let rename = NSMenuItem(title: "Rename...", action: #selector(renameDevice(_:)), keyEquivalent: "")
        rename.target = self
        rename.representedObject = device.id
        submenu.addItem(rename)

        let clearName = NSMenuItem(title: "Clear Name", action: #selector(clearDeviceName(_:)), keyEquivalent: "")
        clearName.target = self
        clearName.representedObject = device.id
        clearName.isEnabled = store.state.aliases[device.id] != nil
        submenu.addItem(clearName)

        submenu.addItem(.separator())

        let copyIP = NSMenuItem(title: "Copy IP", action: #selector(copyIP(_:)), keyEquivalent: "")
        copyIP.target = self
        copyIP.representedObject = device.id
        submenu.addItem(copyIP)

        let copyMAC = NSMenuItem(title: "Copy MAC", action: #selector(copyMAC(_:)), keyEquivalent: "")
        copyMAC.target = self
        copyMAC.representedObject = device.id
        submenu.addItem(copyMAC)

        item.submenu = submenu
        return item
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func displayName(for device: Device) -> String {
        if let alias = store.alias(for: device), !alias.isEmpty {
            return alias
        }
        if let hostname = device.hostname, !hostname.isEmpty {
            return hostname
        }
        return "Device"
    }

    private func localInfoText() -> String {
        let interfaceName = localInfo.interfaceName ?? "unknown interface"
        let ip = localInfo.ip ?? "no IP"
        return "This Mac: \(ip) on \(interfaceName) - \(localInfo.assignment)"
    }

    private func isNewDevice(_ device: Device) -> Bool {
        newDeviceHighlights[device.id] != nil
    }

    private func pruneNewDeviceHighlights(now: Date) {
        let visibleIDs = Set(devices.map(\.id))
        let highlightDuration: TimeInterval = 5 * 60
        newDeviceHighlights = newDeviceHighlights.filter { entry in
            visibleIDs.contains(entry.key) && now.timeIntervalSince(entry.value) <= highlightDuration
        }
    }

    @objc private func toggleShowMacAddresses(_ sender: NSMenuItem) {
        store.setShowMacAddresses(!store.state.showMacAddresses)
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if startupManager.isInstalled {
                try startupManager.uninstall()
            } else {
                try startupManager.install()
            }
            startupError = nil
        } catch {
            startupError = error.localizedDescription
            showError("Launch at Login could not be changed.", detail: error.localizedDescription)
        }

        rebuildMenu()
        settingsWindowController?.syncControls()
    }

    @objc private func showSettings(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                store: store,
                startupManager: startupManager,
                onSettingsChanged: { [weak self] in
                    self?.rebuildMenu()
                }
            )
        }
        settingsWindowController?.syncControls()
        settingsWindowController?.showWindow(nil)
    }

    @objc private func showNetworkMap(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if networkMapWindowController == nil {
            networkMapWindowController = NetworkMapWindowController(store: store)
        }
        updateNetworkMap()
        networkMapWindowController?.showWindow(nil)
    }

    private func updateNetworkMap() {
        networkMapWindowController?.update(
            devices: devices,
            localInfo: localInfo,
            gatewayIP: scanner.gatewayIPAddress(),
            lastRefresh: lastRefresh,
            newDeviceIDs: Set(newDeviceHighlights.keys)
        )
    }

    @objc private func renameDevice(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String,
              let device = devicesByID[deviceID] else { return }

        NSApp.activate(ignoringOtherApps: true)

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = store.alias(for: device) ?? device.hostname ?? ""

        let alert = NSAlert()
        alert.messageText = "Rename \(device.ip)"
        alert.informativeText = "Give this device a friendly name for the menu."
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            store.setAlias(input.stringValue, for: deviceID)
            rebuildMenu()
        }
    }

    @objc private func clearDeviceName(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String else { return }
        store.setAlias(nil, for: deviceID)
        rebuildMenu()
    }

    @objc private func copyIP(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String,
              let device = devicesByID[deviceID] else { return }
        copyToPasteboard(device.ip)
    }

    @objc private func copyMAC(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String,
              let device = devicesByID[deviceID] else { return }
        copyToPasteboard(device.mac)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @objc private func revealStateFile(_ sender: NSMenuItem) {
        NSWorkspace.shared.activateFileViewerSelecting([store.stateFileURL])
    }

    @objc private func showInfoPane(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)

        let startupLine = startupManager.isInstalled ? "Launch at login: On" : "Launch at login: Off"
        let startupDetail = startupError.map { "\nStartup setup note: \($0)" } ?? ""
        let appPath = Bundle.main.bundleURL.path

        let alert = NSAlert()
        alert.messageText = "NetBar"
        alert.informativeText = """
        Designed by Simon Stevens

        Shows recently seen local network devices from this Mac's ARP table.
        \(startupLine)

        Sharing creates a DMG of this signed local build. Without a Developer ID certificate, other Macs may still ask for approval in Privacy & Security.

        App: \(appPath)\(startupDetail)
        """
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Share DMG")
        alert.addButton(withTitle: "Reveal App")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            shareApp(sender)
        } else if response == .alertThirdButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
    }

    @objc private func shareApp(_ sender: Any?) {
        do {
            let zipURL = try createShareDMG()
            if let button = statusItem.button {
                let picker = NSSharingServicePicker(items: [zipURL])
                sharingPicker = picker
                picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([zipURL])
            }
        } catch {
            showError("NetBar could not create the share DMG.", detail: error.localizedDescription)
        }
    }

    private func createShareDMG() throws -> URL {
        let appURL = Bundle.main.bundleURL
        let timestamp = Int(Date().timeIntervalSince1970)
        let stagingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBar-dmg-\(timestamp)", isDirectory: true)
        let dmgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBar-\(timestamp).dmg")

        try? FileManager.default.removeItem(at: stagingURL)
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: appURL, to: stagingURL.appendingPathComponent("NetBar.app"))
        try FileManager.default.createSymbolicLink(
            at: stagingURL.appendingPathComponent("Applications"),
            withDestinationURL: URL(fileURLWithPath: "/Applications")
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "create",
            "-volname", "NetBar",
            "-srcfolder", stagingURL.path,
            "-ov",
            "-format", "UDZO",
            dmgURL.path
        ]

        try process.run()
        process.waitUntilExit()

        try? FileManager.default.removeItem(at: stagingURL)

        if process.terminationStatus != 0 || !FileManager.default.fileExists(atPath: dmgURL.path) {
            throw NSError(
                domain: "NetBarDMG",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "The DMG command did not complete successfully."]
            )
        }

        return dmgURL
    }

    private func showError(_ message: String, detail: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
