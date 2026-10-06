#pragma once

#include <QObject>
#include <QString>
#include <QDBusConnection>
#include <QDBusMessage>

class PortalFilePicker : public QObject {
    Q_OBJECT

public:
    explicit PortalFilePicker(QObject *parent = nullptr);

    Q_INVOKABLE void openFile(const QString &title, const QString &filterName, const QStringList &patterns);

signals:
    void fileSelected(const QString &filePath);
    void canceled();

private slots:
    void onPortalResponse(uint response, const QVariantMap &results);
};
