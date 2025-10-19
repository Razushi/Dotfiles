import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import "../config" as C
import "../commonwidgets" as CW

OffsetMouseWrapper {
  id: root

  property real buttonMargin: 8
  property real topInset: 0
  property real bottomInset: 0

  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(QsWindow.window?.screen)
  readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
  readonly property int workspaceCount: 5
  property int baseWorkspace: (() => {
    const bases = C.Config.settings.bar.workspaces.bases || [];
    const name = root.monitor?.name ?? "";
    const defaultBase = C.Config.settings.bar.workspaces.defaultBase;

    const baseFromSettings = (() => {
      const entry = bases.find(value => value && value.name === name);
      if (!entry)
        return undefined;
      if (typeof entry.base === "number")
        return entry.base;
      return undefined;
    })();

    if (baseFromSettings !== undefined)
      return baseFromSettings;
    if (defaultBase !== undefined)
      return defaultBase;
    return Math.floor((activeWorkspace - 1) / workspaceCount) * workspaceCount + 1;
  })()

  function toChineseNumeral(index) {
    const digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
    if (index <= 0)
      return digits[0];
    if (index <= 10)
      return index == 10 ? "十" : digits[index];
    if (index < 20)
      return "十" + digits[index % 10];
    if (index < 100) {
      const tens = Math.floor(index / 10);
      const ones = index % 10;
      const tensPart = tens == 1 ? "十" : digits[tens] + "十";
      return ones == 0 ? tensPart : tensPart + digits[ones];
    }
    return "" + index;
  }

  // trackpads
  property int scrollAccumulator: 0

  readonly property color textColor: "#ffffff"
  readonly property color accentColor: "#ff4444"
  readonly property color transparentBorder: "#00FFFFFF"

  Component.onCompleted: {
    if (C.Config.settings.bar.workspaces.shown !== workspaceCount)
      C.Config.settings.bar.workspaces.shown = workspaceCount;
  }

  acceptedButtons: Qt.NoButton
  onWheel: event => {
    event.accepted = true;
    let acc = scrollAccumulator - event.angleDelta.x - event.angleDelta.y;
    const sign = Math.sign(acc);
    acc = Math.abs(acc);

    const offset = sign * Math.floor(acc / 120);
    scrollAccumulator = sign * (acc % 120);

    if (offset != 0) {
      const currentWorkspace = root.activeWorkspace;
      const targetWorkspace = currentWorkspace + offset;
      const id = Math.max(baseWorkspace, Math.min(baseWorkspace + workspaceCount - 1, targetWorkspace));
      if (id != currentWorkspace)
        Hyprland.dispatch(`workspace ${id}`);
    }
  }

  Row {
    spacing: 6

    Repeater {
      model: ScriptModel {
        objectProp: "index"
        values: {
          const workspaces = Hyprland.workspaces?.values ?? [];
          const base = root.baseWorkspace;
          const onlyCurrent = C.Config.settings.bar.workspaces.onlyOnCurrent;
          const result = [];
          const monitor = root.monitor;

          for (let i = 0; i < root.workspaceCount; ++i) {
            const id = base + i;
            const ws = workspaces.find(w => w.id == id) || null;
            const exists = !!ws;
            const onCurrentMonitor = exists && !!monitor && ws.monitor == monitor;
            const active = exists && ws.active;
            const visible = !onlyCurrent || onCurrentMonitor;
            result.push({
              index: id,
              exists: exists,
              active: active,
              onCurrentMonitor: onCurrentMonitor,
              visible: visible
            });
          }
          return result;
        }
      }

      WrapperMouseArea {
        id: delegate
        required property var modelData

        implicitHeight: parent.height
        leftMargin: 0
        rightMargin: 0
        topMargin: root.topInset + root.buttonMargin
        bottomMargin: root.bottomInset + root.buttonMargin
        hoverEnabled: true

        onPressed: Hyprland.dispatch(`workspace ${modelData.index}`)

        Rectangle {
          id: pill

          property real activeMul: delegate.modelData.active ? C.Config.settings.bar.workspaces.activeIndicatorWidthMultiplier : 1

          radius: 6
          implicitWidth: {
            const tileSide = Math.max(32, (delegate.height - 2 * 4));
            const contentWidth = text.implicitWidth + 18;
            return C.Config.settings.bar.workspaces.style == 0 ? tileSide * activeMul : Math.max(tileSide, contentWidth);
          }

          color: delegate.modelData.active ? accentColor : (delegate.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.04))
          border.width: 1
          border.color: (delegate.containsMouse || delegate.modelData.active) ? Qt.rgba(1, 1, 1, 0.9) : transparentBorder

          anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: 4
            bottomMargin: 4
          }

          Behavior on activeMul {
            NumberAnimation {
              duration: C.Globals.anim_SLOW
              easing.type: Easing.BezierSpline
              easing.bezierCurve: C.Globals.anim_CURVE_SMOOTH_SLIDE
            }
          }

          Behavior on color {
            ColorAnimation {
              duration: C.Globals.anim_MEDIUM
              easing.type: Easing.BezierSpline
              easing.bezierCurve: C.Globals.anim_CURVE_SMOOTH_SLIDE
            }
          }

          Behavior on border.color {
            ColorAnimation {
              duration: C.Globals.anim_FAST
              easing.type: Easing.BezierSpline
              easing.bezierCurve: C.Globals.anim_CURVE_SMOOTH_SLIDE
            }
          }

          CW.StyledText {
            id: text
            visible: C.Config.settings.bar.workspaces.style != 0
            text: C.Config.settings.bar.workspaces.style == 1 ? "" + modelData.index : (C.Config.settings.bar.workspaces.style == 2 ? C.Config.romanize(modelData.index) : (C.Config.settings.bar.workspaces.style == 3 ? toChineseNumeral(modelData.index) : "" + modelData.index))
            anchors {
              top: parent.top
              bottom: parent.bottom
              left: parent.left
              right: parent.right
              leftMargin: 12
              rightMargin: 12
            }
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: (C.Config.settings.bar.workspaces.style == 2 || C.Config.settings.bar.workspaces.style == 3) ? C.Config.fontSize.small : C.Config.fontSize.normal
            font.family: C.Config.settings.fonts.family
            font.bold: delegate.modelData.active
            color: textColor
            opacity: delegate.modelData.exists ? (delegate.modelData.visible ? 1 : 0.72) : 0.4

            layer.enabled: delegate.modelData.active
            layer.effect: DropShadow {
              color: Qt.rgba(1, 1, 1, 0.9)
              horizontalOffset: 0
              verticalOffset: 0
              radius: 10
              samples: 32
            }

            Behavior on opacity {
              NumberAnimation {
                duration: C.Globals.anim_SLOW
                easing.type: Easing.BezierSpline
                easing.bezierCurve: C.Globals.anim_CURVE_SMOOTH_SLIDE
              }
            }
          }
        }
      }
    }
  }
}
