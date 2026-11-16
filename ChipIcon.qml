import QtQuick

Item {
  id: chip
  property real iconSize: 16
  property color ink: "white"
  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize
  readonly property real unit: iconSize / 16
  Rectangle {
    x: 3 * chip.unit; y: 3 * chip.unit
    width: 10 * chip.unit; height: 10 * chip.unit
    color: "transparent"; border.color: chip.ink; border.width: Math.max(1, chip.unit)
  }
  Rectangle { x: 6 * chip.unit; y: 6 * chip.unit; width: 4 * chip.unit; height: 4 * chip.unit; color: chip.ink }
  Rectangle { x: 0; y: 5 * chip.unit; width: 3 * chip.unit; height: chip.unit; color: chip.ink }
  Rectangle { x: 0; y: 10 * chip.unit; width: 3 * chip.unit; height: chip.unit; color: chip.ink }
  Rectangle { x: 13 * chip.unit; y: 5 * chip.unit; width: 3 * chip.unit; height: chip.unit; color: chip.ink }
  Rectangle { x: 13 * chip.unit; y: 10 * chip.unit; width: 3 * chip.unit; height: chip.unit; color: chip.ink }
  Rectangle { x: 5 * chip.unit; y: 0; width: chip.unit; height: 3 * chip.unit; color: chip.ink }
  Rectangle { x: 10 * chip.unit; y: 0; width: chip.unit; height: 3 * chip.unit; color: chip.ink }
  Rectangle { x: 5 * chip.unit; y: 13 * chip.unit; width: chip.unit; height: 3 * chip.unit; color: chip.ink }
  Rectangle { x: 10 * chip.unit; y: 13 * chip.unit; width: chip.unit; height: 3 * chip.unit; color: chip.ink }
}
