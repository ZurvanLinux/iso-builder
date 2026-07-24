import QtQuick 2.2
import QtQuick.Controls 2.2

Presentation
{
    id: presentation
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: presentation.nextSlide();
    }

    Slide {
        title: "Welcome to Zurvan Linux"
        content: "A Persian-first, KDE Plasma-powered desktop experience built on Debian Stable."
    }
    Slide {
        title: "RTL & Persian Localization"
        content: "Full Jalali calendar support, Vazirmatn typography, and ISIRI 9147 keyboard layout out of the box."
    }
    Slide {
        title: "Modern & Fast"
        content: "Powered by KDE Plasma 6 on Wayland with multimedia codecs and hardware firmware pre-configured."
    }
}
