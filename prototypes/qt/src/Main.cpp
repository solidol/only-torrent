#include "Ot.QtMainWindow.h"
#include <QApplication>

int main(int argc, char* argv[]) {
    QApplication application(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("Only Torrent Qt Prototype"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.0.1"));
    ot::TOtQtMainWindow window;
    window.show();
    return application.exec();
}
