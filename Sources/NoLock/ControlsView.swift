import AppKit
import SwiftUI

private let mint = Color(red: 0.43, green: 0.91, blue: 0.70)

struct ControlsView: View {
    @ObservedObject var controller: AwakeController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(mint)
                    .frame(width: 46, height: 46)
                    .background(mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("NoLock").font(.system(size: 22, weight: .semibold))
                    Text("A little movement. Uninterrupted work.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 7) {
                        Circle().fill(controller.keepingAwake ? mint : Color.gray).frame(width: 7, height: 7)
                        Text(controller.title).font(.system(size: 15, weight: .semibold))
                    }
                    Spacer(minLength: 4)
                    Toggle("Keep Mac awake", isOn: Binding(get: { controller.enabled }, set: { controller.setEnabled($0) }))
                        .labelsHidden().toggleStyle(.switch).tint(mint)
                }
                Text(controller.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(.white.opacity(0.04))
                HStack(spacing: 0) {
                    metric("2 min", label: "BEFORE IDLE")
                    Spacer()
                    metric("30 sec", label: "BETWEEN NUDGES")
                    Spacer()
                    metric("2 pt", label: "TINY MOVEMENT")
                }
            }
            .padding(16)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))

            if !controller.hasPermission {
                VStack(alignment: .leading, spacing: 10) {
                    Label("One macOS permission", systemImage: "hand.raised")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.orange)
                    Text("Allow NoLock in Privacy & Security → Accessibility so it can gently move your cursor.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: { controller.requestPermission() }) {
                        Text("Enable cursor movement").font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
                }
                .padding(14)
                .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(controller.idleLabel).font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(mint)
                    }
                    ProgressView(value: controller.enabled ? min(controller.idleSeconds / 120, 1) : 0)
                        .tint(mint)
                    HStack {
                        Text("\(controller.nudgeCount) nudges this session")
                        Spacer()
                        if let date = controller.lastNudge {
                            Text(date, style: .time)
                        }
                    }
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(get: { controller.loginEnabled }, set: { controller.setLaunchAtLogin($0) })) {
                    Label("Launch at login", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch).controlSize(.small).tint(mint)
                if controller.loginNeedsApproval {
                    Button("Approve in Login Items…") { controller.openLoginSettings() }
                        .font(.system(size: 11))
                }
                if let error = controller.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Nudges pause when you type, move the mouse, or hold a mouse button. Manual locking and lid-close sleep still work.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                Button("Test a nudge") { controller.testNudge() }
                    .disabled(!controller.enabled || !controller.sessionActive)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .font(.system(size: 11)).buttonStyle(.borderless)
        }
        .padding(22)
        .frame(width: 370)
        .background(Color(red: 0.075, green: 0.085, blue: 0.105))
        .preferredColorScheme(.dark)
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 18, weight: .medium, design: .rounded))
            Text(label).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}
