#include "appscanner.h"
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QSet>
#include <algorithm>

AppScanner::AppScanner(QObject *parent) : QObject(parent) {}

QVariantList AppScanner::scanInstalledApps() const {
    QVariantList result;
    QSet<QString> seenIds;

    QStringList dirs = {
        QDir::homePath() + "/.local/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications"
    };

    for (const QString &dirPath : dirs) {
        QDir dir(dirPath);
        if (!dir.exists()) continue;

        const QStringList entries = dir.entryList(QStringList() << "*.desktop", QDir::Files);
        for (const QString &fileName : entries) {
            if (seenIds.contains(fileName)) continue;

            QString fullPath = dir.absoluteFilePath(fileName);
            QSettings desktopFile(fullPath, QSettings::IniFormat);
            desktopFile.beginGroup("Desktop Entry");

            bool noDisplay = desktopFile.value("NoDisplay", false).toBool();
            QString type = desktopFile.value("Type").toString();
            if (type != "Application" || noDisplay) {
                desktopFile.endGroup();
                continue;
            }

            QString name = desktopFile.value("Name").toString();
            QString exec = desktopFile.value("Exec").toString();
            QString icon = desktopFile.value("Icon").toString();
            QString comment = desktopFile.value("Comment").toString();
            desktopFile.endGroup();

            if (name.isEmpty()) continue;

            seenIds.insert(fileName);
            QVariantMap item;
            item["id"] = fileName;
            item["name"] = name;
            item["exec"] = exec;
            item["icon"] = icon;
            item["comment"] = comment;
            result.append(item);
        }
    }

    // Sort by name
    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["name"].toString().toLower() < b.toMap()["name"].toString().toLower();
    });

    return result;
}
