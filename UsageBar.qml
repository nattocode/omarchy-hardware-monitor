import QtQuick
import qs.Commons

Rectangle {
  id: bar
  property real percent: 0
  height: Style.space(6)
  color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.18)
  Rectangle {
    height: parent.height
    width: bar.percent > 0 ? Math.max(Style.space(2), bar.width * Math.max(0, Math.min(100, bar.percent)) / 100) : 0
    color: Color.accent
  }
}
