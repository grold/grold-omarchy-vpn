#include <QtTest>
#include <QTemporaryDir>
#include "configparser.h"

class GroldVpnTests : public QObject {
    Q_OBJECT

private slots:
    void parseStandardWireGuard() {
        QString wgConf =
            "[Interface]\n"
            "PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=\n"
            "Address = 10.0.0.2/32, fd00::2/128\n"
            "DNS = 1.1.1.1, 8.8.8.8\n"
            "ListenPort = 51820\n"
            "MTU = 1420\n"
            "\n"
            "[Peer]\n"
            "PublicKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=\n"
            "Endpoint = 203.0.113.1:51820\n"
            "AllowedIPs = 0.0.0.0/0, ::/0\n"
            "PersistentKeepalive = 25\n";

        VpnProfile profile = VpnProfile::fromConf("test-wg", wgConf);
        QCOMPARE(profile.name, QString("test-wg"));
        QCOMPARE(profile.interfaceConfig.privateKey, QString("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa="));
        QCOMPARE(profile.interfaceConfig.address.size(), 2);
        QCOMPARE(profile.interfaceConfig.address.at(0), QString("10.0.0.2/32"));
        QCOMPARE(profile.interfaceConfig.dns.size(), 2);
        QCOMPARE(profile.interfaceConfig.listenPort, 51820);
        QCOMPARE(profile.interfaceConfig.mtu, 1420);
        QCOMPARE(profile.isAmnezia(), false);

        QCOMPARE(profile.peers.size(), 1);
        QCOMPARE(profile.peers[0].publicKey, QString("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb="));
        QCOMPARE(profile.peers[0].endpoint, QString("203.0.113.1:51820"));
        QCOMPARE(profile.peers[0].persistentKeepalive, 25);
    }

    void parseAmneziaWgParams() {
        QString awgConf =
            "[Interface]\n"
            "PrivateKey = ccccccccccccccccccccccccccccccccccccccccccc=\n"
            "Address = 10.8.0.2/24\n"
            "DNS = 1.1.1.1\n"
            "Jc = 4\n"
            "Jmin = 50\n"
            "Jmax = 1000\n"
            "S1 = 15\n"
            "S2 = 30\n"
            "H1 = 12345678\n"
            "H2 = 23456789\n"
            "H3 = 34567890\n"
            "H4 = 45678901\n"
            "\n"
            "[Peer]\n"
            "PublicKey = ddddddddddddddddddddddddddddddddddddddddddd=\n"
            "Endpoint = 198.51.100.10:51820\n"
            "AllowedIPs = 0.0.0.0/0\n";

        VpnProfile profile = VpnProfile::fromConf("test-awg", awgConf);
        QCOMPARE(profile.isAmnezia(), true);
        QVERIFY(profile.interfaceConfig.jc.has_value());
        QCOMPARE(*profile.interfaceConfig.jc, 4);
        QVERIFY(profile.interfaceConfig.jmin.has_value());
        QCOMPARE(*profile.interfaceConfig.jmin, 50);
        QVERIFY(profile.interfaceConfig.jmax.has_value());
        QCOMPARE(*profile.interfaceConfig.jmax, 1000);
        QVERIFY(profile.interfaceConfig.s1.has_value());
        QCOMPARE(*profile.interfaceConfig.s1, 15);
        QVERIFY(profile.interfaceConfig.s2.has_value());
        QCOMPARE(*profile.interfaceConfig.s2, 30);
        QVERIFY(profile.interfaceConfig.h1.has_value());
        QCOMPARE(*profile.interfaceConfig.h1, 12345678LL);
        QVERIFY(profile.interfaceConfig.h4.has_value());
        QCOMPARE(*profile.interfaceConfig.h4, 45678901LL);

        QString regenerated = profile.toConf();
        VpnProfile roundtrip = VpnProfile::fromConf("test-awg-roundtrip", regenerated);
        QCOMPARE(roundtrip.isAmnezia(), true);
        QCOMPARE(*roundtrip.interfaceConfig.jc, 4);
        QCOMPARE(*roundtrip.interfaceConfig.h1, 12345678LL);
    }

    void fileSaveAndMetadata() {
        QTemporaryDir tmpDir;
        QVERIFY(tmpDir.isValid());

        VpnProfile p;
        p.name = "office-vpn";
        p.interfaceConfig.privateKey = "privkey==";
        p.interfaceConfig.address = QStringList{"10.200.0.5/32"};
        p.splitMode = "inclusive";
        p.splitApps = QStringList{"firefox.desktop", "curl"};
        p.splitIps = QStringList{"192.168.100.0/24"};
        p.killSwitch = true;

        QString confPath = tmpDir.path() + "/office-vpn.conf";
        QVERIFY(p.saveToFile(confPath));

        VpnProfile loaded = VpnProfile::loadFromFile(confPath);
        QCOMPARE(loaded.name, QString("office-vpn"));
        QCOMPARE(loaded.splitMode, QString("inclusive"));
        QCOMPARE(loaded.splitApps.size(), 2);
        QCOMPARE(loaded.splitApps.at(0), QString("firefox.desktop"));
        QCOMPARE(loaded.splitIps.at(0), QString("192.168.100.0/24"));
        QCOMPARE(loaded.killSwitch, true);
    }
};

QTEST_MAIN(GroldVpnTests)
#include "tests.moc"
