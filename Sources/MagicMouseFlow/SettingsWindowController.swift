import AppKit
import ApplicationServices

@MainActor
final class SettingsWindowController: NSWindowController {
    private let enabled = NSButton(checkboxWithTitle: "启用 Magic Mouse Flow", target: nil, action: nil)
    private let tapEnabled = NSButton(checkboxWithTitle: "启用单指分区轻触点击", target: nil, action: nil)
    private let tapHoldEnabled = NSButton(checkboxWithTitle: "启用左侧轻触按住＝左键拖动", target: nil, action: nil)
    private let doubleTapLockEnabled = NSButton(checkboxWithTitle: "启用连续轻触两下＝锁定左键按住（再轻触释放）", target: nil, action: nil)
    private let doubleTapInterval = NSSlider(value: 0.45, minValue: 0.25, maxValue: 0.7, target: nil, action: nil)
    private let zoomEnabled = NSButton(checkboxWithTitle: "启用两指连续缩放", target: nil, action: nil)
    private let zoomMode = NSPopUpButton()
    private let pressure = NSSlider(value: 1, minValue: 0, maxValue: 1.5, target: nil, action: nil)
    private let holdDelay = NSSlider(value: 0.38, minValue: 0.2, maxValue: 0.8, target: nil, action: nil)
    private let zoomSensitivity = NSSlider(value: 1, minValue: 0.3, maxValue: 3, target: nil, action: nil)
    private let edgeRejectionEnabled = NSButton(checkboxWithTitle: "启用鼠标边缘防误触", target: nil, action: nil)
    private let edgeRejectMargin = NSSlider(value: 0.06, minValue: 0.02, maxValue: 0.18, target: nil, action: nil)
    private let tapResponseAreaEnabled = NSButton(checkboxWithTitle: "限制轻触响应区域（红色区域不触发）", target: nil, action: nil)
    private let tapResponseMinY = NSSlider(value: 0.50, minValue: 0.30, maxValue: 0.75, target: nil, action: nil)
    private let tapCenterDeadZoneWidth = NSSlider(value: 0.16, minValue: 0.04, maxValue: 0.35, target: nil, action: nil)
    private let excludedApps = NSTextField()
    private let status = NSTextField(labelWithString: "")
    private let diagnostics = NSTextField(labelWithString: "")
    private let accessibilityButton = NSButton(title: "打开辅助功能设置", target: nil, action: nil)
    private let inputButton = NSButton(title: "打开输入监控设置", target: nil, action: nil)
    private let refreshButton = NSButton(title: "刷新权限状态", target: nil, action: nil)
    private let mouseSurfaceView = MouseSurfaceView()
    private var visualizationTimer: Timer?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Magic Mouse Flow 设置"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        loadValues()
        visualizationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshVisualization() }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        zoomMode.addItems(withTitles: ["两指捏合/张开", "两指上下滑动", "两种方式都启用"])
        excludedApps.placeholderString = "例如：com.apple.FinalCut（多个用逗号分隔）"
        status.textColor = .secondaryLabelColor
        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)
        inputButton.target = self
        inputButton.action = #selector(openInputMonitoringSettings)
        refreshButton.target = self
        refreshButton.action = #selector(refreshPermissionStatus)

        [enabled, tapEnabled, tapHoldEnabled, doubleTapLockEnabled, zoomEnabled, edgeRejectionEnabled, tapResponseAreaEnabled].forEach { $0.target = self; $0.action = #selector(save) }
        zoomMode.target = self; zoomMode.action = #selector(save)
        [pressure, holdDelay, doubleTapInterval, zoomSensitivity, edgeRejectMargin, tapResponseMinY, tapCenterDeadZoneWidth].forEach { $0.target = self; $0.action = #selector(save) }
        excludedApps.target = self; excludedApps.action = #selector(save)

        let hint = NSTextField(wrappingLabelWithString:
            "缩放支持两种动作：两指捏合/张开，或两指同时上下滑动。它会向当前应用发送原生连续缩放事件。部分应用可能需要单独适配。")
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            title("实时妙控鼠标表面"), mouseSurfaceView,
            NSTextField(labelWithString: "触点圆圈越大、颜色越深，代表估算接触力度越高。"),
            separator(),
            title("基本功能"), enabled,
            separator(),
            title("轻触点击"), tapEnabled, tapHoldEnabled,
            NSTextField(labelWithString: "左侧有效区域＝左键点击　　右侧有效区域＝右键单击"),
            doubleTapLockEnabled,
            row("双击判定时间", doubleTapInterval),
            row("轻触压力阈值", pressure),
            row("按住拖动延迟", holdDelay),
            tapResponseAreaEnabled,
            row("底部禁区高度", tapResponseMinY),
            row("中央禁区宽度", tapCenterDeadZoneWidth),
            edgeRejectionEnabled,
            row("左右边缘范围", edgeRejectMargin),
            separator(),
            title("缩放"), zoomEnabled,
            row("缩放手势", zoomMode),
            row("缩放灵敏度", zoomSensitivity), hint,
            separator(),
            title("按应用排除"),
            NSTextField(labelWithString: "以下 Bundle ID 中停用所有手势："), excludedApps,
            separator(), title("运行状态"), status, diagnostics,
            NSStackView(views: [accessibilityButton, inputButton, refreshButton])
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = documentView
        window?.contentView?.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: window!.contentView!.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: window!.contentView!.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20),
            mouseSurfaceView.widthAnchor.constraint(equalToConstant: 550),
            mouseSurfaceView.heightAnchor.constraint(equalToConstant: 280),
            pressure.widthAnchor.constraint(equalToConstant: 250),
            holdDelay.widthAnchor.constraint(equalToConstant: 250),
            doubleTapInterval.widthAnchor.constraint(equalToConstant: 250),
            zoomSensitivity.widthAnchor.constraint(equalToConstant: 250),
            edgeRejectMargin.widthAnchor.constraint(equalToConstant: 250),
            tapResponseMinY.widthAnchor.constraint(equalToConstant: 250),
            tapCenterDeadZoneWidth.widthAnchor.constraint(equalToConstant: 250),
            excludedApps.widthAnchor.constraint(equalToConstant: 470),
            hint.widthAnchor.constraint(equalToConstant: 470)
        ])
    }

    private func refreshVisualization() {
        let engine = TouchEngine.shared
        mouseSurfaceView.touches = engine.currentSurfaceTouches
        mouseSurfaceView.clickKind = engine.lastVisualClick
        mouseSurfaceView.clickTime = engine.lastVisualClickTime
        mouseSurfaceView.leftButtonLocked = engine.isLeftButtonLocked
        let settings = AppSettings.shared
        mouseSurfaceView.showsTapResponseArea = settings.tapResponseAreaEnabled
        mouseSurfaceView.tapResponseMinY = CGFloat(settings.tapResponseMinY)
        mouseSurfaceView.tapCenterDeadZoneWidth = CGFloat(settings.tapCenterDeadZoneWidth)
        mouseSurfaceView.needsDisplay = true
        diagnostics.stringValue = engine.diagnosticsText
    }

    private func title(_ string: String) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.font = .boldSystemFont(ofSize: 14)
        return field
    }

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.widthAnchor.constraint(equalToConstant: 135).isActive = true
        let row = NSStackView(views: [labelField, control])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 470).isActive = true
        return box
    }

    private func loadValues() {
        let settings = AppSettings.shared
        enabled.state = settings.enabled ? .on : .off
        tapEnabled.state = settings.tapEnabled ? .on : .off
        tapHoldEnabled.state = settings.tapHoldEnabled ? .on : .off
        doubleTapLockEnabled.state = settings.doubleTapLockEnabled ? .on : .off
        doubleTapInterval.doubleValue = settings.doubleTapInterval
        zoomEnabled.state = settings.zoomEnabled ? .on : .off
        zoomMode.selectItem(at: settings.zoomMode)
        pressure.doubleValue = settings.tapPressure
        holdDelay.doubleValue = settings.holdDelay
        zoomSensitivity.doubleValue = settings.zoomSensitivity
        edgeRejectionEnabled.state = settings.edgeRejectionEnabled ? .on : .off
        edgeRejectMargin.doubleValue = settings.edgeRejectMargin
        tapResponseAreaEnabled.state = settings.tapResponseAreaEnabled ? .on : .off
        tapResponseMinY.doubleValue = settings.tapResponseMinY
        tapCenterDeadZoneWidth.doubleValue = settings.tapCenterDeadZoneWidth
        excludedApps.stringValue = settings.excludedAppsText
        let accessibilityGranted = AXIsProcessTrusted()
        let inputGranted = CGPreflightListenEventAccess()
        let accessibility = accessibilityGranted ? "已授权" : "未授权"
        let inputMonitoring = inputGranted ? "已授权" : "未授权"
        status.stringValue = "\(TouchEngine.shared.statusText)　辅助功能：\(accessibility)　输入监控：\(inputMonitoring)"
        status.textColor = accessibilityGranted && inputGranted ? .systemGreen : .systemRed
        diagnostics.stringValue = TouchEngine.shared.diagnosticsText
        diagnostics.textColor = .secondaryLabelColor
    }

    @objc private func save() {
        let settings = AppSettings.shared
        settings.enabled = enabled.state == .on
        settings.tapEnabled = tapEnabled.state == .on
        settings.tapHoldEnabled = tapHoldEnabled.state == .on
        settings.doubleTapLockEnabled = doubleTapLockEnabled.state == .on
        settings.doubleTapInterval = doubleTapInterval.doubleValue
        if !settings.doubleTapLockEnabled { TouchEngine.shared.releaseLockedMouseIfNeeded() }
        settings.zoomEnabled = zoomEnabled.state == .on
        settings.zoomMode = zoomMode.indexOfSelectedItem
        settings.rightClickMode = 1
        settings.tapPressure = pressure.doubleValue
        settings.holdDelay = holdDelay.doubleValue
        settings.zoomSensitivity = zoomSensitivity.doubleValue
        settings.edgeRejectionEnabled = edgeRejectionEnabled.state == .on
        settings.edgeRejectMargin = edgeRejectMargin.doubleValue
        settings.tapResponseAreaEnabled = tapResponseAreaEnabled.state == .on
        settings.tapResponseMinY = tapResponseMinY.doubleValue
        settings.tapCenterDeadZoneWidth = tapCenterDeadZoneWidth.doubleValue
        settings.excludedAppsText = excludedApps.stringValue
    }

    @objc private func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    @objc private func openInputMonitoringSettings() {
        _ = CGRequestListenEventAccess()
        openPrivacyPane("Privacy_ListenEvent")
    }

    @objc private func refreshPermissionStatus() {
        loadValues()
    }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    override func showWindow(_ sender: Any?) {
        loadValues()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
