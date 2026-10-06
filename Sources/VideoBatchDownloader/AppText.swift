import Foundation

enum AppText {
    private static let mediaSourceTranslations: [String: String] = [
        "en": "Downloading the matching media source archive…",
        "vi": "Đang tải mã nguồn tương ứng của công cụ media…",
        "zh": "正在下载对应的媒体工具源代码…",
        "es": "Descargando el código fuente de las herramientas multimedia…",
        "fr": "Téléchargement des sources des outils multimédias…",
        "de": "Passender Quellcode der Medienwerkzeuge wird geladen…",
        "pt": "Baixando o código-fonte correspondente das ferramentas de mídia…",
        "ja": "メディアツールに対応するソースをダウンロード中…",
        "ko": "미디어 도구에 해당하는 소스 코드를 다운로드하는 중…"
    ]
    private static let vi: [String: String] = [
        "supportAction":"Ủng hộ",
        "donateTitle":"Thích ứng dụng này?",
        "donateDetail":"Sự ủng hộ của bạn giúp VidSavie ngày càng tốt hơn. Cảm ơn bạn!",
        "donateAccessibility":"Ủng hộ trên Ko-fi (mở trong trình duyệt)",
        "quickAdd":"Thêm nhanh", "pasteMany":"Dán một hoặc nhiều liên kết", "linkPlaceholder":"Liên kết YouTube, Douyin hoặc X…", "quality":"Chất lượng", "best":"Tốt nhất", "type":"Loại", "video":"Video", "audio":"Âm thanh", "active":"Đang tải", "waiting":"Đang chờ", "done":"Hoàn tất", "ready":"Sẵn sàng", "starting":"Đang mở", "downloadComplete":"Tải xuống hoàn tất", "mediaReady":"Nội dung đã sẵn sàng", "open":"Mở", "readyWhen":"Sẵn sàng khi bạn cần", "emptyHint":"Dán liên kết phía trên hoặc dùng nút tải nổi trên YouTube, Douyin hay X.", "folder":"Thư mục", "location":"Vị trí", "clear":"Dọn xong", "general":"Chung", "appearance":"Giao diện", "about":"Giới thiệu", "browserCompanion":"Tiện ích trình duyệt", "browserCompanionSub":"Tiện ích trình duyệt tự động đồng bộ các cài đặt này", "browserDetection":"Nhận diện trên trình duyệt", "browserDetectionDetail":"Bật nhận diện nội dung trên trình duyệt", "floatingButton":"Nút tải nổi", "floatingDetail":"Chỉ hiện cạnh nội dung đang nhìn thấy", "installCompanion":"Cài tiện ích trình duyệt", "included":"Tiện ích được đi kèm với app Mac", "chromeDetail":"Mở trang Extensions và hiện thư mục tiện ích", "firefoxDetail":"Mở trang gỡ lỗi Add-on và hiện thư mục tiện ích", "setup":"Cài đặt", "downloads":"Tải xuống", "downloadsSub":"Áp dụng cho lượt tải nhanh từ trình duyệt", "defaultQuality":"Chất lượng mặc định", "defaultQualityDetail":"Bạn vẫn có thể chọn chất lượng khác", "localSync":"Các thay đổi được đồng bộ nội bộ, không cần tài khoản hay đám mây.", "language":"Ngôn ngữ", "languageSub":"App và nút tải trên trình duyệt", "interfaceLanguage":"Ngôn ngữ giao diện", "interfaceLanguageDetail":"Chọn ngôn ngữ hoặc dùng theo hệ thống", "glassTheme":"Giao diện kính", "glassThemeSub":"Đồng thời đổi nút tải nổi trên trình duyệt", "system":"Hệ thống", "followMac":"Theo macOS", "darkGlass":"Kính tối", "lightGlass":"Kính sáng", "neonGlass":"Kính neon", "version":"Phiên bản", "workflow":"Quy trình media chạy nội bộ", "workflowSub":"App menu bar nhẹ dành cho Mac", "private":"Riêng tư từ thiết kế", "privateDetail":"Liên kết và cookie trình duyệt chỉ nằm trên máy Mac này", "performance":"Hiệu năng ổn định", "performanceDetail":"Tải tuần tự từng mục và chuyển đổi bằng GPU Apple", "replaceable":"Tiện ích có thể thay thế", "replaceableDetail":"App Mac vẫn hoạt động khi không có Chrome", "stop":"Dừng", "retry":"Thử lại", "show":"Hiện file", "gpuOptimizing":"GPU Apple đang tối ưu tương thích", "gpuQueue":"Đang chờ GPU", "queued":"Đang chờ", "reading":"Đang đọc", "downloading":"Đang tải", "convertingVideo":"Đang chuyển video bằng GPU", "convertingAudio":"Đang tạo MP3", "completed":"Hoàn tất", "failed":"Thất bại", "stopped":"Đã dừng", "added":"Đã thêm %d mục vào hàng đợi", "noLinks":"Không tìm thấy liên kết mới được hỗ trợ"
    ]

