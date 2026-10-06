#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QDateTime>
#include <QProcess>

struct VpnStats {
    qint64 rxBytes = 0;
    qint64 txBytes = 0;
    qint64 rxRate = 0; // bytes/sec
    qint64 txRate = 0; // bytes/sec
    qint64 lastHandshakeEpoch = 0;
    qint64 uptimeSeconds = 0;
};

class VpnManager : public QObject {
    Q_OBJECT

public:
    explicit VpnManager(QObject *parent = nullptr);
    ~VpnManager();

    bool isConnected() const { return m_connected; }
    QString activeProfileName() const { return m_activeProfileName; }
    QString activeProfilePath() const { return m_activeProfilePath; }
    QString activeInterface() const { return m_activeInterface; }
    VpnStats currentStats() const { return m_stats; }

    bool connectTunnel(const QString &profilePath, QString &errorMessage);
    bool disconnectTunnel(QString &errorMessage);

signals:
    void stateChanged(bool connected, const QString &profileName);
    void statsUpdated(const VpnStats &stats);

private slots:
    void pollStats();

private:
    QString findVpnTool(bool amnezia) const;
    void parseStatsOutput(const QString &output);

    bool m_connected = false;
    QString m_activeProfileName;
    QString m_activeProfilePath;
    QString m_activeInterface;
    QDateTime m_connectTime;

    VpnStats m_stats;
    qint64 m_lastRx = 0;
    qint64 m_lastTx = 0;
    QDateTime m_lastPollTime;

    QTimer *m_pollTimer = nullptr;
};
