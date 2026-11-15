import Foundation

var failures: [String] = []
var checks = 0

func expect(_ condition: Bool, _ message: String) {
    checks += 1
    if condition {
        return
    }
    failures.append(message)
    fputs("FAIL \(message)\n", stderr)
}

@main
enum PermissionWalkthroughTestRunner {
    static func main() {
        expect(PermissionWalkthroughStep.allCases.map(\.number) == [1, 2, 3, 4], "步骤序号应从 1 到 4")
        expect(PermissionWalkthroughStep.loginItems.next == .quickDoc, "第一步的下一步是找到 QuickDoc")
        expect(PermissionWalkthroughStep.quickDoc.next == .details, "第二步的下一步是信息按钮")
        expect(PermissionWalkthroughStep.details.next == .toggle, "第三步的下一步是打开开关")
        expect(PermissionWalkthroughStep.toggle.next == .loginItems, "自动播放在最后一步之后应循环回第一步")
        expect(PermissionWalkthroughStep.loginItems.predecessor == nil, "第一步没有上一步")
        expect(PermissionWalkthroughStep.toggle.successor == nil, "最后一步没有手动下一步")
        expect(PermissionWalkthroughStep.loginItems.titleKey == "进入“登录项与扩展”", "第一步标题应对应登录项与扩展")
        expect(PermissionWalkthroughStep.quickDoc.titleKey == "找到 QuickDoc", "第二步标题应是找到 QuickDoc")
        expect(PermissionWalkthroughStep.details.titleKey == "点击右侧的信息按钮", "第三步标题应是信息按钮")
        expect(PermissionWalkthroughStep.toggle.titleKey == "打开“文件提供程序”开关", "第四步标题应是打开文件提供程序")
        expect(PermissionWalkthroughStep.loginItems.instructionKey.hasPrefix("1. "), "旧版第一步说明应保留编号")
        expect(PermissionWalkthroughStep.toggle.instructionKey.hasPrefix("4. "), "旧版第四步说明应保留编号")

        expect(
            PermissionWalkthroughPlayback.dwellNanoseconds(for: .toggle) > PermissionWalkthroughPlayback.dwellNanoseconds(for: .loginItems),
            "最后一步应停留更久，方便看清开关"
        )
        expect(PermissionWalkthroughPlayback.transitionDuration > 0.2 && PermissionWalkthroughPlayback.transitionDuration <= 0.5, "转场时长应克制")

        var playback = PermissionWalkthroughPlayback()
        expect(playback.step == .loginItems, "默认停在第一步")
        expect(!playback.isPlaying, "默认不应自动开始，由界面根据减少动态效果决定")
        expect(playback.canGoBackward == false, "第一步不能再往前")
        expect(playback.canGoForward, "第一步可以进入下一步")
        expect(!playback.isLastStep, "第一步不是最后一步")

        playback.play()
        expect(playback.isPlaying, "play() 应开始自动播放")
        playback.advanceIfPlaying()
        expect(playback.step == .quickDoc, "播放中前进应到第二步")
        playback.advanceIfPlaying()
        playback.advanceIfPlaying()
        expect(playback.step == .toggle, "连续前进应到最后一步")
        expect(playback.isLastStep && !playback.canGoForward && playback.canGoBackward, "最后一步只能回退")
        playback.advanceIfPlaying()
        expect(playback.step == .loginItems, "自动播放应从最后一步循环回第一步")

        playback.pause()
        let pausedStep = playback.step
        playback.advanceIfPlaying()
        expect(playback.step == pausedStep, "暂停后不得自动前进一步")
        expect(!playback.isPlaying, "pause() 应保持暂停")

        playback.goForward(userInitiated: true)
        expect(playback.step == .quickDoc, "手动下一步应从第一步到第二步")
        expect(!playback.isPlaying, "手动切步应暂停自动播放")

        playback.goBackward()
        expect(playback.step == .loginItems, "手动上一步应回到第一步")
        expect(!playback.isPlaying, "手动回退应保持暂停")
        playback.goBackward()
        expect(playback.step == .loginItems, "在第一步按上一步应停留在第一步")

        playback.select(.details)
        expect(playback.step == .details && !playback.isPlaying, "点击步骤指示器应跳到对应步骤并暂停")

        playback.goForward(userInitiated: true)
        expect(playback.step == .toggle, "从第三步手动前进一步应到开关步骤")
        playback.goForward(userInitiated: true)
        expect(playback.step == .toggle, "最后一步的手动下一步不应循环")

        playback.replay(autoplay: true)
        expect(playback.step == .loginItems && playback.isPlaying, "重播应回到第一步并恢复自动播放")

        playback.select(.toggle)
        playback.replay(autoplay: false)
        expect(playback.step == .loginItems && !playback.isPlaying, "减少动态效果时重播应回到第一步但保持静止")

        playback.togglePlayback()
        expect(playback.isPlaying, "togglePlayback 应能从暂停改为播放")
        playback.togglePlayback()
        expect(!playback.isPlaying, "togglePlayback 应能从播放改为暂停")

        if !failures.isEmpty {
            fputs("\(failures.count) failed\n", stderr)
            exit(1)
        }
        print("PASS \(checks) permission walkthrough playback checks")
    }
}
