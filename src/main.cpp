// grold-omarchy-vpn — WireGuard & AmneziaWG manager for Omarchy Linux

#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include "backend.h"
#include "theme.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("grold-omarchy-vpn");
    app.setApplicationVersion("0.1.1");

    app.setDesktopFileName("grold-omarchy-vpn");
    app.setWindowIcon(QIcon::fromTheme("grold-omarchy-vpn"));

    QQuickStyle::setStyle("Material");

    Theme theme;
    Backend backend;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);

    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
