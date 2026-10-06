import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Rectangle {
    id: root
    width: parent ? parent.width : 400
    height: 74
    radius: 8

    property var profileData: ({})
    property bool isSelected: false
    readonly property bool isActive: backend.connected && backend.activeProfileName === profileData.name
    readonly property bool isDefault: backend.defaultProfile === profileData.name

    signal connectRequested()
    signal editRequested()
    signal splitRequested()
    signal deleteRequested()
    signal setDefaultRequested()
    signal clicked()

    color: isActive ? "#1c2438" : (isSelected ? "#222228" : (mouseArea.containsMouse ? "#18181c" : "#141416"))
    border.color: isActive ? Material.accent : (isSelected ? Qt.alpha(Material.accent, 0.6) : "#27272a")
    border.width: isActive ? 2 : (isSelected ? 1.5 : 1)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 14

        // Status Indicator Dot
        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: root.isActive ? "#22c55e" : (root.isDefault ? Material.accent : "#52525b")

            // Subtle glow for active
            Rectangle {
                visible: root.isActive
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: Qt.alpha("#22c55e", 0.3)
                z: -1
            }
        }

        // Info Column
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            RowLayout {
                spacing: 8

                Label {
                    text: profileData.name || "Unnamed"
                    font.bold: true
                    font.pointSize: 12
                    color: root.isActive ? "#ffffff" : (root.isSelected ? Material.accent : "#e4e4e7")
                }

                // Type Badge (AmneziaWG / WireGuard)
                Rectangle {
                    radius: 4
                    color: profileData.isAmnezia ? "#6d28d9" : "#0369a1"
                    height: 18
                    width: typeLabel.width + 10
                    Label {
                        id: typeLabel
                        anchors.centerIn: parent
                        text: profileData.isAmnezia ? "AmneziaWG" : "WireGuard"
                        font.pointSize: 8
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                // Default Badge
                Rectangle {
                    visible: root.isDefault
                    radius: 4
                    color: Qt.alpha(Material.accent, 0.2)
                    border.color: Material.accent
                    border.width: 1
                    height: 18
                    width: defaultBadgeLabel.width + 10
                    Label {
                        id: defaultBadgeLabel
                        anchors.centerIn: parent
                        text: "Default"
                        font.pointSize: 8
                        font.bold: true
                        color: Material.accent
                    }
                }

                // Split Mode Badge
                Rectangle {
                    visible: !!(profileData.splitMode && profileData.splitMode !== "off")
                    radius: 4
                    color: "#334155"
                    height: 18
                    width: splitBadgeLabel.width + 10
                    Label {
                        id: splitBadgeLabel
                        anchors.centerIn: parent
                        text: "Split: " + (profileData.splitMode || "")
                        font.pointSize: 8
                        color: "#cbd5e1"
                    }
                }
            }

            // Endpoint & IP details
            Label {
                text: (profileData.peers && profileData.peers.length > 0)
                      ? ("Endpoint: " + (profileData.peers[0].endpoint || "N/A") + "  •  IP: " + (profileData.interface ? profileData.interface.address.join(", ") : "N/A"))
                      : "No peers configured"
                font.pointSize: 9
                opacity: 0.6
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Action Buttons
        RowLayout {
            spacing: 6

            // Default star toggle button
            ToolButton {
                text: root.isDefault ? "★" : "☆"
                font.pointSize: 12
                ToolTip.visible: hovered
                ToolTip.text: root.isDefault ? "Current Default Profile" : "Set as Default Profile (D)"
                onClicked: root.setDefaultRequested()
            }

            // Connect / Disconnect button
            Button {
                text: root.isActive ? "Disconnect" : "Connect"
                highlighted: root.isActive || root.isSelected
                onClicked: root.connectRequested()
            }

            ToolButton {
                text: "⚙"
                ToolTip.visible: hovered
                ToolTip.text: "Split Tunneling (S)"
                onClicked: root.splitRequested()
            }

            ToolButton {
                text: "✏"
                ToolTip.visible: hovered
                ToolTip.text: "Edit Configuration (E)"
                onClicked: root.editRequested()
            }

            ToolButton {
                text: "🗑"
                ToolTip.visible: hovered
                ToolTip.text: "Delete Profile (Del)"
                onClicked: root.deleteRequested()
            }
        }
    }
}
