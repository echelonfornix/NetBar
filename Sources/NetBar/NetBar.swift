import AppKit
import Foundation

struct Device: Codable {
    var id: String
    var ip: String
    var mac: String
    var interfaceName: String
    var hostname: String?
    var isPermanent: Bool
    var isReachable: Bool
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

struct PingResult {
    var ip: String
    var averageMS: Double?
    var receivedCount: Int
    var didTimeout: Bool
    var error: String?

    var isBad: Bool {
        didTimeout || receivedCount == 0 || averageMS == nil
    }
}

struct DeviceIdentityProfile: Codable {
    var name: String
    var deviceIDs: [String] = []
    var macs: [String] = []
    var ips: [String] = []
    var hostnames: [String] = []
    var lockedMacs: [String] = []
    var confirmedZone: String?
    var lastZone: String?
    var lastSeen: Date?
}

struct DeviceIdentityContext {
    var alias: String?
    var note: String?
    var isMacLocked: Bool
    var confirmedZone: String?
    var previousZone: String?
}

struct DevicePresenceRecord: Codable {
    var firstSeen: Date
    var lastSeen: Date?
    var lastDisappearedAt: Date?
    var lastReachableAt: Date?
    var lastUnreachableAt: Date?
    var seenCount: Int
    var absenceCount: Int
    var reachableMissCount: Int?
    var normalSince: Date?
    var restartMarkedUntil: Date?
    var isPresent: Bool
    var wasReachable: Bool?
}

struct DevicePresenceStatus {
    var title: String
    var detail: String
    var badge: String?
    var firstSeen: Date?
    var seenCount: Int
    var isNewToNetwork: Bool
    var isRestartMarked: Bool
    var isUnreachable: Bool
    var isNormal: Bool
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
    var identityProfiles: [String: DeviceIdentityProfile] = [:]
    var networkPresence: [String: DevicePresenceRecord] = [:]
    var showMacAddresses: Bool = false
    var launchAtLoginEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case aliases
        case identityProfiles
        case networkPresence
        case showMacAddresses
        case launchAtLoginEnabled
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aliases = try container.decodeIfPresent([String: String].self, forKey: .aliases) ?? [:]
        identityProfiles = try container.decodeIfPresent([String: DeviceIdentityProfile].self, forKey: .identityProfiles) ?? [:]
        networkPresence = try container.decodeIfPresent([String: DevicePresenceRecord].self, forKey: .networkPresence) ?? [:]
        showMacAddresses = try container.decodeIfPresent(Bool.self, forKey: .showMacAddresses) ?? false
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? true
    }
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
        state.aliases[device.id] ?? identityContext(for: device).alias
    }

    func setAlias(_ alias: String?, for deviceID: String) {
        let trimmed = (alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            state.aliases.removeValue(forKey: deviceID)
        } else {
            state.aliases[deviceID] = trimmed
            var profile = profile(named: trimmed)
            profile.deviceIDs = appendUnique(deviceID, to: profile.deviceIDs, limit: 12)
            state.identityProfiles[profileKey(for: trimmed)] = profile
        }
        save()
    }

    func clearName(for device: Device) {
        state.aliases.removeValue(forKey: device.id)

        let mac = device.mac.lowercased()
        let hostname = device.hostname?.lowercased()
        var emptyProfileKeys: [String] = []

        for key in state.identityProfiles.keys {
            guard var profile = state.identityProfiles[key] else { continue }
            profile.deviceIDs.removeAll { $0 == device.id }
            profile.macs.removeAll { $0 == mac }
            profile.lockedMacs.removeAll { $0 == mac }
            profile.ips.removeAll { $0 == device.ip }
            if let hostname {
                profile.hostnames.removeAll { $0 == hostname }
            }

            if profile.deviceIDs.isEmpty,
               profile.macs.isEmpty,
               profile.ips.isEmpty,
               profile.hostnames.isEmpty,
               profile.lockedMacs.isEmpty {
                emptyProfileKeys.append(key)
            } else {
                state.identityProfiles[key] = profile
            }
        }

        for key in emptyProfileKeys {
            state.identityProfiles.removeValue(forKey: key)
        }

        save()
    }

    func hasSavedName(for device: Device) -> Bool {
        if state.aliases[device.id] != nil {
            return true
        }

        let mac = device.mac.lowercased()
        let hostname = device.hostname?.lowercased()
        return state.identityProfiles.values.contains { profile in
            profile.deviceIDs.contains(device.id)
                || profile.macs.contains(mac)
                || profile.lockedMacs.contains(mac)
                || profile.ips.contains(device.ip)
                || (hostname.map { profile.hostnames.contains($0) } ?? false)
        }
    }

    func identityContexts(for devices: [Device]) -> [String: DeviceIdentityContext] {
        Dictionary(uniqueKeysWithValues: devices.map { ($0.id, identityContext(for: $0)) })
    }

    func updateNetworkPresence(with devices: [Device], now: Date) -> [String: DevicePresenceStatus] {
        let currentIDs = Set(devices.map(\.id))
        let normalSeenThreshold = 3
        let restartWindow: TimeInterval = 3 * 60
        let restartBadgeDuration: TimeInterval = 8 * 60
        var statuses: [String: DevicePresenceStatus] = [:]

        for device in devices {
            var record = state.networkPresence[device.id] ?? DevicePresenceRecord(
                firstSeen: now,
                lastSeen: nil,
                lastDisappearedAt: nil,
                lastReachableAt: nil,
                lastUnreachableAt: nil,
                seenCount: 0,
                absenceCount: 0,
                reachableMissCount: nil,
                normalSince: nil,
                restartMarkedUntil: nil,
                isPresent: false,
                wasReachable: nil
            )

            let wasKnown = state.networkPresence[device.id] != nil
            let wasMissing = wasKnown && !record.isPresent
            let disappearedRecently = record.lastDisappearedAt.map { now.timeIntervalSince($0) <= restartWindow } ?? false
            let wasEstablished = record.normalSince != nil || record.seenCount >= normalSeenThreshold
            let hadReachableHistory = record.lastReachableAt != nil || record.wasReachable == true
            let wasReachable = record.wasReachable ?? false
            let returnedAfterProbeMiss = device.isReachable
                && hadReachableHistory
                && !wasReachable
                && (record.lastUnreachableAt.map { now.timeIntervalSince($0) <= restartWindow } ?? false)
            let isRestart = ((wasMissing && disappearedRecently) || returnedAfterProbeMiss) && wasEstablished

            record.seenCount += 1
            record.lastSeen = now
            if device.isReachable {
                record.lastReachableAt = now
                record.reachableMissCount = 0
                record.wasReachable = true
                record.isPresent = true
            } else if hadReachableHistory {
                record.lastUnreachableAt = now
                record.reachableMissCount = (record.reachableMissCount ?? 0) + 1
                record.wasReachable = false
                if record.isPresent {
                    record.lastDisappearedAt = now
                    record.absenceCount += 1
                }
                record.isPresent = false
            } else {
                record.isPresent = true
            }
            if record.seenCount >= normalSeenThreshold, record.normalSince == nil {
                record.normalSince = now
            }
            if isRestart {
                record.restartMarkedUntil = now.addingTimeInterval(restartBadgeDuration)
            } else if let restartMarkedUntil = record.restartMarkedUntil, restartMarkedUntil < now {
                record.restartMarkedUntil = nil
            }

            state.networkPresence[device.id] = record
            statuses[device.id] = presenceStatus(for: record, now: now)
        }

        for id in state.networkPresence.keys where !currentIDs.contains(id) {
            guard var record = state.networkPresence[id] else { continue }
            if record.isPresent {
                record.isPresent = false
                record.lastDisappearedAt = now
                record.absenceCount += 1
            }
            if record.lastReachableAt != nil || record.wasReachable == true {
                record.lastUnreachableAt = now
                record.reachableMissCount = (record.reachableMissCount ?? 0) + 1
                record.wasReachable = false
            }
            if let restartMarkedUntil = record.restartMarkedUntil, restartMarkedUntil < now {
                record.restartMarkedUntil = nil
            }
            state.networkPresence[id] = record
        }

        save()
        return statuses
    }

    func presenceStatus(for deviceID: String, now: Date) -> DevicePresenceStatus? {
        guard let record = state.networkPresence[deviceID] else { return nil }
        return presenceStatus(for: record, now: now)
    }

    func recordIdentities(from nodes: [DeviceLocationRadarNode]) {
        var didChange = false
        for node in nodes {
            guard shouldRecordIdentity(for: node),
                  let name = displayNameForIdentity(node),
                  !name.isEmpty else { continue }
            var profile = profile(named: name)
            let isTentativeIPMatch = node.identityNote?.hasPrefix("IP matches") == true
            if !isTentativeIPMatch {
                profile.deviceIDs = appendUnique(node.id, to: profile.deviceIDs, limit: 12)
                if let mac = node.mac?.lowercased(), !mac.isEmpty {
                    profile.macs = appendUnique(mac, to: profile.macs, limit: 12)
                }
            }
            if let ip = node.ip, !ip.isEmpty {
                profile.ips = appendUnique(ip, to: profile.ips, limit: 12)
            }
            profile.hostnames = appendUnique(name.lowercased(), to: profile.hostnames, limit: 8)
            profile.lastZone = node.zone
            profile.lastSeen = Date()
            state.identityProfiles[profileKey(for: name)] = profile
            didChange = true
        }
        if didChange {
            save()
        }
    }

    func lockMAC(for node: DeviceLocationRadarNode) -> Bool {
        guard let mac = node.mac?.lowercased(), !mac.isEmpty,
              let name = displayNameForIdentity(node) else {
            return false
        }
        var profile = profile(named: name)
        profile.deviceIDs = appendUnique(node.id, to: profile.deviceIDs, limit: 12)
        profile.macs = appendUnique(mac, to: profile.macs, limit: 12)
        profile.lockedMacs = appendUnique(mac, to: profile.lockedMacs, limit: 8)
        if let ip = node.ip, !ip.isEmpty {
            profile.ips = appendUnique(ip, to: profile.ips, limit: 12)
        }
        profile.lastZone = node.zone
        profile.lastSeen = Date()
        state.identityProfiles[profileKey(for: name)] = profile
        save()
        return true
    }

    func lockMAC(for device: Device, name: String) {
        var profile = profile(named: name)
        profile.deviceIDs = appendUnique(device.id, to: profile.deviceIDs, limit: 12)
        profile.macs = appendUnique(device.mac.lowercased(), to: profile.macs, limit: 12)
        profile.lockedMacs = appendUnique(device.mac.lowercased(), to: profile.lockedMacs, limit: 8)
        profile.ips = appendUnique(device.ip, to: profile.ips, limit: 12)
        if let hostname = device.hostname?.lowercased(), !hostname.isEmpty {
            profile.hostnames = appendUnique(hostname, to: profile.hostnames, limit: 8)
        }
        profile.lastSeen = Date()
        state.identityProfiles[profileKey(for: name)] = profile
        save()
    }

    func setZone(_ zone: String?, for node: DeviceLocationRadarNode) {
        let name = displayNameForIdentity(node) ?? node.title
        var profile = profile(named: name)
        let cleanedZone = zone?.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.deviceIDs = appendUnique(node.id, to: profile.deviceIDs, limit: 12)
        if let mac = node.mac?.lowercased(), !mac.isEmpty {
            profile.macs = appendUnique(mac, to: profile.macs, limit: 12)
        }
        if let ip = node.ip, !ip.isEmpty {
            profile.ips = appendUnique(ip, to: profile.ips, limit: 12)
        }
        profile.confirmedZone = cleanedZone?.isEmpty == false ? cleanedZone : nil
        profile.lastZone = profile.confirmedZone ?? node.zone
        profile.lastSeen = Date()
        state.identityProfiles[profileKey(for: name)] = profile
        if state.aliases[node.id] == nil {
            state.aliases[node.id] = name
        }
        save()
    }

    func setZone(_ zone: String?, for device: Device, name: String) {
        var profile = profile(named: name)
        let cleanedZone = zone?.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.deviceIDs = appendUnique(device.id, to: profile.deviceIDs, limit: 12)
        profile.macs = appendUnique(device.mac.lowercased(), to: profile.macs, limit: 12)
        profile.ips = appendUnique(device.ip, to: profile.ips, limit: 12)
        if let hostname = device.hostname?.lowercased(), !hostname.isEmpty {
            profile.hostnames = appendUnique(hostname, to: profile.hostnames, limit: 8)
        }
        profile.confirmedZone = cleanedZone?.isEmpty == false ? cleanedZone : nil
        profile.lastZone = profile.confirmedZone
        profile.lastSeen = Date()
        state.identityProfiles[profileKey(for: name)] = profile
        state.aliases[device.id] = name
        save()
    }

    private func identityContext(for device: Device) -> DeviceIdentityContext {
        if let directAlias = state.aliases[device.id], !directAlias.isEmpty {
            let profile = profile(named: directAlias)
            return DeviceIdentityContext(
                alias: directAlias,
                note: profile.lockedMacs.contains(device.mac.lowercased()) ? "MAC locked match" : "Saved name match",
                isMacLocked: profile.lockedMacs.contains(device.mac.lowercased()),
                confirmedZone: profile.confirmedZone,
                previousZone: profile.lastZone
            )
        }

        let mac = device.mac.lowercased()
        let hostname = device.hostname?.lowercased()
        var bestContext = DeviceIdentityContext(alias: nil, note: nil, isMacLocked: false, confirmedZone: nil, previousZone: nil)

        for profile in state.identityProfiles.values {
            let lockedMatch = profile.lockedMacs.contains(mac)
            if profile.deviceIDs.contains(device.id) || profile.macs.contains(mac) || lockedMatch {
                return DeviceIdentityContext(
                    alias: profile.name,
                    note: lockedMatch ? "MAC locked match" : "Known MAC/device identity",
                    isMacLocked: lockedMatch,
                    confirmedZone: profile.confirmedZone,
                    previousZone: profile.lastZone
                )
            }

            if let hostname, !hostname.isEmpty, profile.hostnames.contains(hostname) {
                bestContext = DeviceIdentityContext(
                    alias: profile.name,
                    note: "Hostname matches saved identity",
                    isMacLocked: false,
                    confirmedZone: profile.confirmedZone,
                    previousZone: profile.lastZone
                )
            } else if profile.ips.contains(device.ip), bestContext.alias == nil {
                let lockedMismatch = !profile.lockedMacs.isEmpty && !profile.lockedMacs.contains(mac)
                bestContext = DeviceIdentityContext(
                    alias: profile.name,
                    note: lockedMismatch ? "IP matches \(profile.name), but locked MAC differs" : "IP matches saved identity; confirm if MAC rotated",
                    isMacLocked: false,
                    confirmedZone: profile.confirmedZone,
                    previousZone: profile.lastZone
                )
            }
        }

        return bestContext
    }

    private func profile(named name: String) -> DeviceIdentityProfile {
        let key = profileKey(for: name)
        return state.identityProfiles[key] ?? DeviceIdentityProfile(name: name)
    }

    private func profileKey(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func appendUnique(_ value: String, to values: [String], limit: Int) -> [String] {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return values }
        var next = values.filter { $0 != cleaned }
        next.insert(cleaned, at: 0)
        return Array(next.prefix(limit))
    }

    private func presenceStatus(for record: DevicePresenceRecord, now: Date) -> DevicePresenceStatus {
        let restartMarked = record.restartMarkedUntil.map { $0 >= now } ?? false
        if restartMarked {
            return DevicePresenceStatus(
                title: "Device restart marked",
                detail: "Known device disappeared briefly and came back. Good moment to rename it.",
                badge: "RESTART",
                firstSeen: record.firstSeen,
                seenCount: record.seenCount,
                isNewToNetwork: false,
                isRestartMarked: true,
                isUnreachable: false,
                isNormal: false
            )
        }

        if record.lastReachableAt != nil, record.wasReachable == false {
            return DevicePresenceStatus(
                title: "Known device not answering",
                detail: "It may be powered off. If it answers again soon, NetBar will mark it as RESTART.",
                badge: "OFF?",
                firstSeen: record.firstSeen,
                seenCount: record.seenCount,
                isNewToNetwork: false,
                isRestartMarked: false,
                isUnreachable: true,
                isNormal: false
            )
        }

        if record.normalSince != nil || record.seenCount >= 3 {
            return DevicePresenceStatus(
                title: "Normally seen on this network",
                detail: "Seen repeatedly by NetBar.",
                badge: "NORMAL",
                firstSeen: record.firstSeen,
                seenCount: record.seenCount,
                isNewToNetwork: false,
                isRestartMarked: false,
                isUnreachable: false,
                isNormal: true
            )
        }

        return DevicePresenceStatus(
            title: "New to this network",
            detail: "Not enough sightings yet. Rename it now if you just turned something on.",
            badge: "NEW",
            firstSeen: record.firstSeen,
            seenCount: record.seenCount,
            isNewToNetwork: true,
            isRestartMarked: false,
            isUnreachable: false,
            isNormal: false
        )
    }

    private func shouldRecordIdentity(for node: DeviceLocationRadarNode) -> Bool {
        state.aliases[node.id] != nil || state.identityProfiles[profileKey(for: node.title)] != nil
    }

    private func displayNameForIdentity(_ node: DeviceLocationRadarNode) -> String? {
        if let alias = state.aliases[node.id], !alias.isEmpty {
            return alias
        }
        if state.identityProfiles[profileKey(for: node.title)] != nil {
            return node.title
        }
        return nil
    }

    func setShowMacAddresses(_ show: Bool) {
        state.showMacAddresses = show
        save()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        state.launchAtLoginEnabled = enabled
        save()
    }

    var stateFileURL: URL {
        stateURL
    }
}

