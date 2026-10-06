#pragma once

#include <QObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QJsonObject>
#include "vpnmanager.h"
#include "routingmanager.h"

class SocketServer : public QObject {
    Q_OBJECT

public:
    explicit SocketServer(VpnManager *vpnMgr, RoutingManager *routingMgr, QObject *parent = nullptr);
    ~SocketServer();

    bool startServer(const QString &socketPath = QString());
    void stopServer();

    static QString defaultSocketPath();

private slots:
    void onNewConnection();
    void onClientReadyRead();
    void onClientDisconnected();

private:
    QByteArray handleMessage(const QJsonObject &req);
    QJsonObject getStatusJson() const;

    VpnManager *m_vpnMgr = nullptr;
    RoutingManager *m_routingMgr = nullptr;
    QLocalServer *m_server = nullptr;
    QString m_socketPath;
    QList<QLocalSocket*> m_clients;

    // Last known active settings
    QString m_activeSplitMode = "off";
    QStringList m_activeSplitApps;
    QStringList m_activeSplitIps;
    bool m_activeKillSwitch = false;
};
