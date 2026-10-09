import SwiftUI
import AppKit

/// User-selected directory only. Never reads or exports cookie contents.
struct BrowserProfileControl: View {
    @ObservedObject var manager: DownloadManager

    private func t(_ key: String) -> String {
        BrowserSessionCopy.value(key, language: manager.interfaceLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField(t("profile"), text: $manager.browserCookieProfile)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(t("profile"))
            HStack {
                Button(t("choose"), action: chooseProfile)
                if manager.browserCookieSource != .firefox {
                    Button("Default") { manager.browserCookieProfile = "Default" }
                        .help(BrowserAccessCopy.value("default", language: manager.interfaceLanguage))
                }
                Button(t("automatic")) { manager.browserCookieProfile = "" }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(manager.isTestingBrowserSession)
            Text(t("hint")).font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if manager.browserSessionDiagnostic == .accessDenied {
                Text(BrowserAccessCopy.value("scope", language: manager.interfaceLanguage))
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(BrowserAccessCopy.value("privacy", language: manager.interfaceLanguage)) {
                    // Navigation only; never grants permission, edits TCC, or
                    // enables Full Disk Access on the user's behalf.
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private func chooseProfile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.message = t("hint")
        panel.prompt = t("choose")
        panel.directoryURL = BrowserProfileProbe.root(source: manager.browserCookieSource,
            home: FileManager.default.homeDirectoryForCurrentUser)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            manager.browserCookieProfile = url.path
        }
    }
}

enum BrowserAccessCopy {
    private static let keys = ["privacy", "blocked", "scope", "default"]
    private static let translations: [String: [String]] = [
        "en": ["Open macOS Privacy…", "Browser-folder access was denied before yt-dlp started. This is an access problem, not proof that the profile or cookies are missing.", "Review System Settings → Privacy & Security for VidSavie. Full Disk Access is a broad permission, not a required default: grant it only if you trust the app and need it. Restart the app after a permission change, then test again. Do not grant access to Terminal or unrelated apps just for this test.", "Select the browser's Default profile; Profile 1 is not required."],
        "vi": ["Mở quyền riêng tư macOS…", "Bị chặn truy cập thư mục trình duyệt trước khi chạy yt-dlp. Đây là lỗi quyền, chưa thể kết luận thiếu profile hoặc cookie.", "Kiểm tra System Settings → Privacy & Security cho VidSavie. Full Disk Access là quyền rộng, không mặc định bắt buộc: chỉ cấp nếu tin app và cần thiết. Đổi quyền xong khởi động lại app rồi kiểm tra. Không cấp quyền Terminal hay app khác chỉ để thử phiên.", "Chọn profile Default; không cần có Profile 1."],
        "zh": ["打开 macOS 隐私设置…", "启动 yt-dlp 前访问浏览器文件夹被拒绝。这是权限问题，不代表配置或 Cookie 不存在。", "检查系统设置 → 隐私与安全性中的 VidSavie。完全磁盘访问是广泛权限，并非默认要求；仅在信任且确有需要时授权。更改权限后重启应用再测试。不要为此授权终端或无关应用。", "选择 Default 配置；不需要 Profile 1。"],
        "es": ["Privacidad de macOS…", "Se denegó acceso a la carpeta antes de iniciar yt-dlp. No significa que falten el perfil o las cookies.", "Revisa Ajustes del Sistema → Privacidad y seguridad para VidSavie. Acceso total al disco es amplio y no obligatorio por defecto: concédelo solo si confías en la app y lo necesitas. Reinicia tras cambiar permisos. No autorices Terminal ni apps ajenas para esta prueba.", "Seleccionar Default; no necesitas Profile 1."],
        "fr": ["Confidentialité macOS…", "Accès au dossier refusé avant yt-dlp. Cela ne prouve pas l’absence du profil ou des cookies.", "Vérifiez Réglages Système → Confidentialité et sécurité pour VidSavie. L’accès complet au disque est large et non obligatoire par défaut : accordez-le uniquement si nécessaire et si vous faites confiance à l’app. Redémarrez après modification. N’autorisez pas Terminal ou d’autres apps pour ce test.", "Choisir Default ; Profile 1 n’est pas requis."],
        "de": ["macOS-Datenschutz…", "Browserordner-Zugriff vor yt-dlp verweigert. Das beweist nicht, dass Profil oder Cookies fehlen.", "Systemeinstellungen → Datenschutz & Sicherheit für VidSavie prüfen. Festplattenvollzugriff ist weitreichend, nicht standardmäßig nötig: nur bei Vertrauen und Bedarf erlauben. Danach App neu starten. Für diesen Test nicht Terminal oder fremde Apps freigeben.", "Default wählen; Profile 1 ist nicht erforderlich."],
        "pt": ["Privacidade do macOS…", "Acesso à pasta negado antes do yt-dlp. Isso não prova que o perfil ou cookies estejam ausentes.", "Confira Ajustes do Sistema → Privacidade e Segurança para VidSavie. Acesso Total ao Disco é amplo, não obrigatório por padrão: permita apenas se confiar no app e precisar. Reinicie após alterar permissões. Não autorize Terminal ou outros apps para este teste.", "Selecionar Default; Profile 1 não é necessário."],
        "ja": ["macOS のプライバシー設定…", "yt-dlp 起動前にブラウザフォルダへのアクセスが拒否されました。プロファイルや Cookie がないとは限りません。", "システム設定 → プライバシーとセキュリティで VidSavie を確認してください。フルディスクアクセスは広範な権限で、標準の必須条件ではありません。信頼でき、必要な場合のみ許可してください。変更後はアプリを再起動します。このテストのためにターミナルや他のアプリを許可しないでください。", "Default を選択。Profile 1 は必要ありません。"],
        "ko": ["macOS 개인정보 설정…", "yt-dlp 실행 전 브라우저 폴더 접근이 거부되었습니다. 프로필이나 쿠키가 없다는 뜻은 아닙니다.", "시스템 설정 → 개인정보 보호 및 보안에서 VidSavie를 확인하세요. 전체 디스크 접근은 광범위한 권한이며 기본 필수 사항이 아닙니다. 신뢰하고 필요한 경우에만 허용하세요. 권한 변경 후 앱을 재시작하세요. 이 테스트를 위해 Terminal이나 다른 앱에 권한을 주지 마세요.", "Default 선택. Profile 1은 필요하지 않습니다."]
    ]
    static func value(_ key: String, language: String) -> String {
        guard let index = keys.firstIndex(of: key) else { return key }
        return (translations[AppText.resolvedLanguage(language)] ?? translations["en"]!)[index]
    }
}

enum BrowserSessionCopy {
    // Each language has the same ordered keys. Do not imply a successful
    // session test proves sign-in, platform availability, or download access.
    private static let keys = ["session", "profile", "choose", "automatic", "hint", "missing", "denied", "failed", "ready"]
    private static let translations: [String: [String]] = [
        "en": ["Browser session…", "Profile name or folder", "Choose profile…", "Use automatic", "Choose the signed-in profile folder (Default or Profile 1), not the Chrome root. Firefox uses its profile folder. A session test contacts YouTube without downloading media.", "Cookie database not found. Check the browser and choose its profile folder. Open that browser once before testing again; access restrictions can also hide the database.", "The browser session could not be read or decrypted. Check macOS privacy permissions and any Keychain prompt. Choosing a folder does not guarantee access.", "Session test failed. Check your connection, browser profile, and source-site access; this is not always a cookie problem.", "Session test passed; this does not guarantee every video can be downloaded."],
        "vi": ["Phiên trình duyệt…", "Tên hoặc thư mục profile", "Chọn profile…", "Dùng tự động", "Chọn thư mục profile đang đăng nhập (Default hoặc Profile 1), không chọn thư mục gốc Chrome. Firefox dùng thư mục profile riêng. Kiểm tra phiên kết nối YouTube, không tải video.", "Không tìm thấy database cookie. Kiểm tra trình duyệt và chọn thư mục profile. Mở trình duyệt một lần rồi thử lại; giới hạn quyền cũng có thể che database.", "Không đọc hoặc giải mã được phiên. Kiểm tra quyền riêng tư macOS và yêu cầu Keychain nếu có. Chọn thư mục không bảo đảm có quyền đọc.", "Kiểm tra phiên thất bại. Kiểm tra mạng, profile và quyền truy cập trang; không phải lúc nào cũng do cookie.", "Kiểm tra phiên thành công; không bảo đảm tải được mọi video."],
        "zh": ["浏览器会话…", "配置名称或文件夹", "选择配置…", "自动选择", "选择已登录的配置文件夹（Default 或 Profile 1），而非 Chrome 根目录。Firefox 使用自己的配置文件夹。测试会连接 YouTube，但不下载视频。", "找不到 Cookie 数据库。检查浏览器并选择配置文件夹，打开浏览器后重试。权限限制也可能隐藏数据库。", "无法读取或解密会话。检查 macOS 隐私权限和钥匙串提示。选择文件夹不保证访问权限。", "会话测试失败。检查网络、配置和网站访问权限，不一定是 Cookie 问题。", "会话测试通过，但不保证所有视频都能下载。"],
        "es": ["Sesión del navegador…", "Nombre o carpeta del perfil", "Elegir perfil…", "Usar automático", "Elige la carpeta del perfil conectado (Default o Profile 1), no la raíz de Chrome. Firefox usa su propia carpeta. La prueba conecta con YouTube sin descargar vídeos.", "No se encontró la base de cookies. Comprueba el navegador y elige su perfil. Ábrelo y prueba de nuevo; los permisos también pueden ocultar la base.", "No se pudo leer o descifrar la sesión. Comprueba los permisos de macOS y el Llavero. Elegir carpeta no garantiza acceso.", "Falló la prueba. Comprueba la red, el perfil y el acceso al sitio; no siempre son las cookies.", "Prueba superada; no garantiza la descarga de todos los vídeos."],
        "fr": ["Session du navigateur…", "Nom ou dossier du profil", "Choisir un profil…", "Choix automatique", "Choisissez le dossier du profil connecté (Default ou Profile 1), pas la racine Chrome. Firefox utilise son propre dossier. Le test contacte YouTube sans télécharger de vidéo.", "Base de cookies introuvable. Vérifiez le navigateur et choisissez son profil. Ouvrez-le puis réessayez ; les permissions peuvent aussi masquer la base.", "Session illisible ou indéchiffrable. Vérifiez les permissions macOS et le Trousseau. Choisir un dossier ne garantit pas l’accès.", "Échec du test. Vérifiez le réseau, le profil et l’accès au site ; ce ne sont pas toujours les cookies.", "Test réussi ; tous les téléchargements ne sont pas garantis."],
        "de": ["Browsersitzung…", "Profilname oder Ordner", "Profil wählen…", "Automatisch", "Den angemeldeten Profilordner wählen (Default oder Profile 1), nicht den Chrome-Hauptordner. Firefox nutzt seinen Profilordner. Der Test verbindet sich ohne Videodownload mit YouTube.", "Cookie-Datenbank nicht gefunden. Browser und Profil prüfen, Browser öffnen und erneut testen. Auch Zugriffsrechte können die Datenbank verbergen.", "Sitzung nicht lesbar oder entschlüsselbar. macOS-Datenschutz und Schlüsselbund prüfen. Ordnerauswahl garantiert keinen Zugriff.", "Test fehlgeschlagen. Netzwerk, Profil und Website-Zugriff prüfen; nicht immer ein Cookie-Problem.", "Test erfolgreich; nicht jedes Video ist dadurch herunterladbar."],
        "pt": ["Sessão do navegador…", "Nome ou pasta do perfil", "Escolher perfil…", "Usar automático", "Escolha a pasta do perfil conectado (Default ou Profile 1), não a raiz do Chrome. Firefox usa sua própria pasta. O teste acessa o YouTube sem baixar vídeos.", "Banco de cookies não encontrado. Verifique o navegador e escolha seu perfil. Abra-o e tente novamente; permissões também podem ocultar o banco.", "Não foi possível ler ou descriptografar a sessão. Verifique permissões do macOS e as Chaves. Escolher pasta não garante acesso.", "Teste falhou. Verifique rede, perfil e acesso ao site; nem sempre são os cookies.", "Teste aprovado; não garante baixar todos os vídeos."],
        "ja": ["ブラウザセッション…", "プロファイル名またはフォルダ", "プロファイルを選択…", "自動選択", "ログイン中のプロファイルフォルダ（Default や Profile 1）を選びます。Chrome のルートではありません。Firefox は専用フォルダを使います。テストは動画をダウンロードせず YouTube に接続します。", "Cookie データベースが見つかりません。ブラウザとプロファイルを確認し、ブラウザを開いて再試行してください。権限制限も原因になり得ます。", "セッションを読み取り・復号できません。macOS のプライバシー権限とキーチェーンを確認してください。フォルダ選択だけではアクセスは保証されません。", "テスト失敗。ネットワーク、プロファイル、サイトへのアクセスを確認してください。Cookie が原因とは限りません。", "テスト成功。すべての動画のダウンロードを保証するものではありません。"],
        "ko": ["브라우저 세션…", "프로필 이름 또는 폴더", "프로필 선택…", "자동 선택", "로그인한 프로필 폴더(Default 또는 Profile 1)를 선택하세요. Chrome 루트 폴더가 아닙니다. Firefox는 별도 프로필 폴더를 사용합니다. 테스트는 영상 다운로드 없이 YouTube에 연결합니다.", "쿠키 데이터베이스를 찾지 못했습니다. 브라우저와 프로필을 확인하고 브라우저를 연 후 다시 시도하세요. 권한 제한도 원인일 수 있습니다.", "세션을 읽거나 복호화하지 못했습니다. macOS 개인정보 권한과 키체인 요청을 확인하세요. 폴더 선택만으로 접근이 보장되지는 않습니다.", "테스트 실패. 네트워크, 프로필, 사이트 접근을 확인하세요. 항상 쿠키 문제인 것은 아닙니다.", "테스트 성공. 모든 영상 다운로드를 보장하지는 않습니다."]
    ]
    static func value(_ key: String, language: String) -> String {
        guard let index = keys.firstIndex(of: key) else { return key }
        let code = AppText.resolvedLanguage(language)
        return (translations[code] ?? translations["en"]!)[index]
    }
}
