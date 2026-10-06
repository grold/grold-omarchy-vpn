import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "grold.vpn"
    ipcTarget: "grold.vpn"
    manageIpc: false

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property color barIconColor: vpnService.connected ? foreground : dim

    Service {
        id: vpnService
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onOpenedChanged: {
        if (opened) {
            vpnService.refresh()
            vpnService.refreshProfiles()
        }
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        tooltipText: {
            if (vpnService.connected) {
                var totalDown = vpnService.formatBytes(vpnService.rxBytes)
                var totalUp = vpnService.formatBytes(vpnService.txBytes)
                var rateDown = vpnService.formatRate(vpnService.rxRate)
                var rateUp = vpnService.formatRate(vpnService.txRate)
                var name = vpnService.profileName || "VPN"
                return name + " · Connected\n" +
                       "Live: ↓ " + rateDown + "  ↑ " + rateUp + "\n" +
                       "Total: ↓ " + totalDown + "  ↑ " + totalUp
            } else {
                return "VPN Disconnected\nRight-click to toggle"
            }
        }
        onTooltipHoveredChanged: {
            if (tooltipHovered && !root.opened) {
                vpnService.refresh()
                vpnService.refreshProfiles()
            }
        }
        iconComponent: Component {
            Item {
                VpnIcon {
                    anchors.centerIn: parent
                    iconSize: Style.space ? Style.space(11) : 20
                    color: root.barIconColor
                    dotColor: Color.accent
                    active: vpnService.connected
                }
            }
        }
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) {
                vpnService.toggle()
            } else {
                root.toggle()
            }
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: Style.space ? Style.space(330) : 330
        contentHeight: panel.fittedContentHeight(mainLayout.implicitHeight, Style.space ? Style.space(520) : 520)

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: 12

            // Header: Status Icon, Title, Subtitle, and Switch
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                VpnIcon {
                    iconSize: 26
                    color: vpnService.connected ? Color.accent : root.dim
                    dotColor: "#22c55e"
                    active: vpnService.connected
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: vpnService.connected ? "VPN Connected" : "VPN Disconnected"
                        font.bold: true
                        font.pointSize: 11
                    }
                    Label {
                        text: vpnService.connected ? vpnService.profileName : "No active tunnel"
                        font.pointSize: 9
                        opacity: 0.7
                    }
                }

                Switch {
                    checked: vpnService.connected
                    onToggled: vpnService.toggle()
                }
            }

            // Statistics Card (Live Rate & Total Transferred)
            Rectangle {
                visible: vpnService.connected
                Layout.fillWidth: true
                implicitHeight: statsCol.implicitHeight + 16
                radius: 8
                color: "#18181b"
                border.color: "#27272a"
                border.width: 1

                ColumnLayout {
                    id: statsCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Live Throughput
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                text: "SPEED"
                                font.pointSize: 8
                                font.bold: true
                                opacity: 0.5
                            }
                            Label {
                                text: "↓ " + vpnService.formatRate(vpnService.rxRate)
                                color: "#38bdf8"
                                font.bold: true
                                font.pointSize: 10
                            }
                        }

                        Rectangle { width: 1; height: 24; color: "#2d2d32" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                text: ""
                                font.pointSize: 8
                            }
                            Label {
                                text: "↑ " + vpnService.formatRate(vpnService.txRate)
                                color: "#4ade80"
                                font.bold: true
                                font.pointSize: 10
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#27272a" }

                    // Total Transferred
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                text: "TOTAL TRANSFERRED"
                                font.pointSize: 8
                                font.bold: true
                                opacity: 0.5
                            }
                            Label {
                                text: "↓ " + vpnService.formatBytes(vpnService.rxBytes)
                                color: "#93c5fd"
                                font.pointSize: 9.5
                            }
                        }

                        Rectangle { width: 1; height: 24; color: "#2d2d32" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                text: ""
                                font.pointSize: 8
                            }
                            Label {
                                text: "↑ " + vpnService.formatBytes(vpnService.txBytes)
                                color: "#86efac"
                                font.pointSize: 9.5
                            }
                        }
                    }
                }
            }

            // Profiles Header
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "AVAILABLE PROFILES"
                    font.pointSize: 8.5
                    font.bold: true
                    opacity: 0.6
                    Layout.fillWidth: true
                }
                Label {
                    visible: vpnService.profiles.length > 0
                    text: vpnService.profiles.length + " saved"
                    font.pointSize: 8
                    opacity: 0.4
                }
            }

            // Scrollable Profiles List
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(vpnService.profiles.length * 36, 36), 144)
                clip: true
                ScrollBar.vertical.policy: (vpnService.profiles.length > 4) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                ListView {
                    id: profilesList
                    width: parent.width
                    model: vpnService.profiles
                    spacing: 2

                    delegate: Rectangle {
                        width: profilesList.width
                        height: 34
                        radius: 6
                        color: (vpnService.connected && vpnService.profileName === modelData)
                                ? "#27272a"
                                : (profMa.containsMouse ? "#1f1f23" : "transparent")

                        MouseArea {
                            id: profMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (vpnService.connected && vpnService.profileName === modelData) {
                                    vpnService.disconnectVpn()
                                } else {
                                    vpnService.connectProfile(modelData)
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: (vpnService.connected && vpnService.profileName === modelData) ? "#22c55e" : "#555"
                            }
                            Label {
                                text: modelData
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.bold: vpnService.connected && vpnService.profileName === modelData
                                color: (vpnService.connected && vpnService.profileName === modelData) ? Color.accent : root.foreground
                            }
                            Label {
                                visible: vpnService.connected && vpnService.profileName === modelData
                                text: "Active"
                                font.pointSize: 8
                                color: Color.accent
                            }
                        }
                    }
                }
            }

            Label {
                visible: vpnService.profiles.length === 0
                text: "No profiles in ~/.config/grold-omarchy-vpn/profiles/"
                font.pointSize: 9
                opacity: 0.5
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#27272a"
            }

            // Footer: Button to open full VPN manager desktop app
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: footerMa.containsMouse ? Color.accent : "#222226"

                MouseArea {
                    id: footerMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close()
                        vpnService.openApp()
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Label {
                        text: "󰢹"
                        font.pixelSize: 13
                        color: footerMa.containsMouse ? "black" : root.foreground
                    }
                    Label {
                        text: "Open VPN Manager"
                        font.bold: true
                        font.pointSize: 9.5
                        color: footerMa.containsMouse ? "black" : root.foreground
                    }
                }
            }
        }
    }
}
