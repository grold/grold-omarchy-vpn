#include "backend.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDebug>

static QString socketPath() {
    if (QFile::exists("/run/grold-omarchy-vpn/daemon.sock")) {
        return "/run/grold-omarchy-vpn/daemon.sock";
    }
    if (QFile::exists("/tmp/grold-omarchy-vpn-daemon.sock")) {
        return "/tmp/grold-omarchy-vpn-daemon.sock";
    }
    return "/run/grold-omarchy-vpn/daemon.sock";
}

Backend::Backend(QObject *parent)
    : QObject(parent),
      m_pollTimer(new QTimer(this)),
      m_scanner(new AppScanner(this)),
      m_filePicker(new PortalFilePicker(this)) {

    m_installedApps = m_scanner->scanInstalledApps();

    connect(m_filePicker, &PortalFilePicker::fileSelected, this, &Backend::onFileSelected);

    connect(m_pollTimer, &QTimer::timeout, this, &Backend::pollDaemonStatus);
    m_pollTimer->start(1000);

    loadProfiles();
    loadHistory();
    pollDaemonStatus();
}

Backend::~Backend() {
    saveHistory();
}

QString Backend::profilesDir() const {
    QString path = QDir::homePath() + "/.config/grold-omarchy-vpn/profiles";
    QDir().mkpath(path);
    return path;
}

QString Backend::historyFilePath() const {
    QString dir = QDir::homePath() + "/.local/share/grold-omarchy-vpn";
    QDir().mkpath(dir);
    return dir + "/history.json";
}

void Backend::loadProfiles() {
    m_profiles.clear();
    QDir dir(profilesDir());
    const QStringList confFiles = dir.entryList(QStringList() << "*.conf", QDir::Files);

    for (const QString &file : confFiles) {
        QString fullPath = dir.absoluteFilePath(file);
        VpnProfile profile = VpnProfile::loadFromFile(fullPath);
        m_profiles.append(profile.toJson().toVariantMap());
    }

    emit profilesChanged();
}

void Backend::loadHistory() {
    m_sessionLogs.clear();
    QFile file(historyFilePath());
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isArray()) {
            m_sessionLogs = doc.array().toVariantList();
        }
    }
    emit sessionLogsChanged();
}

void Backend::saveHistory() {
    QFile file(historyFilePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(QJsonArray::fromVariantList(m_sessionLogs)).toJson(QJsonDocument::Indented));
    }
}

void Backend::appendSpeedPoint(qint64 rxRate, qint64 txRate) {
    QVariantMap pt;
    pt["rxRate"] = rxRate;
    pt["txRate"] = txRate;
    pt["time"] = QDateTime::currentDateTime().toString("HH:mm:ss");

    m_speedHistory.append(pt);
    if (m_speedHistory.size() > 60) {
        m_speedHistory.removeFirst();
    }
    emit speedHistoryChanged();
}

void Backend::recordSessionLog(const QString &profile, qint64 duration, qint64 rx, qint64 tx) {
    if (duration <= 0 && rx <= 0 && tx <= 0) return;

    QVariantMap entry;
    entry["profile"] = profile;
    entry["date"] = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm");
    entry["duration"] = duration;
    entry["rxBytes"] = rx;
    entry["txBytes"] = tx;

    m_sessionLogs.prepend(entry);
    if (m_sessionLogs.size() > 200) {
        m_sessionLogs.removeLast();
    }
    emit sessionLogsChanged();
    saveHistory();
}

QJsonObject Backend::sendDaemonCommand(const QJsonObject &req) {
    QLocalSocket socket;
    socket.connectToServer(socketPath());
    if (!socket.waitForConnected(500)) {
        if (m_daemonAvailable) {
            m_daemonAvailable = false;
            emit daemonAvailableChanged();
        }
        QJsonObject err;
        err["ok"] = false;
        err["error"] = "Daemon not running";
        return err;
    }

    if (!m_daemonAvailable) {
        m_daemonAvailable = true;
        emit daemonAvailableChanged();
    }

    socket.write(QJsonDocument(req).toJson(QJsonDocument::Compact) + "\n");
    socket.flush();

    if (!socket.waitForReadyRead(3000)) {
        QJsonObject err;
        err["ok"] = false;
        err["error"] = "Timeout communicating with daemon";
        return err;
    }

    QByteArray data = socket.readLine();
    return QJsonDocument::fromJson(data).object();
}

void Backend::pollDaemonStatus() {
    QJsonObject req;
    req["cmd"] = "status";
    QJsonObject res = sendDaemonCommand(req);

    if (!res["ok"].toBool()) {
        if (m_connected) {
            recordSessionLog(m_activeProfileName, m_uptime, m_rxBytes, m_txBytes);
            m_connected = false;
            emit connectedChanged();
        }
        return;
    }

    QJsonObject st = res["status"].toObject();
    bool conn = st["connected"].toBool();
    QString prof = st["profileName"].toString();
    QString iface = st["interface"].toString();
    qint64 rx = st["rxBytes"].toInteger();
    qint64 tx = st["txBytes"].toInteger();
    qint64 rxR = st["rxRate"].toInteger();
    qint64 txR = st["txRate"].toInteger();
    qint64 up = st["uptime"].toInteger();
    qint64 hs = st["lastHandshake"].toInteger();
    QString sm = st["splitMode"].toString();
    bool ks = st["killSwitch"].toBool();

    if (m_connected && !conn) {
        recordSessionLog(m_activeProfileName, m_uptime, m_rxBytes, m_txBytes);
    }

    if (m_connected != conn) {
        m_connected = conn;
        emit connectedChanged();
    }
    if (m_activeProfileName != prof) {
        m_activeProfileName = prof;
        emit activeProfileNameChanged();
    }
    if (m_activeInterface != iface) {
        m_activeInterface = iface;
        emit activeInterfaceChanged();
    }
    if (m_splitMode != sm) {
        m_splitMode = sm;
        emit splitModeChanged();
    }
    if (m_killSwitch != ks) {
        m_killSwitch = ks;
        emit killSwitchChanged();
    }

    m_rxBytes = rx;
    m_txBytes = tx;
    m_rxRate = rxR;
    m_txRate = txR;
    m_uptime = up;
    m_lastHandshake = hs;
    emit statsChanged();

    if (conn) {
        appendSpeedPoint(rxR, txR);
    }
}

