import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Config.loaded && (Config.calendar.enabled ?? true) ? Config.screensFor(Config.calendar.monitor) : []

        CalendarWidget {}
    }

    Variants {
        model: Config.loaded && (Config.coolercontrol.enabled ?? true) ? Config.screensFor(Config.coolercontrol.monitor) : []

        CoolerWidget {}
    }

    Variants {
        model: Config.loaded && (Config.data.overview?.enabled ?? true) ? Quickshell.screens : []

        Overview {}
    }
}
