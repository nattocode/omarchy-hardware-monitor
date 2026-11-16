import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
  id: root
  moduleName: "natto.hardware-monitor"
  ipcTarget: "natto.hardware-monitor"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/natto.hardware-monitor/monitor.py"
  property var snapshot: ({})
  property int tab: 0
  property string query: ""
  property string sortMode: "memory"
  property int selectedPid: -1
  property var selectedStart: 0
  property string selectedName: ""
  property string error: ""
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function amount(bytes) {
    var n = Number(bytes || 0), units = ["B", "KiB", "MiB", "GiB", "TiB"], i = 0
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
    return Commons.I18n.formatNumber(n, i === 0 ? 0 : 1) + " " + units[i]
  }
  function percent(used, total) { return total > 0 ? Math.max(0, Math.min(100, 100 * used / total)) : 0 }
  function percentText(value) { return Commons.I18n.formatNumber(value || 0, 1) + "%" }
  function rows() {
    var items = Array.isArray(snapshot.processes) ? snapshot.processes.slice(0, 2000) : []
    var q = query.toLowerCase().slice(0, 80)
    if (q) items = items.filter(function(p) { return String(p.name || "").toLowerCase().indexOf(q) >= 0 || String(p.pid).indexOf(q) >= 0 })
    items.sort(function(a, b) { return Number(b[sortMode] || 0) - Number(a[sortMode] || 0) })
    return items.slice(0, 40)
  }
  function stopProcess(force) {
    if (selectedPid < 2 || action.running) return
    action.command = ["python3", helper, "terminate", String(selectedPid), String(selectedStart), force ? "force" : "term"]
    action.running = true
    selectedPid = -1
  }
  onOpenedChanged: {
    if (opened) { error = ""; monitor.running = true }
    else { monitor.running = false; selectedPid = -1; query = "" }
  }
  Process {
    id: monitor
    command: ["python3", root.helper, "watch"]
    stdout: SplitParser {
      onRead: function(line) {
        if (!root.opened || line.length > 2000000) return
        try {
          var parsed = JSON.parse(line)
          if (Array.isArray(parsed.processes) && Array.isArray(parsed.disks)) { root.snapshot = parsed; root.error = "" }
        } catch (e) { root.error = strings.t("dataError") }
      }
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (root.opened && text) root.error = String(text).slice(0, 160) }
    onExited: if (root.opened) restartTimer.start()
  }
  Timer { id: restartTimer; interval: 3000; onTriggered: if (root.opened && !monitor.running) monitor.running = true }
  Process {
    id: action
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(text)
          root.error = result.ok ? "" : String(result.error || strings.t("actionError")).slice(0, 160)
        } catch (e) { root.error = strings.t("actionError") }
      }
    }
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    onPressed: function(b) { root.toggle() }
  }
  ChipIcon {
    anchors.centerIn: button
    iconSize: Math.min(Style.bar.iconSlot - Style.space(3), Style.bar.iconSize * 1.2)
    ink: root.barForeground
  }
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(650))
    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: body.implicitHeight
      blocked: searchInput.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.tab = (root.tab + direction + 5) % 5 }
      onTextKey: function(t) { if (t === "r" || t === "R") { monitor.running = false; restartTimer.interval = 50; restartTimer.start() } }
      ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Column {
          id: body
          width: scroll.availableWidth
          spacing: Style.space(12)
          Row {
            width: parent.width
            spacing: Style.space(12)
            ChipIcon { iconSize: Style.font.display; ink: Color.popups.text }
            Column {
              Text { text: "Hardware Monitor"; textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              Text { text: strings.t("subtitle"); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
            }
          }
          Rectangle { width: parent.width; height: 1; color: Color.popups.border }
          Row {
            width: parent.width; spacing: Style.space(4)
            Repeater { model: [strings.t("overview"), strings.t("cpu"), strings.t("memoryTab"), strings.t("storage"), strings.t("processes")]
              delegate: Rectangle {
                width: (body.width - Style.space(16)) / 5; height: Style.space(32)
                color: root.tab === index ? Color.accent : "transparent"
                border.color: Color.popups.border
                Text { anchors.centerIn: parent; text: modelData; textFormat: Text.PlainText; color: root.tab === index ? Color.background : Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: root.tab = index }
              }
            }
          }
          Column {
            visible: root.tab === 0 || root.tab === 1
            width: parent.width; spacing: Style.space(8)
            Text { text: strings.t("cpuUsage"); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            Text { width: parent.width; text: root.percentText(root.snapshot.cpu) + "    " + (root.snapshot.model || "CPU"); textFormat: Text.PlainText; elide: Text.ElideRight; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            UsageBar { width: parent.width; percent: root.snapshot.cpu || 0 }
            Text { text: strings.t("cores").arg(root.snapshot.cores || 0) + "   •   " + strings.t("uptime").arg(Math.floor((root.snapshot.uptime || 0) / 3600)); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            Text { visible: root.tab === 1; text: strings.t("frequency").arg(root.snapshot.frequency === null || root.snapshot.frequency === undefined ? "—" : Commons.I18n.formatNumber(root.snapshot.frequency, 2)) + "    " + strings.t("temperature").arg(root.snapshot.temperature === null || root.snapshot.temperature === undefined ? "—" : Commons.I18n.formatNumber(root.snapshot.temperature, 1)); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
          }
          Column {
            visible: root.tab === 0 || root.tab === 2
            width: parent.width; spacing: Style.space(8)
            Rectangle { width: parent.width; height: 1; color: Color.popups.border }
            Text { text: strings.t("memory"); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            Text { text: root.amount(root.snapshot.memUsed) + " / " + root.amount(root.snapshot.memTotal) + "   (" + root.percentText(root.percent(root.snapshot.memUsed, root.snapshot.memTotal)) + ")"; textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            UsageBar { width: parent.width; percent: root.percent(root.snapshot.memUsed, root.snapshot.memTotal) }
            Text { text: strings.t("swap") + "   " + root.amount(root.snapshot.swapUsed) + " / " + root.amount(root.snapshot.swapTotal); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            UsageBar { width: parent.width; percent: root.percent(root.snapshot.swapUsed, root.snapshot.swapTotal) }
            Text { visible: root.tab === 2; text: strings.t("available").arg(root.amount(root.snapshot.memAvailable)) + "   •   " + strings.t("cached").arg(root.amount(root.snapshot.memCached)); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            Text { visible: root.tab === 2; text: strings.t("free").arg(root.amount(root.snapshot.memFree)); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
          }
          Column {
            visible: root.tab === 0 || root.tab === 3
            width: parent.width; spacing: Style.space(8)
            Rectangle { width: parent.width; height: 1; color: Color.popups.border }
            Text { text: strings.t("storage"); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            Repeater { model: Array.isArray(root.snapshot.disks) ? root.snapshot.disks : []
              delegate: Column {
                width: body.width; spacing: Style.space(3)
                Text { width: parent.width; text: String(modelData.path).slice(0, 100) + "   " + root.amount(modelData.used) + " / " + root.amount(modelData.total); textFormat: Text.PlainText; elide: Text.ElideMiddle; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
                UsageBar { width: parent.width; percent: root.percent(modelData.used, modelData.total) }
              }
            }
          }
          Column {
            visible: root.tab === 4
            width: parent.width; spacing: Style.space(6)
            Rectangle { width: parent.width; height: Style.space(30); color: Color.menu.selectedBackground; border.color: Color.popups.border
              TextInput { id: searchInput; anchors.fill: parent; anchors.margins: Style.space(6); color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; text: root.query; onTextChanged: root.query = text; clip: true }
              Text { anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; visible: !searchInput.text && !searchInput.activeFocus; text: strings.t("search"); textFormat: Text.PlainText; color: Color.foreground; opacity: 0.6; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            }
            Row { spacing: Style.space(6)
              Text { text: strings.t("sort"); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
              Text { text: root.sortMode === "memory" ? strings.t("memory") : strings.t("cpu"); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body
                MouseArea { anchors.fill: parent; onClicked: root.sortMode = root.sortMode === "memory" ? "cpu" : "memory" } }
              Text { text: "  " + (Array.isArray(root.snapshot.processes) ? root.snapshot.processes.length : 0) + " " + strings.t("processes"); textFormat: Text.PlainText; color: Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
            }
            Column { visible: root.selectedPid > 1; width: parent.width; spacing: Style.space(5)
              Text { text: strings.t("confirm").arg(root.selectedName).arg(root.selectedPid); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; wrapMode: Text.Wrap; width: parent.width }
              Row { spacing: Style.space(7)
                Repeater { model: [strings.t("end"), strings.t("force"), strings.t("cancel")]
                  delegate: Rectangle { width: (body.width - Style.space(14)) / 3; height: Style.space(30); color: index === 0 ? Color.accent : "transparent"; border.color: Color.popups.border
                    Text { anchors.centerIn: parent; text: modelData; textFormat: Text.PlainText; color: index === 0 ? Color.background : Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
                    MouseArea { anchors.fill: parent; onClicked: if (index === 2) root.selectedPid = -1; else root.stopProcess(index === 1) }
                  }
                }
              }
            }
            Repeater { model: root.rows()
              delegate: Rectangle {
                width: body.width; height: Style.space(45)
                color: root.selectedPid === modelData.pid ? Color.accent : (index % 2 ? Color.menu.selectedBackground : "transparent")
                Column { anchors.left: parent.left; anchors.right: endButton.left; anchors.rightMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; spacing: 1
                  Text { width: parent.width; text: String(modelData.name || "").slice(0, 80) + "   PID " + modelData.pid; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.selectedPid === modelData.pid ? Color.background : Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { width: parent.width; text: root.percentText(modelData.cpu) + " CPU    " + root.amount(modelData.memory) + " RAM" + (modelData.mine ? "" : "   " + strings.t("otherUser")); textFormat: Text.PlainText; elide: Text.ElideRight; color: root.selectedPid === modelData.pid ? Color.background : Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                Rectangle {
                  id: endButton
                  anchors.right: parent.right; anchors.rightMargin: Style.space(18); anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(26); height: Style.space(24)
                  visible: modelData.mine
                  color: "transparent"
                  border.color: root.selectedPid === modelData.pid ? Color.background : Color.popups.border
                  border.width: 1
                  Text { anchors.centerIn: parent; text: "x"; textFormat: Text.PlainText; color: root.selectedPid === modelData.pid ? Color.background : Color.popups.text; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
                  MouseArea { anchors.fill: parent; onClicked: {
                    root.selectedPid = modelData.pid
                    root.selectedStart = modelData.start
                    root.selectedName = String(modelData.name).slice(0, 80)
                    scroll.contentItem.contentY = 0
                  } }
                }
              }
            }
          }
          Text { visible: root.error !== ""; width: parent.width; text: root.error; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Color.urgent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
          Text { text: strings.t("hint"); textFormat: Text.PlainText; color: Color.popups.text; opacity: 0.6; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
        }
      }
    }
  }
}
