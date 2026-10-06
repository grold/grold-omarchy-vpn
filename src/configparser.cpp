#include "configparser.h"

#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDir>
#include <QRegularExpression>

static QStringList splitAndTrim(const QString &str) {
    QStringList result;
    const auto parts = str.split(',', Qt::SkipEmptyParts);
    for (const auto &part : parts) {
        const QString trimmed = part.trimmed();
        if (!trimmed.isEmpty()) {
            result.append(trimmed);
        }
    }
    return result;
}

VpnProfile VpnProfile::fromConf(const QString &name, const QString &confContent) {
    VpnProfile profile;
    profile.name = name;

    enum Section { None, Interface, Peer };
    Section currentSection = None;
    VpnPeerConfig currentPeer;

    const QStringList lines = confContent.split(QRegularExpression(R"(\r?\n)"));
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        // Remove trailing comment if any, unless inside values
        int commentIdx = line.indexOf('#');
        if (commentIdx != -1) {
            line = line.left(commentIdx).trimmed();
        }
        if (line.isEmpty()) {
            continue;
        }

        if (line.compare("[Interface]", Qt::CaseInsensitive) == 0) {
            if (currentSection == Peer) {
                profile.peers.append(currentPeer);
                currentPeer = VpnPeerConfig();
            }
            currentSection = Interface;
            continue;
        } else if (line.compare("[Peer]", Qt::CaseInsensitive) == 0) {
            if (currentSection == Peer) {
                profile.peers.append(currentPeer);
                currentPeer = VpnPeerConfig();
            }
            currentSection = Peer;
            continue;
        }

        int eqIdx = line.indexOf('=');
        if (eqIdx == -1) continue;

        QString key = line.left(eqIdx).trimmed();
        QString value = line.mid(eqIdx + 1).trimmed();

        if (currentSection == Interface) {
            if (key.compare("PrivateKey", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.privateKey = value;
            } else if (key.compare("Address", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.address.append(splitAndTrim(value));
            } else if (key.compare("DNS", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.dns.append(splitAndTrim(value));
            } else if (key.compare("ListenPort", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.listenPort = value.toInt();
            } else if (key.compare("MTU", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.mtu = value.toInt();
            } else if (key.compare("Jc", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.jc = value.toInt();
            } else if (key.compare("Jmin", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.jmin = value.toInt();
            } else if (key.compare("Jmax", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.jmax = value.toInt();
            } else if (key.compare("S1", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.s1 = value.toInt();
            } else if (key.compare("S2", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.s2 = value.toInt();
            } else if (key.compare("H1", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.h1 = value.toLongLong();
            } else if (key.compare("H2", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.h2 = value.toLongLong();
            } else if (key.compare("H3", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.h3 = value.toLongLong();
            } else if (key.compare("H4", Qt::CaseInsensitive) == 0) {
                profile.interfaceConfig.h4 = value.toLongLong();
            }
        } else if (currentSection == Peer) {
            if (key.compare("PublicKey", Qt::CaseInsensitive) == 0) {
                currentPeer.publicKey = value;
            } else if (key.compare("PresharedKey", Qt::CaseInsensitive) == 0) {
                currentPeer.presharedKey = value;
            } else if (key.compare("AllowedIPs", Qt::CaseInsensitive) == 0) {
                currentPeer.allowedIPs.append(splitAndTrim(value));
            } else if (key.compare("Endpoint", Qt::CaseInsensitive) == 0) {
                currentPeer.endpoint = value;
            } else if (key.compare("PersistentKeepalive", Qt::CaseInsensitive) == 0) {
                currentPeer.persistentKeepalive = value.toInt();
            }
        }
    }

    if (currentSection == Peer) {
        profile.peers.append(currentPeer);
    }

    return profile;
}

QString VpnProfile::toConf() const {
    QString out;
    QTextStream ts(&out);

    ts << "[Interface]\n";
    if (!interfaceConfig.privateKey.isEmpty()) {
        ts << "PrivateKey = " << interfaceConfig.privateKey << "\n";
    }
    if (!interfaceConfig.address.isEmpty()) {
        ts << "Address = " << interfaceConfig.address.join(", ") << "\n";
    }
    if (!interfaceConfig.dns.isEmpty()) {
        ts << "DNS = " << interfaceConfig.dns.join(", ") << "\n";
    }
    if (interfaceConfig.listenPort > 0) {
        ts << "ListenPort = " << interfaceConfig.listenPort << "\n";
    }
    if (interfaceConfig.mtu > 0) {
        ts << "MTU = " << interfaceConfig.mtu << "\n";
    }

    // AmneziaWG parameters
    if (interfaceConfig.jc.has_value()) ts << "Jc = " << *interfaceConfig.jc << "\n";
    if (interfaceConfig.jmin.has_value()) ts << "Jmin = " << *interfaceConfig.jmin << "\n";
    if (interfaceConfig.jmax.has_value()) ts << "Jmax = " << *interfaceConfig.jmax << "\n";
    if (interfaceConfig.s1.has_value()) ts << "S1 = " << *interfaceConfig.s1 << "\n";
    if (interfaceConfig.s2.has_value()) ts << "S2 = " << *interfaceConfig.s2 << "\n";
    if (interfaceConfig.h1.has_value()) ts << "H1 = " << *interfaceConfig.h1 << "\n";
    if (interfaceConfig.h2.has_value()) ts << "H2 = " << *interfaceConfig.h2 << "\n";
    if (interfaceConfig.h3.has_value()) ts << "H3 = " << *interfaceConfig.h3 << "\n";
    if (interfaceConfig.h4.has_value()) ts << "H4 = " << *interfaceConfig.h4 << "\n";

    for (const auto &peer : peers) {
        ts << "\n[Peer]\n";
        if (!peer.publicKey.isEmpty()) {
            ts << "PublicKey = " << peer.publicKey << "\n";
        }
        if (!peer.presharedKey.isEmpty()) {
            ts << "PresharedKey = " << peer.presharedKey << "\n";
        }
        if (!peer.endpoint.isEmpty()) {
            ts << "Endpoint = " << peer.endpoint << "\n";
        }
        if (!peer.allowedIPs.isEmpty()) {
            ts << "AllowedIPs = " << peer.allowedIPs.join(", ") << "\n";
        }
        if (peer.persistentKeepalive > 0) {
            ts << "PersistentKeepalive = " << peer.persistentKeepalive << "\n";
        }
    }

    return out;
}

QJsonObject VpnProfile::toJson() const {
    QJsonObject root;
    root["name"] = name;
    root["filePath"] = filePath;
    root["isAmnezia"] = isAmnezia();
    root["splitMode"] = splitMode;
    root["splitApps"] = QJsonArray::fromStringList(splitApps);
    root["splitIps"] = QJsonArray::fromStringList(splitIps);
    root["killSwitch"] = killSwitch;

    QJsonObject iface;
    iface["privateKey"] = interfaceConfig.privateKey;
    iface["address"] = QJsonArray::fromStringList(interfaceConfig.address);
    iface["dns"] = QJsonArray::fromStringList(interfaceConfig.dns);
    iface["listenPort"] = interfaceConfig.listenPort;
    iface["mtu"] = interfaceConfig.mtu;

    if (interfaceConfig.jc.has_value()) iface["jc"] = *interfaceConfig.jc;
    if (interfaceConfig.jmin.has_value()) iface["jmin"] = *interfaceConfig.jmin;
    if (interfaceConfig.jmax.has_value()) iface["jmax"] = *interfaceConfig.jmax;
    if (interfaceConfig.s1.has_value()) iface["s1"] = *interfaceConfig.s1;
    if (interfaceConfig.s2.has_value()) iface["s2"] = *interfaceConfig.s2;
    if (interfaceConfig.h1.has_value()) iface["h1"] = *interfaceConfig.h1;
    if (interfaceConfig.h2.has_value()) iface["h2"] = *interfaceConfig.h2;
    if (interfaceConfig.h3.has_value()) iface["h3"] = *interfaceConfig.h3;
    if (interfaceConfig.h4.has_value()) iface["h4"] = *interfaceConfig.h4;
    root["interface"] = iface;

    QJsonArray peerArray;
    for (const auto &p : peers) {
        QJsonObject po;
        po["publicKey"] = p.publicKey;
        po["presharedKey"] = p.presharedKey;
        po["endpoint"] = p.endpoint;
        po["allowedIPs"] = QJsonArray::fromStringList(p.allowedIPs);
        po["persistentKeepalive"] = p.persistentKeepalive;
        peerArray.append(po);
    }
    root["peers"] = peerArray;

    return root;
}

VpnProfile VpnProfile::fromJson(const QJsonObject &json) {
    VpnProfile p;
    p.name = json["name"].toString();
    p.filePath = json["filePath"].toString();
    p.splitMode = json["splitMode"].toString("off");
    p.killSwitch = json["killSwitch"].toBool(false);

    const auto appsArr = json["splitApps"].toArray();
    for (const auto &v : appsArr) p.splitApps.append(v.toString());

    const auto ipsArr = json["splitIps"].toArray();
    for (const auto &v : ipsArr) p.splitIps.append(v.toString());

    const auto iface = json["interface"].toObject();
    p.interfaceConfig.privateKey = iface["privateKey"].toString();
    p.interfaceConfig.listenPort = iface["listenPort"].toInt();
    p.interfaceConfig.mtu = iface["mtu"].toInt();

    for (const auto &v : iface["address"].toArray()) p.interfaceConfig.address.append(v.toString());
    for (const auto &v : iface["dns"].toArray()) p.interfaceConfig.dns.append(v.toString());

    if (iface.contains("jc")) p.interfaceConfig.jc = iface["jc"].toInt();
    if (iface.contains("jmin")) p.interfaceConfig.jmin = iface["jmin"].toInt();
    if (iface.contains("jmax")) p.interfaceConfig.jmax = iface["jmax"].toInt();
    if (iface.contains("s1")) p.interfaceConfig.s1 = iface["s1"].toInt();
    if (iface.contains("s2")) p.interfaceConfig.s2 = iface["s2"].toInt();
    if (iface.contains("h1")) p.interfaceConfig.h1 = iface["h1"].toInteger();
    if (iface.contains("h2")) p.interfaceConfig.h2 = iface["h2"].toInteger();
    if (iface.contains("h3")) p.interfaceConfig.h3 = iface["h3"].toInteger();
    if (iface.contains("h4")) p.interfaceConfig.h4 = iface["h4"].toInteger();

    const auto peersArr = json["peers"].toArray();
    for (const auto &val : peersArr) {
        const auto po = val.toObject();
        VpnPeerConfig peer;
        peer.publicKey = po["publicKey"].toString();
        peer.presharedKey = po["presharedKey"].toString();
        peer.endpoint = po["endpoint"].toString();
        peer.persistentKeepalive = po["persistentKeepalive"].toInt();
        for (const auto &ip : po["allowedIPs"].toArray()) {
            peer.allowedIPs.append(ip.toString());
        }
        p.peers.append(peer);
    }

    return p;
}

VpnProfile VpnProfile::loadFromFile(const QString &confPath) {
    QFile file(confPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return VpnProfile();
    }

    QFileInfo fi(confPath);
    QString baseName = fi.completeBaseName();
    QString content = QString::fromUtf8(file.readAll());
    file.close();

    VpnProfile profile = VpnProfile::fromConf(baseName, content);
    profile.filePath = confPath;

    // Load accompanying metadata if present
    QString metaPath = fi.absolutePath() + "/" + baseName + ".meta.json";
    QFile metaFile(metaPath);
    if (metaFile.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(metaFile.readAll());
        if (!doc.isNull() && doc.isObject()) {
            QJsonObject meta = doc.object();
            profile.splitMode = meta["splitMode"].toString("off");
            profile.killSwitch = meta["killSwitch"].toBool(false);
            profile.splitApps.clear();
            for (const auto &v : meta["splitApps"].toArray()) profile.splitApps.append(v.toString());
            profile.splitIps.clear();
            for (const auto &v : meta["splitIps"].toArray()) profile.splitIps.append(v.toString());
        }
    }

    return profile;
}

bool VpnProfile::saveToFile(const QString &confPath) const {
    QFileInfo fi(confPath);
    QDir().mkpath(fi.absolutePath());

    QFile file(confPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    // Set 0600 permissions
    file.setPermissions(QFile::ReadOwner | QFile::WriteOwner);

    QTextStream out(&file);
    out << toConf();
    file.close();

    // Write accompanying metadata
    QString metaPath = fi.absolutePath() + "/" + fi.completeBaseName() + ".meta.json";
    QFile metaFile(metaPath);
    if (metaFile.open(QIODevice::WriteOnly)) {
        metaFile.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
        QJsonObject meta;
        meta["splitMode"] = splitMode;
        meta["killSwitch"] = killSwitch;
        meta["splitApps"] = QJsonArray::fromStringList(splitApps);
        meta["splitIps"] = QJsonArray::fromStringList(splitIps);
        metaFile.write(QJsonDocument(meta).toJson(QJsonDocument::Indented));
        metaFile.close();
    }

    return true;
}
