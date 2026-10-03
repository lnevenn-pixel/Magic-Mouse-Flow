import AppKit
import MagicMouseBridge

@MainActor
final class TouchEngine {
    static let shared = TouchEngine()

    struct SurfaceTouch {
        let x: Float
        let y: Float
        let intensity: Float
    }

    private struct Finger {
        let id: Int32
        let x: Float
        let y: Float
        let pressure: Float
    }

    private var tracking = false
    private var startTime = 0.0
    private var maximumFingerCount = 0
    private var peakPressure: Float = 0
    private var initial: [Int32: Finger] = [:]
    private var previousPairDistance: Float?
    private var previousPairY: Float?
    private var startPairDistance: Float?
    private var startPairY: Float?
    private var zooming = false
    private enum ActiveZoomGesture { case pinch, slide }
    private var activeZoomGesture: ActiveZoomGesture?
    private var holding = false
    private var lockedMouseDown = false
    private var suppressUntilAllFingersLift = false
    private var pendingLeftClick: DispatchWorkItem?
    private var lastLeftTapTime = 0.0
    private var tapStartedInResponseArea = true
    private var rejectingEdgeSequence = false
    private var holdWorkItem: DispatchWorkItem?
    private(set) var isRunning = false
    private(set) var statusText = "尚未启动"
    private(set) var receivedFrameCount = 0
    private(set) var receivedTouchFrameCount = 0
    private(set) var lastObservedPressure: Float = 0
    private(set) var lastAction = "无"
    private(set) var currentSurfaceTouches: [SurfaceTouch] = []
    private(set) var lastVisualClick = ""
    private(set) var lastVisualClickTime = Date.distantPast
    var isLeftButtonLocked: Bool { lockedMouseDown || holding }

    private init() {}