    private static let zh: [String: String] = [
        "quickAdd":"快速添加", "pasteMany":"粘贴一个或多个链接", "quality":"画质", "best":"最佳", "type":"类型", "video":"视频", "audio":"音频", "active":"进行中", "waiting":"等待", "done":"完成", "ready":"就绪", "starting":"启动中", "downloadComplete":"下载完成", "open":"打开", "readyWhen":"随时可以开始", "folder":"文件夹", "location":"位置", "clear":"清除", "general":"常规", "appearance":"外观", "about":"关于", "browserCompanion":"浏览器助手", "browserDetection":"浏览器检测", "floatingButton":"悬浮下载按钮", "installCompanion":"安装浏览器助手", "setup":"设置", "downloads":"下载", "defaultQuality":"默认画质", "language":"语言", "interfaceLanguage":"界面语言", "glassTheme":"玻璃主题", "system":"系统", "followMac":"跟随 macOS", "stop":"停止", "retry":"重试", "show":"显示文件", "completed":"已完成", "failed":"失败", "stopped":"已停止", "downloading":"下载中", "queued":"等待中", "reading":"读取中", "convertingVideo":"GPU 转换视频", "convertingAudio":"正在生成 MP3"
    ]

    private static let es: [String: String] = [
        "quickAdd":"Añadir rápido", "pasteMany":"Pega uno o varios enlaces", "quality":"Calidad", "best":"Mejor", "type":"Tipo", "video":"Vídeo", "audio":"Audio", "active":"Activos", "waiting":"En espera", "done":"Listos", "ready":"Listo", "starting":"Iniciando", "downloadComplete":"Descarga completada", "open":"Abrir", "readyWhen":"Listo cuando quieras", "folder":"Carpeta", "location":"Ubicación", "clear":"Limpiar", "general":"General", "appearance":"Apariencia", "about":"Acerca de", "browserCompanion":"Complemento del navegador", "browserDetection":"Detección del navegador", "floatingButton":"Botón flotante", "installCompanion":"Instalar complemento", "setup":"Instalar", "downloads":"Descargas", "defaultQuality":"Calidad predeterminada", "language":"Idioma", "interfaceLanguage":"Idioma de la interfaz", "glassTheme":"Tema de cristal", "system":"Sistema", "followMac":"Seguir macOS", "stop":"Detener", "retry":"Reintentar", "show":"Mostrar", "completed":"Completado", "failed":"Error", "stopped":"Detenido", "downloading":"Descargando", "queued":"En espera", "reading":"Leyendo", "convertingVideo":"Convirtiendo con GPU", "convertingAudio":"Creando MP3"
    ]

    private static let fr: [String: String] = [
        "quickAdd":"Ajout rapide", "pasteMany":"Collez un ou plusieurs liens", "quality":"Qualité", "best":"Meilleure", "type":"Type", "video":"Vidéo", "audio":"Audio", "active":"Actifs", "waiting":"En attente", "done":"Terminés", "ready":"Prêt", "starting":"Démarrage", "downloadComplete":"Téléchargement terminé", "open":"Ouvrir", "readyWhen":"Prêt quand vous l’êtes", "folder":"Dossier", "location":"Emplacement", "clear":"Effacer", "general":"Général", "appearance":"Apparence", "about":"À propos", "browserCompanion":"Extension navigateur", "browserDetection":"Détection du navigateur", "floatingButton":"Bouton flottant", "installCompanion":"Installer l’extension", "setup":"Installer", "downloads":"Téléchargements", "defaultQuality":"Qualité par défaut", "language":"Langue", "interfaceLanguage":"Langue de l’interface", "glassTheme":"Thème verre", "system":"Système", "followMac":"Suivre macOS", "stop":"Arrêter", "retry":"Réessayer", "show":"Afficher", "completed":"Terminé", "failed":"Échec", "stopped":"Arrêté", "downloading":"Téléchargement", "queued":"En attente", "reading":"Lecture", "convertingVideo":"Conversion GPU", "convertingAudio":"Création du MP3"
    ]

    private static let de: [String: String] = [
        "quickAdd":"Schnell hinzufügen", "pasteMany":"Einen oder mehrere Links einfügen", "quality":"Qualität", "best":"Beste", "type":"Typ", "video":"Video", "audio":"Audio", "active":"Aktiv", "waiting":"Wartend", "done":"Fertig", "ready":"Bereit", "starting":"Startet", "downloadComplete":"Download abgeschlossen", "open":"Öffnen", "readyWhen":"Bereit, wenn du es bist", "folder":"Ordner", "location":"Speicherort", "clear":"Leeren", "general":"Allgemein", "appearance":"Darstellung", "about":"Über", "browserCompanion":"Browser-Erweiterung", "browserDetection":"Browser-Erkennung", "floatingButton":"Schwebender Downloadknopf", "installCompanion":"Erweiterung installieren", "setup":"Einrichten", "downloads":"Downloads", "defaultQuality":"Standardqualität", "language":"Sprache", "interfaceLanguage":"Oberflächensprache", "glassTheme":"Glasdesign", "system":"System", "followMac":"macOS folgen", "stop":"Stoppen", "retry":"Erneut", "show":"Anzeigen", "completed":"Abgeschlossen", "failed":"Fehlgeschlagen", "stopped":"Gestoppt", "downloading":"Lädt", "queued":"Wartet", "reading":"Liest", "convertingVideo":"GPU-Konvertierung", "convertingAudio":"MP3 wird erstellt"
    ]

