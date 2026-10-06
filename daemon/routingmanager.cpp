#include "routingmanager.h"
#include <QProcess>
#include <QDir>
#include <QFile>
#include <QDebug>

RoutingManager::RoutingManager(QObject *parent) : QObject(parent) {
    setupCgroups();
}

RoutingManager::~RoutingManager() {
    cleanupAll();
}

void RoutingManager::runCommand(const QString &cmd, const QStringList &args) {
    QProcess proc;
    proc.start(cmd, args);
    proc.waitForFinished(3000);
}

void RoutingManager::setupCgroups() {
    // Setup cgroup v2 directories if cgroups v2 is mounted at /sys/fs/cgroup
    QStringList cgroupPaths = {
        "/sys/fs/cgroup/grold_vpn",
        "/sys/fs/cgroup/grold_vpn_bypass"
    };

    for (const auto &path : cgroupPaths) {
        QDir().mkpath(path);
        // Grant permissions to write cgroup.procs for users
        QFile::setPermissions(path + "/cgroup.procs",
                              QFile::ReadOwner | QFile::WriteOwner |
                              QFile::ReadGroup | QFile::WriteGroup |
                              QFile::ReadOther | QFile::WriteOther);
    }
}

void RoutingManager::applyRouting(const QString &ifName, const QString &splitMode,
                                  const QStringList &splitApps, const QStringList &splitIps,
                                  bool killSwitch, bool isConnected) {
    m_lastIfName = ifName;

    // First handle Split Tunneling
    clearSplitRules();
    if (isConnected && splitMode != "off") {
        applySplitRules(ifName, splitMode, splitApps, splitIps);
    }

    // Next handle Kill Switch
    setKillSwitch(killSwitch, isConnected, ifName);
}

void RoutingManager::setKillSwitch(bool enabled, bool isConnected, const QString &ifName) {
    m_killSwitchActive = enabled;
    if (!enabled) {
        clearKillSwitchRules();
        return;
    }
    applyKillSwitchRules(true, isConnected, ifName);
}

void RoutingManager::applyKillSwitchRules(bool enabled, bool isConnected, const QString &ifName) {
    clearKillSwitchRules();
    if (!enabled) return;

    // Create nftables table for killswitch
    runCommand("nft", {"add", "table", "inet", "grold_killswitch"});
    runCommand("nft", {"add", "chain", "inet", "grold_killswitch", "output",
                       "{ type filter hook output priority 0; policy accept; }"});

    // Allow loopback
    runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "oifname", "lo", "accept"});
    // Allow DHCP
    runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "udp", "dport", "67", "accept"});
    // Allow LAN traffic (RFC1918)
    runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "ip", "daddr", "192.168.0.0/16", "accept"});
    runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "ip", "daddr", "10.0.0.0/8", "accept"});
    runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "ip", "daddr", "172.16.0.0/12", "accept"});

    if (isConnected && !ifName.isEmpty()) {
        // When connected, allow VPN interface
        runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "oifname", ifName, "accept"});
    }

    // Drop all other egress traffic
    runCommand("nft", {"add", "rule", "inet", "grold_killswitch", "output", "drop"});
}

void RoutingManager::clearKillSwitchRules() {
    runCommand("nft", {"delete", "table", "inet", "grold_killswitch"});
}

void RoutingManager::applySplitRules(const QString &ifName, const QString &mode,
                                    const QStringList &apps, const QStringList &ips) {
    Q_UNUSED(apps);
    m_splitActive = true;

    runCommand("nft", {"add", "table", "inet", "grold_split"});
    runCommand("nft", {"add", "chain", "inet", "grold_split", "output",
                       "{ type route hook output priority 0; policy accept; }"});

    if (mode == "exclusive") {
        // Traffic routes via VPN by default.
        // Bypass marked IPs or bypass cgroup to table main
        runCommand("ip", {"rule", "add", "fwmark", "0x1000", "table", "main", "prio", "990"});

        // Mark bypass cgroup
        runCommand("nft", {"add", "rule", "inet", "grold_split", "output",
                           "cgroup", "grold_vpn_bypass", "meta", "mark", "set", "0x1000"});

        // Mark bypass destination IPs
        for (const QString &ip : ips) {
            QString cleanIp = ip.trimmed();
            if (!cleanIp.isEmpty()) {
                runCommand("nft", {"add", "rule", "inet", "grold_split", "output",
                                   "ip", "daddr", cleanIp, "meta", "mark", "set", "0x1000"});
            }
        }
    } else if (mode == "inclusive") {
        // Traffic routes direct by default.
        // Target apps and IPs routed through VPN
        // Ensure routing table 51820 routes via VPN interface
        runCommand("ip", {"route", "add", "default", "dev", ifName, "table", "51820"});
        runCommand("ip", {"rule", "add", "fwmark", "0x2000", "table", "51820", "prio", "990"});

        // Mark VPN cgroup
        runCommand("nft", {"add", "rule", "inet", "grold_split", "output",
                           "cgroup", "grold_vpn", "meta", "mark", "set", "0x2000"});

        // Mark target destination IPs
        for (const QString &ip : ips) {
            QString cleanIp = ip.trimmed();
            if (!cleanIp.isEmpty()) {
                runCommand("nft", {"add", "rule", "inet", "grold_split", "output",
                                   "ip", "daddr", cleanIp, "meta", "mark", "set", "0x2000"});
            }
        }
    }
}

void RoutingManager::clearSplitRules() {
    if (!m_splitActive) return;
    runCommand("nft", {"delete", "table", "inet", "grold_split"});
    runCommand("ip", {"rule", "del", "fwmark", "0x1000", "table", "main", "prio", "990"});
    runCommand("ip", {"rule", "del", "fwmark", "0x2000", "table", "51820", "prio", "990"});
    runCommand("ip", {"route", "flush", "table", "51820"});
    m_splitActive = false;
}

void RoutingManager::cleanupAll() {
    clearSplitRules();
    clearKillSwitchRules();
}
