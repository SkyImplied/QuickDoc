import SwiftUI

struct PageHeader: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GlassSection<Content: View>: View {
    var fillsAvailableHeight = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            maxHeight: fillsAvailableHeight ? .infinity : nil,
            alignment: .topLeading
        )
        .liquidGlassCard()
    }
}

struct FillCardToWindowBottom<Content: View>: View {
    var bottomGap: CGFloat = 22
    @ViewBuilder var content: (_ fills: Bool) -> Content
    @State private var cardHeight: CGFloat?
    @State private var intrinsicHeight: CGFloat?

    var body: some View {
        content(cardHeight != nil)
            .frame(maxWidth: .infinity, maxHeight: cardHeight == nil ? nil : .infinity, alignment: .top)
            .frame(height: cardHeight)
            .background(
                WindowBottomGapReader { measured, gap in
                    guard measured > 40, gap.isFinite, abs(gap) < 5000 else { return }
                    if intrinsicHeight == nil {
                        intrinsicHeight = measured
                    }
                    let floor = intrinsicHeight ?? measured
                    let proposed = max(floor, measured + gap - bottomGap)
                    guard cardHeight == nil || abs((cardHeight ?? 0) - proposed) > 1 else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        cardHeight = proposed
                    }
                    #if SIDEBAR_PREVIEW
                    print(String(format: "DEMOFILL measured %.0f gap %.0f height %.0f", measured, gap, proposed))
                    #endif
                }
            )
    }
}

private struct WindowBottomGapReader: NSViewRepresentable {
    var onMeasure: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> GapProbeView {
        let view = GapProbeView()
        view.onMeasure = onMeasure
        return view
    }

    func updateNSView(_ nsView: GapProbeView, context: Context) {
        nsView.onMeasure = onMeasure
    }
}

private final class GapProbeView: NSView {
    var onMeasure: ((CGFloat, CGFloat) -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        report()
    }

    override func layout() {
        super.layout()
        report()
    }

    private func report() {
        guard let content = window?.contentView, bounds.height > 40 else { return }
        let frame = convert(bounds, to: content)
        let gap = content.isFlipped ? content.bounds.maxY - frame.maxY : frame.minY
        let height = bounds.height
        DispatchQueue.main.async { [weak self] in
            self?.onMeasure?(height, gap)
        }
    }
}

struct GlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.blue.opacity(0.07),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
