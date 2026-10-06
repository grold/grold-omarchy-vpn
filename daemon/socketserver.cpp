#include "socketserver.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QFileInfo>
#include <QDir>
#include <QFile>
#include <QDebug>
#include <sys/stat.h>

SocketServer::SocketServer(VpnManager *vpnMgr, RoutingManager *routingMgr, QObject *parent)
    : QObject(parent),
      m_vpnMgr(vpnMgr),
      m_routingMgr(routingMgr),
      m_server(new QLocalServer(this)) {
    connect(m_server, &QLocalServer::newConnection, this, &SocketServer::onNewConnection);
}

SocketServer::~SocketServer() {
    stopServer();
}

QString SocketServer::defaultSocketPath() {
    // If running as root, prefer /run/grold-omarchy-vpn/daemon.sock
    // If not writable, fall back to /tmp/grold-omarchy-vpn-daemon.sock
    QString preferred = "/run/grold-omarchy-vpn/daemon.sock";
    QFileInfo fi("/run");
    if (fi.isWritable() || QDir("/run/grold-omarchy-vpn").exists()) {
        return preferred;
    }
    return "/tmp/grold-omarchy-vpn-daemon.sock";
}

bool SocketServer::startServer(const QString &socketPath) {
    m_socketPath = socketPath.isEmpty() ? defaultSocketPath() : socketPath;

    QFileInfo fi(m_socketPath);
    QDir().mkpath(fi.absolutePath());

    // Clean up stale socket file if it exists
    QFile::remove(m_socketPath);

    if (!m_server->listen(m_socketPath)) {
        qWarning() << "Failed to listen on socket" << m_socketPath << ":" << m_server->errorString();
        return false;
    }

    // Set socket file permissions to 0666 so any user/GUI client can connect
    chmod(m_socketPath.toUtf8().constData(), 0666);
    return true;
}

void SocketServer::stopServer() {
    if (m_server && m_server->isListening()) {
        m_server->close();
        QFile::remove(m_socketPath);
    }
}

void SocketServer::onNewConnection() {
    while (m_server->hasPendingConnections()) {
        QLocalSocket *client = m_server->nextPendingConnection();
        m_clients.append(client);
        connect(client, &QLocalSocket::readyRead, this, &SocketServer::onClientReadyRead);
        connect(client, &QLocalSocket::disconnected, this, &SocketServer::onClientDisconnected);
    }
}

void SocketServer::onClientDisconnected() {
    QLocalSocket *client = qobject_cast<QLocalSocket*>(sender());
    if (client) {
        m_clients.removeAll(client);
        client->deleteLater();
    }
}

void SocketServer::onClientReadyRead() {
    QLocalSocket *client = qobject_cast<QLocalSocket*>(sender());
    if (!client) return;

    QByteArray data = client->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        QJsonObject err;
        err["ok"] = false;
        err["error"] = "Invalid JSON request";
        client->write(QJsonDocument(err).toJson(QJsonDocument::Compact) + "\n");
        client->flush();
        return;
    }

    QByteArray response = handleMessage(doc.object());
    client->write(response + "\n");
    client->flush();
}

QJsonObject SocketServer::getStatusJson() const {
    QJsonObject obj;
    bool connected = m_vpnMgr->isConnected();
    VpnStats stats = m_vpnMgr->currentStats();

    obj["connected"] = connected;
    obj["profileName"] = m_vpnMgr->activeProfileName();
    obj["profilePath"] = m_vpnMgr->activeProfilePath();
    obj["interface"] = m_vpnMgr->activeInterface();
    obj["rxBytes"] = stats.rxBytes;
    obj["txBytes"] = stats.txBytes;
    obj["rxRate"] = stats.rxRate;
    obj["txRate"] = stats.txRate;
    obj["uptime"] = stats.uptimeSeconds;
    obj["lastHandshake"] = stats.lastHandshakeEpoch;
    obj["splitMode"] = m_activeSplitMode;
    obj["splitApps"] = QJsonArray::fromStringList(m_activeSplitApps);
    obj["splitIps"] = QJsonArray::fromStringList(m_activeSplitIps);
    obj["killSwitch"] = m_activeKillSwitch;

    return obj;
}

