TEMPLATE = subdirs

SUBDIRS += \
    daemon \
    cli \
    src \
    tests

daemon.file = daemon/daemon.pro
cli.file = cli/cli.pro
src.file = src/app.pro
tests.file = tests/tests.pro