    private static let pt: [String: String] = [
        "quickAdd":"Adicionar rápido", "pasteMany":"Cole um ou vários links", "quality":"Qualidade", "best":"Melhor", "type":"Tipo", "video":"Vídeo", "audio":"Áudio", "active":"Ativos", "waiting":"Aguardando", "done":"Concluídos", "ready":"Pronto", "starting":"Iniciando", "downloadComplete":"Download concluído", "open":"Abrir", "readyWhen":"Pronto quando você estiver", "folder":"Pasta", "location":"Local", "clear":"Limpar", "general":"Geral", "appearance":"Aparência", "about":"Sobre", "browserCompanion":"Extensão do navegador", "browserDetection":"Detecção no navegador", "floatingButton":"Botão flutuante", "installCompanion":"Instalar extensão", "setup":"Instalar", "downloads":"Downloads", "defaultQuality":"Qualidade padrão", "language":"Idioma", "interfaceLanguage":"Idioma da interface", "glassTheme":"Tema de vidro", "system":"Sistema", "followMac":"Seguir macOS", "stop":"Parar", "retry":"Tentar novamente", "show":"Mostrar", "completed":"Concluído", "failed":"Falhou", "stopped":"Parado", "downloading":"Baixando", "queued":"Aguardando", "reading":"Lendo", "convertingVideo":"Conversão por GPU", "convertingAudio":"Criando MP3"
    ]

    private static let ja: [String: String] = [
        "quickAdd":"クイック追加", "pasteMany":"1つまたは複数のリンクを貼り付け", "quality":"画質", "best":"最高", "type":"種類", "video":"動画", "audio":"音声", "active":"実行中", "waiting":"待機中", "done":"完了", "ready":"準備完了", "starting":"起動中", "downloadComplete":"ダウンロード完了", "open":"開く", "readyWhen":"いつでも開始できます", "folder":"フォルダ", "location":"保存先", "clear":"消去", "general":"一般", "appearance":"外観", "about":"情報", "browserCompanion":"ブラウザ拡張", "browserDetection":"ブラウザ検出", "floatingButton":"フローティングボタン", "installCompanion":"拡張機能をインストール", "setup":"設定", "downloads":"ダウンロード", "defaultQuality":"標準画質", "language":"言語", "interfaceLanguage":"表示言語", "glassTheme":"ガラステーマ", "system":"システム", "followMac":"macOSに従う", "stop":"停止", "retry":"再試行", "show":"表示", "completed":"完了", "failed":"失敗", "stopped":"停止済み", "downloading":"ダウンロード中", "queued":"待機中", "reading":"読み込み中", "convertingVideo":"GPUで変換中", "convertingAudio":"MP3を作成中"
    ]

    private static let ko: [String: String] = [
        "quickAdd":"빠른 추가", "pasteMany":"하나 이상의 링크 붙여넣기", "quality":"화질", "best":"최고", "type":"유형", "video":"비디오", "audio":"오디오", "active":"진행 중", "waiting":"대기", "done":"완료", "ready":"준비됨", "starting":"시작 중", "downloadComplete":"다운로드 완료", "open":"열기", "readyWhen":"언제든 준비되었습니다", "folder":"폴더", "location":"위치", "clear":"지우기", "general":"일반", "appearance":"모양", "about":"정보", "browserCompanion":"브라우저 확장", "browserDetection":"브라우저 감지", "floatingButton":"플로팅 다운로드 버튼", "installCompanion":"확장 프로그램 설치", "setup":"설정", "downloads":"다운로드", "defaultQuality":"기본 화질", "language":"언어", "interfaceLanguage":"인터페이스 언어", "glassTheme":"글래스 테마", "system":"시스템", "followMac":"macOS 따르기", "stop":"중지", "retry":"다시 시도", "show":"보기", "completed":"완료", "failed":"실패", "stopped":"중지됨", "downloading":"다운로드 중", "queued":"대기 중", "reading":"읽는 중", "convertingVideo":"GPU 변환 중", "convertingAudio":"MP3 생성 중"
    ]

