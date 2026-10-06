QT += core gui qml quick quickcontrols2 dbus network

CONFIG += c++17 release
TARGET = grold-omarchy-vpn
TEMPLATE = app

HEADERS += \
    backend.h \
    theme.h \
    configparser.h \
    appscanner.h \
    portalfilepicker.h

SOURCES += \
    main.cpp \
    backend.cpp \
    theme.cpp \
    configparser.cpp \
    appscanner.cpp \
    portalfilepicker.cpp

RESOURCES += resources.qrc
