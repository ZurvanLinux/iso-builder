/*
 * Zurvan OS KSplash — session-start splash.
 *
 * NOTE: the QtQuick import is version-pinned (2.15). A versionless
 * `import QtQuick` makes ksplashqml segfault on older Qt5 builds
 * (catppuccin/kde#80); 2.15 is valid on both Qt5 and Qt6, so this is
 * crash-safe across the supported Plasma runtimes.
 */
import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    // Brand void colour — matches the image edges so there are no black seams
    // if the screen aspect differs from 16:9.
    color: "#0F172A"

    Image {
        anchors.fill: parent
        source: "images/zurvan.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
