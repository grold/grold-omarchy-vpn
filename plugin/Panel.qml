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
    manageIpc: true

    property int phraseIndex: 0
    readonly property var activePhrases: [
        "Shielding connections",
        "Encrypting packets",
        "Routing secure tunnel",
        "Obfuscating traffic",
        "Guarding gateway",
        "Securing wire"
    ]
    readonly property string heroPhraseText: activePhrases[phraseIndex % activePhrases.length]

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color urgent: bar ? bar.urgent : Color.urgent
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color barIconColor: vpnService.connected ? foreground : dim
    readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
    readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

    Service {
        id: vpnService
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Timer {
        id: phraseTimer
        interval: 3200
        repeat: true
        running: root.opened && vpnService.connected
        onTriggered: {
            root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
        }
    }

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
                var defProf = vpnService.selectedProfile ? (" (" + vpnService.selectedProfile + ")") : ""
                return "VPN Disconnected" + defProf + "\nRight-click to connect"
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
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(mainCol.implicitHeight, Style.space(580))

        Column {
            id: mainCol
            anchors.fill: parent
            spacing: Style.space(12)

            // 1. Panel Hero Header
            PanelHero {
                id: hero
                width: parent.width
                title: vpnService.connected ? (vpnService.profileName || "VPN Tunnel") : (vpnService.selectedProfile ? vpnService.selectedProfile : "VPN Tunnel")
                meta: vpnService.connected ? root.heroPhraseText : "VPN is disconnected"
                foreground: root.foreground
                fontFamily: root.fontFamily
                iconOpacity: vpnService.connected ? 1.0 : 0.5
                iconComponent: Component {
                    VpnIcon {
                        iconSize: Style.font.display
                        color: vpnService.connected ? Color.accent : root.dim
                        dotColor: Color.accent
                        active: vpnService.connected
                    }
                }

                trailingControl: Component {
                    ToggleSwitch {
                        checked: vpnService.connected
                        foreground: hero.foreground
                        onToggled: vpnService.toggle()
                        PanelToolTip {
                            visible: parent.containsMouse
                            text: vpnService.connected ? "Disconnect VPN" : ("Connect " + (vpnService.selectedProfile || "VPN"))
                            fontFamily: hero.fontFamily
                        }
                    }
                }
            }

            // 2. Telemetry Card (When Connected)
            CursorSurface {
                id: statsSurface
                visible: vpnService.connected
                width: parent.width
                bordered: true
                foreground: root.foreground
                fill: root.hoverFill
                currentFill: root.selectedFill
                implicitHeight: statsLayout.implicitHeight + Style.space(16)

                Item {
                    id: statsLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(10)
                    implicitHeight: Style.space(36)

                    // Left Column: Live Rates
                    Column {
                        anchors.left: parent.left
                        anchors.right: statsDivider.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)

                        Text {
                            textFormat: Text.PlainText
                            text: "CURRENT SPEED"
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.dim
                        }
                        Text {
                            textFormat: Text.PlainText
                            text: "↓ " + vpnService.formatRate(vpnService.rxRate) + "  ↑ " + vpnService.formatRate(vpnService.txRate)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                            color: Color.accent
                        }
                    }

                    // Divider
                    Rectangle {
                        id: statsDivider
                        anchors.centerIn: parent
                        width: 1
                        height: Style.space(26)
                        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    }

                    // Right Column: Total Transferred
                    Column {
                        anchors.left: statsDivider.right
                        anchors.right: parent.right
                        anchors.leftMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)

                        Text {
                            textFormat: Text.PlainText
                            text: "TOTAL TRANSFERRED"
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.dim
                        }
                        Text {
                            textFormat: Text.PlainText
                            text: "↓ " + vpnService.formatBytes(vpnService.rxBytes) + "  ↑ " + vpnService.formatBytes(vpnService.txBytes)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            color: root.foreground
                        }
                    }
                }
            }

            PanelSeparator {
                foreground: root.foreground
            }

            // 3. Profiles Section Header
            Item {
                width: parent.width
                implicitHeight: Math.max(headerTitle.implicitHeight, headerCount.implicitHeight)

                PanelSectionHeader {
                    id: headerTitle
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "AVAILABLE PROFILES"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                }

                Text {
                    id: headerCount
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    visible: vpnService.profiles.length > 0
                    text: vpnService.profiles.length + " saved"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                }
            }

            // 4. Profiles List (Column + Repeater matching Omarchy tailscale panel)
            Column {
                id: profilesColumn
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                    model: vpnService.profiles

                    ProfileItemRow {
                        required property var modelData
                        required property int index
                        width: profilesColumn.width
                        profileName: String(modelData)
                        isActive: vpnService.connected && vpnService.profileName === String(modelData)
                        isDefault: !isActive && vpnService.selectedProfile === String(modelData)
                    }
                }

                Text {
                    visible: vpnService.profiles.length === 0
                    width: parent.width
                    textFormat: Text.PlainText
                    text: "No configurations in ~/.config/grold-omarchy-vpn/profiles/"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    color: root.dim
                    wrapMode: Text.WordWrap
                    topPadding: Style.space(4)
                    bottomPadding: Style.space(4)
                }
            }

            PanelSeparator {
                foreground: root.foreground
            }

            // 5. Footer Action Button (Native Omarchy Button)
            Button {
                width: parent.width
                text: "Open VPN Manager..."
                iconText: "󰢹"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: {
                    root.close()
                    vpnService.openApp()
                }
            }
        }
    }

    // Inline Profile Row using Omarchy's CursorSurface
    component ProfileItemRow: CursorSurface {
        id: pRow
        property string profileName: ""
        property bool isActive: false
        property bool isDefault: false

        width: parent.width
        implicitHeight: Style.space(36)
        foreground: root.foreground
        current: isActive || isDefault
        fill: root.hoverFill
        currentFill: isActive ? root.selectedFill : Style.hoverFillFor(root.foreground, Color.accent)

        Item {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)

            // Radio/Selection Indicator
            Rectangle {
                id: radioDot
                width: Style.space(8)
                height: Style.space(8)
                radius: width / 2
                color: pRow.isActive ? "#22c55e" : (pRow.isDefault ? Color.accent : "transparent")
                border.color: (pRow.isActive || pRow.isDefault) ? "transparent" : root.dim
                border.width: 1.5
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            // Profile Name
            Text {
                id: nameText
                textFormat: Text.PlainText
                text: pRow.profileName
                color: pRow.isActive ? Color.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: pRow.isActive || pRow.isDefault
                elide: Text.ElideRight
                anchors.left: radioDot.right
                anchors.leftMargin: Style.space(10)
                anchors.right: statusBadge.visible ? statusBadge.left : parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Status Badge: "Connected" or "Default"
            Text {
                id: statusBadge
                visible: pRow.isActive || pRow.isDefault
                textFormat: Text.PlainText
                text: pRow.isActive ? "Connected" : "Default"
                color: pRow.isActive ? "#22c55e" : Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: rowMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (vpnService.connected) {
                    if (pRow.isActive) {
                        vpnService.disconnectVpn()
                    } else {
                        vpnService.connectProfile(pRow.profileName)
                    }
                } else {
                    vpnService.saveSelectedProfile(pRow.profileName)
                    vpnService.connectProfile(pRow.profileName)
                }
            }
        }

        PanelToolTip {
            visible: rowMouseArea.containsMouse
            text: pRow.isActive ? "Click to disconnect" : "Click to select and connect"
            fontFamily: root.fontFamily
        }
    }
}
