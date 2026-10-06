import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 960
    height: 700
    minimumWidth: 720
    minimumHeight: 520
    visible: true
    title: "grold-omarchy-vpn"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent

    property bool helpVisible: false
    property int selectedIndex: 0

    // Ensure selectedIndex is always within valid bounds
    onSelectedIndexChanged: {
        clampSelection()
    }

    Connections {
        target: backend
        function onProfilesChanged() {
            clampSelection()
        }
    }

    function clampSelection() {
        if (backend.profiles.length === 0) {
            selectedIndex = 0
        } else if (selectedIndex >= backend.profiles.length) {
            selectedIndex = Math.max(0, backend.profiles.length - 1)
        } else if (selectedIndex < 0) {
            selectedIndex = 0
        }
    }

    function selectedProfile() {
        if (backend.profiles.length > 0 && selectedIndex >= 0 && selectedIndex < backend.profiles.length) {
            return backend.profiles[selectedIndex]
        }
        return null
    }

    function selectNext() {
        if (backend.profiles.length > 0) {
            selectedIndex = (selectedIndex + 1) % backend.profiles.length
        }
    }

    function selectPrev() {
        if (backend.profiles.length > 0) {
            selectedIndex = (selectedIndex - 1 + backend.profiles.length) % backend.profiles.length
        }
    }

    function connectOrToggleSelected() {
        var prof = selectedProfile()
        if (backend.connected) {
            if (prof && backend.activeProfileName !== prof.name) {
                // Connect to the newly selected profile
                backend.connectProfile(prof.name)
            } else {
                backend.toggleConnection()
            }
        } else {
            if (prof) {
                backend.connectProfile(prof.name)
            } else {
                backend.toggleConnection()
            }
        }
    }

    function editSelected() {
        var prof = selectedProfile()
        if (!prof) return
        configEditorModal.isNew = false
        configEditorModal.profileName = prof.name
        configEditorModal.initialConf = backend.readProfileConf(prof.name)
        configEditorModal.splitMode = prof.splitMode || "off"
        configEditorModal.killSwitch = prof.killSwitch || false
        configEditorModal.splitApps = prof.splitApps || []
        configEditorModal.splitIps = prof.splitIps || []
        configEditorModal.open()
    }

    function splitSelected() {
        var prof = selectedProfile()
        if (!prof) return
        splitTunnelModal.profileName = prof.name
        splitTunnelModal.currentMode = prof.splitMode || "off"
        splitTunnelModal.selectedApps = (prof.splitApps || []).slice()
        splitTunnelModal.customIps = (prof.splitIps || []).slice()
        splitTunnelModal.open()
    }

    function deleteSelected() {
        var prof = selectedProfile()
        if (!prof) return
        deleteConfirmDialog.targetProfile = prof.name
        deleteConfirmDialog.open()
    }

    function setDefaultSelected() {
        var prof = selectedProfile()
        if (prof) {
            backend.setDefaultProfile(prof.name)
        }
    }

    // Keyboard Shortcuts (Omarchy Standard)
    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.toggleConnection() }
    Shortcut { sequence: "Return"; context: Qt.ApplicationShortcut; onActivated: connectOrToggleSelected() }
    Shortcut { sequence: "Enter"; context: Qt.ApplicationShortcut; onActivated: connectOrToggleSelected() }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; onActivated: selectNext() }
    Shortcut { sequence: "J"; context: Qt.ApplicationShortcut; onActivated: selectNext() }
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; onActivated: selectPrev() }
    Shortcut { sequence: "K"; context: Qt.ApplicationShortcut; onActivated: selectPrev() }
    Shortcut { sequence: "A"; context: Qt.ApplicationShortcut; onActivated: backend.requestImportDialog() }
    Shortcut { sequence: "N"; context: Qt.ApplicationShortcut; onActivated: openNewProfileModal() }
    Shortcut { sequence: "E"; context: Qt.ApplicationShortcut; onActivated: editSelected() }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; onActivated: splitSelected() }
    Shortcut { sequence: "D"; context: Qt.ApplicationShortcut; onActivated: setDefaultSelected() }
    Shortcut { sequence: "Delete"; context: Qt.ApplicationShortcut; onActivated: deleteSelected() }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; onActivated: backend.refresh() }

    function openNewProfileModal() {
        configEditorModal.isNew = true
        configEditorModal.profileName = ""
        configEditorModal.initialConf = ""
        configEditorModal.splitMode = "off"
        configEditorModal.killSwitch = false
        configEditorModal.splitApps = []
        configEditorModal.splitIps = []
        configEditorModal.open()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ================= HERO TELEMETRY HEADER =================
        Rectangle {
            Layout.fillWidth: true
            height: 76
            color: "#121215"
            border.color: "#222228"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16

                // App Brand
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "VPN Manager"
                        font.bold: true
                        font.pointSize: 15
                        color: "#ffffff"
                    }
                    Label {
                        text: "Omarchy System Client"
                        font.pointSize: 9
                        color: theme.accent
                    }
                }

                // Global Status Badge
                Rectangle {
                    radius: 16
                    height: 32
                    width: heroStatusLayout.width + 20
                    color: backend.connected ? "#14532d" : "#222228"
                    border.color: backend.connected ? "#22c55e" : "#3f3f46"
                    border.width: 1

                    RowLayout {
                        id: heroStatusLayout
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: backend.connected ? "#22c55e" : "#71717a"
                        }
                        Label {
                            text: backend.connected
                                  ? ("CONNECTED: " + backend.activeProfileName)
                                  : "DISCONNECTED"
                            font.bold: true
                            font.pointSize: 9
                            color: backend.connected ? "#86efac" : "#a1a1aa"
                        }
                    }
                }

                // Live transfer badges (Download / Upload)
                RowLayout {
                    visible: backend.connected
                    spacing: 12
                    Rectangle {
                        radius: 12
                        height: 26
                        width: dlBadgeLayout.width + 16
                        color: "#0c2838"
                        border.color: "#0284c7"
                        RowLayout {
                            id: dlBadgeLayout
                            anchors.centerIn: parent
                            spacing: 4
                            Label { text: "↓"; color: "#38bdf8"; font.bold: true; font.pointSize: 9 }
                            Label {
                                text: statsViewHelper.formatSpeed(backend.rxRate)
                                color: "#e0f2fe"
                                font.pointSize: 9
                                font.bold: true
                            }
                        }
                    }
                    Rectangle {
                        radius: 12
                        height: 26
                        width: ulBadgeLayout.width + 16
                        color: "#0f2e1b"
                        border.color: "#16a34a"
                        RowLayout {
                            id: ulBadgeLayout
                            anchors.centerIn: parent
                            spacing: 4
                            Label { text: "↑"; color: "#4ade80"; font.bold: true; font.pointSize: 9 }
                            Label {
                                text: statsViewHelper.formatSpeed(backend.txRate)
                                color: "#dcfce7"
                                font.pointSize: 9
                                font.bold: true
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Quick Kill Switch in Hero Bar
                RowLayout {
                    spacing: 6
                    Label {
                        text: "Kill Switch"
                        font.pointSize: 10
                        color: "#a1a1aa"
                    }
                    Switch {
                        checked: backend.killSwitch
                        onToggled: backend.setKillSwitch(checked)
                    }
                }

                // Primary Connection Toggle
                Button {
                    text: backend.connected ? "Disconnect (Space)" : "Connect (Space)"
                    highlighted: !backend.connected
                    onClicked: backend.toggleConnection()
                }

                ToolButton {
                    text: "?"
                    font.bold: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Shortcuts Help (?)"
                    onClicked: win.helpVisible = !win.helpVisible
                }
            }
        }

        // ================= NAVIGATION TABS =================
        TabBar {
            id: mainTabBar
            Layout.fillWidth: true
            currentIndex: 0

            TabButton { text: "Profiles (" + backend.profiles.length + ")" }
            TabButton { text: "Split Tunneling" }
            TabButton { text: "Telemetry & Logs" }
        }

        // ================= MAIN VIEWS STACK =================
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mainTabBar.currentIndex

            // ---------------- VIEW 0: PROFILES ----------------
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // Action Toolbar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: "CONFIGURED PROFILES"
                            font.bold: true
                            font.pointSize: 10
                            color: "#71717a"
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Import .conf (A)"
                            onClicked: backend.requestImportDialog()
                        }

                        Button {
                            text: "+ New Profile (N)"
                            highlighted: true
                            onClicked: openNewProfileModal()
                        }
                    }

                    // Empty State
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        visible: backend.profiles.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 14

                            Label {
                                text: "No VPN Profiles Found"
                                font.pointSize: 16
                                font.bold: true
                                color: "#71717a"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Label {
                                text: "Import an existing WireGuard / AmneziaWG configuration file or create one manually."
                                font.pointSize: 11
                                color: "#52525b"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Button {
                                text: "Import .conf via File Chooser"
                                highlighted: true
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: backend.requestImportDialog()
                            }
                        }
                    }

                    // Profiles List
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: backend.profiles.length > 0

                        ListView {
                            id: profilesListView
                            width: parent.width
                            spacing: 8
                            model: backend.profiles

                            delegate: ProfileCard {
                                profileData: modelData
                                isSelected: index === win.selectedIndex

                                onConnectRequested: {
                                    if (isActive) backend.disconnectVpn()
                                    else backend.connectProfile(modelData.name)
                                }
                                onSetDefaultRequested: {
                                    backend.setDefaultProfile(modelData.name)
                                }
                                onEditRequested: {
                                    win.selectedIndex = index
                                    editSelected()
                                }
                                onSplitRequested: {
                                    win.selectedIndex = index
                                    splitSelected()
                                }
                                onDeleteRequested: {
                                    win.selectedIndex = index
                                    deleteSelected()
                                }
                                onClicked: {
                                    win.selectedIndex = index
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- VIEW 1: SPLIT TUNNELING ----------------
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Label {
                        text: "System Split Tunneling Routing"
                        font.bold: true
                        font.pointSize: 14
                        color: theme.accent
                    }

                    Label {
                        text: "Split tunneling routes specific desktop applications or destination subnets outside (Bypass/Exclusive) or through (Inclusive) the active VPN tunnel. AmneziaWG obfuscation is preserved for all routed traffic."
                        wrapMode: Text.Wrap
                        opacity: 0.8
                        font.pointSize: 11
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#27272a"
                    }

                    RowLayout {
                        spacing: 16
                        Label { text: "Current Active Session Mode:"; font.bold: true }
                        Rectangle {
                            radius: 4
                            height: 24
                            width: activeModeLabel.width + 16
                            color: "#27272a"
                            Label {
                                id: activeModeLabel
                                anchors.centerIn: parent
                                text: backend.splitMode.toUpperCase()
                                font.pointSize: 9
                                font.bold: true
                                color: theme.accent
                            }
                        }
                    }

                    Button {
                        text: "Configure Active Routing Rules (S)"
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

            // ---------------- VIEW 2: TELEMETRY & LOGS ----------------
            StatsView {
                id: statsViewHelper
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // ================= STATUS FOOTER BAR =================
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#0a0a0c"
            border.color: "#1c1c20"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Label {
                    text: backend.statusMessage || (backend.daemonAvailable ? "● Daemon connected (/run/grold-omarchy-vpn/daemon.sock)" : "○ Daemon offline — systemctl start grold-omarchy-vpnd")
                    font.pointSize: 9
                    opacity: 0.7
                    color: backend.daemonAvailable ? "#a1a1aa" : "#f87171"
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Press ? for shortcuts"
                    font.pointSize: 9
                    opacity: 0.5
                }

                Label {
                    visible: backend.connected
                    text: " • Interface: " + backend.activeInterface
                    font.pointSize: 9
                    opacity: 0.7
                    color: theme.accent
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

    Dialog {
        id: deleteConfirmDialog
        title: "Delete Profile"
        modal: true
        width: 380
        anchors.centerIn: parent
        property string targetProfile: ""

        Material.theme: Material.Dark
        Material.accent: theme.accent

        contentItem: ColumnLayout {
            spacing: 16
            Label {
                text: "Are you sure you want to permanently delete profile '" + deleteConfirmDialog.targetProfile + "'?"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    onClicked: deleteConfirmDialog.close()
                }
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

    // Omarchy Keyboard Shortcuts Overlay (?)
    Rectangle {
        id: helpOverlay
        anchors.fill: parent
        color: "#d9050507"
        visible: win.helpVisible
        z: 99

        MouseArea {
            anchors.fill: parent
            onClicked: win.helpVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 540
            height: 440
            radius: 10
            color: "#141418"
            border.color: theme.accent
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Keyboard Shortcuts"
                        font.bold: true
                        font.pointSize: 15
                        color: theme.accent
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: "Omarchy Standard"
                        font.pointSize: 9
                        opacity: 0.5
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#27272a" }

                GridLayout {
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 24
                    Layout.fillWidth: true

                    Label { text: "Space"; font.bold: true; color: "#ffffff" }
                    Label { text: "Toggle VPN connection (Connect / Disconnect)" }

                    Label { text: "Enter / Return"; font.bold: true; color: "#ffffff" }
                    Label { text: "Connect to selected profile" }

                    Label { text: "Down / J, Up / K"; font.bold: true; color: "#ffffff" }
                    Label { text: "Navigate profile selection list" }

                    Label { text: "D"; font.bold: true; color: "#ffffff" }
                    Label { text: "Set selected profile as Default" }

                    Label { text: "A"; font.bold: true; color: "#ffffff" }
                    Label { text: "Import configuration (.conf) via Portal" }

                    Label { text: "N"; font.bold: true; color: "#ffffff" }
                    Label { text: "Create new profile manually" }

                    Label { text: "E"; font.bold: true; color: "#ffffff" }
                    Label { text: "Edit selected profile configuration" }

                    Label { text: "S"; font.bold: true; color: "#ffffff" }
                    Label { text: "Configure split tunneling rules" }

                    Label { text: "Delete"; font.bold: true; color: "#ffffff" }
                    Label { text: "Delete selected profile" }

                    Label { text: "?"; font.bold: true; color: "#ffffff" }
                    Label { text: "Toggle this shortcuts help modal" }

                    Label { text: "Q"; font.bold: true; color: "#ffffff" }
                    Label { text: "Quit application" }
                }

                Item { Layout.fillHeight: true }

                Button {
                    text: "Close (Esc / ?)"
                    highlighted: true
                    Layout.alignment: Qt.AlignRight
                    onClicked: win.helpVisible = false
                }
            }
        }
    }
}
