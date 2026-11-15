import Foundation

enum PermissionWalkthroughStep: Int, CaseIterable, Identifiable, Equatable {
    case loginItems
    case quickDoc
    case details
    case toggle

    var id: Int { rawValue }

    var number: Int { rawValue + 1 }

    var titleKey: String {
        switch self {
        case .loginItems:
            return "进入“登录项与扩展”"
        case .quickDoc:
            return "找到 QuickDoc"
        case .details:
            return "点击右侧的信息按钮"
        case .toggle:
            return "打开“文件提供程序”开关"
        }
    }

    var instructionKey: String {
        switch self {
        case .loginItems:
            return "1. 进入“登录项与扩展”"
        case .quickDoc:
            return "2. 找到 QuickDoc"
        case .details:
            return "3. 点击右侧的信息按钮"
        case .toggle:
            return "4. 打开“文件提供程序”开关"
        }
    }

    var next: PermissionWalkthroughStep {
        Self(rawValue: (rawValue + 1) % Self.allCases.count) ?? .loginItems
    }

    var predecessor: PermissionWalkthroughStep? {
        Self(rawValue: rawValue - 1)
    }

    var successor: PermissionWalkthroughStep? {
        Self(rawValue: rawValue + 1)
    }
}

struct PermissionWalkthroughPlayback: Equatable {
    var step: PermissionWalkthroughStep = .loginItems
    var isPlaying = false

    static let standardDwellNanoseconds: UInt64 = 2_400_000_000
    static let lastStepDwellNanoseconds: UInt64 = 3_200_000_000
    static let transitionDuration = 0.45

    var canGoForward: Bool { step.successor != nil }
    var canGoBackward: Bool { step.predecessor != nil }
    var isLastStep: Bool { step == .toggle }

    static func dwellNanoseconds(for step: PermissionWalkthroughStep) -> UInt64 {
        step == .toggle ? lastStepDwellNanoseconds : standardDwellNanoseconds
    }

    mutating func replay(autoplay: Bool) {
        step = .loginItems
        isPlaying = autoplay
    }

    mutating func pause() {
        isPlaying = false
    }

    mutating func play() {
        isPlaying = true
    }

    mutating func togglePlayback() {
        isPlaying.toggle()
    }

    mutating func select(_ step: PermissionWalkthroughStep) {
        self.step = step
        isPlaying = false
    }

    mutating func goForward(userInitiated: Bool) {
        if userInitiated {
            guard let successor = step.successor else { return }
            step = successor
            isPlaying = false
            return
        }
        step = step.next
    }

    mutating func goBackward() {
        guard let predecessor = step.predecessor else { return }
        step = predecessor
        isPlaying = false
    }

    mutating func advanceIfPlaying() {
        guard isPlaying else { return }
        step = step.next
    }
}
