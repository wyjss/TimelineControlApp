#include <QtTest/QSignalSpy>
#include <QtTest/QTest>

#include <UICore/Fields/AppField.h>
#include <UICore/Fields/BaseField.h>
#include <UICore/Forms/AppForm.h>
#include <UICore/Forms/AppFormSection.h>

using namespace UICore;

class FieldContractsTest : public QObject
{
    Q_OBJECT

private slots:
    void baseFieldValidityFollowsErrorText();
    void appFieldProxiesValidationState();
    void aggregateValidityRecoversAfterFieldDeletion();
};

void FieldContractsTest::baseFieldValidityFollowsErrorText()
{
    BaseField field;
    QSignalSpy errorTextChangedSpy(&field, &BaseField::errorTextChanged);
    QSignalSpy validChangedSpy(&field, &BaseField::validChanged);

    QVERIFY(field.valid());

    field.setErrorText(QStringLiteral("Required"));
    QCOMPARE(field.errorText(), QStringLiteral("Required"));
    QVERIFY(!field.valid());
    QCOMPARE(errorTextChangedSpy.count(), 1);
    QCOMPARE(validChangedSpy.count(), 1);

    field.setErrorText(QStringLiteral("Still invalid"));
    QCOMPARE(errorTextChangedSpy.count(), 2);
    QCOMPARE(validChangedSpy.count(), 1);

    field.setErrorText(QString());
    QVERIFY(field.valid());
    QCOMPARE(errorTextChangedSpy.count(), 3);
    QCOMPARE(validChangedSpy.count(), 2);
}

void FieldContractsTest::appFieldProxiesValidationState()
{
    BaseField sourceField;
    AppField field;
    field.setSourceField(&sourceField);

    QSignalSpy requiredChangedSpy(&field, &AppField::requiredChanged);
    QSignalSpy errorTextChangedSpy(&field, &AppField::errorTextChanged);
    QSignalSpy validChangedSpy(&field, &AppField::validChanged);

    field.setRequired(true);
    field.setErrorText(QStringLiteral("Invalid"));

    QVERIFY(sourceField.required());
    QCOMPARE(sourceField.errorText(), QStringLiteral("Invalid"));
    QVERIFY(!sourceField.valid());
    QVERIFY(field.required());
    QCOMPARE(field.errorText(), QStringLiteral("Invalid"));
    QVERIFY(!field.valid());
    QCOMPARE(requiredChangedSpy.count(), 1);
    QCOMPARE(errorTextChangedSpy.count(), 1);
    QCOMPARE(validChangedSpy.count(), 1);
}

void FieldContractsTest::aggregateValidityRecoversAfterFieldDeletion()
{
    AppForm form;
    auto *section = new AppFormSection(&form);
    form.appendSection(section);

    auto *field = new AppField(section);
    field->setErrorText(QStringLiteral("Invalid"));
    section->appendField(field);

    QVERIFY(!section->valid());
    QVERIFY(!form.valid());

    delete field;

    QCOMPARE(section->fieldCount(), 0);
    QVERIFY(section->valid());
    QVERIFY(form.valid());
}

int runFieldContracts(int argc, char **argv)
{
    FieldContractsTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_FieldContracts.moc"