    private static let translations: [String: [String: String]] = ["vi": vi, "zh": zh, "es": es, "fr": fr, "de": de, "pt": pt, "ja": ja, "ko": ko]
    private static let updaterTranslations: [String: [String: String]] = [
        "vi": ["supportTools":"Công cụ hỗ trợ", "supportToolsReady":"Bộ công cụ đã sẵn sàng", "supportToolsReadyDetail":"Tự động kiểm tra bản mới mỗi 24 giờ", "supportToolsNeeded":"Giữ bộ tải luôn mới", "supportToolsNeededDetail":"Bấm một lần, app tự làm mọi thứ", "installSupportTools":"Cài công cụ hỗ trợ", "updateSupportTools":"Cập nhật công cụ", "retrySupportTools":"Thử lại", "supportToolsChecking":"Đang kiểm tra phiên bản mới nhất…", "supportToolsDownloadingYtDlp":"Đang tải bộ máy tải video…", "supportToolsDownloadingFFmpeg":"Đang tải bộ xử lý media…", "supportToolsDownloadingFFprobe":"Đang tải bộ kiểm tra media…", "supportToolsVerifying":"Đang kiểm tra an toàn…", "supportToolsActivating":"Đang hoàn tất cài đặt…", "supportToolsFallback":"Nếu mạng lỗi, app vẫn dùng bộ dự phòng để tải."],
        "zh": ["supportTools":"支持工具", "supportToolsReady":"支持工具已就绪", "supportToolsReadyDetail":"每 24 小时自动检查更新", "supportToolsNeeded":"保持下载引擎最新", "supportToolsNeededDetail":"点击一次，应用自动完成全部设置", "installSupportTools":"安装支持工具", "updateSupportTools":"更新工具", "retrySupportTools":"重试", "supportToolsChecking":"正在检查最新版本…", "supportToolsDownloadingYtDlp":"正在下载视频引擎…", "supportToolsDownloadingFFmpeg":"正在下载媒体引擎…", "supportToolsDownloadingFFprobe":"正在下载媒体检查器…", "supportToolsVerifying":"正在验证安全性…", "supportToolsActivating":"正在完成设置…", "supportToolsFallback":"网络失败时，应用仍会使用内置备用工具。"],
        "ja": ["supportTools":"サポートツール", "supportToolsReady":"サポートツール準備完了", "supportToolsReadyDetail":"24時間ごとに更新を自動確認", "supportToolsNeeded":"ダウンロード機能を最新に保つ", "supportToolsNeededDetail":"一度押すだけでアプリが自動設定", "installSupportTools":"サポートツールをインストール", "updateSupportTools":"ツールを更新", "retrySupportTools":"再試行", "supportToolsChecking":"最新版を確認中…", "supportToolsDownloadingYtDlp":"動画エンジンをダウンロード中…", "supportToolsDownloadingFFmpeg":"メディアエンジンをダウンロード中…", "supportToolsDownloadingFFprobe":"メディア検査ツールをダウンロード中…", "supportToolsVerifying":"安全性を確認中…", "supportToolsActivating":"設定を完了中…", "supportToolsFallback":"通信に失敗しても内蔵ツールでダウンロードできます。"],
        "ko": ["supportTools":"지원 도구", "supportToolsReady":"지원 도구 준비 완료", "supportToolsReadyDetail":"24시간마다 업데이트 자동 확인", "supportToolsNeeded":"다운로드 엔진을 최신으로 유지", "supportToolsNeededDetail":"한 번만 누르면 앱이 자동으로 설정", "installSupportTools":"지원 도구 설치", "updateSupportTools":"도구 업데이트", "retrySupportTools":"다시 시도", "supportToolsChecking":"최신 버전 확인 중…", "supportToolsDownloadingYtDlp":"비디오 엔진 다운로드 중…", "supportToolsDownloadingFFmpeg":"미디어 엔진 다운로드 중…", "supportToolsDownloadingFFprobe":"미디어 검사기 다운로드 중…", "supportToolsVerifying":"안전성 확인 중…", "supportToolsActivating":"설정 완료 중…", "supportToolsFallback":"네트워크 오류 시에도 내장 도구로 다운로드할 수 있습니다."]
    ]
    private static let browserSessionTranslations: [String: [String: String]] = [
        "vi": [
            "browserSession":"Phiên đăng nhập trình duyệt",
            "browserSessionSub":"Dùng cookie cục bộ khi website yêu cầu xác minh",
            "cookiePolicy":"Cách sử dụng",
            "cookieSmart":"Tự động",
            "cookieAlways":"Luôn dùng",
            "cookieNever":"Không dùng",
            "cookieBrowser":"Trình duyệt",
            "cookieProfile":"Profile",
            "cookieProfileHint":"Để trống để dùng profile mặc định",
            "testSession":"Kiểm tra phiên",
            "advancedOptions":"Tùy chọn",
            "cookiePrivacy":"App không hiển thị, xuất hoặc tải cookie lên đám mây."
        ],
        "zh": [
            "browserSession":"浏览器登录会话",
            "browserSessionSub":"网站要求验证时使用本地 Cookie",
            "cookiePolicy":"使用方式",
            "cookieSmart":"智能",
            "cookieAlways":"始终使用",
            "cookieNever":"不使用",
            "cookieBrowser":"浏览器",
            "cookieProfile":"配置文件",
            "cookieProfileHint":"留空以使用默认配置文件",
            "testSession":"检查会话",
            "advancedOptions":"选项",
            "cookiePrivacy":"应用不会显示、导出或上传 Cookie。"
        ]
    ]
    private static let storageTranslations: [String: [String: String]] = [
        "vi": [
            "downloadLocation":"Thư mục tải xuống",
            "downloadLocationSub":"Nơi lưu video, âm thanh và ảnh đã tải",
            "currentLocation":"Vị trí hiện tại",
            "temporaryForSession":"Tạm thời cho phiên này",
            "temporaryDownloadFolder":"Chọn thư mục tải tạm thời",
            "downloadFolderUnavailable":"Thư mục tải mặc định hiện không tồn tại. Hãy chọn thư mục khác cho phiên app này. Vị trí mặc định của bạn sẽ không bị thay đổi.",
            "useForThisSession":"Dùng cho phiên này",
            "openFolder":"Mở thư mục",
            "changeLocation":"Đổi vị trí",
            "backgroundApp":"Ứng dụng menu bar",
            "backgroundAppDetail":"Chạy gọn trong thanh menu của Mac",
            "quitApp":"Thoát ứng dụng",
            "pasteAuto":"⌘V một hoặc nhiều link · tự động tải",
            "bulkLinkPlaceholder":"Dán link tại đây, mỗi dòng một link…",
            "defaultMediaType":"Loại nội dung mặc định",
            "defaultMediaTypeDetail":"Dùng khi dán link trong menu bar",
            "settingsTitle":"Cài đặt",
            "localConnection":"Kết nối nội bộ riêng tư",
            "generalSettingsSub":"Thư mục, mặc định tải và điều khiển ứng dụng nền",
            "downloadSettingsSub":"Định dạng, chất lượng và bộ máy tải xuống",
            "browserSettingsSub":"Tiện ích trình duyệt và phiên đăng nhập",
            "appearanceSettingsSub":"Ngôn ngữ và phong cách hiển thị của ứng dụng",
            "aboutSettingsSub":"Thông tin sản phẩm và quyền riêng tư",
            "localWorkflow":"Hoạt động nội bộ",
            "localWorkflowSub":"App và tiện ích chỉ giao tiếp trên máy Mac này",
            "localSyncDetail":"Không cần tài khoản hoặc kết nối đám mây",
            "backgroundReady":"Luôn sẵn sàng trong nền",
            "backgroundReadyDetail":"Bộ máy tải luôn sẵn sàng từ thanh menu",
            "downloadDefaults":"Mặc định tải xuống",
            "downloadEngine":"Bộ máy tải xuống",
            "downloadEngineSub":"Tự động duy trì khả năng hỗ trợ các website",
            "sessionNeedsAttention":"Phiên trình duyệt cần được xử lý",
            "sessionNeedsAttentionDetail":"Kiểm tra profile trình duyệt, đăng nhập lại rồi thử tải.",
            "repairSession":"Sửa phiên trình duyệt",
            "fixSession":"Sửa phiên",
            "session403Detail":"YouTube đã từ chối luồng video. Phiên trình duyệt hoặc yt-dlp có thể cần làm mới.",
            "sessionVerificationDetail":"YouTube yêu cầu đăng nhập hoặc xác minh trước khi tải video này.",
            "sessionDouyinFreshDetail":"Douyin cần cookie trình duyệt mới. Hãy mở Douyin một lần trong đúng trình duyệt đã chọn, rồi thử lại.",
            "sessionCookieDetail":"Không đọc được profile trình duyệt đã chọn. Hãy kiểm tra trình duyệt và profile bên dưới.",
            "checkingSession":"Đang kiểm tra phiên trình duyệt…",
            "openBrowser":"Mở trình duyệt",
            "later":"Để sau",
            "retryDownload":"Thử tải lại",
            "installChromeGuide":"Cài tiện ích Chrome",
            "installChromeGuideSub":"Hai bước nhanh, không cần dòng lệnh",
            "enableDeveloperMode":"Bật Chế độ nhà phát triển",
            "enableDeveloperModeDetail":"Dùng công tắc ở góc trên bên phải trang Extensions",
            "dragExtensionFolder":"Kéo thư mục tiện ích",
            "dragExtensionFolderDetail":"Kéo ChromeExtension từ Finder vào tab Extensions",
            "openAgain":"Mở lại Chrome và Finder",
            "gotIt":"Đã hiểu",
            "chromeDetail":"Bật Chế độ nhà phát triển, rồi kéo thư mục đi kèm vào trang Extensions"
        ],
        "zh": [
            "downloadLocation":"下载位置",
            "downloadLocationSub":"保存已下载的视频、音频和图片",
            "currentLocation":"当前位置",
            "temporaryForSession":"仅用于本次会话",
            "temporaryDownloadFolder":"选择临时下载文件夹",
            "downloadFolderUnavailable":"默认下载文件夹当前不可用。请为本次应用会话选择其他文件夹。默认位置不会更改。",
            "useForThisSession":"本次会话使用",
            "openFolder":"打开文件夹",
            "changeLocation":"更改位置",
            "backgroundApp":"菜单栏应用",
            "backgroundAppDetail":"在 Mac 菜单栏中安静运行",
            "quitApp":"退出应用",
            "pasteAuto":"⌘V 粘贴一个或多个链接并自动下载",
            "bulkLinkPlaceholder":"在此粘贴链接，每行一个…",
            "defaultMediaType":"默认媒体类型",
            "defaultMediaTypeDetail":"用于菜单栏中粘贴的链接",
            "settingsTitle":"设置",
            "localConnection":"私密本地连接",
            "generalSettingsSub":"存储位置、下载默认设置和后台应用控制",
            "downloadSettingsSub":"默认格式、画质和下载引擎",
            "browserSettingsSub":"浏览器助手和登录会话",
            "appearanceSettingsSub":"应用语言和视觉风格",
            "aboutSettingsSub":"产品信息和隐私",
            "localWorkflow":"本地工作流程",
            "localWorkflowSub":"应用和助手仅在此 Mac 上通信",
            "localSyncDetail":"无需账户或云连接",
            "backgroundReady":"后台随时就绪",
            "backgroundReadyDetail":"可随时从菜单栏使用下载引擎",
            "downloadDefaults":"下载默认设置",
            "downloadEngine":"下载引擎",
            "downloadEngineSub":"自动保持网站支持能力",
            "sessionNeedsAttention":"YouTube 会话需要处理",
            "sessionNeedsAttentionDetail":"检查浏览器配置文件，重新登录后重试。",
            "repairSession":"修复浏览器会话",
            "fixSession":"修复会话",
            "session403Detail":"YouTube 拒绝了视频流。浏览器会话或 yt-dlp 可能需要刷新。",
            "sessionVerificationDetail":"下载此视频前，YouTube 要求登录或验证。",
            "sessionCookieDetail":"无法读取所选浏览器配置文件。请检查下面的浏览器和配置文件。",
            "checkingSession":"正在检查浏览器会话…",
            "openBrowser":"打开浏览器",
            "later":"稍后",
            "retryDownload":"重新尝试下载",
            "installChromeGuide":"安装 Chrome 助手",
            "installChromeGuideSub":"只需两步，无需命令行",
            "enableDeveloperMode":"开启开发者模式",
            "enableDeveloperModeDetail":"使用扩展程序页面右上角的开关",
            "dragExtensionFolder":"拖动扩展文件夹",
            "dragExtensionFolderDetail":"将 Finder 中的 ChromeExtension 拖到扩展程序标签页",
            "openAgain":"重新打开 Chrome 和 Finder",
            "gotIt":"知道了",
            "chromeDetail":"开启开发者模式，然后将附带文件夹拖入扩展程序页面"
        ]
    ]
    private static let historyTranslations: [String: [String: String]] = [
        "vi": ["downloadHistory":"Lịch sử tải", "clearHistory":"Xóa lịch sử", "historyEmpty":"Chưa có nội dung đã tải", "historyEmptyHint":"Video, âm thanh và ảnh hoàn tất sẽ xuất hiện tại đây.", "fileReady":"Còn file", "fileMissing":"File đã bị xóa", "showInFinder":"Mở thư mục", "redownload":"Tải lại", "deleteHistoryItem":"Xóa khỏi lịch sử", "delete":"Xóa"],
        "zh": ["downloadHistory":"下载历史", "clearHistory":"清除历史", "historyEmpty":"暂无下载", "historyEmptyHint":"已完成的媒体会显示在这里。", "fileReady":"文件可用", "fileMissing":"文件已删除", "showInFinder":"在访达中显示", "redownload":"重新下载", "deleteHistoryItem":"从历史中删除", "delete":"删除"],
        "es": ["downloadHistory":"Historial de descargas", "clearHistory":"Borrar historial", "historyEmpty":"Sin descargas", "historyEmptyHint":"Los archivos completados aparecerán aquí.", "fileReady":"Disponible", "fileMissing":"Archivo eliminado", "showInFinder":"Mostrar en Finder", "redownload":"Descargar de nuevo", "deleteHistoryItem":"Quitar del historial", "delete":"Eliminar"],
        "fr": ["downloadHistory":"Historique", "clearHistory":"Effacer l’historique", "historyEmpty":"Aucun téléchargement", "historyEmptyHint":"Les médias terminés apparaîtront ici.", "fileReady":"Disponible", "fileMissing":"Fichier supprimé", "showInFinder":"Afficher dans Finder", "redownload":"Retélécharger", "deleteHistoryItem":"Retirer de l’historique", "delete":"Supprimer"],
        "de": ["downloadHistory":"Downloadverlauf", "clearHistory":"Verlauf löschen", "historyEmpty":"Keine Downloads", "historyEmptyHint":"Abgeschlossene Medien erscheinen hier.", "fileReady":"Verfügbar", "fileMissing":"Datei gelöscht", "showInFinder":"Im Finder zeigen", "redownload":"Erneut laden", "deleteHistoryItem":"Aus Verlauf entfernen", "delete":"Löschen"],
        "pt": ["downloadHistory":"Histórico de downloads", "clearHistory":"Limpar histórico", "historyEmpty":"Nenhum download", "historyEmptyHint":"As mídias concluídas aparecerão aqui.", "fileReady":"Disponível", "fileMissing":"Arquivo excluído", "showInFinder":"Mostrar no Finder", "redownload":"Baixar novamente", "deleteHistoryItem":"Remover do histórico", "delete":"Excluir"],
        "ja": ["downloadHistory":"ダウンロード履歴", "clearHistory":"履歴を消去", "historyEmpty":"ダウンロードはありません", "historyEmptyHint":"完了したメディアがここに表示されます。", "fileReady":"利用可能", "fileMissing":"ファイル削除済み", "showInFinder":"Finderで表示", "redownload":"再ダウンロード", "deleteHistoryItem":"履歴から削除", "delete":"削除"],
        "ko": ["downloadHistory":"다운로드 기록", "clearHistory":"기록 지우기", "historyEmpty":"다운로드 없음", "historyEmptyHint":"완료된 미디어가 여기에 표시됩니다.", "fileReady":"사용 가능", "fileMissing":"파일 삭제됨", "showInFinder":"Finder에서 보기", "redownload":"다시 다운로드", "deleteHistoryItem":"기록에서 삭제", "delete":"삭제"]
    ]
    private static let mediaToolTranslations: [String: [String: String]] = [
        "vi": [
            "videoCutter":"Cắt video",
            "videoCutterSub":"Chia video thành các đoạn gọn, dễ tái sử dụng",
            "sourceVideo":"Video nguồn",
            "sourceVideos":"Video nguồn",
            "dropVideos":"Kéo một hoặc nhiều video vào đây",
            "dropVideosDetail":"Kéo video từ Finder hoặc chọn bên dưới. App sẽ cắt tuần tự từng video.",
            "chooseVideo":"Chọn video",
            "replaceVideo":"Đổi video",
            "chooseVideos":"Chọn video",
            "addVideos":"Thêm video",
            "batchVideoCount":"%d video sẽ được cắt lần lượt",
            "cutSettings":"Thiết lập cắt",
            "segmentDuration":"Thời lượng mỗi đoạn",
            "seconds":"giây",
            "cutMode":"Chế độ cắt",
            "fastCut":"Nhanh · giữ nguyên chất lượng",
            "preciseCut":"Chính xác · GPU Apple",
            "fastCutDetail":"Rất nhanh; điểm cắt đi theo keyframe của video nguồn.",
            "preciseCutDetail":"Cắt đúng thời gian bằng bộ mã hóa H.264 VideoToolbox.",
            "segmentArrangement":"Sắp xếp đoạn",
            "sequentialCut":"Cắt theo thứ tự",
            "creativeRandomSegments":"Đảo đoạn ngẫu nhiên",
            "randomSourceMix":"Trộn nguồn ngẫu nhiên",
            "sequentialCutDetail":"Với batch: A1 → B1 → C1 → A2. A–Z là video nguồn.",
            "creativeRandomSegmentsDetail":"Xáo các đoạn của từng video trước, rồi xếp vòng A → B → C trong timeline chung.",
            "randomSourceMixDetail":"Xáo đoạn và nguồn; tránh lặp cùng nguồn liên tiếp khi còn lựa chọn khác.",
            "outputName":"Tên file xuất",
            "outputNameHint":"App tự thêm số 0001 và chữ A–Z.",
            "beforeNumber":"Tên trước",
            "outputFolder":"Thư mục xuất",
            "batchOutputRoot":"Thư mục xuất chung",
            "batchNameHint":"Tất cả đoạn nằm trong một thư mục. A–Z là video nguồn; batch luân phiên một đoạn từ mỗi video.",
            "autoMixedFolder":"Tự tạo mixed_N",
            "chooseOutputFolder":"Chọn thư mục",
            "notSelected":"Chưa chọn",
            "choose":"Chọn",
            "startCutting":"Bắt đầu cắt",
            "mediaConverter":"Chuyển đổi",
            "mediaConverterSub":"Chuyển video, âm thanh và ảnh bằng các cấu hình tối ưu",
            "sourceFiles":"File nguồn",
            "chooseOneOrMore":"Chọn một hoặc nhiều file media. File xuất được lưu cạnh file nguồn.",
            "addFiles":"Thêm file",
            "conversionPreset":"Kiểu chuyển đổi",
            "videoMP4Preset":"Video → MP4 H.264 · GPU Apple",
            "audioMP3Preset":"Âm thanh → MP3 · 320 kbps",
            "imageJPGPreset":"Ảnh → JPG · Chất lượng cao",
            "imagePNGPreset":"Ảnh → PNG · Lossless",
            "startConverting":"Bắt đầu chuyển đổi",
            "audioMastering":"Chỉnh âm",
            "audioMasteringSub":"Cân bằng âm lượng giọng nói nhưng vẫn giữ chất âm gốc",
            "sourceMedia":"Audio hoặc video nguồn",
            "audioSourceHint":"Chọn file audio hoặc video có chứa luồng âm thanh.",
            "chooseFile":"Chọn file",
            "replaceFile":"Đổi file",
            "masteringChain":"Chuỗi xử lý âm thanh",
            "softGate":"Gate mềm giảm nhẹ hơi thở và tạp âm",
            "youtubeLoudness":"Chuẩn hóa âm lượng gần −14 LUFS",
            "truePeak":"Giới hạn True Peak ở −1.5 dBTP",
            "preserveVoice":"Không EQ, denoise hoặc nén mạnh",
            "trashOriginalAudio":"Đưa audio gốc vào Thùng rác sau khi xong",
            "trashOriginalAudioDetail":"Chỉ áp dụng với file chỉ có audio; video nguồn luôn được giữ lại.",
            "startMastering":"Bắt đầu chỉnh âm",
            "error":"Lỗi"
        ],
        "zh": [
            "videoCutter":"视频切割",
            "mediaConverter":"媒体转换",
            "audioMastering":"音频母带",
            "choose":"选择",
            "notSelected":"未选择",
            "seconds":"秒",
            "error":"错误"
        ]
    ]
    private static let finderQuickActionTranslations: [String: [String: String]] = [
        "vi": [
            "finderQuickActions":"Tác vụ nhanh Finder",
            "finderQuickActionsSub":"Gửi file đang chọn trong Finder thẳng vào công cụ media của app",
            "finderQuickActionsDetail":"Bấm chuột phải file được hỗ trợ và mở đúng công cụ VidSavie",
            "quickCutVideo":"Cắt video",
            "quickCutVideoDetail":"Dùng cho file video",
            "quickConvert":"Chuyển đổi media",
            "quickConvertDetail":"Dùng cho video, audio và ảnh",
            "quickMasterAudio":"Chỉnh âm",
            "quickMasterAudioDetail":"Dùng cho file audio và video",
            "enableFinderActions":"Bật trong Finder",
            "enableFinderActionsDetail":"macOS cần bạn cấp quyền thủ công một lần cho các dịch vụ chuột phải",
            "quickActionsIncluded":"Tác vụ nhanh đã được tích hợp trong app",
            "quickActionsApproval":"Bấm Cài đặt → Services → bung Files and Folders, bật ba dịch vụ VidSavie rồi dùng menu chuột phải của Finder.",
            "finderGuideTitle":"Bật tác vụ nhanh Finder",
            "finderGuideSub":"Chỉ cấp quyền macOS một lần, sau đó dùng công cụ từ mọi cửa sổ Finder",
            "openServicesList":"Bấm Phím tắt bàn phím… → Dịch vụ",
            "openServicesListDetail":"Cài đặt hệ thống mở trang Bàn phím. Bấm Phím tắt bàn phím…, rồi chọn Dịch vụ ở cột trái.",
            "expandFilesFolders":"Bung Tệp và thư mục",
            "expandFilesFoldersDetail":"Bấm mũi tên cạnh Tệp và thư mục để hiện các hàng dịch vụ bên trong.",
            "enableBatchActions":"Bật ba tác vụ VidSavie",
            "enableBatchActionsDetail":"Tick Cắt video, Chuyển đổi và Chỉnh âm. Sau đó bấm chuột phải file trong Finder → Tác vụ nhanh hoặc Dịch vụ.",
            "openSystemSettings":"Mở Bàn phím",
            "openFinder":"Mở Finder"
        ],
        "zh": [
            "finderQuickActions":"Finder 快速操作",
            "finderQuickActionsSub":"将 Finder 中选中的文件直接发送到媒体工具",
            "quickCutVideo":"剪切视频",
            "quickConvert":"转换媒体",
            "quickMasterAudio":"音频处理",
            "enableFinderActions":"在 Finder 中启用",
            "openServicesList":"打开服务 → 文件与文件夹",
            "enableBatchActions":"启用三个 VidSavie 操作",
            "openSystemSettings":"打开系统设置",
            "openFinder":"打开 Finder"
        ]
    ]
    private static let linkActionTranslations: [String: [String: String]] = [
        "vi": ["copyLink":"Chép link", "linkCopied":"Đã chép", "copyError":"Chép lỗi", "errorCopied":"Đã chép lỗi", "continueDownload":"Tiếp tục", "douyinDirectSourceUnavailable":"Nút nổi không lấy được nguồn trực tiếp đã xác minh cho video Douyin này. Luồng yt-dlp dự phòng:"],
        "zh": ["copyLink":"复制链接", "linkCopied":"已复制", "copyError":"复制错误", "errorCopied":"错误已复制", "continueDownload":"继续", "douyinDirectSourceUnavailable":"悬浮按钮未能获取此抖音视频的已验证直连地址。yt-dlp 备用路径："],
        "es": ["copyLink":"Copiar enlace", "linkCopied":"Copiado", "copyError":"Copiar error", "errorCopied":"Error copiado", "continueDownload":"Continuar"],
        "fr": ["copyLink":"Copier le lien", "linkCopied":"Copié", "copyError":"Copier l’erreur", "errorCopied":"Erreur copiée", "continueDownload":"Continuer"],
        "de": ["copyLink":"Link kopieren", "linkCopied":"Kopiert", "copyError":"Fehler kopieren", "errorCopied":"Fehler kopiert", "continueDownload":"Fortsetzen"],
        "pt": ["copyLink":"Copiar link", "linkCopied":"Copiado", "copyError":"Copiar erro", "errorCopied":"Erro copiado", "continueDownload":"Continuar"],
        "ja": ["copyLink":"リンクをコピー", "linkCopied":"コピー済み", "copyError":"エラーをコピー", "errorCopied":"エラーをコピー済み", "continueDownload":"再開", "douyinDirectSourceUnavailable":"フローティングボタンはこのDouyin動画の確認済み直接URLを取得できませんでした。yt-dlpの代替処理："],
        "ko": ["copyLink":"링크 복사", "linkCopied":"복사됨", "copyError":"오류 복사", "errorCopied":"오류 복사됨", "continueDownload":"계속", "douyinDirectSourceUnavailable":"플로팅 버튼이 이 Douyin 영상의 확인된 직접 주소를 찾지 못했습니다. yt-dlp 대체 경로:"]
    ]

    static func resolvedLanguage(_ setting: String) -> String {
        if setting != "auto" { return setting }
        return Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "en"
    }

    static func value(_ key: String, language: String, fallback: String) -> String {
        let code = resolvedLanguage(language)
        if key == "supportToolsDownloadingMediaSource" { return mediaSourceTranslations[code] ?? fallback }
        return linkActionTranslations[code]?[key]
            ?? finderQuickActionTranslations[code]?[key]
            ?? mediaToolTranslations[code]?[key]
            ?? historyTranslations[code]?[key]
            ?? storageTranslations[code]?[key]
            ?? updaterTranslations[code]?[key]
            ?? browserSessionTranslations[code]?[key]
            ?? translations[code]?[key]
            ?? fallback
    }
}
