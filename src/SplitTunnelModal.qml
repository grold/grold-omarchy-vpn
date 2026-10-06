import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Dialog {
    id: root
    title: "Configure Split Tunneling"
    modal: true
    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 720)
    height: Math.min(parent.height - 40, 640)

    Material.theme: Material.Dark
    Material.accent: theme.accent

    property string profileName: ""
    property string currentMode: "off"
    property var selectedApps: []
    property var customIps: []

    onOpened: {
        modeOffRadio.checked = (currentMode === "off")
        modeExclusiveRadio.checked = (currentMode === "exclusive")
        modeInclusiveRadio.checked = (currentMode === "inclusive")
        ipModel.clear()
        for (var i = 0; i < customIps.length; i++) {
            ipModel.append({ ip: customIps[i] })
        }
    }

    ListModel { id: ipModel }

    contentItem: ColumnLayout {
        spacing: 14

        Label {
            text: "Profile: " + (profileName ? profileName : "Active Session")
            font.bold: true
            color: Material.accent
        }

        GroupBox {
            title: "Routing Mode"
            Layout.fillWidth: true

            RowLayout {
                spacing: 20
                RadioButton {
                    id: modeOffRadio
                    text: "Off (All traffic via VPN)"
                }
                RadioButton {
                    id: modeExclusiveRadio
                    text: "Bypass / Exclusive\n(VPN by default, bypass selected)"
                }
                RadioButton {
                    id: modeInclusiveRadio
                    text: "Inclusive\n(Direct by default, route selected via VPN)"
                }
            }
        }

        TabBar {
            id: splitTab
            Layout.fillWidth: true
            TabButton { text: "Applications (" + selectedApps.length + " selected)" }
            TabButton { text: "IP / CIDR Ranges (" + ipModel.count + ")" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: splitTab.currentIndex

            // Applications selector
            ColumnLayout {
                spacing: 8

                TextField {
                    id: appSearch
                    Layout.fillWidth: true
                    placeholderText: "Search applications..."
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: backend.installedApps

                    delegate: ItemDelegate {
                        width: appList.width
                        visible: modelData.name.toLowerCase().indexOf(appSearch.text.toLowerCase()) !== -1
                        height: visible ? 46 : 0

                        contentItem: RowLayout {
                            spacing: 12
                            CheckBox {
                                checked: root.selectedApps.indexOf(modelData.id) !== -1
                                onToggled: {
                                    var arr = root.selectedApps.slice()
                                    var idx = arr.indexOf(modelData.id)
                                    if (checked && idx === -1) {
                                        arr.push(modelData.id)
                                    } else if (!checked && idx !== -1) {
                                        arr.splice(idx, 1)
                                    }
                                    root.selectedApps = arr
                                }
                            }
                            ColumnLayout {
                                spacing: 2
                                Label { text: modelData.name; font.bold: true }
                                Label { text: modelData.exec; font.pointSize: 9; opacity: 0.6; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }

            // IP / CIDR ranges selector
            ColumnLayout {
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: newIpInput
                        Layout.fillWidth: true
                        placeholderText: "e.g. 192.168.1.0/24, 10.0.0.1, 1.1.1.1"
                    }
                    Button {
                        text: "Add Range"
                        onClicked: {
                            var val = newIpInput.text.trim()
                            if (val !== "") {
                                ipModel.append({ ip: val })
                                newIpInput.text = ""
                            }
                        }
                    }
                }

                ListView {
                    id: ipListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ipModel
                    delegate: ItemDelegate {
                        width: ipListView.width
                        contentItem: RowLayout {
                            Label { text: model.ip; Layout.fillWidth: true; font.family: "Monospace" }
                            ToolButton {
                                text: "✕"
                                onClicked: ipModel.remove(index)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                onClicked: root.close()
            }
            Button {
                text: "Apply"
                highlighted: true
                onClicked: {
                    var m = "off"
                    if (modeExclusiveRadio.checked) m = "exclusive"
                    else if (modeInclusiveRadio.checked) m = "inclusive"

                    var ips = []
                    for (var i = 0; i < ipModel.count; i++) {
                        ips.push(ipModel.get(i).ip)
                    }

                    if (root.profileName) {
                        var prof = backend.getProfile(root.profileName)
                        var conf = backend.readProfileConf(root.profileName)
                        backend.saveProfile(root.profileName, conf, m, prof.killSwitch, root.selectedApps, ips)
                    }
                    backend.setSplitTunnel(m, root.selectedApps, ips)
                    root.close()
                }
            }
        }
    }
}
