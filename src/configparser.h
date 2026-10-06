#pragma once

#include <QString>
#include <QStringList>
#include <QList>
#include <QJsonObject>
#include <QMap>
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
    std::optional<int> s3;
    std::optional<int> s4;
    QString h1;
    QString h2;
    QString h3;
    QString h4;
    QString i1;
    QString i2;
    QMap<QString, QString> extra;

    bool hasAmneziaParams() const {
        return jc.has_value() || jmin.has_value() || jmax.has_value() ||
               s1.has_value() || s2.has_value() || s3.has_value() || s4.has_value() ||
               !h1.isEmpty() || !h2.isEmpty() || !h3.isEmpty() || !h4.isEmpty() ||
               !i1.isEmpty() || !i2.isEmpty() || !extra.isEmpty();
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
    QString rawConf;
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
