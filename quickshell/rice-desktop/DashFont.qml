pragma Singleton
import Quickshell
import QtQuick

// Fonts of the dashboard: your interface font (Google Sans Flex by default) for text, Material Symbols for icons
// when installed (rice-fonts downloads both), otherwise Nerd Font icons.
Singleton {
    readonly property bool symbols: Fonts.symbols
    readonly property string sans: Fonts.main
    readonly property string nerd: Fonts.icons
}
