import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

// MARK: - IME (notification-based cache)

var cachedIsJapaneseIME = false

func updateIMECache() {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
    else {
        cachedIsJapaneseIME = false
        return
    }
    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    cachedIsJapaneseIME = id.contains("Japanese") || id.contains("japanese")
}

let inputSourceObserver = DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
    object: nil, queue: nil
) { _ in updateIMECache() }

// MARK: - Composing detection

enum ComposingState {
    case composing, notComposing, unsupported
}

let systemWideElement = AXUIElementCreateSystemWide()

func queryComposingViaAX() -> ComposingState {
    var focusedElement: AnyObject?
    guard AXUIElementCopyAttributeValue(
        systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement
    ) == .success else {
        return .unsupported
    }
    let element = focusedElement as! AXUIElement
    var markedRange: AnyObject?
    let result = AXUIElementCopyAttributeValue(
        element, "AXTextInputMarkedRange" as CFString, &markedRange
    )
    guard result == .success, let value = markedRange else {
        if result.rawValue == -25205 { return .unsupported }
        return .notComposing
    }
    guard CFGetTypeID(value) == AXValueGetTypeID() else { return .notComposing }
    var range = CFRange(location: 0, length: 0)
    AXValueGetValue(value as! AXValue, .cfRange, &range)
    return range.length > 0 ? .composing : .notComposing
}

var fallbackComposing = false
var lastTargetPID: Int64 = 0
let composingResetKeys: Set<Int64> = [36, 53, 48]

func updateFallbackComposing(keyCode: Int64, event: CGEvent) {
    if composingResetKeys.contains(keyCode) {
        fallbackComposing = false
        return
    }
    if keyCode == 49 { return }
    if !event.flags.intersection([.maskCommand, .maskControl]).isEmpty { return }
    var actualLen = 0
    var chars = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &actualLen, unicodeString: &chars)
    if actualLen == 1 {
        let c = chars[0]
        fallbackComposing = (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A)
    }
}

// MARK: - Event tap callback

let spaceKeyCode: Int64 = 49

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .leftMouseDown {
        fallbackComposing = false
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let targetPID = event.getIntegerValueField(.eventTargetUnixProcessID)
    if targetPID != lastTargetPID {
        fallbackComposing = false
        lastTargetPID = targetPID
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    guard cachedIsJapaneseIME else {
        fallbackComposing = false
        return Unmanaged.passUnretained(event)
    }

    if keyCode == spaceKeyCode {
        let axState = queryComposingViaAX()
        let composing = axState == .composing || (axState == .unsupported && fallbackComposing)
        if !composing {
            if event.flags.contains(.maskShift) {
                var fullSpace: UniChar = 0x3000
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &fullSpace)
                event.flags.remove(.maskShift)
            } else {
                var halfSpace: UniChar = 0x0020
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &halfSpace)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    updateFallbackComposing(keyCode: keyCode, event: event)

    return Unmanaged.passUnretained(event)
}

if !AXIsProcessTrusted() {
    print("アクセシビリティ権限が必要です")
    print("システム設定 > プライバシーとセキュリティ > アクセシビリティ で許可してください")

    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)

    while !AXIsProcessTrusted() {
        Thread.sleep(forTimeInterval: 1.0)
    }
    print("権限が許可されました")
}

updateIMECache()
_ = inputSourceObserver

var eventTap: CFMachPort!

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(
        (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
    ),
    callback: callback,
    userInfo: nil
) else {
    print("イベントタップの作成に失敗しました")
    exit(1)
}
eventTap = tap

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

signal(SIGINT) { _ in exit(0) }
signal(SIGTERM) { _ in exit(0) }

RunLoop.current.run()
