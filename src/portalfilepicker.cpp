#include "portalfilepicker.h"
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QUrl>
#include <QDebug>
#include <QRandomGenerator>

PortalFilePicker::PortalFilePicker(QObject *parent) : QObject(parent) {}

void PortalFilePicker::openFile(const QString &title, const QString &filterName, const QStringList &patterns) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        emit canceled();
        return;
    }

    QString token = QString("grold_vpn_%1").arg(QRandomGenerator::global()->generate());
    QString sender = bus.baseService().replace('.', '_').replace(':', '_');
    QString requestPath = QString("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);

    bus.connect("org.freedesktop.portal.Desktop",
                requestPath,
                "org.freedesktop.portal.Request",
                "Response",
                this,
                SLOT(onPortalResponse(uint, QVariantMap)));

    QVariantMap options;
    options["handle_token"] = token;
    options["multiple"] = false;

    // Filters structure: a(sa(us))
    QVariantList filterList;
    for (const QString &pattern : patterns) {
        // [0, pattern] where 0 means glob pattern
        QVariantList patternEntry;
        patternEntry << (uint)0 << pattern;
        filterList << QVariant(patternEntry);
    }
    QVariantList currentFilter;
    currentFilter << filterName << QVariant(filterList);

    QVariantList allFilters;
    allFilters << QVariant(currentFilter);
    options["filters"] = allFilters;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile"
    );

    msg << QString() << title << options;
    bus.call(msg);
}

void PortalFilePicker::onPortalResponse(uint response, const QVariantMap &results) {
    if (response == 0 && results.contains("uris")) {
        QStringList uris = results["uris"].toStringList();
        if (!uris.isEmpty()) {
            QUrl url(uris.first());
            emit fileSelected(url.isLocalFile() ? url.toLocalFile() : url.toString());
            return;
        }
    }
    emit canceled();
}
