#include "portalfilepicker.h"
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QDBusArgument>
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

    QString token = QString("grold%1").arg(QRandomGenerator::global()->generate() % 100000);
    QString sender = bus.baseService();
    if (sender.startsWith(':')) {
        sender.remove(0, 1);
    }
    sender.replace('.', '_').replace(':', '_');
    QString requestPath = QString("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);

    // Connect to predictable request path
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
        QVariantList patternEntry;
        patternEntry << (uint)0 << pattern;
        filterList << QVariant(patternEntry);
    }
    QVariantList currentFilter;
    currentFilter << filterName << QVariant(filterList);
    options["filters"] = QVariantList{QVariant(currentFilter)};

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile"
    );

    msg << QString() << title << options;
    QDBusMessage reply = bus.call(msg);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        QDBusObjectPath handle = reply.arguments().first().value<QDBusObjectPath>();
        QString returnedPath = handle.path();
        if (!returnedPath.isEmpty() && returnedPath != requestPath) {
            bus.connect("org.freedesktop.portal.Desktop",
                        returnedPath,
                        "org.freedesktop.portal.Request",
                        "Response",
                        this,
                        SLOT(onPortalResponse(uint, QVariantMap)));
        }
    } else {
        qWarning() << "OpenFile DBus call failed:" << reply.errorMessage();
        emit canceled();
    }
}

void PortalFilePicker::onPortalResponse(uint response, const QVariantMap &results) {
    if (response == 0 && results.contains("uris")) {
        QStringList uris;
        QVariant val = results["uris"];
        if (val.userType() == qMetaTypeId<QDBusArgument>()) {
            QDBusArgument arg = val.value<QDBusArgument>();
            arg >> uris;
        } else if (val.canConvert<QStringList>()) {
            uris = val.toStringList();
        }

        if (!uris.isEmpty()) {
            QUrl url(uris.first());
            QString localPath = url.isLocalFile() ? url.toLocalFile() : url.toString();
            emit fileSelected(localPath);
            return;
        }
    }
    emit canceled();
}