final class NetworkScanner {
    func scan(previousDevices: [String: Device], localInfo: LocalAddressInfo, activeLookup: Bool = true) -> [Device] {
        let reachableIPs = activeLookup ? probeLocalSubnet(from: localInfo.ip) : []

        let now = Date()
        let output = run("/usr/sbin/arp", ["-a"])
        let devices = output
            .split(separator: "\n")
            .compactMap { parseARPLine(String($0), now: now, previousDevices: previousDevices, reachableIPs: reachableIPs) }

        return devices.sorted { lhs, rhs in
            compareIPv4(lhs.ip, rhs.ip)
        }
    }

    private func probeLocalSubnet(from localIP: String?) -> Set<String> {
        guard let targets = localSubnetTargets(from: localIP), !targets.isEmpty else { return [] }

        let queue = DispatchQueue(label: "netbar.local-lookup", attributes: .concurrent)
        let group = DispatchGroup()
        let limit = DispatchSemaphore(value: 32)
        let lock = NSLock()
        var reachableIPs = Set<String>()

        for target in targets {
            limit.wait()
            group.enter()
            queue.async {
                if self.runPingProbe(target) {
                    lock.lock()
                    reachableIPs.insert(target)
                    lock.unlock()
                }
                limit.signal()
                group.leave()
            }
        }

        _ = group.wait(timeout: .now() + 6)
        return reachableIPs
    }

    private func localSubnetTargets(from localIP: String?) -> [String]? {
        guard let localIP else { return nil }
        let parts = localIP.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, isPrivateIPv4(parts) else { return nil }

        let prefix = "\(parts[0]).\(parts[1]).\(parts[2])"
        return (1...254)
            .filter { $0 != parts[3] }
            .map { "\(prefix).\($0)" }
    }

    private func isPrivateIPv4(_ parts: [Int]) -> Bool {
        guard parts.count == 4 else { return false }
        return parts[0] == 10
            || (parts[0] == 172 && (16...31).contains(parts[1]))
            || (parts[0] == 192 && parts[1] == 168)
            || (parts[0] == 169 && parts[1] == 254)
    }

    private func runPingProbe(_ ip: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "350", ip]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        return process.terminationStatus == 0
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

