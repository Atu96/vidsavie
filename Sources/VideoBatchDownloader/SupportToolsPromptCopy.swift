import Foundation

enum SupportToolsPromptCopy {
    static func text(language: String) -> (title: String, detail: String, later: String) {
        let resolved = language == "auto" ? String((Locale.preferredLanguages.first ?? "en").prefix(2)) : language
        switch resolved {
        case "vi": return ("Có bản cập nhật công cụ", "Bạn có thể cập nhật công cụ tải và xử lý media. App vẫn dùng được với bộ công cụ hiện có.", "Để sau")
        case "zh": return ("工具有可用更新", "可以更新下载和媒体处理工具。当前工具仍可使用。", "稍后")
        case "es": return ("Actualización de herramientas disponible", "Puedes actualizar las herramientas de descarga y multimedia. Las actuales siguen funcionando.", "Más tarde")
        case "fr": return ("Mise à jour des outils disponible", "Vous pouvez mettre à jour les outils de téléchargement et multimédia. Les outils actuels restent utilisables.", "Plus tard")
        case "de": return ("Werkzeug-Update verfügbar", "Die Download- und Medienwerkzeuge können aktualisiert werden. Die vorhandenen Werkzeuge bleiben nutzbar.", "Später")
        case "pt": return ("Atualização de ferramentas disponível", "Você pode atualizar as ferramentas de download e mídia. As atuais continuam disponíveis.", "Mais tarde")
        case "ja": return ("ツールの更新があります", "ダウンロード・メディア処理ツールを更新できます。現在のツールも引き続き使えます。", "後で")
        case "ko": return ("도구 업데이트 사용 가능", "다운로드 및 미디어 처리 도구를 업데이트할 수 있습니다. 현재 도구도 계속 사용할 수 있습니다.", "나중에")
        default: return ("Support tools update available", "You can update the download and media tools. The app can still use the tools you already have.", "Later")
        }
    }
}
