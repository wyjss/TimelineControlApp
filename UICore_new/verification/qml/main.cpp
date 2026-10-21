#include <QObject>
#include <QQmlEngine>
#include <QStandardItemModel>
#include <QtQuickTest/quicktest.h>

#include <UICore/UICore.h>

class TreeTestModel : public QStandardItemModel
{
    Q_OBJECT

public:
    using QStandardItemModel::QStandardItemModel;

    Q_INVOKABLE void resetItems()
    {
        clear();
        for (const auto *text : {"A", "Unselectable", "Disabled", "B", "Parent"})
            appendRow(new QStandardItem(QString::fromLatin1(text)));
        item(1)->setSelectable(false);
        item(2)->setEnabled(false);
        item(4)->appendRow(new QStandardItem(QStringLiteral("Child")));
    }

    Q_INVOKABLE void setItemFlags(int row, int flags)
    {
        item(row)->setFlags(Qt::ItemFlags(flags));
    }

    Q_INVOKABLE void removeItem(int row)
    {
        removeRow(row);
    }

    Q_INVOKABLE void insertItem(int row)
    {
        insertRow(row, new QStandardItem(QStringLiteral("Inserted")));
    }
};

class UICoreQuickTestSetup : public QObject
{
    Q_OBJECT

public slots:
    void applicationAvailable()
    {
        UICore::initialize();
        qmlRegisterType<TreeTestModel>("UICore.Tests", 1, 0, "TreeTestModel");
    }
};

QUICK_TEST_MAIN_WITH_SETUP(uicoreqmltests, UICoreQuickTestSetup)

#include "main.moc"