void Backend::refresh() {
    loadProfiles();
    pollDaemonStatus();
}

void Backend::connectProfile(const QString &name) {
    QString path = profilesDir() + "/" + name + ".conf";
    if (!QFile::exists(path)) return;

    VpnProfile p = VpnProfile::loadFromFile(path);

    QJsonObject req;
    req["cmd"] = "connect";
    req["profile"] = path;
    req["splitMode"] = p.splitMode;
    req["killSwitch"] = p.killSwitch;
    req["splitApps"] = QJsonArray::fromStringList(p.splitApps);
    req["splitIps"] = QJsonArray::fromStringList(p.splitIps);

    QJsonObject res = sendDaemonCommand(req);
    if (!res["ok"].toBool()) {
        m_statusMessage = "Connection failed: " + res["error"].toString();
        emit statusMessageChanged();
    } else {
        m_statusMessage = "Connected to " + name;
        emit statusMessageChanged();
        pollDaemonStatus();
    }
}

void Backend::disconnectVpn() {
    QJsonObject req;
    req["cmd"] = "disconnect";
    QJsonObject res = sendDaemonCommand(req);
    if (res["ok"].toBool()) {
        m_statusMessage = "Disconnected";
        emit statusMessageChanged();
        pollDaemonStatus();
    }
}

void Backend::toggleConnection(const QString &profileName) {
    if (m_connected) {
        disconnectVpn();
    } else {
        QString target = profileName.isEmpty() ?
            (m_profiles.isEmpty() ? QString() : m_profiles.first().toMap()["name"].toString())
            : profileName;
        if (!target.isEmpty()) {
            connectProfile(target);
        }
    }
}

bool Backend::saveProfile(const QString &name, const QString &confContent,
                         const QString &splitMode, bool killSwitch,
                         const QStringList &apps, const QStringList &ips) {
    if (name.trimmed().isEmpty()) return false;

    QString cleanName = name.trimmed();
    QString confPath = profilesDir() + "/" + cleanName + ".conf";

    VpnProfile profile = VpnProfile::fromConf(cleanName, confContent);
    profile.splitMode = splitMode;
    profile.killSwitch = killSwitch;
    profile.splitApps = apps;
    profile.splitIps = ips;

    bool saved = profile.saveToFile(confPath);
    if (saved) {
        loadProfiles();
        m_statusMessage = "Profile " + cleanName + " saved";
        emit statusMessageChanged();
    }
    return saved;
}

bool Backend::deleteProfile(const QString &name) {
    QString confPath = profilesDir() + "/" + name + ".conf";
    QString metaPath = profilesDir() + "/" + name + ".meta.json";

    QFile::remove(confPath);
    QFile::remove(metaPath);
    loadProfiles();

    m_statusMessage = "Profile " + name + " deleted";
    emit statusMessageChanged();
    return true;
}

bool Backend::importConf(const QString &filePath) {
    QString cleanPath = filePath;
    if (cleanPath.startsWith("file://")) {
        QUrl u(cleanPath);
        cleanPath = u.toLocalFile();
    }
    QFileInfo fi(cleanPath);
    if (!fi.exists()) {
        emit fileImportError("Selected file does not exist: " + cleanPath);
        return false;
    }

    VpnProfile profile = VpnProfile::loadFromFile(cleanPath);
    profile.name = fi.completeBaseName();
    QString destPath = profilesDir() + "/" + profile.name + ".conf";

    if (profile.saveToFile(destPath)) {
        loadProfiles();
        m_statusMessage = "Imported " + profile.name;
        emit statusMessageChanged();
        emit fileImportSuccess(profile.name);
        return true;
    } else {
        emit fileImportError("Failed to write imported profile");
        return false;
    }
}

void Backend::setKillSwitch(bool enabled) {
    QJsonObject req;
    req["cmd"] = "killswitch";
    req["enabled"] = enabled;
    sendDaemonCommand(req);
    pollDaemonStatus();
}

void Backend::setSplitTunnel(const QString &mode, const QStringList &apps, const QStringList &ips) {
    QJsonObject req;
    req["cmd"] = "splittunnel";
    req["mode"] = mode;
    req["apps"] = QJsonArray::fromStringList(apps);
    req["ips"] = QJsonArray::fromStringList(ips);
    sendDaemonCommand(req);
    pollDaemonStatus();
}

QVariantMap Backend::getProfile(const QString &name) {
    for (const auto &v : m_profiles) {
        QVariantMap m = v.toMap();
        if (m["name"].toString() == name) return m;
    }
    return QVariantMap();
}

QString Backend::readProfileConf(const QString &name) {
    QString confPath = profilesDir() + "/" + name + ".conf";
    QFile f(confPath);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString::fromUtf8(f.readAll());
    }
    return QString();
}

void Backend::requestImportDialog() {
    m_filePicker->openFile("Import WireGuard / AmneziaWG Configuration",
                           "VPN Configurations (*.conf)",
                           QStringList{"*.conf"});
}

void Backend::onFileSelected(const QString &path) {
    importConf(path);
}
