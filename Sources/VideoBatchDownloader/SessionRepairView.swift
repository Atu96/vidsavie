import AppKit
import SwiftUI

@MainActor
final class SessionRepairCoordinator {
    static let shared = SessionRepairCoordinator()

    private var windowController: NSWindowController?
    private var hostingController: NSHostingController<SessionRepairView>?

    private init() {}

    func show(manager: DownloadManager, job: DownloadJob) {
        let rootView = SessionRepairView(manager: manager, job: job) { [weak self] in
            self?.close()
        }

        if let windowController, let hostingController {
            hostingController.rootView = rootView
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
        } else {
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 470),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Repair Browser Session"
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentViewController = hostingController
            window.center()

            let controller = NSWindowController(window: window)
            self.hostingController = hostingController
            windowController = controller
            controller.showWindow(nil)
        }

        if let window = windowController?.window {
            WindowActivationCoordinator.shared.bringToFront(window)
        }
    }

    func close() {
        windowController?.close()
    }
}

struct SessionRepairView: View {
    @ObservedObject var manager: DownloadManager
    @ObservedObject var job: DownloadJob
    let close: () -> Void

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(accentGradient, in: RoundedRectangle(cornerRadius: 15))
                    .shadow(color: .purple.opacity(0.25), radius: 10, y: 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text(t("repairSession", "Repair Browser Session"))
                        .font(.title2.bold())
                    Text(issueDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 0) {
                repairRow(
                    icon: "switch.2",
                    title: t("cookiePolicy", "Usage"),
                    detail: t("browserSessionSub", "Use local cookies only when required")
                ) {
                    Picker(t("cookiePolicy", "Usage"), selection: $manager.browserCookiePolicy) {
                        Text(t("cookieSmart", "Automatic")).tag(BrowserCookiePolicy.smart)
                        Text(t("cookieAlways", "Always")).tag(BrowserCookiePolicy.always)
                        Text(t("cookieNever", "Never")).tag(BrowserCookiePolicy.never)
                    }
                    .labelsHidden().frame(width: 125)
                }

                Divider().opacity(0.45)

                repairRow(
                    icon: "globe",
                    title: t("cookieBrowser", "Browser"),
                    detail: t("cookieProfileHint", "Choose the signed-in browser profile")
                ) {
                    Picker(t("cookieBrowser", "Browser"), selection: $manager.browserCookieSource) {
                        ForEach(BrowserCookieSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .labelsHidden().frame(width: 150)
                }

                Divider().opacity(0.45)

                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(accentGradient)
                        .frame(width: 26)
                    BrowserProfileControl(manager: manager)
                }
                .padding(13)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08)))

            if manager.isTestingBrowserSession || !manager.browserSessionStatus.isEmpty {
                HStack(spacing: 8) {
                    if manager.isTestingBrowserSession {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: manager.browserSessionTestPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(manager.browserSessionTestPassed ? Color.green : Color.orange)
                    }
                    Text(manager.isTestingBrowserSession
                         ? t("checkingSession", "Checking browser session…")
                         : manager.browserSessionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 9) {
                Button {
                    manager.openSelectedBrowserForSessionRepair(failedURL: job.normalizedURL)
                } label: {
                    Label(t("openBrowser", "Open Browser"), systemImage: "safari")
                }
                .buttonStyle(.bordered)

                Button {
                    manager.testBrowserSession()
                } label: {
                    Label(t("testSession", "Test Session"), systemImage: "checkmark.shield")
                }
                .buttonStyle(.bordered)
                .disabled(manager.isTestingBrowserSession || manager.browserCookiePolicy == .never)

                Button {
                    manager.scheduleSupportToolsUpdate(force: true)
                } label: {
                    Label(
                        manager.supportToolsLastUpdateFailed
                            ? t("retrySupportTools", "Try again")
                            : manager.supportToolsInstalled
                            ? t("updateSupportTools", "Update tools")
                            : t("installSupportTools", "Install tools"),
                        systemImage: manager.supportToolsInstalled ? "arrow.clockwise" : "square.and.arrow.down"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(manager.isUpdatingSupportTools)

                Spacer()
            }

            HStack {
                Button(t("later", "Later"), action: close)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    manager.retry(job)
                    close()
                } label: {
                    Label(t("retryDownload", "Try Download Again"), systemImage: "arrow.clockwise.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(job.status != .failed)
            }
        }
        .padding(24)
        .frame(width: 520, height: 470)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var issueDescription: String {
        switch job.browserSessionIssue {
        case .forbidden:
            t("session403Detail", "YouTube rejected the video stream. The browser session or yt-dlp may need refreshing.")
        case .verificationRequired:
            if URLNormalizer.isDouyin(job.normalizedURL) {
                t("sessionDouyinFreshDetail", "Douyin needs fresh browser cookies. Open Douyin once in the selected browser, then retry.")
            } else {
                t("sessionVerificationDetail", "YouTube requires sign-in or bot verification before this video can be downloaded.")
            }
        case .cookieAccess:
            t("sessionCookieDetail", "The selected browser profile could not be read. Check the browser and profile below.")
        case nil:
            t("sessionNeedsAttentionDetail", "Check the browser profile, refresh your sign-in, then retry.")
        }
    }

    private func repairRow<Content: View>(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(accentGradient)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            content()
        }
        .padding(13)
    }
}
