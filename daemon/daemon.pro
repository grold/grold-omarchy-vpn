QT += core network

CONFIG += c++17 release
TARGET = grold-omarchy-vpnd
TEMPLATE = app

HEADERS += \
    vpnmanager.h \
    routingmanager.h \
    socketserver.h

SOURCES += \
    main.cpp \
    vpnmanager.cpp \
    routingmanager.cpp \
    socketserver.cpp