    func start() {
        guard !isRunning else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        isRunning = MMTStart({ touches, count, timestamp, context in
            guard let context else { return }
            let engine = Unmanaged<TouchEngine>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                engine.process(touches: touches, count: Int(count), timestamp: timestamp)
            }
        }, context)
        statusText = isRunning ? "已连接妙控鼠标" : "未检测到外置多点触控设备"
    }

    func stop() {
        MMTStop()
        cancelHold()
        if holding { EventInjector.leftMouseUp() }
        if lockedMouseDown { EventInjector.leftMouseUp() }
        pendingLeftClick?.cancel()
        holding = false
        lockedMouseDown = false
        isRunning = false
        statusText = "已暂停"
        reset()
    }

    private func process(touches: UnsafePointer<MMTTouch>?, count: Int, timestamp: Double) {
        receivedFrameCount += 1
        if count > 0 { receivedTouchFrameCount += 1 }
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard AppSettings.shared.isAllowed(bundleIdentifier: bundleID) else {
            if holding { EventInjector.leftMouseUp(); holding = false }
            reset()
            return
        }

        let fingers: [Finger] = guardTouches(touches, count: count)
        currentSurfaceTouches = surfaceTouches(touches, count: count)
        lastObservedPressure = fingers.map(\.pressure).max() ?? lastObservedPressure

        if suppressUntilAllFingersLift {
            if fingers.isEmpty { suppressUntilAllFingersLift = false }
            return
        }

        if lockedMouseDown, !fingers.isEmpty {
            EventInjector.leftMouseUp()
            lockedMouseDown = false
            suppressUntilAllFingersLift = true
            lastAction = "已释放左键锁定"
            recordVisualClick("释放")
            return
        }

        if rejectingEdgeSequence {
            if fingers.isEmpty { rejectingEdgeSequence = false }
            return
        }

        if holding {
            if fingers.isEmpty {
                EventInjector.leftMouseUp()
                holding = false
                reset()
            }
            return
        }

        if !tracking, !fingers.isEmpty {
            let settings = AppSettings.shared
            let isResponsiveStart = fingers.allSatisfy { isInTapResponseArea(x: $0.x, y: $0.y) }
            // Recognize the second tap on touch-down. Waiting until touch-up
            // races the pending single-click timer and can lose the double tap.
            if fingers.count == 1,
               isResponsiveStart,
               settings.doubleTapLockEnabled,
               pendingLeftClick != nil,
               timestamp - lastLeftTapTime <= settings.doubleTapInterval {
                pendingLeftClick?.cancel()
                pendingLeftClick = nil
                lastLeftTapTime = 0
                EventInjector.leftMouseDown()
                lockedMouseDown = true
                suppressUntilAllFingersLift = true
                lastAction = "左键已锁定按住"
                recordVisualClick("左键锁定")
                return
            }
            if settings.edgeRejectionEnabled {
                let margin = Float(settings.edgeRejectMargin)
                if fingers.contains(where: { $0.x < margin || $0.x > 1 - margin }) {
                    rejectingEdgeSequence = true
                    lastAction = "边缘触控已忽略"
                    return
                }
            }
            tracking = true
            tapStartedInResponseArea = isResponsiveStart
            if !isResponsiveStart { lastAction = "触点位于轻触禁区" }
            startTime = timestamp
            maximumFingerCount = fingers.count
            peakPressure = fingers.map(\.pressure).max() ?? 0
            initial = Dictionary(uniqueKeysWithValues: fingers.map { ($0.id, $0) })
            updatePairState(fingers)
            scheduleHold()
            return
        }

        guard tracking else { return }
        peakPressure = max(peakPressure, fingers.map(\.pressure).max() ?? 0)
        maximumFingerCount = max(maximumFingerCount, fingers.count)

        if fingers.count == 2, AppSettings.shared.zoomEnabled {
            processZoom(fingers)
        }

        if fingers.isEmpty {
            cancelHold()
            let duration = timestamp - startTime
            let fingerCount = maximumFingerCount
            let pressure = peakPressure
            let averageX = initial.values.map(\.x).reduce(0, +) / Float(max(1, initial.count))
            let wasZooming = zooming
            let tapAllowed = tapStartedInResponseArea
            if wasZooming { EventInjector.endZoom() }
            reset()
            guard !wasZooming,
                  tapAllowed,
                  AppSettings.shared.tapEnabled,
                  duration >= 0.015,
                  duration <= AppSettings.shared.tapDuration,
                  pressure >= Float(AppSettings.shared.tapPressure) else { return }
            fireTap(fingerCount: fingerCount, averageX: averageX, timestamp: timestamp)
        }
    }

    private func guardTouches(_ pointer: UnsafePointer<MMTTouch>?, count: Int) -> [Finger] {
        guard let pointer, count > 0 else { return [] }
        return (0..<count).map {
            let touch = pointer[$0]
            return Finger(id: touch.fingerID,
                          x: touch.normalizedVector.position.x,
                          y: touch.normalizedVector.position.y,
                          pressure: touch.zTotal)
        }
    }

    private func surfaceTouches(_ pointer: UnsafePointer<MMTTouch>?, count: Int) -> [SurfaceTouch] {
        guard let pointer, count > 0 else { return [] }
        return (0..<count).map {
            let touch = pointer[$0]
            let area = max(0, touch.majorAxis * touch.minorAxis)
            // USB-C Magic Mouse models often report zTotal/zPressure as zero.
            // Geometric mean of the contact ellipse remains available and
            // changes with finger contact, so use it as the pressure proxy.
            let areaEstimate = min(1.5, sqrt(area) * 0.1)
            return SurfaceTouch(x: touch.normalizedVector.position.x,
                                y: touch.normalizedVector.position.y,
                                intensity: max(touch.zTotal, touch.zPressure, areaEstimate))
        }
    }

    func recordVisualClick(_ kind: String) {
        lastVisualClick = kind
        lastVisualClickTime = Date()
    }

    private func processZoom(_ fingers: [Finger]) {
        cancelHold()
        let dx = fingers[0].x - fingers[1].x
        let dy = fingers[0].y - fingers[1].y
        let distance = sqrt(dx * dx + dy * dy)
        let centerY = (fingers[0].y + fingers[1].y) / 2
        if startPairDistance == nil { startPairDistance = distance }
        if startPairY == nil { startPairY = centerY }
        defer { previousPairDistance = distance; previousPairY = centerY }
        guard let oldDistance = previousPairDistance, let oldY = previousPairY else { return }

        let pinchDelta = distance - oldDistance
        let slideDelta = centerY - oldY
        let cumulativePinch = distance - (startPairDistance ?? distance)
        let cumulativeSlide = centerY - (startPairY ?? centerY)

        if activeZoomGesture == nil {
            switch AppSettings.shared.zoomMode {
            case 0:
                if abs(cumulativePinch) > 0.006 { activeZoomGesture = .pinch }
            case 1:
                if abs(cumulativeSlide) > 0.008 { activeZoomGesture = .slide }
            default:
                if abs(cumulativePinch) > 0.006 || abs(cumulativeSlide) > 0.008 {
                    activeZoomGesture = abs(cumulativePinch) >= abs(cumulativeSlide) * 0.8 ? .pinch : .slide
                }
            }
        }

        guard let activeZoomGesture else { return }
        if !zooming {
            zooming = true
            EventInjector.beginZoom()
        }
        let sensitivity = Float(AppSettings.shared.zoomSensitivity)
        let movement = activeZoomGesture == .pinch ? pinchDelta * 4.0 : slideDelta * 2.5
        let magnification = movement * sensitivity
        guard abs(magnification) > 0.0001 else { return }
        EventInjector.changeZoom(delta: Double(magnification))
        lastAction = magnification > 0 ? "原生捏合放大" : "原生捏合缩小"
    }

    private func isInTapResponseArea(x: Float, y: Float) -> Bool {
        let settings = AppSettings.shared
        guard settings.tapResponseAreaEnabled else { return true }
        let minimumY = Float(settings.tapResponseMinY)
        let halfDeadZone = Float(settings.tapCenterDeadZoneWidth / 2)
        return y >= minimumY && abs(x - 0.5) >= halfDeadZone
    }

    private func updatePairState(_ fingers: [Finger]) {
        guard fingers.count == 2 else { previousPairDistance = nil; previousPairY = nil; return }
        let dx = fingers[0].x - fingers[1].x
        let dy = fingers[0].y - fingers[1].y
        previousPairDistance = sqrt(dx * dx + dy * dy)
        previousPairY = (fingers[0].y + fingers[1].y) / 2
        startPairDistance = previousPairDistance
        startPairY = previousPairY
    }

    private func fireTap(fingerCount: Int, averageX: Float, timestamp: Double) {
        let settings = AppSettings.shared
        if fingerCount == 1, settings.doubleTapLockEnabled {
            lastLeftTapTime = timestamp
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingLeftClick = nil
                if settings.rightClickMode == 1, averageX >= 0.55 {
                    EventInjector.click(button: .right)
                    self.lastAction = "右键点击"
                    self.recordVisualClick("右键")
                } else {
                    EventInjector.click(button: .left)
                    self.lastAction = "左键点击"
                    self.recordVisualClick("左键")
                }
            }
            pendingLeftClick = item
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.doubleTapInterval, execute: item)
            return
        }

        if AppSettings.shared.rightClickMode == 0 {
            if fingerCount == 1 { EventInjector.click(button: .left); lastAction = "左键点击"; recordVisualClick("左键") }
            if fingerCount == 2 { EventInjector.click(button: .right); lastAction = "右键点击"; recordVisualClick("右键") }
        } else if fingerCount == 1 {
            let isRight = averageX >= 0.55
            EventInjector.click(button: isRight ? .right : .left)
            lastAction = isRight ? "右键点击" : "左键点击"
            recordVisualClick(isRight ? "右键" : "左键")
        }
    }

    private func scheduleHold() {
        let initialX = initial.values.first?.x ?? 0.5
        guard maximumFingerCount == 1,
              tapStartedInResponseArea,
              initialX < 0.5,
              AppSettings.shared.tapEnabled,
              AppSettings.shared.tapHoldEnabled else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.tracking, !self.zooming else { return }
            self.holding = true
            self.tracking = false
            EventInjector.leftMouseDown()
            self.lastAction = "开始拖动"
            self.recordVisualClick("左键按住")
        }
        holdWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + AppSettings.shared.holdDelay, execute: item)
    }

    private func cancelHold() { holdWorkItem?.cancel(); holdWorkItem = nil }

    func releaseLockedMouseIfNeeded() {
        pendingLeftClick?.cancel()
        pendingLeftClick = nil
        if lockedMouseDown {
            EventInjector.leftMouseUp()
            lockedMouseDown = false
            lastAction = "已释放左键锁定"
        }
    }
    private func reset() {
        cancelHold()
        tracking = false
        maximumFingerCount = 0
        peakPressure = 0
        initial.removeAll()
        previousPairDistance = nil
        previousPairY = nil
        startPairDistance = nil
        startPairY = nil
        zooming = false
        activeZoomGesture = nil
        rejectingEdgeSequence = false
        tapStartedInResponseArea = true
    }

    var diagnosticsText: String {
        let pressureText = String(format: "%.2f", lastObservedPressure)
        return "触控帧：\(receivedTouchFrameCount)/\(receivedFrameCount)　最近压力：\(pressureText)　最近动作：\(lastAction)"
    }
}
