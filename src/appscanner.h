#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class AppScanner : public QObject {
    Q_OBJECT

public:
    explicit AppScanner(QObject *parent = nullptr);

    QVariantList scanInstalledApps() const;
};
