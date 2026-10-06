#include "vpnmanager.h"
#include <QFileInfo>
#include <QFile>
#include <QRegularExpression>
#include <QDebug>

VpnManager::VpnManager(QObject *parent)
    : QObject(parent),
      m_pollTimer(new QTimer(this)) {
    connect(m_pollTimer, &QTimer::timeout, this, &VpnManager::pollStats);
    m_pollTimer->setInterval(1000);
}

VpnManager::~VpnManager() {
    if (m_connected) {
        QString err;
        disconnectTunnel(err);
    }
}

QString VpnManager::findVpnTool(bool amnezia) const {
    if (amnezia) {
        if (QFile::exists("/usr/bin/awg-quick")) return "/usr/bin/awg-quick";
        if (QFile::exists("/usr/local/bin/awg-quick")) return "/usr/local/bin/awg-quick";
    }
    if (QFile::exists("/usr/bin/awg-quick")) return "/usr/bin/awg-quick";
    if (QFile::exists("/usr/bin/wg-quick")) return "/usr/bin/wg-quick";
    return QString();
}

bool VpnManager::connectTunnel(const QString &profilePath, QString &errorMessage) {
    if (m_connected) {
        QString err;
        disconnectTunnel(err);
    }

    QFileInfo fi(profilePath);
    if (!fi.exists()) {
        errorMessage = "Profile configuration file does not exist: " + profilePath;
        return false;
    }

    // Determine if AmneziaWG
    QFile f(profilePath);
    bool isAwg = false;
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString content = QString::fromUtf8(f.readAll());
        if (content.contains("Jc", Qt::CaseInsensitive) || content.contains("H1", Qt::CaseInsensitive)) {
            isAwg = true;
        }
        f.close();
    }

    QString tool = findVpnTool(isAwg);
    if (tool.isEmpty()) {
        errorMessage = "Neither awg-quick nor wg-quick found on system";
        return false;
    }

    // Sanitize interface name to max 15 chars alphanumeric
    QString rawName = fi.completeBaseName();
    QString ifName;
    for (const QChar &ch : rawName) {
        if (ch.isLetterOrNumber()) {
            ifName.append(ch);
            if (ifName.length() >= 15) break;
        }
    }
    if (ifName.isEmpty()) ifName = "groldvpn0";

    QProcess proc;
    proc.start(tool, QStringList{"up", profilePath});
    if (!proc.waitForFinished(10000)) {
        errorMessage = "Timeout starting VPN interface via " + tool;
        return false;
    }

    if (proc.exitCode() != 0) {
        errorMessage = QString::fromUtf8(proc.readAllStandardError()).trimmed();
        if (errorMessage.isEmpty()) {
            errorMessage = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        }
        return false;
    }

    m_connected = true;
    m_activeProfileName = fi.completeBaseName();
    m_activeProfilePath = profilePath;
    m_activeInterface = ifName;
    m_connectTime = QDateTime::currentDateTime();
    m_lastPollTime = QDateTime::currentDateTime();
    m_lastRx = 0;
    m_lastTx = 0;
    m_stats = VpnStats();

    m_pollTimer->start();
    emit stateChanged(true, m_activeProfileName);
    return true;
}

bool VpnManager::disconnectTunnel(QString &errorMessage) {
    if (!m_connected && m_activeProfilePath.isEmpty()) {
        return true;
    }

    m_pollTimer->stop();

    QString tool = findVpnTool(false);
    if (tool.isEmpty()) tool = "/usr/bin/awg-quick";

    QProcess proc;
    proc.start(tool, QStringList{"down", m_activeProfilePath});
    proc.waitForFinished(10000);

    m_connected = false;
    m_activeProfileName.clear();
    m_activeProfilePath.clear();
    m_activeInterface.clear();
    m_stats = VpnStats();

    emit stateChanged(false, QString());
    emit statsUpdated(m_stats);
    return true;
}

void VpnManager::pollStats() {
    if (!m_connected || m_activeInterface.isEmpty()) return;

    QString showTool = QFile::exists("/usr/bin/awg") ? "/usr/bin/awg" : "/usr/bin/wg";
    QProcess proc;
    proc.start(showTool, QStringList{"show", m_activeInterface, "dump"});
    if (!proc.waitForFinished(1000)) return;

    if (proc.exitCode() == 0) {
        parseStatsOutput(QString::fromUtf8(proc.readAllStandardOutput()));
    }
}

void VpnManager::parseStatsOutput(const QString &output) {
    // wg / awg dump output:
    // line 1: interface: private-key public-key listen-port fwmark
    // line 2+: peer: public-key preshared-key endpoint allowed-ips latest-handshake rx-bytes tx-bytes persistent-keepalive
    const QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    if (lines.size() < 2) return;

    qint64 totalRx = 0;
    qint64 totalTx = 0;
    qint64 latestHandshake = 0;

    for (int i = 1; i < lines.size(); ++i) {
        const QStringList fields = lines[i].split('\t');
        if (fields.size() >= 7) {
            qint64 hs = fields[4].toLongLong();
            if (hs > latestHandshake) latestHandshake = hs;
            totalRx += fields[5].toLongLong();
            totalTx += fields[6].toLongLong();
        }
    }

    QDateTime now = QDateTime::currentDateTime();
    qint64 elapsedSec = m_lastPollTime.msecsTo(now) / 1000;
    if (elapsedSec <= 0) elapsedSec = 1;

    qint64 rxRate = 0;
    qint64 txRate = 0;

    if (m_lastRx > 0 && totalRx >= m_lastRx) {
        rxRate = (totalRx - m_lastRx) / elapsedSec;
    }
    if (m_lastTx > 0 && totalTx >= m_lastTx) {
        txRate = (totalTx - m_lastTx) / elapsedSec;
    }

    m_lastRx = totalRx;
    m_lastTx = totalTx;
    m_lastPollTime = now;

    m_stats.rxBytes = totalRx;
    m_stats.txBytes = totalTx;
    m_stats.rxRate = rxRate;
    m_stats.txRate = txRate;
    m_stats.lastHandshakeEpoch = latestHandshake;
    m_stats.uptimeSeconds = m_connectTime.secsTo(now);

    emit statsUpdated(m_stats);
}
