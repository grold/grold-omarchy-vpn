#pragma once

#include <QString>
#include <QStringList>
#include <QList>
#include <QJsonObject>
#include <optional>

struct VpnInterfaceConfig {
    QString privateKey;
    QStringList address;
    QStringList dns;
    int listenPort = 0;
    int mtu = 0;

    // AmneziaWG 3.1 parameters
    std::optional<int> jc;
    std::optional<int> jmin;
    std::optional<int> jmax;
    std::optional<int> s1;
    std::optional<int> s2;
    std::optional<qint64> h1;
    std::optional<qint64> h2;
    std::optional<qint64> h3;
    std::optional<qint64> h4;

    bool hasAmneziaParams() const {
        return jc.has_value() || jmin.has_value() || jmax.has_value() ||
               s1.has_value() || s2.has_value() ||
               h1.has_value() || h2.has_value() || h3.has_value() || h4.has_value();
    }
};

struct VpnPeerConfig {
    QString publicKey;
    QString presharedKey;
    QStringList allowedIPs;
    QString endpoint;
    int persistentKeepalive = 0;
};

class VpnProfile {
public:
    QString name;
    QString filePath;
    VpnInterfaceConfig interfaceConfig;
    QList<VpnPeerConfig> peers;

    // Split tunneling & security preferences
    QString splitMode = "off"; // "off", "exclusive", "inclusive"
    QStringList splitApps;
    QStringList splitIps;
    bool killSwitch = false;

    bool isAmnezia() const {
        return interfaceConfig.hasAmneziaParams();
    }

    static VpnProfile fromConf(const QString &name, const QString &confContent);
    QString toConf() const;

    QJsonObject toJson() const;
    static VpnProfile fromJson(const QJsonObject &json);

    static VpnProfile loadFromFile(const QString &confPath);
    bool saveToFile(const QString &confPath) const;
};
