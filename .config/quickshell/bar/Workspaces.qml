import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../config" as C
import "../commonwidgets" as CW

OffsetMouseWrapper {
  id: root

  property real padding: height / 4
  property real topInset: 0
  property real bottomInset: 0

  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(QsWindow.window?.screen)
  readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
  property int shownWorkspaces: C.Config.settings.bar.workspaces.shown
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
      if (typeof entry.chunk === "number") {
        const start = defaultBase !== undefined ? defaultBase : 1;
        return start + entry.chunk * shownWorkspaces;
      }
      return undefined;
    })();

    if (baseFromSettings !== undefined)
      return baseFromSettings;
    if (defaultBase !== undefined)
      return defaultBase;
    return Math.floor((activeWorkspace - 1) / shownWorkspaces) * shownWorkspaces + 1;
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

  function colorForWorkspace(model) {
    if (!model.exists)
      return C.Config.theme.surface_container_highest;
    const base = model.onCurrentMonitor ? C.Config.theme.primary : C.Config.theme.secondary;
    return model.active ? base : Qt.darker(base, 1.5);
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
      const id = Math.max(baseWorkspace, Math.min(baseWorkspace + shownWorkspaces - 1, targetWorkspace));
      if (id != currentWorkspace)
        Hyprland.dispatch(`workspace ${id}`);
    }
  }

  Row {
    spacing: 1

    Repeater {
      model: ScriptModel {
        objectProp: "index"
        values: {
          const workspaces = Hyprland.workspaces?.values ?? [];
          const base = root.baseWorkspace;
          const onlyCurrent = C.Config.settings.bar.workspaces.onlyOnCurrent;
          const result = [];
          const monitor = root.monitor;

          for (let i = 0; i < root.shownWorkspaces; ++i) {
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
        leftMargin: 1
        rightMargin: 1
        topMargin: root.topInset + root.padding
        bottomMargin: root.bottomInset + root.padding

        onPressed: Hyprland.dispatch(`workspace ${modelData.index}`)

        Rectangle {
          property real activeMul: C.Config.settings.bar.workspaces.style == 0 ? (delegate.modelData.active ? (C.Config.settings.bar.workspaces.activeIndicatorWidthMultiplier) : 1) : 1
          Behavior on activeMul {
            NumberAnimation {
              duration: C.Globals.anim_SLOW
              easing.type: Easing.BezierSpline
              easing.bezierCurve: C.Globals.anim_CURVE_SMOOTH_SLIDE
            }
          }

          radius: height / 2
          implicitWidth: C.Config.settings.bar.workspaces.style != 0 ? text.implicitWidth + 2 : height * activeMul

          color: C.Config.settings.bar.workspaces.style != 0 ? "transparent" : colorForWorkspace(delegate.modelData)

          Behavior on color {
            ColorAnimation {
              duration: C.Globals.anim_SLOW
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
            }
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: (C.Config.settings.bar.workspaces.style == 2 || C.Config.settings.bar.workspaces.style == 3) ? C.Config.fontSize.small : C.Config.fontSize.normal
            font.bold: delegate.modelData.active
            color: colorForWorkspace(delegate.modelData)
            opacity: delegate.modelData.exists ? (delegate.modelData.visible ? 1 : 0.55) : 0.3

            Behavior on color {
              ColorAnimation {
                duration: C.Globals.anim_SLOW
                easing.type: Easing.BezierSpline
                easing.bezierCurve: C.Globals.anim_CURVE_SMOOTH_SLIDE
              }
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
