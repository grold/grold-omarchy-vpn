import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: win
    width: 960
    height: 680
    minimumWidth: 700
    minimumHeight: 500
    visible: true
    title: "grold-omarchy-vpn"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent

    property bool helpVisible: false

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.toggleConnection() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header bar
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: "#131316"
            border.color: "#222226"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16

                // App title
                Label {
                    text: "grold-omarchy-vpn"
                    font.bold: true
                    font.pointSize: 15
                    color: theme.accent
                }

                // Global Status Pill
                Rectangle {
                    radius: 14
                    height: 28
                    width: statusPillLayout.width + 16
                    color: backend.connected ? "#14532d" : "#27272a"

                    RowLayout {
                        id: statusPillLayout
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: backend.connected ? "#22c55e" : "#71717a"
                        }
                        Label {
                            text: backend.connected ? ("CONNECTED (" + backend.activeProfileName + ")") : "DISCONNECTED"
                            font.bold: true
                            font.pointSize: 10
                            color: backend.connected ? "#86efac" : "#a1a1aa"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Quick Kill Switch toggle in header
                RowLayout {
                    spacing: 6
                    Label { text: "Kill Switch:"; font.pointSize: 10; opacity: 0.8 }
                    Switch {
                        checked: backend.killSwitch
                        onToggled: backend.setKillSwitch(checked)
                    }
                }

                // Global primary toggle button
                Button {
                    text: backend.connected ? "Disconnect (Space)" : "Connect (Space)"
                    highlighted: !backend.connected
                    onClicked: backend.toggleConnection()
                }

                ToolButton {
                    text: "?"
                    ToolTip.visible: hovered
                    ToolTip.text: "Keyboard Shortcuts (?)"
                    onClicked: win.helpVisible = !win.helpVisible
                }
            }
        }

        // Navigation TabBar
        TabBar {
            id: mainTabBar
            Layout.fillWidth: true
            currentIndex: 0

            TabButton { text: "Profiles (" + backend.profiles.length + ")" }
            TabButton { text: "Split Tunneling" }
            TabButton { text: "Usage Statistics & Telemetry" }
        }

        // Main views stack
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mainTabBar.currentIndex

            // TAB 0: PROFILES VIEW
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: "Configured Profiles"
                            font.bold: true
                            font.pointSize: 13
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Import .conf..."
                            onClicked: importFileDialog.open()
                        }

                        Button {
                            text: "+ New Profile"
                            highlighted: true
                            onClicked: {
                                configEditorModal.isNew = true
                                configEditorModal.profileName = ""
                                configEditorModal.initialConf = ""
                                configEditorModal.splitMode = "off"
                                configEditorModal.killSwitch = false
                                configEditorModal.splitApps = []
                                configEditorModal.splitIps = []
                                configEditorModal.open()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        visible: backend.profiles.length === 0
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            Label {
                                text: "No VPN profiles configured yet"
                                font.pointSize: 14
                                opacity: 0.5
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Button {
                                text: "Import .conf File"
                                highlighted: true
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: importFileDialog.open()
                            }
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: backend.profiles.length > 0

                        ListView {
                            id: profilesListView
                            width: parent.width
                            spacing: 10
                            model: backend.profiles

                            delegate: ProfileCard {
                                profileData: modelData
                                onConnectRequested: {
                                    if (isActive) backend.disconnectVpn()
                                    else backend.connectProfile(modelData.name)
                                }
                                onEditRequested: {
                                    configEditorModal.isNew = false
                                    configEditorModal.profileName = modelData.name
                                    configEditorModal.initialConf = backend.readProfileConf(modelData.name)
                                    configEditorModal.splitMode = modelData.splitMode || "off"
                                    configEditorModal.killSwitch = modelData.killSwitch || false
                                    configEditorModal.splitApps = modelData.splitApps || []
                                    configEditorModal.splitIps = modelData.splitIps || []
                                    configEditorModal.open()
                                }
                                onSplitRequested: {
                                    splitTunnelModal.profileName = modelData.name
                                    splitTunnelModal.currentMode = modelData.splitMode || "off"
                                    splitTunnelModal.selectedApps = (modelData.splitApps || []).slice()
                                    splitTunnelModal.customIps = (modelData.splitIps || []).slice()
                                    splitTunnelModal.open()
                                }
                                onDeleteRequested: {
                                    deleteConfirmDialog.targetProfile = modelData.name
                                    deleteConfirmDialog.open()
                                }
                            }
                        }
                    }
                }
            }

            // TAB 1: SPLIT TUNNELING GLOBAL CONFIG
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Label {
                        text: "Active Split Tunneling Rules"
                        font.bold: true
                        font.pointSize: 13
                        color: theme.accent
                    }

                    Label {
                        text: "Split tunneling allows routing specific applications or target IP addresses through or outside the VPN tunnel. AmneziaWG and WireGuard connections can use either Bypass (Exclusive) or Inclusive modes."
                        wrapMode: Text.Wrap
                        opacity: 0.8
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Configure Active Routing Rules"
                        highlighted: true
                        onClicked: {
                            splitTunnelModal.profileName = backend.activeProfileName
                            splitTunnelModal.currentMode = backend.splitMode
                            splitTunnelModal.selectedApps = []
                            splitTunnelModal.customIps = []
                            splitTunnelModal.open()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // TAB 2: STATS VIEW
            StatsView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // Status footer bar
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: "#0a0a0c"
            border.color: "#18181b"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Label {
                    text: backend.statusMessage || (backend.daemonAvailable ? "Daemon connected" : "Daemon offline (start grold-omarchy-vpnd)")
                    font.pointSize: 9
                    opacity: 0.6
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: backend.connected ? ("Interface: " + backend.activeInterface) : ""
                    font.pointSize: 9
                    opacity: 0.6
                }
            }
        }
    }

    // Modal dialogs
    ConfigEditorModal {
        id: configEditorModal
    }

    SplitTunnelModal {
        id: splitTunnelModal
    }

    FileDialog {
        id: importFileDialog
        title: "Import WireGuard / AmneziaWG Configuration"
        nameFilters: ["VPN Configurations (*.conf)", "All Files (*)"]
        onAccepted: {
            backend.importConf(selectedFile.toString())
        }
    }

    Dialog {
        id: deleteConfirmDialog
        title: "Delete Profile"
        modal: true
        width: 360
        anchors.centerIn: parent
        property string targetProfile: ""
        contentItem: ColumnLayout {
            spacing: 12
            Label { text: "Are you sure you want to delete profile '" + deleteConfirmDialog.targetProfile + "'?" }
            RowLayout {
                Button { text: "Cancel"; onClicked: deleteConfirmDialog.close() }
                Button {
                    text: "Delete"
                    highlighted: true
                    onClicked: {
                        backend.deleteProfile(deleteConfirmDialog.targetProfile)
                        deleteConfirmDialog.close()
                    }
                }
            }
        }
    }

    // Help overlay (invoked via ?)
    Rectangle {
        id: helpOverlay
        anchors.fill: parent
        color: "#d9000000"
        visible: win.helpVisible

        MouseArea {
            anchors.fill: parent
            onClicked: win.helpVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 480
            height: 320
            radius: 8
            color: "#18181b"
            border.color: theme.accent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Label {
                    text: "grold-omarchy-vpn Shortcuts"
                    font.bold: true
                    font.pointSize: 14
                    color: theme.accent
                }

                GridLayout {
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 20
                    Layout.fillWidth: true

                    Label { text: "Space"; font.bold: true }
                    Label { text: "Toggle VPN connection (Connect / Disconnect)" }

                    Label { text: "?"; font.bold: true }
                    Label { text: "Toggle this help overlay" }

                    Label { text: "Q"; font.bold: true }
                    Label { text: "Quit application" }
                }

                Item { Layout.fillHeight: true }

                Button {
                    text: "Close"
                    Layout.alignment: Qt.AlignRight
                    onClicked: win.helpVisible = false
                }
            }
        }
    }
}
