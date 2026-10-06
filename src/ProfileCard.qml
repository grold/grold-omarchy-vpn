import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Rectangle {
    id: root
    width: parent.width
    height: 82
    radius: 8
    color: isActive ? "#1e293b" : "#18181b"
    border.color: isActive ? Material.accent : "#27272a"
    border.width: isActive ? 2 : 1

    property var profileData: ({})
    readonly property bool isActive: backend.connected && backend.activeProfileName === profileData.name

    signal connectRequested()
    signal editRequested()
    signal splitRequested()
    signal deleteRequested()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // Status indicator dot
        Rectangle {
            width: 12
            height: 12
            radius: 6
            color: root.isActive ? "#22c55e" : "#52525b"
        }

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            RowLayout {
                spacing: 8
                Label {
                    text: profileData.name || "Unnamed"
                    font.bold: true
                    font.pointSize: 13
                }
                Rectangle {
                    radius: 4
                    color: profileData.isAmnezia ? "#7c3aed" : "#0284c7"
                    height: 18
                    width: typeLabel.width + 10
                    Label {
                        id: typeLabel
                        anchors.centerIn: parent
                        text: profileData.isAmnezia ? "AmneziaWG" : "WireGuard"
                        font.pointSize: 9
                        color: "white"
                        font.bold: true
                    }
                }
                Rectangle {
                    visible: !!(profileData.splitMode && profileData.splitMode !== "off")
                    radius: 4
                    color: "#334155"
                    height: 18
                    width: splitLabel.width + 10
                    Label {
                        id: splitLabel
                        anchors.centerIn: parent
                        text: "Split: " + (profileData.splitMode || "")
                        font.pointSize: 9
                        color: "#94a3b8"
                    }
                }
            }

            Label {
                text: (profileData.peers && profileData.peers.length > 0)
                      ? "Endpoint: " + (profileData.peers[0].endpoint || "N/A") + " • IPs: " + (profileData.interface ? profileData.interface.address.join(", ") : "")
                      : "No peers configured"
                font.pointSize: 9
                opacity: 0.6
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 8

            Button {
                text: root.isActive ? "Disconnect" : "Connect"
                highlighted: root.isActive
                onClicked: root.connectRequested()
            }

            ToolButton {
                text: "⚙ Split"
                ToolTip.visible: hovered
                ToolTip.text: "Configure Split Tunneling"
                onClicked: root.splitRequested()
            }

            ToolButton {
                text: "✏ Edit"
                ToolTip.visible: hovered
                ToolTip.text: "Edit Configuration"
                onClicked: root.editRequested()
            }

            ToolButton {
                text: "🗑"
                ToolTip.visible: hovered
                ToolTip.text: "Delete Profile"
                onClicked: root.deleteRequested()
            }
        }
    }
}
