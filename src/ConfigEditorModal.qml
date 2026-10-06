import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Dialog {
    id: root
    title: isNew ? "Create VPN Profile" : "Edit VPN Profile"
    modal: true
    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 780)
    height: Math.min(parent.height - 40, 680)

    property bool isNew: false
    property string profileName: ""
    property string initialConf: ""
    property string splitMode: "off"
    property bool killSwitch: false
    property var splitApps: []
    property var splitIps: []

    property var extraProps: ({})

    onOpened: {
        rawEditor.text = initialConf
        if (isNew && initialConf === "") {
            rawEditor.text = "[Interface]\nPrivateKey = \nAddress = 10.0.0.2/32\nDNS = 1.1.1.1\n\n[Peer]\nPublicKey = \nEndpoint = \nAllowedIPs = 0.0.0.0/0\n"
        }
        nameInput.text = profileName
        loadFieldsFromConf(rawEditor.text)
    }

    function loadFieldsFromConf(text) {
        var lines = text.split(/\r?\n/)
        var section = ""
        extraProps = {}
        for (var i = 0; i < lines.length; i++) {
            var rawLine = lines[i].trim()
            if (rawLine === "" || rawLine.startsWith("#")) continue
            if (rawLine === "[Interface]") { section = "Interface"; continue; }
            if (rawLine === "[Peer]") { section = "Peer"; continue; }
            var eq = rawLine.indexOf("=")
            if (eq === -1) continue
            var k = rawLine.substring(0, eq).trim().toLowerCase()
            var origKey = rawLine.substring(0, eq).trim()
            var v = rawLine.substring(eq + 1).trim()
            if (section === "Interface") {
                if (k === "privatekey") privKeyInput.text = v
                else if (k === "address") addrInput.text = v
                else if (k === "dns") dnsInput.text = v
                else if (k === "listenport") portInput.text = v
                else if (k === "mtu") mtuInput.text = v
                else if (k === "jc") jcInput.text = v
                else if (k === "jmin") jminInput.text = v
                else if (k === "jmax") jmaxInput.text = v
                else if (k === "s1") s1Input.text = v
                else if (k === "s2") s2Input.text = v
                else if (k === "s3") s3Input.text = v
                else if (k === "s4") s4Input.text = v
                else if (k === "h1") h1Input.text = v
                else if (k === "h2") h2Input.text = v
                else if (k === "h3") h3Input.text = v
                else if (k === "h4") h4Input.text = v
                else if (k === "i1") i1Input.text = v
                else if (k === "i2") i2Input.text = v
                else extraProps[origKey] = v
            } else if (section === "Peer") {
                if (k === "publickey") pubKeyInput.text = v
                else if (k === "presharedkey") pskInput.text = v
                else if (k === "endpoint") endpointInput.text = v
                else if (k === "allowedips") allowedIpsInput.text = v
                else if (k === "persistentkeepalive") keepaliveInput.text = v
            }
        }
    }

    function buildConfFromFields() {
        var out = "[Interface]\n"
        if (privKeyInput.text) out += "PrivateKey = " + privKeyInput.text + "\n"
        if (addrInput.text) out += "Address = " + addrInput.text + "\n"
        if (dnsInput.text) out += "DNS = " + dnsInput.text + "\n"
        if (portInput.text) out += "ListenPort = " + portInput.text + "\n"
        if (mtuInput.text) out += "MTU = " + mtuInput.text + "\n"
        if (jcInput.text) out += "Jc = " + jcInput.text + "\n"
        if (jminInput.text) out += "Jmin = " + jminInput.text + "\n"
        if (jmaxInput.text) out += "Jmax = " + jmaxInput.text + "\n"
        if (s1Input.text) out += "S1 = " + s1Input.text + "\n"
        if (s2Input.text) out += "S2 = " + s2Input.text + "\n"
        if (s3Input.text) out += "S3 = " + s3Input.text + "\n"
        if (s4Input.text) out += "S4 = " + s4Input.text + "\n"
        if (h1Input.text) out += "H1 = " + h1Input.text + "\n"
        if (h2Input.text) out += "H2 = " + h2Input.text + "\n"
        if (h3Input.text) out += "H3 = " + h3Input.text + "\n"
        if (h4Input.text) out += "H4 = " + h4Input.text + "\n"
        if (i1Input.text) out += "I1 = " + i1Input.text + "\n"
        if (i2Input.text) out += "I2 = " + i2Input.text + "\n"

        for (var prop in extraProps) {
            out += prop + " = " + extraProps[prop] + "\n"
        }

        out += "\n[Peer]\n"
        if (pubKeyInput.text) out += "PublicKey = " + pubKeyInput.text + "\n"
        if (pskInput.text) out += "PresharedKey = " + pskInput.text + "\n"
        if (endpointInput.text) out += "Endpoint = " + endpointInput.text + "\n"
        if (allowedIpsInput.text) out += "AllowedIPs = " + allowedIpsInput.text + "\n"
        if (keepaliveInput.text) out += "PersistentKeepalive = " + keepaliveInput.text + "\n"
        return out
    }

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label { text: "Profile Name:"; font.bold: true }
            TextField {
                id: nameInput
                Layout.fillWidth: true
                placeholderText: "e.g. home-vpn or amnezia-work"
                enabled: root.isNew
            }
        }

        TabBar {
            id: editorTabBar
            Layout.fillWidth: true
            currentIndex: 0
            onCurrentIndexChanged: {
                if (currentIndex === 1) {
                    rawEditor.text = buildConfFromFields()
                } else {
                    loadFieldsFromConf(rawEditor.text)
                }
            }

            TabButton { text: "Form Editor" }
            TabButton { text: "Raw .conf" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: editorTabBar.currentIndex

            // Form Tab
            ScrollView {
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: root.width - 70
                    spacing: 12

                    Label { text: "Interface (WireGuard & AmneziaWG)"; font.bold: true; color: Material.accent }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Private Key:"; Layout.preferredWidth: 100 }
                        TextField { id: privKeyInput; Layout.fillWidth: true; echoMode: TextInput.PasswordEchoOnEdit }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Address:"; Layout.preferredWidth: 100 }
                        TextField { id: addrInput; Layout.fillWidth: true; placeholderText: "10.0.0.2/32, fd00::2/128" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "DNS:"; Layout.preferredWidth: 100 }
                        TextField { id: dnsInput; Layout.fillWidth: true; placeholderText: "1.1.1.1, 8.8.8.8" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "ListenPort:"; Layout.preferredWidth: 100 }
                        TextField { id: portInput; Layout.preferredWidth: 150; placeholderText: "51820" }
                        Label { text: "MTU:"; Layout.preferredWidth: 60 }
                        TextField { id: mtuInput; Layout.fillWidth: true; placeholderText: "1420" }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#333" }
                    Label { text: "AmneziaWG Obfuscation Parameters (AWG 3.1)"; font.bold: true; color: Material.accent }

                    GridLayout {
                        columns: 4
                        Layout.fillWidth: true
                        rowSpacing: 6
                        columnSpacing: 8

                        Label { text: "Jc (Junk Packets):" }
                        TextField { id: jcInput; placeholderText: "e.g. 4" }
                        Label { text: "Jmin / Jmax (Bytes):" }
                        RowLayout {
                            TextField { id: jminInput; placeholderText: "50"; Layout.preferredWidth: 70 }
                            TextField { id: jmaxInput; placeholderText: "1000"; Layout.preferredWidth: 70 }
                        }

                        Label { text: "S1 / S2 (Bytes):" }
                        RowLayout {
                            TextField { id: s1Input; placeholderText: "15"; Layout.preferredWidth: 70 }
                            TextField { id: s2Input; placeholderText: "30"; Layout.preferredWidth: 70 }
                        }
                        Label { text: "H1 / H2 (Header):" }
                        RowLayout {
                            TextField { id: h1Input; placeholderText: "H1"; Layout.preferredWidth: 70 }
                            TextField { id: h2Input; placeholderText: "H2"; Layout.preferredWidth: 70 }
                        }

                        Label { text: "H3 / H4 (Header):" }
                        RowLayout {
                            TextField { id: h3Input; placeholderText: "H3"; Layout.preferredWidth: 70 }
                            TextField { id: h4Input; placeholderText: "H4"; Layout.preferredWidth: 70 }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#333" }
                    Label { text: "Peer"; font.bold: true; color: Material.accent }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Public Key:"; Layout.preferredWidth: 100 }
                        TextField { id: pubKeyInput; Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Endpoint:"; Layout.preferredWidth: 100 }
                        TextField { id: endpointInput; Layout.fillWidth: true; placeholderText: "vpn.example.com:51820" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "AllowedIPs:"; Layout.preferredWidth: 100 }
                        TextField { id: allowedIpsInput; Layout.fillWidth: true; placeholderText: "0.0.0.0/0, ::/0" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Preshared Key:"; Layout.preferredWidth: 100 }
                        TextField { id: pskInput; Layout.fillWidth: true; echoMode: TextInput.PasswordEchoOnEdit }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Keepalive:"; Layout.preferredWidth: 100 }
                        TextField { id: keepaliveInput; Layout.preferredWidth: 120; placeholderText: "25" }
                    }
                }
            }

            // Raw .conf Tab
            ScrollView {
                clip: true
                TextArea {
                    id: rawEditor
                    font.family: "Monospace"
                    font.pointSize: 11
                    wrapMode: TextEdit.NoWrap
                    selectByMouse: true
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
                text: "Save Profile"
                highlighted: true
                onClicked: {
                    var finalConf = (editorTabBar.currentIndex === 0) ? buildConfFromFields() : rawEditor.text
                    var finalName = nameInput.text.trim()
                    if (finalName === "") return
                    backend.saveProfile(finalName, finalConf, root.splitMode, root.killSwitch, root.splitApps, root.splitIps)
                    root.close()
                }
            }
        }
    }
}
