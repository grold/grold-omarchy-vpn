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
        anchors.margins: 16
        spacing: 16

        // Telemetry cards grid
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 10
            columnSpacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#18181b"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    Label { text: "DOWNLOAD SPEED"; font.pointSize: 9; opacity: 0.7 }
                    Label { text: formatSpeed(backend.rxRate); font.bold: true; font.pointSize: 14; color: "#38bdf8" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#18181b"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    Label { text: "UPLOAD SPEED"; font.pointSize: 9; opacity: 0.7 }
                    Label { text: formatSpeed(backend.txRate); font.bold: true; font.pointSize: 14; color: "#4ade80" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#18181b"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    Label { text: "SESSION DATA"; font.pointSize: 9; opacity: 0.7 }
                    Label {
                        text: "↓ " + formatBytes(backend.rxBytes) + "  ↑ " + formatBytes(backend.txBytes)
                        font.bold: true
                        font.pointSize: 12
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#18181b"
                border.color: "#27272a"
                ColumnLayout {
                    anchors.centerIn: parent
                    Label { text: "UPTIME"; font.pointSize: 9; opacity: 0.7 }
                    Label { text: formatDuration(backend.uptime); font.bold: true; font.pointSize: 14; color: Material.accent }
                }
            }
        }

        // Live speed graph canvas
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 6
            color: "#141416"
            border.color: "#27272a"

            Canvas {
                id: speedCanvas
                anchors.fill: parent
                anchors.margins: 12

                Connections {
                    target: backend
                    function onSpeedHistoryChanged() { speedCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var history = backend.speedHistory
                    if (!history || history.length < 2) {
                        ctx.fillStyle = "#555"
                        ctx.font = "12px sans-serif"
                        ctx.fillText("Waiting for telemetry data...", 10, height / 2)
                        return
                    }

                    var maxRate = 1024 * 1024 // at least 1 MB/s scale
                    for (var i = 0; i < history.length; i++) {
                        if (history[i].rxRate > maxRate) maxRate = history[i].rxRate
                        if (history[i].txRate > maxRate) maxRate = history[i].txRate
                    }

                    // Grid lines
                    ctx.strokeStyle = "#222"
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

        Label { text: "Historical Connection Logs"; font.bold: true; color: Material.accent }

        // Historical logs list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: logList
                width: parent.width
                model: backend.sessionLogs

                delegate: ItemDelegate {
                    width: logList.width
                    contentItem: RowLayout {
                        spacing: 16
                        Label { text: modelData.date || ""; font.pointSize: 10; opacity: 0.6; Layout.preferredWidth: 140 }
                        Label { text: modelData.profile || ""; font.bold: true; Layout.preferredWidth: 150; elide: Text.ElideRight }
                        Label { text: "Duration: " + formatDuration(modelData.duration); Layout.preferredWidth: 120 }
                        Label {
                            text: "↓ " + formatBytes(modelData.rxBytes) + "  ↑ " + formatBytes(modelData.txBytes)
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
