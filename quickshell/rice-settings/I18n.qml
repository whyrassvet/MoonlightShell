pragma Singleton
import Quickshell
import QtQuick

// The language of Settings (Settings > System > Languages). I18n.t("English text") gives the text in the chosen
// language, or the English text when there is no translation yet. The words are in I18nData.qml.
Singleton {
    id: i18n
    // "en" or one of the codes below
    readonly property string lang: Prefs.lang
    readonly property var table: I18nData.d[lang] || ({})
    readonly property int count: Object.keys(table).length
    // dates in the chosen language
    readonly property var loc: Qt.locale(lang === "en" ? "en_US" : lang.replace("-", "_"))

    // [code, name in its own language, name in English]
    readonly property var langs: [
        ["en", "English", "English"], ["pl", "Polski", "Polish"], ["pt-BR", "Português (Brasil)", "Portuguese (Brazil)"],
        ["es", "Español", "Spanish"], ["fr", "Français", "French"], ["de", "Deutsch", "German"],
        ["it", "Italiano", "Italian"], ["nl", "Nederlands", "Dutch"], ["ru", "Русский", "Russian"],
        ["uk", "Українська", "Ukrainian"], ["tr", "Türkçe", "Turkish"], ["cs", "Čeština", "Czech"],
        ["sv", "Svenska", "Swedish"], ["ro", "Română", "Romanian"], ["hu", "Magyar", "Hungarian"],
        ["ja", "日本語", "Japanese"], ["ko", "한국어", "Korean"], ["zh-CN", "简体中文", "Chinese (Simplified)"],
        ["id", "Bahasa Indonesia", "Indonesian"], ["vi", "Tiếng Việt", "Vietnamese"]
    ]
    function nameOf(code) {
        for (let k = 0; k < langs.length; k++) if (langs[k][0] === code) return langs[k][1]
        return "English"
    }
    // text in the chosen language; "%1" in the text is replaced by a
    function t(s, a, b) {
        const v = table[s]
        let r = v !== undefined ? v : s
        if (a !== undefined) r = r.replace("%1", a)
        if (b !== undefined) r = r.replace("%2", b)
        return r
    }
}
