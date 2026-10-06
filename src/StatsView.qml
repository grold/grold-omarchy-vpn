import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(2) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatSpeed(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0) return "0 KB/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(2) + " MB/s"
    }

    function formatDuration(sec) {
        if (!sec || sec <= 0) return "0s"
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        var s = sec % 60
        if (h > 0) return h + "h " + m + "m " + s + "s"
        if (m > 0) return m + "m " + s + "s"
        return s + "s"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        // Live Telemetry Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                height: 80
                radius: 8
                color: "#141416"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: "DOWNLOAD RATE"
                        font.pointSize: 9
                        font.bold: true
                        color: "#71717a"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: formatSpeed(backend.rxRate)
                        font.bold: true
                        font.pointSize: 15
                        color: "#38bdf8"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 80
                radius: 8
                color: "#141416"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: "UPLOAD RATE"
                        font.pointSize: 9
                        font.bold: true
                        color: "#71717a"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: formatSpeed(backend.txRate)
                        font.bold: true
                        font.pointSize: 15
                        color: "#4ade80"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 80
                radius: 8
                color: "#141416"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: "TOTAL TRANSFERRED"
                        font.pointSize: 9
                        font.bold: true
                        color: "#71717a"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: "↓ " + formatBytes(backend.rxBytes) + "  ↑ " + formatBytes(backend.txBytes)
                        font.bold: true
                        font.pointSize: 12
                        color: "#f4f4f5"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 80
                radius: 8
                color: "#141416"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: "ACTIVE UPTIME"
                        font.pointSize: 9
                        font.bold: true
                        color: "#71717a"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: formatDuration(backend.uptime)
                        font.bold: true
                        font.pointSize: 15
                        color: Material.accent
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // Live speed graph canvas
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 8
            color: "#101012"
            border.color: "#27272a"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Throughput Activity (Last 60s)"
                        font.bold: true
                        font.pointSize: 11
                        color: "#a1a1aa"
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 10; height: 10; radius: 5; color: "#38bdf8" }
                    Label { text: "Download"; font.pointSize: 9; color: "#71717a" }
                    Rectangle { width: 10; height: 10; radius: 5; color: "#4ade80"; Layout.leftMargin: 8 }
                    Label { text: "Upload"; font.pointSize: 9; color: "#71717a" }
                }

                Canvas {
                    id: speedCanvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Connections {
                        target: backend
                        function onSpeedHistoryChanged() { speedCanvas.requestPaint() }
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var history = backend.speedHistory
                        if (!history || history.length < 2) {
                            ctx.fillStyle = "#52525b"
                            ctx.font = "12px sans-serif"
                            ctx.fillText("No active network traffic recorded", 14, height / 2)
                            return
                        }

                        var maxRate = 1024 * 1024 // at least 1 MB/s scale
                        for (var i = 0; i < history.length; i++) {
                            if (history[i].rxRate > maxRate) maxRate = history[i].rxRate
                            if (history[i].txRate > maxRate) maxRate = history[i].txRate
                        }

                        // Grid lines
                        ctx.strokeStyle = "#1e1e24"
                        ctx.lineWidth = 1
                        for (var g = 1; g <= 3; g++) {
                            var gy = height * (g / 4)
                            ctx.beginPath()
                            ctx.moveTo(0, gy)
                            ctx.lineTo(width, gy)
                            ctx.stroke()
                        }

                        function drawLine(key, color) {
                            ctx.strokeStyle = color
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            var stepX = width / (history.length - 1)
                            for (var idx = 0; idx < history.length; idx++) {
                                var val = history[idx][key] || 0
                                var x = idx * stepX
                                var y = height - (val / maxRate) * (height - 10)
                                if (idx === 0) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                            }
                            ctx.stroke()
                        }

                        // Rx = Blue, Tx = Green
                        drawLine("rxRate", "#38bdf8")
                        drawLine("txRate", "#4ade80")
                    }
                }
            }
        }

        // Connection History
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Session History"
                font.bold: true
                font.pointSize: 12
                color: Material.accent
            }
            Item { Layout.fillWidth: true }
            Label {
                text: backend.sessionLogs.length + " logged sessions"
                font.pointSize: 10
                opacity: 0.6
            }
        }

        // Historical logs list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#101012"
            border.color: "#27272a"
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 4
                clip: true

                ListView {
                    id: logList
                    width: parent.width
                    model: backend.sessionLogs

                    delegate: Rectangle {
                        width: logList.width
                        height: 42
                        color: index % 2 === 0 ? "transparent" : "#141418"
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 16

                            Label {
                                text: modelData.date || ""
                                font.pointSize: 9
                                opacity: 0.6
                                Layout.preferredWidth: 130
                            }
                            Label {
                                text: modelData.profile || "Unnamed"
                                font.bold: true
                                font.pointSize: 11
                                Layout.preferredWidth: 160
                                elide: Text.ElideRight
                            }
                            Label {
                                text: "Duration: " + formatDuration(modelData.duration)
                                font.pointSize: 10
                                opacity: 0.8
                                Layout.preferredWidth: 120
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: "↓ " + formatBytes(modelData.rxBytes) + "   ↑ " + formatBytes(modelData.txBytes)
                                font.bold: true
                                font.pointSize: 10
                                color: "#a1a1aa"
                            }
                        }
                    }
                }
            }
        }
    }
}
