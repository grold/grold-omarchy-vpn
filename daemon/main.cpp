#include <QCoreApplication>
#include <QCommandLineParser>
#include <csignal>
#include <iostream>
#include "vpnmanager.h"
#include "routingmanager.h"
#include "socketserver.h"

static SocketServer *g_server = nullptr;
static VpnManager *g_vpn = nullptr;
static RoutingManager *g_routing = nullptr;

static void handleSignal(int sig) {
    std::cout << "\nCaught signal " << sig << ", cleaning up..." << std::endl;
    if (g_routing) g_routing->cleanupAll();
    if (g_vpn && g_vpn->isConnected()) {
        QString err;
        g_vpn->disconnectTunnel(err);
    }
    if (g_server) g_server->stopServer();
    QCoreApplication::exit(0);
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    app.setApplicationName("grold-omarchy-vpnd");
    app.setApplicationVersion("0.1.0");

    QCommandLineParser parser;
    parser.setApplicationDescription("Daemon for grold-omarchy-vpn WireGuard & AmneziaWG manager");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption socketOpt(QStringList() << "s" << "socket", "Socket path to listen on", "path");
    parser.addOption(socketOpt);
    parser.process(app);

    QString socketPath = parser.value(socketOpt);

    VpnManager vpnMgr;
    RoutingManager routingMgr;
    SocketServer server(&vpnMgr, &routingMgr);

    g_vpn = &vpnMgr;
    g_routing = &routingMgr;
    g_server = &server;

    std::signal(SIGINT, handleSignal);
    std::signal(SIGTERM, handleSignal);

    if (!server.startServer(socketPath)) {
        std::cerr << "Fatal: Failed to start UNIX domain socket server." << std::endl;
        return 1;
    }

    std::cout << "grold-omarchy-vpnd started successfully." << std::endl;
    return app.exec();
}
