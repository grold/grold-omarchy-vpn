QT += core testlib

CONFIG += c++17 testcase
TARGET = grold_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += \
    ../src/configparser.h

SOURCES += \
    tests.cpp \
    ../src/configparser.cpp
