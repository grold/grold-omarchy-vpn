#include <QCoreApplication>
#include <QCommandLineParser>
#include <QLocalSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
#include <QDir>
#include <iostream>

static QString findSocketPath() {
    if (QFile::exists("/run/grold-omarchy-vpn/daemon.sock")) {
        return "/run/grold-omarchy-vpn/daemon.sock";
    }
    if (QFile::exists("/tmp/grold-omarchy-vpn-daemon.sock")) {
        return "/tmp/grold-omarchy-vpn-daemon.sock";
    }
    return "/run/grold-omarchy-vpn/daemon.sock";
}

static QJsonObject sendCommand(const QJsonObject &req, const QString &customSocket = QString()) {
    QString sockPath = customSocket.isEmpty() ? findSocketPath() : customSocket;
    QLocalSocket socket;
    socket.connectToServer(sockPath);
    if (!socket.waitForConnected(2000)) {
        QJsonObject err;
        err["ok"] = false;
        err["error"] = "Cannot connect to daemon socket at " + sockPath + ": " + socket.errorString();
        return err;
    }

    QByteArray data = QJsonDocument(req).toJson(QJsonDocument::Compact);
    socket.write(data + "\n");
    socket.flush();

    if (!socket.waitForReadyRead(5000)) {
        QJsonObject err;
        err["ok"] = false;
        err["error"] = "Timeout waiting for daemon response";
        return err;
    }

    QByteArray resData = socket.readLine();
    QJsonDocument doc = QJsonDocument::fromJson(resData);
    if (!doc.isObject()) {
        QJsonObject err;
        err["ok"] = false;
        err["error"] = "Invalid response from daemon";
        return err;
    }

    return doc.object();
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    app.setApplicationName("grold-omarchy-vpn-ctl");
    app.setApplicationVersion("0.1.0");

    QCommandLineParser parser;
    parser.setApplicationDescription("Control client for grold-omarchy-vpnd");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption jsonOpt("json", "Output response in raw JSON");
    parser.addOption(jsonOpt);

    QCommandLineOption socketOpt("socket", "Custom socket path", "path");
    parser.addOption(socketOpt);

    parser.addPositionalArgument("command", "Command: status, connect, disconnect, toggle, ping, killswitch, splittunnel");
    parser.addPositionalArgument("arg", "Optional argument (e.g. profile path, on/off)", "[arg]");

    parser.process(app);

    const QStringList posArgs = parser.positionalArguments();
    QString cmd = posArgs.isEmpty() ? "status" : posArgs.at(0);
    QString arg = posArgs.size() > 1 ? posArgs.at(1) : QString();
    QString sockPath = parser.value(socketOpt);
    bool outputJson = parser.isSet(jsonOpt);

    QJsonObject req;
    req["cmd"] = cmd;

    if (cmd == "connect" || cmd == "toggle") {
        if (!arg.isEmpty()) {
            QFileInfo fi(arg);
            req["profile"] = fi.absoluteFilePath();
        }
    } else if (cmd == "killswitch") {
        req["enabled"] = (arg == "on" || arg == "true" || arg == "1");
    } else if (cmd == "splittunnel") {
        req["mode"] = arg.isEmpty() ? "off" : arg;
    }

    QJsonObject resp = sendCommand(req, sockPath);

    if (outputJson) {
        std::cout << QJsonDocument(resp).toJson(QJsonDocument::Compact).toStdString() << std::endl;
        return resp["ok"].toBool() ? 0 : 1;
    }

    if (!resp["ok"].toBool()) {
        std::cerr << "Error: " << resp["error"].toString().toStdString() << std::endl;
        return 1;
    }

    if (cmd == "status") {
        QJsonObject status = resp["status"].toObject();
        bool conn = status["connected"].toBool();
        std::cout << "Status: " << (conn ? "CONNECTED" : "DISCONNECTED") << "\n";
        if (conn) {
            std::cout << "Profile: " << status["profileName"].toString().toStdString() << "\n";
            std::cout << "Interface: " << status["interface"].toString().toStdString() << "\n";
            std::cout << "Uptime: " << status["uptime"].toInteger() << " seconds\n";
            std::cout << "Rx: " << (status["rxBytes"].toInteger() / 1024) << " KB ("
                      << (status["rxRate"].toInteger() / 1024) << " KB/s)\n";
            std::cout << "Tx: " << (status["txBytes"].toInteger() / 1024) << " KB ("
                      << (status["txRate"].toInteger() / 1024) << " KB/s)\n";
        }
        std::cout << "Split Mode: " << status["splitMode"].toString().toStdString() << "\n";
        std::cout << "Kill Switch: " << (status["killSwitch"].toBool() ? "ENABLED" : "DISABLED") << "\n";
    } else if (cmd == "ping") {
        std::cout << "PONG" << std::endl;
    } else {
        std::cout << "Success: " << cmd.toStdString() << std::endl;
    }

    return 0;
}