QByteArray SocketServer::handleMessage(const QJsonObject &req) {
    QString cmd = req["cmd"].toString();
    QJsonObject res;
    res["cmd"] = cmd;

    if (cmd == "ping") {
        res["ok"] = true;
        res["pong"] = true;
    } else if (cmd == "status") {
        res["ok"] = true;
        res["status"] = getStatusJson();
    } else if (cmd == "connect") {
        QString profilePath = req["profile"].toString();
        if (req.contains("splitMode")) m_activeSplitMode = req["splitMode"].toString();
        if (req.contains("killSwitch")) m_activeKillSwitch = req["killSwitch"].toBool();
        if (req.contains("splitApps")) {
            m_activeSplitApps.clear();
            for (const auto &v : req["splitApps"].toArray()) m_activeSplitApps.append(v.toString());
        }
        if (req.contains("splitIps")) {
            m_activeSplitIps.clear();
            for (const auto &v : req["splitIps"].toArray()) m_activeSplitIps.append(v.toString());
        }

        QString errorMsg;
        bool ok = m_vpnMgr->connectTunnel(profilePath, errorMsg);
        res["ok"] = ok;
        if (!ok) {
            res["error"] = errorMsg;
        } else {
            m_routingMgr->applyRouting(m_vpnMgr->activeInterface(), m_activeSplitMode,
                                       m_activeSplitApps, m_activeSplitIps,
                                       m_activeKillSwitch, true);
            res["status"] = getStatusJson();
        }
    } else if (cmd == "disconnect") {
        QString errorMsg;
        bool ok = m_vpnMgr->disconnectTunnel(errorMsg);
        m_routingMgr->applyRouting("", m_activeSplitMode, m_activeSplitApps,
                                   m_activeSplitIps, m_activeKillSwitch, false);
        res["ok"] = ok;
        if (!ok) res["error"] = errorMsg;
        res["status"] = getStatusJson();
    } else if (cmd == "toggle") {
        if (m_vpnMgr->isConnected()) {
            QString errorMsg;
            m_vpnMgr->disconnectTunnel(errorMsg);
            m_routingMgr->applyRouting("", m_activeSplitMode, m_activeSplitApps,
                                       m_activeSplitIps, m_activeKillSwitch, false);
            res["ok"] = true;
        } else {
            QString profilePath = req["profile"].toString();
            QString errorMsg;
            bool ok = m_vpnMgr->connectTunnel(profilePath, errorMsg);
            res["ok"] = ok;
            if (!ok) res["error"] = errorMsg;
            else {
                m_routingMgr->applyRouting(m_vpnMgr->activeInterface(), m_activeSplitMode,
                                           m_activeSplitApps, m_activeSplitIps,
                                           m_activeKillSwitch, true);
            }
        }
        res["status"] = getStatusJson();
    } else if (cmd == "killswitch") {
        m_activeKillSwitch = req["enabled"].toBool();
        m_routingMgr->setKillSwitch(m_activeKillSwitch, m_vpnMgr->isConnected(), m_vpnMgr->activeInterface());
        res["ok"] = true;
        res["status"] = getStatusJson();
    } else if (cmd == "splittunnel") {
        m_activeSplitMode = req["mode"].toString("off");
        m_activeSplitApps.clear();
        for (const auto &v : req["apps"].toArray()) m_activeSplitApps.append(v.toString());
        m_activeSplitIps.clear();
        for (const auto &v : req["ips"].toArray()) m_activeSplitIps.append(v.toString());

        if (m_vpnMgr->isConnected()) {
            m_routingMgr->applyRouting(m_vpnMgr->activeInterface(), m_activeSplitMode,
                                       m_activeSplitApps, m_activeSplitIps,
                                       m_activeKillSwitch, true);
        }
        res["ok"] = true;
        res["status"] = getStatusJson();
    } else {
        res["ok"] = false;
        res["error"] = "Unknown command: " + cmd;
    }

    return QJsonDocument(res).toJson(QJsonDocument::Compact);
}
