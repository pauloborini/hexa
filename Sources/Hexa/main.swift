// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit

Defaults.register()
HexaTheme.registerFonts()

#if HEXA_DEVELOPMENT
if CommandLine.arguments.contains("--settings-presentation-test") {
    SettingsPresentationProbe.runAndExit()
}
if CommandLine.arguments.contains("--notch-presentation-test") {
    NotchPresentationProbe.runAndExit()
}
#endif

if CommandLine.arguments.contains("--selftest") {
    SelfTest.runAndExit()
}
if CommandLine.arguments.contains("--sensors") {
    SensorDump.runAndExit()
}
// Same cleanup as Ajustes > Avançado > Desinstalar, without the bundle's
// move to the Trash. Run from the installed bundle before removing it:
// `/Applications/hexa.app/Contents/MacOS/Hexa --uninstall`.
if CommandLine.arguments.contains("--uninstall") {
    Uninstaller.runAndExit()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
