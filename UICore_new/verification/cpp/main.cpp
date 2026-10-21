#include <QByteArray>
#include <QCoreApplication>

int runFieldContracts(int argc, char **argv);
int runTaskContracts(int argc, char **argv);

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);

    const QByteArray suite = qgetenv("UICORE_TEST_SUITE");
    if (suite == "field")
        return runFieldContracts(argc, argv);
    if (suite == "task")
        return runTaskContracts(argc, argv);

    return runFieldContracts(argc, argv) | runTaskContracts(argc, argv);
}
