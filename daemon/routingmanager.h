#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class RoutingManager : public QObject {
    Q_OBJECT

public:
    explicit RoutingManager(QObject *parent = nullptr);
    ~RoutingManager();

    void setupCgroups();
    void applyRouting(const QString &ifName, const QString &splitMode,
                      const QStringList &splitApps, const QStringList &splitIps,
                      bool killSwitch, bool isConnected);
    void cleanupAll();

    void setKillSwitch(bool enabled, bool isConnected, const QString &ifName);

private:
    void runCommand(const QString &cmd, const QStringList &args);
    void applyKillSwitchRules(bool enabled, bool isConnected, const QString &ifName);
    void applySplitRules(const QString &ifName, const QString &mode,
                         const QStringList &apps, const QStringList &ips);
    void clearSplitRules();
    void clearKillSwitchRules();

    bool m_killSwitchActive = false;
    bool m_splitActive = false;
    QString m_lastIfName;
};
