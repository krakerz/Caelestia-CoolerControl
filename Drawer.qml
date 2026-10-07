import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A Caelestia-style drawer: grows out of the screen frame on one edge, filleted into it.
// Hovering the frame edge opens it unless mode is "always", it's pinned, or opened via IPC.
// Full-screen window; the input mask limits interaction to the trigger strip and the panel.
PanelWindow {
    id: root

    required property var modelData
    required property var cfg
    required property string ns // also the config section name
    default property alias content: body.data
    property bool holdOpen: false // e.g. while editing
    property bool keyboard: false

    // position: top | bottom | left | right (centred on that edge) or a corner (top-left, ...).
    readonly property string position: cfg.position ?? "top-left"
    readonly property string edge: position.startsWith("bottom") ? "bottom" : position.startsWith("top") ? "top" : position
    readonly property bool vertical: edge === "left" || edge === "right" // panel grows sideways
    readonly property string align: position.endsWith("left") && !vertical ? "start" : position.endsWith("right") && !vertical ? "end" : "center"

    // Caelestia frame: bar on the left, thin border elsewhere.
    readonly property var frame: Config.theme.frame ?? ({})
    readonly property int thick: frame.thickness ?? 10
    // Over a fullscreen app Caelestia hides its frame, so the panel floats as a plain card instead.
    readonly property bool floating: fullscreen
    readonly property int gap: cfg.fullscreenMargin ?? 10
    readonly property int inL: floating ? gap : frame.barWidth ?? 60
    readonly property int inT: floating ? gap : thick
    readonly property int inR: floating ? gap : thick
    readonly property int inB: floating ? gap : thick
    readonly property real edgeInset: ({
            top: inT,
            bottom: inB,
            left: inL,
            right: inR
        })[edge] ?? inT

    // The window's own width/height don't track the anchored size, so use the screen's.
    readonly property real sw: modelData.width
    readonly property real sh: modelData.height
    readonly property real panelW: cfg.width ?? 360
    readonly property real contentH: body.implicitHeight + Theme.padding * 2
    readonly property real along: vertical ? contentH : panelW // panel length along the edge
    readonly property real depthFull: vertical ? panelW : contentH
    readonly property real depth: depthFull * progress

    // Span of the inner frame along the edge, and the panel's start on it (x/y nudge, clamped).
    readonly property real spanStart: vertical ? inT : inL
    readonly property real spanEnd: vertical ? sh - inB : sw - inR
    readonly property real nudge: vertical ? (cfg.y ?? 0) : (cfg.x ?? 0)
    readonly property real start: {
        const base = align === "start" ? spanStart : align === "end" ? spanEnd - along : (spanStart + spanEnd - along) / 2;
        return Math.max(spanStart, Math.min(spanEnd - along, base + nudge));
    }
    readonly property bool flushStart: start <= spanStart + 0.5
    readonly property bool flushEnd: start + along >= spanEnd - 0.5
    readonly property real r: Math.min(Theme.panelRounding, depth / 2, along / 2)

    readonly property bool pinned: cfg.pinned ?? false
    readonly property bool ipcOpen: Ipc.opened[ns] ?? false
    // Overlay sits above fullscreen apps, so stay out of the way there unless opened explicitly via IPC.
    readonly property bool fullscreen: Hyprland.monitorFor(modelData)?.activeWorkspace?.lastIpcObject?.hasfullscreen ?? false
    readonly property bool suppressed: fullscreen && !ipcOpen && (cfg.hideOnFullscreen ?? true)
    readonly property bool open: ipcOpen || (!suppressed && ((cfg.mode ?? "hover") === "always" || pinned || holdOpen || hover.hovered || closeDelay.running))
    property real progress: open ? 1 : 0

    // Maps edge-local (u along the edge, v depth into the screen) to screen coordinates.
    function pt(u, v) {
        switch (edge) {
        case "bottom":
            return [u, sh - inB - v];
        case "left":
            return [inL + v, u];
        case "right":
            return [sw - inR - v, u];
        default:
            return [u, inT + v];
        }
    }

    // Panel outline drawn as for the top edge; bottom/left are mirror images, so arc sweeps flip.
    // Sides touching the frame bleed `b` px into it (same colour) so anti-aliased edges never sit over windows.
    readonly property string path: {
        const u0 = start, u1 = start + along, h = depth, rr = r, b = 2;
        const flip = edge === "bottom" || edge === "left";
        const M = (u, v) => `M ${pt(u, v).join(" ")} `;
        const L = (u, v) => `L ${pt(u, v).join(" ")} `;
        const A = (u, v, sweep) => `A ${rr} ${rr} 0 0 ${flip ? 1 - sweep : sweep} ${pt(u, v).join(" ")} `;
        if (floating)
            return M(u0 + rr, 0) + L(u1 - rr, 0) + A(u1, rr, 1) + L(u1, h - rr) + A(u1 - rr, h, 1) + L(u0 + rr, h) + A(u0, h - rr, 1) + L(u0, rr) + A(u0 + rr, 0, 1) + "Z";
        let p = flushStart ? M(u0 - b, -b) : M(u0 - rr, -b);
        if (flushEnd)
            p += L(u1 + b, -b) + L(u1 + b, h + rr) + L(u1, h + rr) + A(u1 - rr, h, 0);
        else
            p += L(u1 + rr, -b) + L(u1 + rr, 0) + A(u1, rr, 0) + L(u1, h - rr) + A(u1 - rr, h, 1);
        p += L(u0 + rr, h);
        if (flushStart)
            p += A(u0, h + rr, 0) + L(u0 - b, h + rr);
        else
            p += A(u0, h - rr, 1) + L(u0, rr) + A(u0 - rr, 0, 0);
        return p + "Z";
    }

    // Rect from edge-local ranges, for the hit area and the content clip.
    function rect(u0, u1, v0, v1) {
        const a = pt(u0, v0), b = pt(u1, v1);
        return Qt.rect(Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.abs(b[0] - a[0]), Math.abs(b[1] - a[1]));
    }

    function togglePin() {
        Config.setValue(ns, "pinned", !pinned);
    }

    screen: modelData
    color: "transparent"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    // Overlay by default: Caelestia's full-screen frame window is on Top and, when it starts after us,
    // stacks above our panels (its frame shadow shows on them and it swallows the hover strip).
    WlrLayershell.layer: cfg.layer === "top" ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.namespace: "caelestia-coolercontrol-" + ns
    WlrLayershell.keyboardFocus: keyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: hitArea
    }

    Behavior on progress {
        NumberAnimation {
            duration: Config.theme.animDuration ?? 400
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }
    }

    Component.onCompleted: Hyprland.refreshWorkspaces()

    // lastIpcObject is only refreshed on request; do it whenever fullscreen state may have changed.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["fullscreen", "workspace", "workspacev2", "focusedmon", "openwindow", "closewindow", "movewindow", "movewindowv2"].includes(event.name))
                Hyprland.refreshWorkspaces();
        }
    }

    Timer {
        id: closeDelay

        interval: root.cfg.closeDelay ?? 300
    }

    Connections {
        target: hover

        function onHoveredChanged() {
            if (!hover.hovered)
                closeDelay.restart();
        }
    }

    // Input region: a strip of the frame along the panel (from the screen edge), plus the panel while it's out.
    Item {
        id: hitArea

        readonly property real trigger: root.cfg.triggerSize ?? root.thick
        // v is measured from the inner frame edge, so the screen edge sits at -edgeInset.
        readonly property rect area: root.rect(root.flushStart ? 0 : root.start, root.flushEnd ? (root.vertical ? root.sh : root.sw) : root.start + root.along, -root.edgeInset, root.depth > 0.5 ? root.depth : trigger - root.edgeInset)

        x: area.x
        y: area.y
        width: root.suppressed && root.depth <= 0.5 ? 0 : area.width
        height: area.height
    }

    // Hover is tracked on an ancestor of the content so hovering buttons inside still counts;
    // the input mask keeps it from reacting outside the strip/panel.
    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
        }

        Shape {
            anchors.fill: parent
            visible: root.depth > 0.5
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.m3surface
                strokeWidth: root.floating ? 1 : -1
                strokeColor: Theme.m3outlineVariant

                PathSvg {
                    path: root.path
                }
            }
        }

        Item {
            readonly property rect area: root.rect(root.start, root.start + root.along, 0, root.depth)

            x: area.x
            y: area.y
            width: area.width
            height: area.height
            clip: true
            visible: root.depth > 0.5

            Item {
                // Content rides on the moving edge of the panel.
                x: root.edge === "left" ? root.depth - root.panelW : 0
                y: root.edge === "top" ? root.depth - root.contentH : 0
                width: root.panelW
                height: root.contentH
                opacity: Math.min(1, root.progress * 1.5)

                Column {
                    id: body

                    x: Theme.padding
                    y: Theme.padding
                    width: parent.width - Theme.padding * 2
                    spacing: Theme.spacing
                }
            }
        }
    }
}
