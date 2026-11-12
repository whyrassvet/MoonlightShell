pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Settings window preferences kept in ~/.config/rice/settings-app.json (Home > Settings).
// Prefs.scroll: how fast the pages scroll with the wheel or the touchpad (1 = 120 px a notch; the default is 1.8,
// 1 felt slow).
Singleton {
    id: prefs
    property real scroll: 1.8
    // the language of Settings (Settings > System > Languages): "en", "pl", "pt-BR" ...
    property string lang: "en"
    function setLang(v) { lang = v; save("lang", v) }
    // the live pictures at the top of some pages (Home > Settings > Previews); off by default
    property bool previews: false
    // how Settings moves (Settings > Motion): expressive = a little spring, standard = calm curves; speed 0.5 .. 2
    property string motion: "expressive"
    property real motionSpeed: 1.0
    function setMotion(v) { motion = v; save("motion", v) }
    function setMotionSpeed(v) { motionSpeed = Math.max(0.5, Math.min(2, Math.round(v * 20) / 20)); save("motionSpeed", motionSpeed) }
    function setPreviews(v) { previews = v; save("previews", v) }
    // Appearance > Fonts > Typography
    property real textScale: 1.0          // 0.85 .. 1.3
    property bool emphHeadings: false     // titles one step heavier
    property bool roundText: false        // Google Sans Flex with round letter ends (ROND axis)
    function setTextScale(v) { textScale = Math.max(0.85, Math.min(1.3, Math.round(v * 20) / 20)); save("textScale", textScale) }
    function setEmphHeadings(v) { emphHeadings = v; save("emphHeadings", v) }
    function setRoundText(v) { roundText = v; save("roundText", v) }
    // Appearance > Components
    property bool switchIcons: true       // check / cross in the switch handle
    property real sliderThick: 1.0        // 0.6 .. 1.6 times the normal track
    property bool wavy: true              // progress shown as a wave (sliders while dragging, loaders, music)
    property int progressThick: 4         // 2 .. 8 px
    property string shape: "round"        // (older setting, kept for reading old files)
    property real cornerScale: 1.0        // Appearance > Shapes > Corners: 0.3 .. 1.5 times the normal corners
    property string accentShape: "verysunny"   // Appearance > Shapes: the shape of the avatar, the hero and highlights
    property real bounce: 1.0             // Motion > Bounce: 0 = no overshoot, 2 = twice as bouncy
    function setCornerScale(v) { cornerScale = Math.max(0.3, Math.min(1.5, Math.round(v * 20) / 20)); save("cornerScale", cornerScale) }
    function setAccentShape(v) { accentShape = v; save("accentShape", v) }
    function setBounce(v) { bounce = Math.max(0, Math.min(2, Math.round(v * 10) / 10)); save("bounce", bounce) }
    function setSwitchIcons(v) { switchIcons = v; save("switchIcons", v) }
    function setSliderThick(v) { sliderThick = Math.max(0.6, Math.min(1.6, Math.round(v * 10) / 10)); save("sliderThick", sliderThick) }
    function setWavy(v) { wavy = v; save("wavy", v) }
    function setProgressThick(v) { progressThick = Math.max(2, Math.min(8, Math.round(v))); save("progressThick", progressThick) }
    function setShape(v) { shape = v; save("shape", v) }
    readonly property real wheel: 1.0 * scroll       // pixels per wheel unit on a page (one notch: 120 px at 1x)
    // size of the Settings window: 1 = the default size, 0.75 smaller, 1.5 bigger
    property real size: 1.0
    // the Settings window in pixels on a screen of sw x sh at size k (the window and the preview use the same formula)
    function winW(sw, k) { return Math.min(sw - 20, Math.round(Math.max(Math.min(1000, sw - 40), Math.min(1180, Math.round(sw * 0.6))) * k)) }
    function winH(sh, k) { return Math.min(sh - 40, Math.round(Math.max(Math.min(680, sh - 60), Math.min(820, Math.round(sh * 0.74))) * k)) }
    function setSize(v) {
        size = Math.max(0.75, Math.min(1.5, Math.round(v * 20) / 20))
        save("size", size)
    }

    function save(key, value) {
        Quickshell.execDetached(["python3", "-c",
            "import json,os,sys\np=os.path.expanduser('~/.config/rice/settings-app.json')\n" +
            "try: d=json.load(open(p))\nexcept Exception: d={}\nd[sys.argv[1]]=json.loads(sys.argv[2])\n" +
            "os.makedirs(os.path.dirname(p),exist_ok=True)\njson.dump(d,open(p,'w'))",
            key, JSON.stringify(value)])
    }
    function setScroll(v) {
        scroll = Math.max(0.3, Math.min(3, Math.round(v * 20) / 20))
        save("scroll", scroll)
    }
    Process {
        command: ["bash", "-c", "cat \"$HOME/.config/rice/settings-app.json\" 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    if (typeof j.lang === "string" && /^[a-zA-Z-]{2,6}$/.test(j.lang)) prefs.lang = j.lang
                    if (j.scroll !== undefined) prefs.scroll = Math.max(0.3, Math.min(3, Number(j.scroll)))
                    if (j.previews !== undefined) prefs.previews = j.previews === true
                    if (j.motion === "standard" || j.motion === "expressive") prefs.motion = j.motion
                    if (j.motionSpeed !== undefined) prefs.motionSpeed = Math.max(0.5, Math.min(2, Number(j.motionSpeed)))
                    if (j.textScale !== undefined) prefs.textScale = Math.max(0.85, Math.min(1.3, Number(j.textScale)))
                    if (j.emphHeadings !== undefined) prefs.emphHeadings = j.emphHeadings === true
                    if (j.roundText !== undefined) prefs.roundText = j.roundText === true
                    if (j.switchIcons !== undefined) prefs.switchIcons = j.switchIcons !== false
                    if (j.sliderThick !== undefined) prefs.sliderThick = Math.max(0.6, Math.min(1.6, Number(j.sliderThick)))
                    if (j.wavy !== undefined) prefs.wavy = j.wavy !== false
                    if (j.progressThick !== undefined) prefs.progressThick = Math.max(2, Math.min(8, Number(j.progressThick)))
                    if (["round", "soft", "square"].indexOf(j.shape) >= 0) { prefs.shape = j.shape; if (j.cornerScale === undefined) prefs.cornerScale = j.shape === "square" ? 0.4 : (j.shape === "soft" ? 0.7 : 1) }
                    if (j.cornerScale !== undefined) prefs.cornerScale = Math.max(0.3, Math.min(1.5, Number(j.cornerScale)))
                    if (typeof j.accentShape === "string" && j.accentShape !== "") prefs.accentShape = j.accentShape
                    if (j.bounce !== undefined) prefs.bounce = Math.max(0, Math.min(2, Number(j.bounce)))
                    if (j.size !== undefined) prefs.size = Math.max(0.75, Math.min(1.5, Number(j.size)))
                } catch (e) { }
            }
        }
    }
}
