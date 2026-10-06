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

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property color barIconColor: vpnService.connected ? foreground : dim

    Service {
        id: vpnService
    }

    ShellIpc {
        target: root.ipcTarget
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function toggleVpn(): string { vpnService.toggle(); return "ok" }
        function status(): string { return vpnService.connected ? "connected" : "disconnected" }
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
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
        contentWidth: 320
        contentHeight: contentCol.implicitHeight + 24

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Header: Status + Main Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                VpnIcon {
                    iconSize: 24
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

            // Live throughput rates when connected
            if (vpnService.connected) {
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: "#18181b"
                    border.color: "#27272a"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        Label {
                            text: "↓ " + (vpnService.rxRate / 1024).toFixed(1) + " KB/s"
                            color: "#38bdf8"
                            font.bold: true
                            font.pointSize: 10
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle { width: 1; height: 20; color: "#333" }
                        Label {
                            text: "↑ " + (vpnService.txRate / 1024).toFixed(1) + " KB/s"
                            color: "#4ade80"
                            font.bold: true
                            font.pointSize: 10
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // Profiles list
            Label {
                text: "PROFILES"
                font.pointSize: 9
                font.bold: true
                opacity: 0.6
            }

            ListView {
                id: profilesList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(vpnService.profiles.length * 36, 36), 180)
                clip: true
                model: vpnService.profiles

                delegate: ItemDelegate {
                    width: profilesList.width
                    height: 36
                    highlighted: vpnService.connected && vpnService.profileName === modelData

                    contentItem: RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: (vpnService.connected && vpnService.profileName === modelData) ? "#22c55e" : "#555"
                        }
                        Label {
                            text: modelData
                            Layout.fillWidth: true
                            font.bold: vpnService.connected && vpnService.profileName === modelData
                        }
                        if (vpnService.connected && vpnService.profileName === modelData) {
                            Label { text: "Active"; font.pointSize: 8; color: Color.accent }
                        }
                    }

                    onClicked: {
                        if (vpnService.connected && vpnService.profileName === modelData) {
                            vpnService.disconnectVpn()
                        } else {
                            vpnService.connectProfile(modelData)
                        }
                    }
                }
            }

            if (vpnService.profiles.length === 0) {
                Label {
                    text: "No profiles found in ~/.config/grold-omarchy-vpn/profiles/"
                    font.pointSize: 9
                    opacity: 0.5
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#27272a" }

            // Footer: Button to open full app
            Button {
                Layout.fillWidth: true
                text: "Open VPN Manager..."
                highlighted: false
                onClicked: {
                    root.close()
                    vpnService.openApp()
                }
            }
        }
    }
}
