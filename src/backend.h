#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
#include <QLocalSocket>
#include <QDateTime>
#include "configparser.h"
#include "appscanner.h"
#include "portalfilepicker.h"

class Backend : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString activeProfileName READ activeProfileName NOTIFY activeProfileNameChanged)
    Q_PROPERTY(QString activeInterface READ activeInterface NOTIFY activeInterfaceChanged)
    Q_PROPERTY(qint64 rxBytes READ rxBytes NOTIFY statsChanged)
    Q_PROPERTY(qint64 txBytes READ txBytes NOTIFY statsChanged)
    Q_PROPERTY(qint64 rxRate READ rxRate NOTIFY statsChanged)
    Q_PROPERTY(qint64 txRate READ txRate NOTIFY statsChanged)
    Q_PROPERTY(qint64 uptime READ uptime NOTIFY statsChanged)
    Q_PROPERTY(qint64 lastHandshake READ lastHandshake NOTIFY statsChanged)
    Q_PROPERTY(QString splitMode READ splitMode NOTIFY splitModeChanged)
    Q_PROPERTY(bool killSwitch READ killSwitch NOTIFY killSwitchChanged)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QVariantList installedApps READ installedApps CONSTANT)
    Q_PROPERTY(QVariantList speedHistory READ speedHistory NOTIFY speedHistoryChanged)
    Q_PROPERTY(QVariantList sessionLogs READ sessionLogs NOTIFY sessionLogsChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool daemonAvailable READ daemonAvailable NOTIFY daemonAvailableChanged)
    Q_PROPERTY(QString defaultProfile READ defaultProfile NOTIFY defaultProfileChanged)

public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend();

    bool connected() const { return m_connected; }
    QString activeProfileName() const { return m_activeProfileName; }
    QString activeInterface() const { return m_activeInterface; }
    qint64 rxBytes() const { return m_rxBytes; }
    qint64 txBytes() const { return m_txBytes; }
    qint64 rxRate() const { return m_rxRate; }
    qint64 txRate() const { return m_txRate; }
    qint64 uptime() const { return m_uptime; }
    qint64 lastHandshake() const { return m_lastHandshake; }
    QString splitMode() const { return m_splitMode; }
    bool killSwitch() const { return m_killSwitch; }
    QVariantList profiles() const { return m_profiles; }
    QVariantList installedApps() const { return m_installedApps; }
    QVariantList speedHistory() const { return m_speedHistory; }
    QVariantList sessionLogs() const { return m_sessionLogs; }
    QString statusMessage() const { return m_statusMessage; }
    bool daemonAvailable() const { return m_daemonAvailable; }
    QString defaultProfile() const { return m_defaultProfile; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void toggleConnection(const QString &profileName = QString());
    Q_INVOKABLE void connectProfile(const QString &name);
    Q_INVOKABLE void disconnectVpn();
    Q_INVOKABLE void setDefaultProfile(const QString &name);
    Q_INVOKABLE bool saveProfile(const QString &name, const QString &confContent,
                                 const QString &splitMode, bool killSwitch,
                                 const QStringList &apps, const QStringList &ips);
    Q_INVOKABLE bool deleteProfile(const QString &name);
    Q_INVOKABLE bool importConf(const QString &filePath);
    Q_INVOKABLE void setKillSwitch(bool enabled);
    Q_INVOKABLE void setSplitTunnel(const QString &mode, const QStringList &apps, const QStringList &ips);
    Q_INVOKABLE QVariantMap getProfile(const QString &name);
    Q_INVOKABLE QString readProfileConf(const QString &name);
    Q_INVOKABLE void requestImportDialog();

signals:
    void connectedChanged();
    void activeProfileNameChanged();
    void activeInterfaceChanged();
    void statsChanged();
    void splitModeChanged();
    void killSwitchChanged();
    void profilesChanged();
    void speedHistoryChanged();
    void sessionLogsChanged();
    void statusMessageChanged();
    void daemonAvailableChanged();
    void defaultProfileChanged();
    void fileImportSuccess(const QString &profileName);
    void fileImportError(const QString &error);

private slots:
    void pollDaemonStatus();
    void onFileSelected(const QString &path);

private:
    void loadProfiles();
    void loadHistory();
    void saveHistory();
    void appendSpeedPoint(qint64 rxRate, qint64 txRate);
    void recordSessionLog(const QString &profile, qint64 duration, qint64 rx, qint64 tx);
    QJsonObject sendDaemonCommand(const QJsonObject &req);
    QString profilesDir() const;
    QString historyFilePath() const;
    QString defaultProfileFilePath() const;
    void loadDefaultProfile();

    bool m_connected = false;
    QString m_activeProfileName;
    QString m_activeInterface;
    QString m_defaultProfile;
    qint64 m_rxBytes = 0;
    qint64 m_txBytes = 0;
    qint64 m_rxRate = 0;
    qint64 m_txRate = 0;
    qint64 m_uptime = 0;
    qint64 m_lastHandshake = 0;
    QString m_splitMode = "off";
    bool m_killSwitch = false;
    bool m_daemonAvailable = false;
    QString m_statusMessage;

    QVariantList m_profiles;
    QVariantList m_installedApps;
    QVariantList m_speedHistory;
    QVariantList m_sessionLogs;

    QTimer *m_pollTimer = nullptr;
    AppScanner *m_scanner = nullptr;
    PortalFilePicker *m_filePicker = nullptr;
};
