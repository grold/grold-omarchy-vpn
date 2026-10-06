import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool connected: false
    property string profileName: ""
    property string activeInterface: ""
    property real rxBytes: 0
    property real txBytes: 0
    property real rxRate: 0
    property real txRate: 0
    property real uptime: 0
    property string splitMode: "off"
    property bool killSwitch: false
    property var profiles: []
    property string selectedProfile: ""
    property bool refreshing: false

    property string _targetProfileToConnect: ""
    property string _targetToggleArg: ""

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return "0 B"
        var k = 1024
        var sizes = ["B", "KB", "MB", "GB", "TB"]
        var i = Math.floor(Math.log(bytes) / Math.log(k))
        if (i < 0) i = 0
        if (i >= sizes.length) i = sizes.length - 1
        return (bytes / Math.pow(k, i)).toFixed(i === 0 ? 0 : 1) + " " + sizes[i]
    }

    function formatRate(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0) return "0 KB/s"
        if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        }
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            root.refresh()
            root.refreshProfiles()
        }
    }

    Component.onCompleted: {
        root.loadSelectedProfile()
        root.refresh()
        root.refreshProfiles()
    }

    function loadSelectedProfile() {
        if (!readSelectedProcess.running) {
            readSelectedProcess.running = true
        }
    }

    function saveSelectedProfile(name) {
        root.selectedProfile = name
        var home = Quickshell.env("HOME")
        var dir = home + "/.config/grold-omarchy-vpn"
        writeSelectedProcess.command = ["sh", "-c", "mkdir -p '" + dir + "' && printf '%s' '" + name + "' > '" + dir + "/default-profile'"]
        if (!writeSelectedProcess.running) {
            writeSelectedProcess.running = true
        }
    }

    function refresh() {
        if (!statusProcess.running) {
            statusProcess.running = true
        }
    }

    function refreshProfiles() {
        if (!profilesListProcess.running) {
            profilesListProcess.stdout.collected = []
            profilesListProcess.running = true
        }
    }

    function toggle() {
        if (root.connected) {
            _targetToggleArg = ""
        } else {
            var home = Quickshell.env("HOME")
            var prof = root.selectedProfile || root.profileName
            if (!prof && root.profiles && root.profiles.length > 0) {
                prof = root.profiles[0]
            }
            _targetToggleArg = prof ? (home + "/.config/grold-omarchy-vpn/profiles/" + prof + ".conf") : ""
        }
        if (!toggleProcess.running) {
            toggleProcess.running = true
        }
    }

    function connectProfile(name) {
        saveSelectedProfile(name)
        var home = Quickshell.env("HOME")
        var path = home + "/.config/grold-omarchy-vpn/profiles/" + name + ".conf"
        _targetProfileToConnect = path
        if (!connectProcess.running) {
            connectProcess.running = true
        }
    }

    function disconnectVpn() {
        if (!disconnectProcess.running) {
            disconnectProcess.running = true
        }
    }

    function openApp() {
        if (!appProcess.running) {
            appProcess.running = true
        }
    }

    Process {
        id: statusProcess
        command: ["grold-omarchy-vpn-ctl", "--json", "status"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var doc = JSON.parse(line)
                    if (doc && doc.ok && doc.status) {
                        var st = doc.status
                        root.connected = st.connected === true
                        if (st.profileName) {
                            root.profileName = st.profileName
                            if (!root.selectedProfile) root.selectedProfile = st.profileName
                        }
                        root.activeInterface = st.interface || ""
                        root.rxBytes = st.rxBytes || 0
                        root.txBytes = st.txBytes || 0
                        root.rxRate = st.rxRate || 0
                        root.txRate = st.txRate || 0
                        root.uptime = st.uptime || 0
                        root.splitMode = st.splitMode || "off"
                        root.killSwitch = st.killSwitch === true
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: readSelectedProcess
        command: ["sh", "-c", "cat \"$HOME/.config/grold-omarchy-vpn/default-profile\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: function(line) {
                var name = String(line || "").trim()
                if (name !== "") root.selectedProfile = name
            }
        }
    }

    Process {
        id: writeSelectedProcess
        command: ["true"]
    }

    Process {
        id: toggleProcess
        command: root._targetToggleArg !== "" ? ["grold-omarchy-vpn-ctl", "toggle", root._targetToggleArg] : ["grold-omarchy-vpn-ctl", "toggle"]
        onExited: function(code) {
            root.refresh()
            root.refreshProfiles()
        }
    }

    Process {
        id: connectProcess
        command: ["grold-omarchy-vpn-ctl", "connect", root._targetProfileToConnect]
        onExited: function(code) {
            root.refresh()
            root.refreshProfiles()
        }
    }

    Process {
        id: disconnectProcess
        command: ["grold-omarchy-vpn-ctl", "disconnect"]
        onExited: function(code) {
            root.refresh()
            root.refreshProfiles()
        }
    }

    Process {
        id: profilesListProcess
        command: ["sh", "-c", "ls -1 \"$HOME/.config/grold-omarchy-vpn/profiles/\" 2>/dev/null | grep '\\.conf$' | sed 's/\\.conf$//'"]
        stdout: SplitParser {
            property var collected: []
            onRead: function(line) {
                var name = String(line || "").trim()
                if (name !== "") collected.push(name)
            }
        }
        onExited: function(code) {
            root.profiles = profilesListProcess.stdout.collected.slice()
            profilesListProcess.stdout.collected = []
            if (!root.selectedProfile && root.profiles.length > 0) {
                root.selectedProfile = root.profiles[0]
            }
        }
    }

    Process {
        id: appProcess
        command: ["grold-omarchy-vpn"]
    }
}
