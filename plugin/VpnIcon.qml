import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property real iconSize: 22
    property color color: "white"
    property color dotColor: "#22c55e"
    property bool active: false
    property bool hasDot: true

    implicitWidth: iconSize
    implicitHeight: iconSize

    Shape {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        layer.enabled: true
        layer.samples: 4

        // Shield / Keyhole shape
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: root.iconSize * 0.5
            startY: root.iconSize * 0.15

            PathLine { x: root.iconSize * 0.85; y: root.iconSize * 0.28 }
            PathLine { x: root.iconSize * 0.85; y: root.iconSize * 0.58 }
            PathQuad {
                x: root.iconSize * 0.5
                y: root.iconSize * 0.90
                controlX: root.iconSize * 0.82
                controlY: root.iconSize * 0.80
            }
            PathQuad {
                x: root.iconSize * 0.15
                y: root.iconSize * 0.58
                controlX: root.iconSize * 0.18
                controlY: root.iconSize * 0.80
            }
            PathLine { x: root.iconSize * 0.15; y: root.iconSize * 0.28 }
            PathLine { x: root.iconSize * 0.5; y: root.iconSize * 0.15 }
        }

        // Inner lock bar
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.6
            fillColor: root.active ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: root.iconSize * 0.5
            startY: root.iconSize * 0.42
            PathLine { x: root.iconSize * 0.5; y: root.iconSize * 0.62 }
        }
    }

    // Status dot
    Rectangle {
        visible: root.hasDot && root.active
        width: root.iconSize * 0.32
        height: root.iconSize * 0.32
        radius: width / 2
        color: root.dotColor
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: -1
        border.color: "#18181b"
        border.width: 1
    }
}
