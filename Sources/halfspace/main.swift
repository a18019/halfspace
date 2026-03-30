import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

// MARK: - IME

func isJapaneseIMEActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
    else { return false }
    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    return id.contains("Japanese") || id.contains("japanese")
}

// MARK: - Key codes

let spaceKeyCode: Int64 = 49
let returnKeyCode: Int64 = 36
let escapeKeyCode: Int64 = 53

// MARK: - Event tap callback

/// IME の変換中かどうかを追跡 — composing 中のスペースは変換操作なので触らない
var isComposing = false

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        CGEvent.tapEnable(tap: event as! CFMachPort, enable: true)
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    guard isJapaneseIMEActive() else {
        isComposing = false
        return Unmanaged.passRetained(event)
    }

    // composing 状態の更新
    if keyCode == returnKeyCode || keyCode == escapeKeyCode {
        isComposing = false
        return Unmanaged.passRetained(event)
    }

    if keyCode == spaceKeyCode && !isComposing {
        if event.flags.contains(.maskShift) {
            // Shift+Space → 全角スペース (U+3000)
            var fullSpace: UniChar = 0x3000
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &fullSpace)
        } else {
            // Space → 半角スペース (U+0020)
            var halfSpace: UniChar = 0x0020
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &halfSpace)
        }
        return Unmanaged.passRetained(event)
    }

    // アルファベット入力 → composing 開始
    var actualLen = 0
    var chars = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &actualLen, unicodeString: &chars)
    if actualLen == 1 {
        let c = chars[0]
        if (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) {
            isComposing = true
        }
    }

    return Unmanaged.passRetained(event)
}

guard AXIsProcessTrusted() else {
    print("アクセシビリティ権限が必要です")
    print("システム設定 > プライバシーとセキュリティ > アクセシビリティ で許可してください")

    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)

    exit(1)
}

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: callback,
    userInfo: nil
) else {
    print("イベントタップの作成に失敗しました")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

signal(SIGINT) { _ in
    exit(0)
}

RunLoop.current.run()
