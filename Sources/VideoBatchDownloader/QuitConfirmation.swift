import AppKit

/// Central termination gate: power button, application menu and Cmd-Q share one prompt.
/// Closing an ordinary app window does not terminate the background application.
final class QuitConfirmationDelegate: NSObject, NSApplicationDelegate {
    private var isPresenting = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isPresenting else { return .terminateCancel }
        isPresenting = true
        defer { isPresenting = false }

        let language = AppText.resolvedLanguage(UserDefaults.standard.string(forKey: PreferenceKeys.interfaceLanguage) ?? "auto")
        let copy = QuitConfirmationCopy.localized(language)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = copy.title
        alert.informativeText = copy.message + "\n\n" + copy.question
        alert.icon = NSApplication.shared.applicationIconImage
        // Staying is the safe default. Explicit confirmation alone permits termination.
        alert.addButton(withTitle: copy.stay).keyEquivalent = "\r"
        alert.addButton(withTitle: copy.quit).keyEquivalent = ""
        let support = alert.addButton(withTitle: copy.support)
        let title = NSMutableAttributedString(string: "♥ ", attributes: [.foregroundColor: NSColor.systemRed])
        title.append(NSAttributedString(string: copy.support, attributes: [.foregroundColor: NSColor.labelColor]))
        support.attributedTitle = title
        support.setAccessibilityLabel(copy.support)
        let divider = NSBox(frame: NSRect(x: 0, y: 0, width: 360, height: 1))
        divider.boxType = .separator
        alert.accessoryView = divider
        alert.layout()
        alert.buttons[0].keyEquivalent = "\u{1b}"
        alert.window.defaultButtonCell = alert.buttons[0].cell as? NSButtonCell
        sender.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn { return .terminateNow }
        if response == .alertThirdButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/atu1202")!)
        }
        return .terminateCancel
    }
}

struct QuitConfirmationCopy {
    let title: String
    let message: String
    let question: String
    let stay: String
    let quit: String
    let support: String

    static func localized(_ language: String) -> QuitConfirmationCopy {
        switch language {
        case "vi": return .init(title: "Chào bạn! 👋", message: "Mình dùng AI để tạo những ứng dụng nhỏ, hữu ích và chia sẻ miễn phí. Nếu app giúp bạn tiết kiệm thời gian, một chút ủng hộ trên Ko-fi sẽ tiếp thêm động lực để mình cải thiện nó. Hoàn toàn tùy bạn — cảm ơn bạn đã sử dụng! ❤️", question: "Bạn muốn thoát VidSavie? Công việc đang chạy sẽ bị gián đoạn.", stay: "Không, ở lại", quit: "Có, thoát", support: "Ủng hộ")
        case "zh": return .init(title: "你好！👋", message: "我用 AI 制作简单实用的免费应用。如果它帮你节省了时间，可以在 Ko-fi 支持我继续改进。完全自愿，感谢你的使用！❤️", question: "退出 VidSavie？正在进行的任务将被中断。", stay: "不，留下", quit: "是，退出", support: "支持")
        case "es": return .init(title: "¡Hola! 👋", message: "Creo pequeñas apps útiles con IA y las comparto gratis. Si esta app te ahorró tiempo, una propina en Ko-fi me anima a seguir mejorándola. Sin compromiso: ¡gracias por usarla! ❤️", question: "¿Salir de VidSavie? Las tareas en curso se interrumpirán.", stay: "No, quedarse", quit: "Sí, salir", support: "Apoyar")
        case "fr": return .init(title: "Bonjour ! 👋", message: "Je crée avec l’IA de petites apps utiles et gratuites. Si celle-ci vous a fait gagner du temps, un don sur Ko-fi m’encourage à l’améliorer. Aucune obligation : merci de l’utiliser ! ❤️", question: "Quitter VidSavie ? Les tâches en cours seront interrompues.", stay: "Non, rester", quit: "Oui, quitter", support: "Soutenir")
        case "de": return .init(title: "Hallo! 👋", message: "Ich entwickle mit KI kleine, nützliche Apps und teile sie kostenlos. Wenn dir diese App Zeit spart, motiviert mich ein Trinkgeld auf Ko-fi, sie weiter zu verbessern. Ganz freiwillig — danke fürs Nutzen! ❤️", question: "VidSavie beenden? Laufende Aufgaben werden unterbrochen.", stay: "Nein, bleiben", quit: "Ja, beenden", support: "Unterstützen")
        case "pt": return .init(title: "Olá! 👋", message: "Crio pequenos apps úteis com IA e compartilho de graça. Se este app poupou seu tempo, uma contribuição no Ko-fi me incentiva a melhorá-lo. Sem obrigação — obrigado por usar! ❤️", question: "Sair do VidSavie? As tarefas em andamento serão interrompidas.", stay: "Não, ficar", quit: "Sim, sair", support: "Apoiar")
        case "ja": return .init(title: "こんにちは！👋", message: "AIを使って便利な小さなアプリを作り、無料で公開しています。時間の節約に役立ったら、Ko-fiでの応援が改善の励みになります。もちろん任意です。ご利用ありがとうございます！❤️", question: "VidSavieを終了しますか？実行中の作業は中断されます。", stay: "いいえ、戻る", quit: "はい、終了", support: "応援する")
        case "ko": return .init(title: "안녕하세요! 👋", message: "AI로 작고 유용한 앱을 만들고 무료로 나눕니다. 시간을 아끼는 데 도움이 됐다면 Ko-fi 후원이 개선을 이어갈 힘이 됩니다. 부담 없이, 사용해 주셔서 감사합니다! ❤️", question: "VidSavie를 종료할까요? 진행 중인 작업이 중단됩니다.", stay: "아니요, 유지", quit: "예, 종료", support: "후원")
        default: return .init(title: "Hi there! 👋", message: "I build small, useful apps with AI and share them for free. If this app saved you time, a small Ko-fi tip helps me keep improving it. No pressure — thanks for using it! ❤️", question: "Quit VidSavie? Any running work will be interrupted.", stay: "No, stay", quit: "Yes, quit", support: "Support")
        }
    }
}
