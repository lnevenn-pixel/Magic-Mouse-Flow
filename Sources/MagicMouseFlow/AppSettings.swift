import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let tapEnabled = "tapEnabled"
        static let tapHoldEnabled = "tapHoldEnabled"
        static let doubleTapLockEnabled = "doubleTapLockEnabled"
        static let doubleTapInterval = "doubleTapInterval"
        static let tapPressure = "tapPressure"
        static let tapDuration = "tapDuration"
        static let holdDelay = "holdDelay"
        static let rightClickMode = "rightClickMode"
        static let zoomEnabled = "zoomEnabled"
        static let zoomMode = "zoomMode"
        static let zoomSensitivity = "zoomSensitivity"
        static let edgeRejectionEnabled = "edgeRejectionEnabled"
        static let edgeRejectMargin = "edgeRejectMargin"
        static let tapResponseAreaEnabled = "tapResponseAreaEnabled"
        static let tapResponseMinY = "tapResponseMinY"
        static let tapCenterDeadZoneWidth = "tapCenterDeadZoneWidth"
        static let excludedApps = "excludedApps"
        static let settingsRevision = "settingsRevision"
    }

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.tapEnabled: true,
            Key.tapHoldEnabled: true,
            Key.doubleTapLockEnabled: true,
            Key.doubleTapInterval: 0.45,
            Key.tapPressure: 0.0,
            Key.tapDuration: 0.22,
            Key.holdDelay: 0.38,
            Key.rightClickMode: 0,
            Key.zoomEnabled: true,
            Key.zoomMode: 2,
            Key.zoomSensitivity: 1.0,
            Key.edgeRejectionEnabled: true,
            Key.edgeRejectMargin: 0.06,
            Key.tapResponseAreaEnabled: true,
            Key.tapResponseMinY: 0.50,
            Key.tapCenterDeadZoneWidth: 0.16,
            Key.excludedApps: ""
        ])
        // Earlier prototypes defaulted to 1.0, which is too high on some Magic
        // Mouse generations and can silently reject every tap. Start unfiltered;
        // users can raise the threshold after confirming input works.
        if defaults.integer(forKey: Key.settingsRevision) < 2 {
            defaults.set(0.0, forKey: Key.tapPressure)
            defaults.set(2, forKey: Key.settingsRevision)
        }
        if defaults.integer(forKey: Key.settingsRevision) < 3 {
            defaults.set(0.45, forKey: Key.doubleTapInterval)
            defaults.set(3, forKey: Key.settingsRevision)
        }
        if defaults.integer(forKey: Key.settingsRevision) < 4 {
            defaults.set(1, forKey: Key.rightClickMode)
            defaults.set(4, forKey: Key.settingsRevision)
        }
    }

    var enabled: Bool { get { defaults.bool(forKey: Key.enabled) } set { defaults.set(newValue, forKey: Key.enabled) } }
    var tapEnabled: Bool { get { defaults.bool(forKey: Key.tapEnabled) } set { defaults.set(newValue, forKey: Key.tapEnabled) } }
    var tapHoldEnabled: Bool { get { defaults.bool(forKey: Key.tapHoldEnabled) } set { defaults.set(newValue, forKey: Key.tapHoldEnabled) } }
    var doubleTapLockEnabled: Bool { get { defaults.bool(forKey: Key.doubleTapLockEnabled) } set { defaults.set(newValue, forKey: Key.doubleTapLockEnabled) } }
    var doubleTapInterval: Double { get { defaults.double(forKey: Key.doubleTapInterval) } set { defaults.set(newValue, forKey: Key.doubleTapInterval) } }
    var tapPressure: Double { get { defaults.double(forKey: Key.tapPressure) } set { defaults.set(newValue, forKey: Key.tapPressure) } }
    var tapDuration: Double { get { defaults.double(forKey: Key.tapDuration) } set { defaults.set(newValue, forKey: Key.tapDuration) } }
    var holdDelay: Double { get { defaults.double(forKey: Key.holdDelay) } set { defaults.set(newValue, forKey: Key.holdDelay) } }
    /// 0: two-finger right click, 1: right half right click.
    var rightClickMode: Int { get { defaults.integer(forKey: Key.rightClickMode) } set { defaults.set(newValue, forKey: Key.rightClickMode) } }
    var zoomEnabled: Bool { get { defaults.bool(forKey: Key.zoomEnabled) } set { defaults.set(newValue, forKey: Key.zoomEnabled) } }
    /// 0: pinch only, 1: parallel slide only, 2: both.
    var zoomMode: Int { get { defaults.integer(forKey: Key.zoomMode) } set { defaults.set(newValue, forKey: Key.zoomMode) } }
    var zoomSensitivity: Double { get { defaults.double(forKey: Key.zoomSensitivity) } set { defaults.set(newValue, forKey: Key.zoomSensitivity) } }
    var edgeRejectionEnabled: Bool { get { defaults.bool(forKey: Key.edgeRejectionEnabled) } set { defaults.set(newValue, forKey: Key.edgeRejectionEnabled) } }
    var edgeRejectMargin: Double { get { defaults.double(forKey: Key.edgeRejectMargin) } set { defaults.set(newValue, forKey: Key.edgeRejectMargin) } }
    var tapResponseAreaEnabled: Bool { get { defaults.bool(forKey: Key.tapResponseAreaEnabled) } set { defaults.set(newValue, forKey: Key.tapResponseAreaEnabled) } }
    var tapResponseMinY: Double { get { defaults.double(forKey: Key.tapResponseMinY) } set { defaults.set(newValue, forKey: Key.tapResponseMinY) } }
    var tapCenterDeadZoneWidth: Double { get { defaults.double(forKey: Key.tapCenterDeadZoneWidth) } set { defaults.set(newValue, forKey: Key.tapCenterDeadZoneWidth) } }
    var excludedAppsText: String { get { defaults.string(forKey: Key.excludedApps) ?? "" } set { defaults.set(newValue, forKey: Key.excludedApps) } }

    func isAllowed(bundleIdentifier: String?) -> Bool {
        guard enabled else { return false }
        let excluded = Set(excludedAppsText
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
        guard let bundleIdentifier else { return true }
        return !excluded.contains(bundleIdentifier.lowercased())
    }
}