    func gatewayIPAddress(localInfo: LocalAddressInfo? = nil) -> String? {
        if let interfaceName = localInfo?.interfaceName,
           !isTunnelInterface(interfaceName),
           let gateway = gatewayIPAddressFromRoutingTable(interfaceName: interfaceName) {
            return gateway
        }

        let output = run("/sbin/route", ["-n", "get", "default"])
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("gateway:") {
                let gateway = trimmed.replacingOccurrences(of: "gateway:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if isPrivateIPv4String(gateway) {
                    return gateway
                }
            }
        }
        return nil
    }

    private func gatewayIPAddressFromRoutingTable(interfaceName: String) -> String? {
        let output = run("/usr/sbin/netstat", ["-rn", "-f", "inet"])
        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count >= 4,
                  parts[0] == "default",
                  parts.last == interfaceName,
                  isPrivateIPv4String(parts[1]) else {
                continue
            }
            return parts[1]
        }
        return nil
    }

    private func isPrivateIPv4String(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        return isPrivateIPv4(parts)
    }

    private func parseARPLine(_ line: String, now: Date, previousDevices: [String: Device], reachableIPs: Set<String>) -> Device? {
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
            isReachable: reachableIPs.contains(ip),
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

    func sync(enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try uninstall()
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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
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
        launchAtLoginButton.state = store.state.launchAtLoginEnabled ? .on : .off
        showMACButton.state = store.state.showMacAddresses ? .on : .off
        let launchSetting = store.state.launchAtLoginEnabled ? "on" : "off"
        let launchAgent = startupManager.isInstalled ? "installed" : "not installed"
        let macDisplay = store.state.showMacAddresses ? "shown" : "hidden"
        statusLabel.stringValue = "Launch at login: \(launchSetting) (\(launchAgent)). MAC addresses: \(macDisplay)."
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        do {
            store.setLaunchAtLoginEnabled(enabled)
            try startupManager.sync(enabled: enabled)
        } catch {
            store.setLaunchAtLoginEnabled(!enabled)
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
    var statusBadge: String? = nil
    var statusColor: NSColor? = nil
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
        if node.isNew || node.statusBadge == "RESTART" || node.statusBadge == "OFF?" {
            (node.statusColor ?? node.accent).withAlphaComponent(0.08).setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        node.accent.withAlphaComponent(0.20).setFill()
        NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY, width: 7, height: rect.height), xRadius: 4, yRadius: 4).fill()

        let highlightColor = node.statusColor ?? node.accent
        let isHighlighted = node.isNew || node.statusBadge == "RESTART" || node.statusBadge == "OFF?"
        (isHighlighted ? highlightColor : NSColor.separatorColor).withAlphaComponent(isHighlighted ? 0.95 : 0.8).setStroke()
        path.lineWidth = isHighlighted ? 2.2 : 1
        path.stroke()

        if let statusBadge = node.statusBadge {
            drawStatusBadge(statusBadge, in: rect, accent: highlightColor)
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
        let titleWidth = node.statusBadge == nil ? textWidth : max(80, textWidth - 70)
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

    private func drawStatusBadge(_ text: String, in rect: NSRect, accent: NSColor) {
        let badgeWidth: CGFloat = text == "RESTART" ? 62 : 46
        let badgeRect = NSRect(x: rect.maxX - badgeWidth - 15, y: rect.minY + 13, width: badgeWidth, height: 18)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 9, yRadius: 9)
        accent.setFill()
        badgePath.fill()
        drawText(
            text,
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

    func update(devices: [Device], localInfo: LocalAddressInfo, gatewayIP: String?, lastRefresh: Date?, presenceStatuses: [String: DevicePresenceStatus]) {
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
            .map { node(for: $0, role: nil, forcedIcon: nil, accent: nil, presence: presenceStatuses[$0.id]) }

        let refreshed = lastRefresh.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? "never"
        let newCount = mapView.deviceNodes.filter(\.isNew).count
        let restartCount = mapView.deviceNodes.filter { $0.statusBadge == "RESTART" }.count
        let offCount = mapView.deviceNodes.filter { $0.statusBadge == "OFF?" }.count
        let statusParts = [
            newCount > 0 ? "\(newCount) new" : nil,
            restartCount > 0 ? "\(restartCount) restarted" : nil,
            offCount > 0 ? "\(offCount) off?" : nil
        ].compactMap { $0 }
        let statusText = statusParts.isEmpty ? "" : " - \(statusParts.joined(separator: ", "))"
        mapView.footerText = "\(mapView.deviceNodes.count) devices below this Mac\(statusText) - refreshed \(refreshed)"
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

    private func node(for device: Device, role: String?, forcedIcon: String?, accent: NSColor?, presence: DevicePresenceStatus? = nil) -> NetworkMapNode {
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

        let statusBadge: String?
        let statusColor: NSColor?
        if presence?.isRestartMarked == true {
            statusBadge = "RESTART"
            statusColor = .systemOrange
        } else if presence?.isUnreachable == true {
            statusBadge = "OFF?"
            statusColor = .systemGray
        } else if presence?.isNewToNetwork == true {
            statusBadge = "NEW"
            statusColor = accent ?? classification.accent
        } else {
            statusBadge = nil
            statusColor = nil
        }

        return NetworkMapNode(
            title: title,
            subtitle: device.ip,
            detail: role ?? presence?.title ?? mapDetail(for: classification),
            icon: forcedIcon ?? classification.icon,
            accent: accent ?? classification.accent,
            isNew: presence?.isNewToNetwork == true,
            statusBadge: statusBadge,
            statusColor: statusColor
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

struct DeviceLocationRadarNode {
    var id: String
    var title: String
    var detail: String
    var zone: String
    var ip: String?
    var mac: String?
    var confidence: Int
    var category: String
    var icon: String
    var accent: NSColor
    var angle: CGFloat
    var radius: CGFloat
    var isLeftBehind: Bool
    var isNew: Bool
    var identityNote: String?
    var movementNote: String?
    var isMacLocked: Bool
    var isZoneConfirmed: Bool
}

final class DeviceLocationLayer {
    struct Observation {
        var id: String
        var name: String
        var source: String
        var ip: String?
        var mac: String?
        var hostname: String?
        var rssi: Int?
        var inferredClass: String
        var displayType: String
        var icon: String
        var accent: NSColor
        var confidenceHint: String
        var identityNote: String?
        var confirmedZone: String?
        var previousZone: String?
        var isMacLocked: Bool
    }

    private let dbURL: URL
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var isPaused = false
    private(set) var lastSnapshotAt: Date?
    private(set) var lastStateLines: [String] = ["Learning baseline from local snapshots."]
    private(set) var recentChangeLines: [String] = ["No changes recorded yet."]
    private(set) var knownPresentCount = 0
    private(set) var mobilePresentCount = 0
    private(set) var unknownPresentCount = 0
    private(set) var leftBehindAlerts: [String] = []
    private(set) var radarNodes: [DeviceLocationRadarNode] = []

    private var hasSeenBaseline = false
    private var lastPresentIDs = Set<String>()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("NetBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        dbURL = folder.appendingPathComponent("device-location-layer.sqlite")
        initializeDatabase()
    }

    var databaseURL: URL {
        dbURL
    }

    var statusText: String {
        if isPaused {
            return "paused"
        }
        if lastSnapshotAt == nil {
            return "learning"
        }
        return "scanning"
    }

    func recordSnapshot(devices: [Device], localInfo: LocalAddressInfo, routerIP: String?, aliases: [String: String] = [:], identityContexts: [String: DeviceIdentityContext] = [:]) {
        guard !isPaused else { return }

        let now = Date()
        let snapshotID = Int(now.timeIntervalSince1970 * 1000)
        let wifi = wifiInfo()
        var observations = networkObservations(from: devices, localInfo: localInfo, routerIP: routerIP, aliases: aliases, identityContexts: identityContexts)
        addRouterObservationIfNeeded(to: &observations, routerIP: routerIP, aliases: aliases)
        observations.append(contentsOf: bluetoothObservations())
        observations = deduplicatedObservations(observations)

        let currentIDs = Set(observations.map(\.id))
        let appeared = hasSeenBaseline ? currentIDs.subtracting(lastPresentIDs) : []
        let disappeared = hasSeenBaseline ? lastPresentIDs.subtracting(currentIDs) : []
        hasSeenBaseline = true
        lastPresentIDs = currentIDs

        writeSnapshot(
            id: snapshotID,
            date: now,
            wifi: wifi,
            localInfo: localInfo,
            routerIP: routerIP,
            observations: observations
        )

        updateState(
            observations: observations,
            appeared: appeared,
            disappeared: disappeared,
            routerIP: routerIP,
            snapshotID: snapshotID,
            date: now
        )
    }

    func resetBaseline() {
        sqliteExec("""
        DELETE FROM observations;
        DELETE FROM snapshots;
        DELETE FROM classifications;
        DELETE FROM clusters;
        DELETE FROM confidence_scores;
        DELETE FROM learned_baselines;
        UPDATE devices SET observation_count = 0;
        """)
        lastSnapshotAt = nil
        lastStateLines = ["Baseline reset. Learning will restart on the next snapshot."]
        recentChangeLines = ["Baseline reset."]
        knownPresentCount = 0
        mobilePresentCount = 0
        unknownPresentCount = 0
        leftBehindAlerts = []
        radarNodes = []
        hasSeenBaseline = false
        lastPresentIDs.removeAll()
    }

    func markDevice(id: String, name: String, classification: String?, ignored: Bool) {
        let now = dateFormatter.string(from: Date())
        sqliteExec("""
        INSERT INTO devices (id, display_name, user_classification, ignored, first_seen, last_seen, observation_count)
        VALUES (\(sqlValue(id)), \(sqlValue(name)), \(sqlValue(classification)), \(ignored ? 1 : 0), \(sqlValue(now)), \(sqlValue(now)), 0)
        ON CONFLICT(id) DO UPDATE SET
            display_name = excluded.display_name,
            user_classification = excluded.user_classification,
            ignored = excluded.ignored,
            last_seen = excluded.last_seen;
        """)
    }

    private func initializeDatabase() {
        sqliteExec("""
        CREATE TABLE IF NOT EXISTS devices (
            id TEXT PRIMARY KEY,
            display_name TEXT,
            last_ip TEXT,
            last_mac TEXT,
            hostname TEXT,
            manufacturer_hint TEXT,
            inferred_class TEXT,
            user_classification TEXT,
            ignored INTEGER DEFAULT 0,
            first_seen TEXT,
            last_seen TEXT,
            observation_count INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS snapshots (
            id INTEGER PRIMARY KEY,
            captured_at TEXT,
            wifi_ssid TEXT,
            wifi_bssid TEXT,
            wifi_rssi INTEGER,
            local_ip TEXT,
            local_interface TEXT,
            router_ip TEXT
        );
        CREATE TABLE IF NOT EXISTS observations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_id INTEGER,
            device_id TEXT,
            source TEXT,
            present INTEGER,
            ip TEXT,
            mac TEXT,
            hostname TEXT,
            rssi INTEGER,
            ping_present INTEGER
        );
        CREATE TABLE IF NOT EXISTS clusters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cluster_key TEXT,
            device_ids TEXT,
            confidence REAL,
            updated_at TEXT
        );
        CREATE TABLE IF NOT EXISTS classifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            snapshot_id INTEGER,
            class TEXT,
            state TEXT,
            confidence REAL,
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS confidence_scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            snapshot_id INTEGER,
            presence_score REAL,
            stability_score REAL,
            mobility_score REAL,
            cluster_score REAL,
            novelty_score REAL,
            near_mac_score REAL,
            left_behind_score REAL
        );
        CREATE TABLE IF NOT EXISTS learned_baselines (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TEXT
        );
        """)
    }

    private func networkObservations(from devices: [Device], localInfo: LocalAddressInfo, routerIP: String?, aliases: [String: String], identityContexts: [String: DeviceIdentityContext]) -> [Observation] {
        let normalizedRouterIP = routerIP?.trimmingCharacters(in: .whitespacesAndNewlines)
        return devices.compactMap { device in
            let saved = savedClassification(for: device.id)
            guard !saved.ignored else { return nil }
            guard !isRadarNoise(device: device, localInfo: localInfo) else { return nil }
            let isRouter = device.ip == normalizedRouterIP
            let identityContext = identityContexts[device.id]
            let name = identityContext?.alias
                ?? aliases[device.id]
                ?? (device.hostname?.isEmpty == false ? device.hostname! : nil)
                ?? (isRouter ? "Router / Gateway" : "Device \(lastOctet(of: device.ip))")
            let guess = DeviceClassifier.classify(device: device, name: name)
            let inferred = saved.classification ?? inferredClass(from: guess.label, ip: device.ip, routerIP: normalizedRouterIP)
            return Observation(
                id: device.id,
                name: name,
                source: isRouter ? "router" : "arp",
                ip: device.ip,
                mac: device.mac,
                hostname: device.hostname,
                rssi: nil,
                inferredClass: inferred,
                displayType: isRouter ? "Router" : guess.label,
                icon: isRouter ? "📡" : guess.icon,
                accent: isRouter ? .systemBlue : guess.accent,
                confidenceHint: guess.confidence,
                identityNote: identityContext?.note,
                confirmedZone: identityContext?.confirmedZone,
                previousZone: identityContext?.previousZone,
                isMacLocked: identityContext?.isMacLocked ?? false
            )
        }
    }

    private func addRouterObservationIfNeeded(to observations: inout [Observation], routerIP: String?, aliases: [String: String]) {
        guard let routerIP, !observations.contains(where: { $0.ip == routerIP || $0.source == "router" }) else { return }
        let id = "router:\(routerIP)"
        observations.append(
            Observation(
                id: id,
                name: aliases[id] ?? "Router / Gateway",
                source: "router",
                ip: routerIP,
                mac: nil,
                hostname: nil,
                rssi: nil,
                inferredClass: "static",
                displayType: "Router",
                icon: "📡",
                accent: .systemBlue,
                confidenceHint: "medium",
                identityNote: aliases[id] == nil ? nil : "Saved router name",
                confirmedZone: nil,
                previousZone: nil,
                isMacLocked: false
            )
        )
    }

    private func isRadarNoise(device: Device, localInfo: LocalAddressInfo) -> Bool {
        if let localIP = localInfo.ip, device.ip == localIP {
            return true
        }
        if device.ip.hasSuffix(".0") || device.ip.hasSuffix(".255") {
            return true
        }
        let mac = device.mac.lowercased()
        if mac == "ff:ff:ff:ff:ff:ff" || mac == "0:0:0:0:0:0" || mac == "00:00:00:00:00:00" {
            return true
        }
        return false
    }

    private func savedClassification(for id: String) -> (classification: String?, ignored: Bool) {
        let output = sqliteOutput("SELECT COALESCE(user_classification, ''), ignored FROM devices WHERE id = \(sqlValue(id));")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = output.split(separator: "|", omittingEmptySubsequences: false)
        let classification = pieces.first.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
        let ignored = pieces.dropFirst().first.map { $0 == "1" } ?? false
        return (classification, ignored)
    }

    private func bluetoothObservations() -> [Observation] {
        let output = run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var observations: [Observation] = []
        collectBluetoothObjects(json, into: &observations)
        return deduplicatedObservations(observations)
    }

    private func deduplicatedObservations(_ observations: [Observation]) -> [Observation] {
        var seen: [String: Observation] = [:]

        for observation in observations {
            let key: String
            if let mac = observation.mac?.lowercased(), !mac.isEmpty {
                key = "\(observation.source):\(mac)"
            } else if let ip = observation.ip, !ip.isEmpty {
                key = "\(observation.source):\(ip)"
            } else {
                key = "\(observation.source):\(observation.name.lowercased())"
            }

            if let existing = seen[key] {
                if existing.rssi == nil && observation.rssi != nil {
                    seen[key] = observation
                }
            } else {
                seen[key] = observation
            }
        }

        return Array(seen.values)
    }

    private func collectBluetoothObjects(_ object: Any, into observations: inout [Observation]) {
        if let dictionary = object as? [String: Any] {
            let name = (dictionary["_name"] as? String)
                ?? (dictionary["device_name"] as? String)
                ?? (dictionary["name"] as? String)
            let address = (dictionary["device_address"] as? String)
                ?? (dictionary["address"] as? String)
                ?? (dictionary["bt_address"] as? String)
            let rssiValue = dictionary["device_rssi"] as? Int ?? dictionary["rssi"] as? Int

            if let name, !name.isEmpty {
                let id = "bt:\((address ?? name).lowercased())"
                observations.append(
                    Observation(
                        id: id,
                        name: name,
                        source: "bluetooth",
                        ip: nil,
                        mac: address,
                        hostname: nil,
                        rssi: rssiValue,
                        inferredClass: inferredBluetoothClass(from: name),
                        displayType: "Bluetooth",
                        icon: "📱",
                        accent: .systemPurple,
                        confidenceHint: rssiValue == nil ? "low" : "medium",
                        identityNote: nil,
                        confirmedZone: nil,
                        previousZone: nil,
                        isMacLocked: false
                    )
                )
            }

            for value in dictionary.values {
                collectBluetoothObjects(value, into: &observations)
            }
        } else if let array = object as? [Any] {
            for value in array {
                collectBluetoothObjects(value, into: &observations)
            }
        }
    }

    private func wifiInfo() -> (ssid: String?, bssid: String?, rssi: Int?) {
        let output = run("/usr/sbin/system_profiler", ["SPAirPortDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return (nil, nil, nil)
        }
        return findWiFiStatus(in: json)
    }

    private func findWiFiStatus(in object: Any) -> (ssid: String?, bssid: String?, rssi: Int?) {
        if let dictionary = object as? [String: Any] {
            let ssid = dictionary["spairport_current_network_information"] as? String
                ?? dictionary["spairport_network"] as? String
                ?? dictionary["ssid"] as? String
            let bssid = dictionary["spairport_bssid"] as? String
                ?? dictionary["bssid"] as? String
            let rssi = dictionary["spairport_signal_noise"] as? Int
                ?? dictionary["agrCtlRSSI"] as? Int
                ?? dictionary["rssi"] as? Int
            if ssid != nil || bssid != nil || rssi != nil {
                return (ssid, bssid, rssi)
            }
            for value in dictionary.values {
                let found = findWiFiStatus(in: value)
                if found.ssid != nil || found.bssid != nil || found.rssi != nil {
                    return found
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                let found = findWiFiStatus(in: value)
                if found.ssid != nil || found.bssid != nil || found.rssi != nil {
                    return found
                }
            }
        }
        return (nil, nil, nil)
    }

    private func writeSnapshot(id: Int, date: Date, wifi: (ssid: String?, bssid: String?, rssi: Int?), localInfo: LocalAddressInfo, routerIP: String?, observations: [Observation]) {
        let now = dateFormatter.string(from: date)
        var sql = """
        BEGIN TRANSACTION;
        INSERT INTO snapshots (id, captured_at, wifi_ssid, wifi_bssid, wifi_rssi, local_ip, local_interface, router_ip)
        VALUES (\(id), \(sqlValue(now)), \(sqlValue(wifi.ssid)), \(sqlValue(wifi.bssid)), \(sqlValue(wifi.rssi)), \(sqlValue(localInfo.ip)), \(sqlValue(localInfo.interfaceName)), \(sqlValue(routerIP)));
        INSERT INTO learned_baselines (key, value, updated_at)
        VALUES ('total_snapshots', CAST((SELECT COUNT(*) FROM snapshots) AS TEXT), \(sqlValue(now)))
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;
        """

        for observation in observations {
            sql += """
            INSERT INTO devices (id, display_name, last_ip, last_mac, hostname, manufacturer_hint, inferred_class, first_seen, last_seen, observation_count)
            VALUES (\(sqlValue(observation.id)), \(sqlValue(observation.name)), \(sqlValue(observation.ip)), \(sqlValue(observation.mac)), \(sqlValue(observation.hostname)), \(sqlValue(observation.confidenceHint)), \(sqlValue(observation.inferredClass)), \(sqlValue(now)), \(sqlValue(now)), 1)
            ON CONFLICT(id) DO UPDATE SET
                display_name = excluded.display_name,
                last_ip = excluded.last_ip,
                last_mac = excluded.last_mac,
                hostname = excluded.hostname,
                manufacturer_hint = excluded.manufacturer_hint,
                inferred_class = excluded.inferred_class,
                last_seen = excluded.last_seen,
                observation_count = observation_count + 1;
            INSERT INTO observations (snapshot_id, device_id, source, present, ip, mac, hostname, rssi, ping_present)
            VALUES (\(id), \(sqlValue(observation.id)), \(sqlValue(observation.source)), 1, \(sqlValue(observation.ip)), \(sqlValue(observation.mac)), \(sqlValue(observation.hostname)), \(sqlValue(observation.rssi)), \(observation.source == "arp" || observation.source == "router" ? 1 : 0));
            """
        }

        sql += "COMMIT;"
        sqliteExec(sql)
    }

    private func updateState(observations: [Observation], appeared: Set<String>, disappeared: Set<String>, routerIP: String?, snapshotID: Int, date: Date) {
        let totalSnapshots = max(1, Int(sqliteOutput("SELECT COUNT(*) FROM snapshots;").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1)
        var lines: [String] = []
        var mobileCount = 0
        var unknownCount = 0
        var leftBehind: [String] = []
        var nodes: [DeviceLocationRadarNode] = []
        let disappearedMobileCount = disappeared.count
        let normalizedRouterIP = routerIP?.trimmingCharacters(in: .whitespacesAndNewlines)

        let now = dateFormatter.string(from: date)
        var scoreSQL = "BEGIN TRANSACTION;"

        for observation in observations {
            let seenCount = max(1, Int(sqliteOutput("SELECT observation_count FROM devices WHERE id = \(sqlValue(observation.id));").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1)
            let stability = min(100, Double(seenCount) / Double(totalSnapshots) * 100)
            let presence = 100.0
            let mobility = mobilityScore(for: observation.inferredClass, stability: stability)
            let novelty = appeared.contains(observation.id) || seenCount <= 2 ? 85.0 : max(0, 100 - stability)
            let nearMac = observation.source == "bluetooth" ? (observation.rssi == nil ? 65.0 : 80.0) : 45.0
            let cluster = clusterScore(for: observation, appeared: appeared)
            let leftBehindScore = leftBehindScore(for: observation, disappearedMobileCount: disappearedMobileCount)
            let confidence = min(96, max(20, (presence * 0.25) + (stability * 0.25) + (nearMac * 0.2) + ((100 - novelty) * 0.15) + (cluster * 0.15)))
            let isRouterObservation = observation.source == "router" || observation.ip == normalizedRouterIP
            let nodeTitle = observation.name
            let nodeCategory = isRouterObservation ? "Router" : observation.displayType
            let nodeIcon = isRouterObservation ? "📡" : observation.icon
            let nodeAccent: NSColor = isRouterObservation ? .systemBlue : observation.accent
            let observedZone = isRouterObservation ? "Near router" : zoneLabel(for: observation)
            let zone = observation.confirmedZone ?? observedZone
            let state = "\(nodeTitle): \(zone), \(nodeCategory), confidence \(Int(confidence.rounded()))%"
            let isLeftBehind = leftBehindScore >= 60
            let movementNote = movementNote(from: observation.previousZone, to: zone)

            if observation.inferredClass == "mobile" || observation.inferredClass == "semi-static" {
                mobileCount += 1
            }
            if observation.inferredClass == "transient" {
                unknownCount += 1
            }
            if isLeftBehind {
                leftBehind.append("\(nodeTitle) may be left behind")
            }
            lines.append(state)
            nodes.append(
                DeviceLocationRadarNode(
                    id: observation.id,
                    title: nodeTitle,
                    detail: state,
                    zone: zone,
                    ip: observation.ip,
                    mac: observation.mac,
                    confidence: Int(confidence.rounded()),
                    category: nodeCategory,
                    icon: nodeIcon,
                    accent: nodeAccent,
                    angle: angle(for: observation.id, zone: zone),
                    radius: isRouterObservation ? 0.92 : radius(for: observation, zone: zone),
                    isLeftBehind: isLeftBehind,
                    isNew: appeared.contains(observation.id),
                    identityNote: observation.identityNote,
                    movementNote: movementNote,
                    isMacLocked: observation.isMacLocked,
                    isZoneConfirmed: observation.confirmedZone != nil
                )
            )

            scoreSQL += """
            INSERT INTO classifications (device_id, snapshot_id, class, state, confidence, created_at)
            VALUES (\(sqlValue(observation.id)), \(snapshotID), \(sqlValue(observation.inferredClass)), \(sqlValue(state)), \(confidence), \(sqlValue(now)));
            INSERT INTO confidence_scores (device_id, snapshot_id, presence_score, stability_score, mobility_score, cluster_score, novelty_score, near_mac_score, left_behind_score)
            VALUES (\(sqlValue(observation.id)), \(snapshotID), \(presence), \(stability), \(mobility), \(cluster), \(novelty), \(nearMac), \(leftBehindScore));
            """
        }

        scoreSQL += "COMMIT;"
        sqliteExec(scoreSQL)

        var changes: [String] = []
        if !appeared.isEmpty {
            changes.append("Appeared: \(names(for: appeared).joined(separator: ", "))")
        }
        if !disappeared.isEmpty {
            changes.append("Disappeared: \(names(for: disappeared).joined(separator: ", "))")
        }
        if changes.isEmpty {
            changes.append("No device presence changes in the last snapshot.")
        }

        lastSnapshotAt = date
        lastStateLines = lines.isEmpty ? ["No devices observed in the latest snapshot."] : lines.sorted()
        recentChangeLines = changes
        knownPresentCount = observations.count
        mobilePresentCount = mobileCount
        unknownPresentCount = unknownCount
        leftBehindAlerts = leftBehind
        radarNodes = nodes.sorted { first, second in
            if first.isLeftBehind != second.isLeftBehind {
                return first.isLeftBehind
            }
            if first.isNew != second.isNew {
                return first.isNew
            }
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }

    private func names(for ids: Set<String>) -> [String] {
        ids.map { id in
            let output = sqliteOutput("SELECT display_name FROM devices WHERE id = \(sqlValue(id));")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? id : output
        }.sorted()
    }

    private func inferredClass(from label: String, ip: String, routerIP: String?) -> String {
        if ip == routerIP || label == "Router" || label == "Printer" || label == "TV / Media" || label == "Smart Home" {
            return "static"
        }
        if label == "Games" || label == "Computer" {
            return "semi-static"
        }
        if label == "Mobile" || label == "Mobile or laptop" {
            return "mobile"
        }
        return "transient"
    }

    private func inferredBluetoothClass(from name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("watch") || lower.contains("phone") || lower.contains("iphone") || lower.contains("airtag") || lower.contains("airpods") || lower.contains("headphone") {
            return "mobile"
        }
        return "transient"
    }

    private func mobilityScore(for inferredClass: String, stability: Double) -> Double {
        switch inferredClass {
        case "static":
            return max(5, 30 - stability * 0.2)
        case "semi-static":
            return max(30, 80 - stability * 0.4)
        case "mobile":
            return max(55, 100 - stability * 0.3)
        default:
            return max(65, 100 - stability * 0.2)
        }
    }

    private func clusterScore(for observation: Observation, appeared: Set<String>) -> Double {
        guard observation.inferredClass == "mobile" || observation.inferredClass == "transient" else { return 15 }
        return appeared.count >= 2 && appeared.contains(observation.id) ? 70 : 35
    }

    private func leftBehindScore(for observation: Observation, disappearedMobileCount: Int) -> Double {
        guard observation.inferredClass == "mobile" || observation.inferredClass == "transient" else { return 0 }
        return disappearedMobileCount >= 2 ? 62 : 0
    }

    private func zoneLabel(for observation: Observation) -> String {
        if observation.source == "router" {
            return "Near router"
        }
        if observation.source == "bluetooth" {
            return "Bluetooth nearby"
        }
        if observation.source == "arp" {
            return "Home network present"
        }
        return "Unknown"
    }

    private func movementNote(from previousZone: String?, to zone: String) -> String? {
        guard let previousZone, !previousZone.isEmpty else { return nil }
        if previousZone == zone {
            return "Stable in \(zone)"
        }
        return "Moved: \(previousZone) → \(zone)"
    }

    private func accent(for inferredClass: String, source: String) -> NSColor {
        if source == "bluetooth" {
            return .systemPurple
        }
        switch inferredClass {
        case "static":
            return .systemBlue
        case "semi-static":
            return .systemTeal
        case "mobile":
            return .systemIndigo
        default:
            return .systemOrange
        }
    }

    private func angle(for id: String, zone: String? = nil) -> CGFloat {
        if let zoneAngle = fixedZoneAngle(zone) {
            return zoneAngle
        }
        let total = id.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return CGFloat(total % 360) * .pi / 180
    }

    private func radius(for observation: Observation, zone: String? = nil) -> CGFloat {
        if observation.source == "router" {
            return 0.92
        }
        if fixedZoneAngle(zone) != nil {
            return 0.68
        }
        if observation.source == "bluetooth" {
            return 0.36
        }
        switch observation.inferredClass {
        case "static":
            return 0.76
        case "semi-static":
            return 0.62
        case "mobile":
            return 0.50
        default:
            return 0.84
        }
    }

    private func fixedZoneAngle(_ zone: String?) -> CGFloat? {
        guard let zone else { return nil }
        switch zone.lowercased() {
        case "kitchen":
            return 5.10
        case "bedroom":
            return 3.78
        case "office":
            return 0.25
        case "living room":
            return 1.55
        case "hallway":
            return 2.50
        case "desk":
            return 0.72
        default:
            return nil
        }
    }

    private func lastOctet(of ip: String) -> String {
        ip.split(separator: ".").last.map { ".\($0)" } ?? ip
    }

    private func sqliteExec(_ sql: String) {
        _ = runSQLite(sql)
    }

    private func sqliteOutput(_ sql: String) -> String {
        runSQLite(sql, output: true)
    }

    private func runSQLite(_ sql: String, output: Bool = false) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = output
            ? ["-batch", "-noheader", dbURL.path, sql]
            : ["-batch", dbURL.path, sql]

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

    private func sqlValue(_ value: String?) -> String {
        guard let value else { return "NULL" }
        return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    private func sqlValue(_ value: Int?) -> String {
        guard let value else { return "NULL" }
        return "\(value)"
    }

    private func run(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return ""
        }

        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

final class DeviceLocationRadarView: NSView {
    var nodes: [DeviceLocationRadarNode] = []
    var statusText = "learning"
    var summaryText = "No snapshots yet."
    var lastSnapshotText = "never"
    var recentChanges: [String] = []
    var leftBehindAlerts: [String] = []
    var showMacAddresses = false
    var onRenameNode: ((DeviceLocationRadarNode) -> Void)?
    var onSetZoneNode: ((DeviceLocationRadarNode) -> Void)?

    private var selectedNodeID: String?
    private var sweepAngle: CGFloat = 0
    private var animationTimer: Timer?
    private var hitRects: [String: NSRect] = [:]
    private var renameButtonRect: NSRect?
    private var zoneButtonRect: NSRect?

    override var isFlipped: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            animationTimer?.invalidate()
            animationTimer = nil
        } else if animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.sweepAngle = (self.sweepAngle + 0.035).truncatingRemainder(dividingBy: .pi * 2)
                self.needsDisplay = true
            }
        }
    }

    func updateFromLayer(_ layer: DeviceLocationLayer, formattedSnapshot: String, showMacAddresses: Bool) {
        nodes = layer.radarNodes
        statusText = layer.statusText
        summaryText = "\(layer.knownPresentCount) present - \(layer.mobilePresentCount) mobile - \(layer.unknownPresentCount) unknown"
        lastSnapshotText = formattedSnapshot
        recentChanges = Array(layer.recentChangeLines.prefix(3))
        leftBehindAlerts = Array(layer.leftBehindAlerts.prefix(3))
        self.showMacAddresses = showMacAddresses

        if let selectedNodeID, nodes.contains(where: { $0.id == selectedNodeID }) {
            self.selectedNodeID = selectedNodeID
        } else {
            self.selectedNodeID = nodes.first(where: { $0.category == "Router" })?.id ?? nodes.first?.id
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if let renameButtonRect, renameButtonRect.contains(location), let selectedNode {
            onRenameNode?(selectedNode)
            return
        }
        if let zoneButtonRect, zoneButtonRect.contains(location), let selectedNode {
            onSetZoneNode?(selectedNode)
            return
        }
        if let match = hitRects.first(where: { $0.value.contains(location) }) {
            selectedNodeID = match.key
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let layout = currentLayout()
        hitRects.removeAll()
        renameButtonRect = nil
        zoneButtonRect = nil

        drawHeader()
        drawRadar(in: layout.radar)
        drawKey(in: layout.key)
        drawSelectedInfo(in: layout.detail)
    }

    private func currentLayout() -> (radar: NSRect, key: NSRect, detail: NSRect) {
        let padding: CGFloat = 28
        let headerHeight: CGFloat = 76
        let detailHeight: CGFloat = 154
        let keyWidth: CGFloat = min(250, max(210, bounds.width * 0.25))
        let detail = NSRect(x: padding, y: bounds.height - detailHeight - 20, width: bounds.width - padding * 2, height: detailHeight)
        let key = NSRect(x: bounds.width - keyWidth - padding, y: headerHeight, width: keyWidth, height: detail.minY - headerHeight - 18)
        let radar = NSRect(x: padding, y: headerHeight, width: key.minX - padding * 1.5, height: detail.minY - headerHeight - 18)
        return (radar, key, detail)
    }

    private func drawHeader() {
        drawText("Device Radar", in: NSRect(x: 28, y: 22, width: 300, height: 28), font: .systemFont(ofSize: 24, weight: .bold), color: .labelColor)
        drawText("Status: \(statusText) - \(summaryText) - last snapshot \(lastSnapshotText)", in: NSRect(x: 30, y: 52, width: bounds.width - 60, height: 18), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
    }

    private func drawRadar(in rect: NSRect) {
        let size = max(240, min(rect.width, rect.height))
        let radarBounds = NSRect(x: rect.midX - size / 2, y: rect.midY - size / 2, width: size, height: size)
        let center = NSPoint(x: radarBounds.midX, y: radarBounds.midY)
        let radius = size / 2 - 22

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(ovalIn: radarBounds).fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.systemGreen.withAlphaComponent(0.08).setFill()
        NSBezierPath(ovalIn: radarBounds.insetBy(dx: 10, dy: 10)).fill()

        for fraction in [0.33, 0.66, 1.0] {
            let ringRadius = radius * CGFloat(fraction)
            let ring = NSRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
            NSColor.systemGreen.withAlphaComponent(0.18).setStroke()
            let path = NSBezierPath(ovalIn: ring)
            path.lineWidth = 1
            path.stroke()
        }

        drawCrosshair(center: center, radius: radius)
        drawSweep(center: center, radius: radius)
        drawZoneLabels(center: center, radius: radius)
        drawCenterMac(center: center)

        for node in nodes.prefix(40) {
            drawRadarNode(node, center: center, radius: radius)
        }

        if nodes.isEmpty {
            drawText("Learning from snapshots", in: NSRect(x: radarBounds.midX - 110, y: radarBounds.midY + 36, width: 220, height: 20), font: .systemFont(ofSize: 13, weight: .medium), color: .secondaryLabelColor, alignment: .center)
        }
    }

    private func drawCrosshair(center: NSPoint, radius: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - radius, y: center.y))
        path.line(to: NSPoint(x: center.x + radius, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - radius))
        path.line(to: NSPoint(x: center.x, y: center.y + radius))
        NSColor.systemGreen.withAlphaComponent(0.14).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawSweep(center: NSPoint, radius: CGFloat) {
        let path = NSBezierPath()
        path.move(to: center)
        path.appendArc(withCenter: center, radius: radius, startAngle: degrees(sweepAngle - 0.32), endAngle: degrees(sweepAngle), clockwise: false)
        path.close()
        NSColor.systemGreen.withAlphaComponent(0.18).setFill()
        path.fill()

        let line = NSBezierPath()
        line.move(to: center)
        line.line(to: NSPoint(x: center.x + cos(sweepAngle) * radius, y: center.y + sin(sweepAngle) * radius))
        NSColor.systemGreen.withAlphaComponent(0.7).setStroke()
        line.lineWidth = 2
        line.stroke()
    }

    private func drawZoneLabels(center: NSPoint, radius: CGFloat) {
        drawText("Near Mac", in: NSRect(x: center.x - 44, y: center.y - radius * 0.38, width: 88, height: 16), font: .systemFont(ofSize: 10, weight: .medium), color: .secondaryLabelColor, alignment: .center)
        drawText("Home network", in: NSRect(x: center.x - 58, y: center.y - radius * 0.72, width: 116, height: 16), font: .systemFont(ofSize: 10, weight: .medium), color: .secondaryLabelColor, alignment: .center)
        drawText("Router edge", in: NSRect(x: center.x - 50, y: center.y + radius * 0.78, width: 100, height: 16), font: .systemFont(ofSize: 10, weight: .medium), color: .secondaryLabelColor, alignment: .center)
    }

    private func drawCenterMac(center: NSPoint) {
        let macRect = NSRect(x: center.x - 31, y: center.y - 31, width: 62, height: 62)
        NSColor.systemGreen.withAlphaComponent(0.24).setFill()
        NSBezierPath(ovalIn: macRect).fill()
        NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
        let path = NSBezierPath(ovalIn: macRect)
        path.lineWidth = 2
        path.stroke()
        drawText("💻", in: macRect.insetBy(dx: 8, dy: 8), font: .systemFont(ofSize: 24), color: .labelColor, alignment: .center)
    }

    private func drawRadarNode(_ node: DeviceLocationRadarNode, center: NSPoint, radius: CGFloat) {
        let pointRadius = radius * node.radius
        let position = NSPoint(x: center.x + cos(node.angle) * pointRadius, y: center.y + sin(node.angle) * pointRadius)
        let isSelected = node.id == selectedNodeID
        let dotSize: CGFloat = isSelected ? 32 : (node.isLeftBehind ? 28 : 24)
        let dotRect = NSRect(x: position.x - dotSize / 2, y: position.y - dotSize / 2, width: dotSize, height: dotSize)
        hitRects[node.id] = dotRect.insetBy(dx: -8, dy: -8)

        if isSelected {
            node.accent.withAlphaComponent(0.18).setFill()
            NSBezierPath(ovalIn: dotRect.insetBy(dx: -7, dy: -7)).fill()
        }

        node.accent.withAlphaComponent(node.isLeftBehind ? 0.96 : 0.86).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        NSColor.controlBackgroundColor.withAlphaComponent(0.92).setStroke()
        let outline = NSBezierPath(ovalIn: dotRect)
        outline.lineWidth = isSelected ? 2.6 : 1.5
        outline.stroke()

        drawText(node.isLeftBehind ? "!" : node.icon, in: dotRect.insetBy(dx: 3, dy: 3), font: .systemFont(ofSize: isSelected ? 16 : 13, weight: node.isLeftBehind ? .bold : .regular), color: .white, alignment: .center)
    }

    private func drawKey(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.75).setStroke()
        path.lineWidth = 1
        path.stroke()

        var y = rect.minY + 16
        drawText("Key", in: NSRect(x: rect.minX + 16, y: y, width: rect.width - 32, height: 22), font: .systemFont(ofSize: 16, weight: .semibold), color: .labelColor)
        y += 30

        for item in legendItems() {
            let count = nodes.filter { $0.category == item.title }.count
            guard count > 0 || item.alwaysShow else { continue }
            let marker = NSRect(x: rect.minX + 16, y: y + 2, width: 20, height: 20)
            item.color.withAlphaComponent(0.86).setFill()
            NSBezierPath(ovalIn: marker).fill()
            drawText(item.icon, in: marker.insetBy(dx: 3, dy: 3), font: .systemFont(ofSize: 11), color: .white, alignment: .center)
            drawText("\(item.title) \(count > 0 ? "(\(count))" : "")", in: NSRect(x: rect.minX + 44, y: y + 2, width: rect.width - 60, height: 18), font: .systemFont(ofSize: 12), color: .labelColor)
            y += 27
        }

        y += 8
        if !leftBehindAlerts.isEmpty {
            drawText("Alerts", in: NSRect(x: rect.minX + 16, y: y, width: rect.width - 32, height: 18), font: .systemFont(ofSize: 12, weight: .semibold), color: .systemOrange)
            y += 22
            for alert in leftBehindAlerts.prefix(2) {
                y = drawWrapped(alert, x: rect.minX + 16, y: y, width: rect.width - 32, color: .labelColor, height: 32)
            }
        }
    }

    private func drawSelectedInfo(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.75).setStroke()
        path.lineWidth = 1
        path.stroke()

        guard let node = selectedNode else {
            drawText("Select a radar dot", in: rect.insetBy(dx: 18, dy: 18), font: .systemFont(ofSize: 15, weight: .medium), color: .secondaryLabelColor)
            return
        }

        let iconRect = NSRect(x: rect.minX + 18, y: rect.minY + 19, width: 42, height: 42)
        node.accent.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: iconRect).fill()
        drawText(node.icon, in: iconRect.insetBy(dx: 6, dy: 7), font: .systemFont(ofSize: 19), color: .white, alignment: .center)

        let canSetZone = node.category != "Router"
        let editRect = NSRect(x: rect.minX + 74 + rect.width * 0.36 - 30, y: rect.minY + 14, width: 26, height: 24)
        renameButtonRect = editRect
        zoneButtonRect = nil
        drawText(node.title, in: NSRect(x: rect.minX + 74, y: rect.minY + 15, width: rect.width * 0.36 - (canSetZone ? 110 : 36), height: 24), font: .systemFont(ofSize: 17, weight: .semibold), color: .labelColor)
        drawPencilButton(in: editRect)
        if canSetZone {
            let zoneRect = NSRect(x: editRect.maxX + 8, y: rect.minY + 14, width: 66, height: 24)
            zoneButtonRect = zoneRect
            drawZoneButton(in: zoneRect, confirmed: node.isZoneConfirmed)
        }
        drawText("\(node.category) - \(node.zone) - confidence \(node.confidence)%", in: NSRect(x: rect.minX + 74, y: rect.minY + 42, width: rect.width * 0.42, height: 18), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)

        let ipText = node.ip ?? "No IP observed"
        let macText = showMacAddresses ? (node.mac ?? "No MAC observed") : "Hidden - enable Show MAC addresses"
        drawText("IP: \(ipText)", in: NSRect(x: rect.minX + 74, y: rect.minY + 72, width: rect.width * 0.38, height: 18), font: .monospacedSystemFont(ofSize: 12, weight: .regular), color: .labelColor)
        drawText("MAC: \(macText)", in: NSRect(x: rect.minX + 74, y: rect.minY + 96, width: rect.width * 0.48, height: 18), font: .monospacedSystemFont(ofSize: 12, weight: .regular), color: .secondaryLabelColor)
        let lockText = node.isMacLocked ? "Identity: MAC locked" : (node.identityNote ?? node.movementNote ?? "Identity: learning")
        drawText(lockText, in: NSRect(x: rect.minX + 74, y: rect.minY + 120, width: rect.width * 0.48, height: 18), font: .systemFont(ofSize: 12, weight: node.isMacLocked ? .medium : .regular), color: node.isMacLocked ? .systemGreen : .secondaryLabelColor)

        let rightX = rect.midX + 38
        drawText("Recent", in: NSRect(x: rightX, y: rect.minY + 17, width: rect.maxX - rightX - 18, height: 18), font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabelColor)
        var y = rect.minY + 41
        for change in recentChanges.prefix(3) {
            y = drawWrapped(change, x: rightX, y: y, width: rect.maxX - rightX - 18, color: .labelColor, height: 26)
        }
        if let movementNote = node.movementNote, node.identityNote != nil {
            drawText(movementNote, in: NSRect(x: rightX, y: rect.maxY - 54, width: rect.maxX - rightX - 18, height: 18), font: .systemFont(ofSize: 12, weight: .regular), color: .secondaryLabelColor)
        }
        if node.isNew {
            drawText("New in the current baseline window", in: NSRect(x: rightX, y: rect.maxY - 32, width: rect.maxX - rightX - 18, height: 18), font: .systemFont(ofSize: 12, weight: .medium), color: node.accent)
        } else if node.isLeftBehind {
            drawText("Possible left-behind device", in: NSRect(x: rightX, y: rect.maxY - 32, width: rect.maxX - rightX - 18, height: 18), font: .systemFont(ofSize: 12, weight: .medium), color: .systemOrange)
        }
    }

    private var selectedNode: DeviceLocationRadarNode? {
        if let selectedNodeID, let match = nodes.first(where: { $0.id == selectedNodeID }) {
            return match
        }
        return nodes.first(where: { $0.category == "Router" }) ?? nodes.first
    }

    func renameNode(id: String, to name: String) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].title = name
        nodes[index].detail = "\(name): \(nodes[index].zone), \(nodes[index].category), confidence \(nodes[index].confidence)%"
        selectedNodeID = id
        needsDisplay = true
    }

    private func drawPencilButton(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
        path.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 1
        path.stroke()
        drawText("✎", in: rect.insetBy(dx: 4, dy: 2), font: .systemFont(ofSize: 14, weight: .semibold), color: .controlAccentColor, alignment: .center)
    }

    private func drawZoneButton(in rect: NSRect, confirmed: Bool) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        (confirmed ? NSColor.systemGreen : NSColor.controlAccentColor).withAlphaComponent(0.14).setFill()
        path.fill()
        (confirmed ? NSColor.systemGreen : NSColor.controlAccentColor).withAlphaComponent(0.45).setStroke()
        path.lineWidth = 1
        path.stroke()
        drawText("Zone", in: rect.insetBy(dx: 6, dy: 3), font: .systemFont(ofSize: 12, weight: .semibold), color: confirmed ? .systemGreen : .controlAccentColor, alignment: .center)
    }

    private func legendItems() -> [(title: String, icon: String, color: NSColor, alwaysShow: Bool)] {
        [
            ("Router", "📡", .systemBlue, true),
            ("Mobile", "📱", .systemIndigo, true),
            ("Mobile or laptop", "📱", .systemIndigo, false),
            ("Computer", "💻", .systemGreen, true),
            ("Games", "🎮", .systemPurple, true),
            ("TV / Media", "📺", .systemRed, true),
            ("Printer", "🖨", .systemOrange, true),
            ("Smart Home", "🏠", .systemYellow, true),
            ("Bluetooth", "📱", .systemPurple, true),
            ("Unknown device", "🔹", .systemGray, true)
        ]
    }

    private func drawWrapped(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor, height: CGFloat) -> CGFloat {
        let rect = NSRect(x: x, y: y, width: width, height: height)
        drawText(text, in: rect, font: .systemFont(ofSize: 12), color: color, lineBreak: .byWordWrapping)
        return y + height + 4
    }

    private func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineBreak: NSLineBreakMode = .byTruncatingTail) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = lineBreak
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func degrees(_ radians: CGFloat) -> CGFloat {
        radians * 180 / .pi
    }
}

final class DeviceLocationWindowController: NSWindowController {
    private let radarView = DeviceLocationRadarView(frame: NSRect(x: 0, y: 0, width: 980, height: 700))

    init(onRename: @escaping (DeviceLocationRadarNode) -> Void, onSetZone: @escaping (DeviceLocationRadarNode) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NetBar Device Location Layer"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        radarView.autoresizingMask = [.width, .height]
        radarView.onRenameNode = onRename
        radarView.onSetZoneNode = onSetZone
        window.contentView = radarView
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(layer: DeviceLocationLayer, formattedSnapshot: String, showMacAddresses: Bool) {
        radarView.updateFromLayer(layer, formattedSnapshot: formattedSnapshot, showMacAddresses: showMacAddresses)
    }

    func renameNode(id: String, to name: String) {
        radarView.renameNode(id: id, to: name)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let scanner = NetworkScanner()
    private let store = StateStore()
    private let startupManager = StartupManager()
    private let locationLayer = DeviceLocationLayer()
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    private var devicesByID: [String: Device] = [:]
    private var devices: [Device] = []
    private var devicePresenceStatuses: [String: DevicePresenceStatus] = [:]
    private var localInfo = LocalAddressInfo(interfaceName: nil, ip: nil, assignment: "Unknown")
    private var lastRefresh: Date?
    private var isRefreshing = false
    private var timer: Timer?
    private var huntTimer: Timer?
    private var huntUntil: Date?
    private var startupError: String?
    private var sharingPicker: NSSharingServicePicker?
    private var settingsWindowController: SettingsWindowController?
    private var networkMapWindowController: NetworkMapWindowController?
    private var deviceLocationWindowController: DeviceLocationWindowController?

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
            try startupManager.sync(enabled: store.state.launchAtLoginEnabled)
        } catch {
            startupError = error.localizedDescription
        }

        refresh(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh(nil)
        }
    }

    @objc private func refresh(_ sender: Any?) {
        guard !isRefreshing else { return }
        isRefreshing = true
        rebuildMenu()

        let previousDevices = devicesByID
        let scanner = self.scanner
        let locationLayer = self.locationLayer
        let store = self.store

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let localInfo = scanner.localAddressInfo()
            let devices = scanner.scan(previousDevices: previousDevices, localInfo: localInfo, activeLookup: true)
            let routerIP = scanner.gatewayIPAddress(localInfo: localInfo)
            let identityContexts = store.identityContexts(for: devices)
            let aliases = Dictionary(uniqueKeysWithValues: identityContexts.compactMap { entry in
                entry.value.alias.map { (entry.key, $0) }
            })
            let locationDevices = devices.map { device -> Device in
                var copy = device
                if let alias = identityContexts[device.id]?.alias, !alias.isEmpty {
                    copy.hostname = alias
                }
                return copy
            }
            locationLayer.recordSnapshot(
                devices: locationDevices,
                localInfo: localInfo,
                routerIP: routerIP,
                aliases: aliases,
                identityContexts: identityContexts
            )
            let now = Date()

            DispatchQueue.main.async {
                self?.finishRefresh(
                    devices: devices,
                    localInfo: localInfo,
                    now: now
                )
            }
        }
    }

    private func finishRefresh(devices refreshedDevices: [Device], localInfo refreshedLocalInfo: LocalAddressInfo, now: Date) {
        localInfo = refreshedLocalInfo
        devices = refreshedDevices
        devicesByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        devicePresenceStatuses = store.updateNetworkPresence(with: devices, now: now)
        lastRefresh = now
        isRefreshing = false
        store.recordIdentities(from: locationLayer.radarNodes)
        rebuildMenu()
        updateNetworkMap()
        updateDeviceLocationWindow()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "NetBar", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let refreshed = lastRefresh.map { timeFormatter.string(from: $0) } ?? "Never"
        let newCount = devices.filter { presenceStatus(for: $0).isNewToNetwork }.count
        let restartCount = devices.filter { presenceStatus(for: $0).isRestartMarked }.count
        let offCount = devices.filter { presenceStatus(for: $0).isUnreachable }.count
        let statusParts = [
            newCount > 0 ? "\(newCount) new" : nil,
            restartCount > 0 ? "\(restartCount) restarted" : nil,
            offCount > 0 ? "\(offCount) off?" : nil,
            isHuntDeviceActive ? "hunt active" : nil
        ].compactMap { $0 }
        let statusSummary = statusParts.isEmpty ? "" : " - \(statusParts.joined(separator: ", "))"
        let summaryTitle = isRefreshing
            ? "Looking up local network..."
            : "\(devices.count) seen\(statusSummary) - refreshed \(refreshed)"
        let summary = NSMenuItem(title: summaryTitle, action: nil, keyEquivalent: "")
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
        launchAtLogin.state = store.state.launchAtLoginEnabled ? .on : .off
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

        let radar = NSMenuItem(title: "Device Radar...", action: #selector(showDeviceRadar(_:)), keyEquivalent: "d")
        radar.target = self
        menu.addItem(radar)

        addLocationLayerItems(to: menu)

        if isHuntDeviceActive, let huntUntil {
            addDisabled("Hunt Device: scanning until \(timeFormatter.string(from: huntUntil))", to: menu)
        }

        let huntTitle = isHuntDeviceActive ? "Stop Hunt Device" : "Hunt Device..."
        let hunt = NSMenuItem(title: huntTitle, action: #selector(toggleHuntDevice(_:)), keyEquivalent: "h")
        hunt.target = self
        menu.addItem(hunt)

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

    private func addLocationLayerItems(to menu: NSMenu) {
        menu.addItem(.separator())

        let title = NSMenuItem(title: "Device Location Layer", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        addDisabled("Status: \(locationLayer.statusText)", to: menu)
        addDisabled("Present: \(locationLayer.knownPresentCount) known, \(locationLayer.mobilePresentCount) mobile, \(locationLayer.unknownPresentCount) unknown", to: menu)
        if locationLayer.leftBehindAlerts.isEmpty {
            addDisabled("Left-behind alerts: none", to: menu)
        } else {
            addDisabled("Left-behind alerts: \(locationLayer.leftBehindAlerts.count)", to: menu)
        }
        let snapshotText = locationLayer.lastSnapshotAt.map { timeFormatter.string(from: $0) } ?? "never"
        addDisabled("Last snapshot: \(snapshotText)", to: menu)

        let pauseTitle = locationLayer.isPaused ? "Start Scanning" : "Pause Scanning"
        let pause = NSMenuItem(title: pauseTitle, action: #selector(toggleLocationLayer(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let snapshot = NSMenuItem(title: "Take Snapshot Now", action: #selector(takeLocationSnapshot(_:)), keyEquivalent: "")
        snapshot.target = self
        menu.addItem(snapshot)

        let state = NSMenuItem(title: "Open Radar View...", action: #selector(showDeviceRadar(_:)), keyEquivalent: "")
        state.target = self
        menu.addItem(state)

        let changes = NSMenuItem(title: "Show Recent Changes...", action: #selector(showRecentChanges(_:)), keyEquivalent: "")
        changes.target = self
        menu.addItem(changes)

        let export = NSMenuItem(title: "Export Logs...", action: #selector(exportLocationLogs(_:)), keyEquivalent: "")
        export.target = self
        menu.addItem(export)

        let reset = NSMenuItem(title: "Reset Learned Baseline...", action: #selector(resetLocationBaseline(_:)), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
    }

    private func menuItem(for device: Device) -> NSMenuItem {
        let label = displayName(for: device)
        let subtitle = store.state.showMacAddresses ? "\(device.ip) - \(device.mac)" : device.ip
        let presence = presenceStatus(for: device)
        let statusPrefix: String
        if presence.isRestartMarked {
            statusPrefix = "RESTART  "
        } else if presence.isUnreachable {
            statusPrefix = "OFF?  "
        } else if presence.isNewToNetwork {
            statusPrefix = "NEW  "
        } else {
            statusPrefix = ""
        }
        let item = NSMenuItem(title: "\(statusPrefix)\(label)  \(subtitle)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        addDisabled("Status: \(presence.title)", to: submenu)
        addDisabled(presence.detail, to: submenu)
        addDisabled("IP: \(device.ip)", to: submenu)
        addDisabled("Interface: \(device.interfaceName)", to: submenu)
        addDisabled("Address: \(device.addressStatus)", to: submenu)
        let guess = DeviceClassifier.classify(device: device, name: label)
        addDisabled("Guessed as: \(guess.summary)", to: submenu)
        addDisabled("MAC clue: \(guess.clue)", to: submenu)
        addDisabled("Seen count: \(presence.seenCount)", to: submenu)
        if let firstSeen = presence.firstSeen {
            addDisabled("First seen on network: \(timeFormatter.string(from: firstSeen))", to: submenu)
        }
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
        clearName.isEnabled = store.hasSavedName(for: device)
        submenu.addItem(clearName)

        submenu.addItem(.separator())

        let markStatic = NSMenuItem(title: "Location: Mark Static", action: #selector(markLocationDevice(_:)), keyEquivalent: "")
        markStatic.target = self
        markStatic.representedObject = ["id": device.id, "class": "static"]
        submenu.addItem(markStatic)

        let markMobile = NSMenuItem(title: "Location: Mark Mobile", action: #selector(markLocationDevice(_:)), keyEquivalent: "")
        markMobile.target = self
        markMobile.representedObject = ["id": device.id, "class": "mobile"]
        submenu.addItem(markMobile)

        let ignoreLocation = NSMenuItem(title: "Location: Ignore", action: #selector(markLocationDevice(_:)), keyEquivalent: "")
        ignoreLocation.target = self
        ignoreLocation.representedObject = ["id": device.id, "class": "ignored"]
        submenu.addItem(ignoreLocation)

        submenu.addItem(.separator())

        let lockMAC = NSMenuItem(title: "Identity: Lock Current MAC", action: #selector(lockDeviceMAC(_:)), keyEquivalent: "")
        lockMAC.target = self
        lockMAC.representedObject = device.id
        lockMAC.isEnabled = displayName(for: device) != "Device"
        submenu.addItem(lockMAC)

        submenu.addItem(.separator())

        let pingIP = NSMenuItem(title: "Ping IP (6 avg)", action: #selector(pingDevice(_:)), keyEquivalent: "")
        pingIP.target = self
        pingIP.representedObject = device.id
        submenu.addItem(pingIP)

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

    private func presenceStatus(for device: Device) -> DevicePresenceStatus {
        devicePresenceStatuses[device.id]
            ?? store.presenceStatus(for: device.id, now: Date())
            ?? DevicePresenceStatus(
                title: "Learning network presence",
                detail: "NetBar is still building a local baseline for this device.",
                badge: nil,
                firstSeen: nil,
                seenCount: 0,
                isNewToNetwork: false,
                isRestartMarked: false,
                isUnreachable: false,
                isNormal: false
            )
    }

    @objc private func toggleShowMacAddresses(_ sender: NSMenuItem) {
        store.setShowMacAddresses(!store.state.showMacAddresses)
        rebuildMenu()
        settingsWindowController?.syncControls()
        updateDeviceLocationWindow()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let enabled = !store.state.launchAtLoginEnabled
        do {
            store.setLaunchAtLoginEnabled(enabled)
            try startupManager.sync(enabled: enabled)
            startupError = nil
        } catch {
            store.setLaunchAtLoginEnabled(!enabled)
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
            gatewayIP: scanner.gatewayIPAddress(localInfo: localInfo),
            lastRefresh: lastRefresh,
            presenceStatuses: devicePresenceStatuses
        )
    }

    @objc private func toggleLocationLayer(_ sender: NSMenuItem) {
        locationLayer.isPaused.toggle()
        rebuildMenu()
        if !locationLayer.isPaused {
            refresh(nil)
        }
    }

    @objc private func takeLocationSnapshot(_ sender: NSMenuItem) {
        refresh(nil)
    }

    private var isHuntDeviceActive: Bool {
        huntUntil.map { $0 > Date() } ?? false
    }

    @objc private func toggleHuntDevice(_ sender: NSMenuItem) {
        if isHuntDeviceActive {
            stopHuntDevice()
            rebuildMenu()
            return
        }

        startHuntDevice()
    }

    private func startHuntDevice() {
        let until = Date().addingTimeInterval(3 * 60)
        huntUntil = until
        huntTimer?.invalidate()
        huntTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isHuntDeviceActive else {
                self.stopHuntDevice()
                self.rebuildMenu()
                return
            }
            self.refresh(nil)
        }
        refresh(nil)
    }

    private func stopHuntDevice() {
        huntTimer?.invalidate()
        huntTimer = nil
        huntUntil = nil
    }

    @objc private func showDeviceRadar(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if deviceLocationWindowController == nil {
            deviceLocationWindowController = DeviceLocationWindowController(onRename: { [weak self] node in
                self?.renameRadarDevice(node)
            }, onSetZone: { [weak self] node in
                self?.setRadarDeviceZone(node)
            })
        }
        updateDeviceLocationWindow()
        deviceLocationWindowController?.showWindow(nil)
        deviceLocationWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showRecentChanges(_ sender: NSMenuItem) {
        var lines = locationLayer.recentChangeLines
        let networkEvents = devices.compactMap { device -> String? in
            let presence = presenceStatus(for: device)
            if presence.isRestartMarked {
                return "Restart marked: \(displayName(for: device)) (\(device.ip))"
            }
            if presence.isUnreachable {
                return "Not answering: \(displayName(for: device)) (\(device.ip))"
            }
            if presence.isNewToNetwork {
                return "New to network: \(displayName(for: device)) (\(device.ip))"
            }
            return nil
        }
        if !networkEvents.isEmpty {
            lines.append("")
            lines.append("Network baseline:")
            lines.append(contentsOf: networkEvents)
        }
        if isHuntDeviceActive, let huntUntil {
            lines.append("")
            lines.append("Hunt Device is scanning until \(timeFormatter.string(from: huntUntil)).")
        }
        if !locationLayer.leftBehindAlerts.isEmpty {
            lines.append("")
            lines.append("Possible left-behind alerts:")
            lines.append(contentsOf: locationLayer.leftBehindAlerts)
        }
        showTextPanel(title: "Recent Device Changes", message: lines.joined(separator: "\n"))
    }

    @objc private func exportLocationLogs(_ sender: NSMenuItem) {
        NSWorkspace.shared.activateFileViewerSelecting([locationLayer.databaseURL])
    }

    @objc private func resetLocationBaseline(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset learned baseline?"
        alert.informativeText = "This clears snapshots, observations, clusters, and confidence scores. Device labels and NetBar settings are kept."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            locationLayer.resetBaseline()
            rebuildMenu()
            updateDeviceLocationWindow()
        }
    }

    private func updateDeviceLocationWindow() {
        let snapshot = locationLayer.lastSnapshotAt.map { timeFormatter.string(from: $0) } ?? "never"
        deviceLocationWindowController?.update(layer: locationLayer, formattedSnapshot: snapshot, showMacAddresses: store.state.showMacAddresses)
    }

    private func renameRadarDevice(_ node: DeviceLocationRadarNode) {
        NSApp.activate(ignoringOtherApps: true)

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = store.state.aliases[node.id] ?? node.title

        let alert = NSAlert()
        alert.messageText = "Rename \(node.title)"
        alert.informativeText = "This saved name is used in the radar, menu list, and Network Map."
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            store.setAlias(name, for: node.id)
            deviceLocationWindowController?.renameNode(id: node.id, to: name.isEmpty ? node.title : name)
            rebuildMenu()
            updateNetworkMap()
            refresh(nil)
        }
    }

    private func setRadarDeviceZone(_ node: DeviceLocationRadarNode) {
        NSApp.activate(ignoringOtherApps: true)

        let zones = ["Kitchen", "Bedroom", "Office", "Living Room", "Hallway", "Desk", "Clear Zone"]
        let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 28), pullsDown: false)
        picker.addItems(withTitles: zones)
        if node.isZoneConfirmed, let index = zones.firstIndex(where: { $0.caseInsensitiveCompare(node.zone) == .orderedSame }) {
            picker.selectItem(at: index)
        }

        let alert = NSAlert()
        alert.messageText = "Set zone for \(node.title)"
        alert.informativeText = "This is a calibration hint. NetBar will move this device on the radar and use it as a stronger identity clue."
        alert.accessoryView = picker
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let selectedZone = picker.titleOfSelectedItem == "Clear Zone" ? nil : picker.titleOfSelectedItem
            store.setZone(selectedZone, for: node)
            rebuildMenu()
            refresh(nil)
        }
    }

    private func showTextPanel(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message.isEmpty ? "No data yet." : message
        alert.addButton(withTitle: "Done")
        alert.runModal()
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
        guard let deviceID = sender.representedObject as? String,
              let device = devicesByID[deviceID] else { return }
        store.clearName(for: device)
        updateNetworkMap()
        updateDeviceLocationWindow()
        rebuildMenu()
    }

    @objc private func markLocationDevice(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? [String: String],
              let deviceID = payload["id"],
              let device = devicesByID[deviceID] else { return }

        let label = displayName(for: device)
        let classification = payload["class"]
        if classification == "ignored" {
            locationLayer.markDevice(id: deviceID, name: label, classification: nil, ignored: true)
        } else {
            locationLayer.markDevice(id: deviceID, name: label, classification: classification, ignored: false)
        }
        refresh(nil)
    }

    @objc private func lockDeviceMAC(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String,
              let device = devicesByID[deviceID] else { return }
        let name = displayName(for: device)
        guard name != "Device" else {
            showError("Name the device first.", detail: "A MAC lock needs a friendly device name so NetBar knows which identity it belongs to.")
            return
        }
        store.lockMAC(for: device, name: name)
        refresh(nil)
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

    @objc private func pingDevice(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String,
              let device = devicesByID[deviceID] else { return }

        let label = displayName(for: device)
        let ip = device.ip
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.runPing(ip: ip) ?? PingResult(
                ip: ip,
                averageMS: nil,
                receivedCount: 0,
                didTimeout: true,
                error: "NetBar could not start the ping check."
            )
            DispatchQueue.main.async {
                self?.showPingResult(result, label: label)
            }
        }
    }

    private func runPing(ip: String) -> PingResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "6", "-W", "1000", ip]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return PingResult(
                ip: ip,
                averageMS: nil,
                receivedCount: 0,
                didTimeout: false,
                error: error.localizedDescription
            )
        }

        let didTimeout = semaphore.wait(timeout: .now() + 6) == .timedOut
        if didTimeout {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.15)
            if process.isRunning {
                process.interrupt()
            }
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return PingResult(
            ip: ip,
            averageMS: parsePingAverage(from: output),
            receivedCount: parseReceivedPingCount(from: output),
            didTimeout: didTimeout,
            error: nil
        )
    }

    private func parsePingAverage(from output: String) -> Double? {
        for line in output.split(separator: "\n") {
            guard line.contains("="), line.contains("/") else { continue }
            let parts = line.components(separatedBy: "=")
            guard parts.count > 1 else { continue }
            let values = parts[1]
                .replacingOccurrences(of: "ms", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "/")
            if values.count >= 2 {
                return Double(values[1])
            }
        }
        return nil
    }

    private func parseReceivedPingCount(from output: String) -> Int {
        for line in output.split(separator: "\n") where line.contains("packets received") {
            let pieces = line.split(separator: ",")
            guard pieces.count >= 2 else { continue }
            let receivedText = pieces[1].trimmingCharacters(in: .whitespaces)
            if let first = receivedText.split(separator: " ").first,
               let count = Int(first) {
                return count
            }
        }
        return 0
    }

    private func showPingResult(_ result: PingResult, label: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        if result.isBad {
            alert.alertStyle = .warning
            alert.messageText = "Bad ping"
            alert.informativeText = "\(label) at \(result.ip) did not reply within 6 seconds."
        } else {
            alert.alertStyle = .informational
            alert.messageText = "Ping average"
            let average = String(format: "%.1f", result.averageMS ?? 0)
            alert.informativeText = "\(label) at \(result.ip)\nAverage: \(average) ms across \(result.receivedCount)/6 replies."
        }

        if let error = result.error {
            alert.informativeText += "\n\n\(error)"
        }

        alert.addButton(withTitle: "Done")
        alert.runModal()
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

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let startupSetting = store.state.launchAtLoginEnabled ? "On" : "Off"
        let startupAgent = startupManager.isInstalled ? "installed" : "not installed"
        let macLine = store.state.showMacAddresses ? "MAC addresses: Shown in menu" : "MAC addresses: Hidden in menu"
        let startupDetail = startupError.map { "\nStartup setup note: \($0)" } ?? ""
        let appPath = Bundle.main.bundleURL.path

        let alert = NSAlert()
        alert.messageText = "NetBar"
        alert.informativeText = """
        Designed by Simon Stevens

        Version: \(version) (\(build))
        Local network lookup: On
        Launch at login: \(startupSetting) (\(startupAgent))
        \(macLine)

        NetBar briefly probes this Mac's private/local subnet, reads the macOS ARP table, highlights newly discovered devices, and can ping a selected IP 6 times for an average.

        Device Location Layer: \(locationLayer.statusText)
        Location snapshots: local SQLite only

        The location layer learns likely static, mobile, transient, new, and left-behind states from repeated local snapshots. It reports confidence zones, not exact coordinates.

        Network data stays local. NetBar does not upload analytics or contact a remote service.

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
