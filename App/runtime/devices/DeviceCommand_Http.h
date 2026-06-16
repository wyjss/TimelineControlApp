#pragma once

#include "devices/DeviceCommand.h"

namespace TimelineControl {

//! HTTP 协议指令，提供请求方法、路径、请求体等强类型参数。
class DeviceCommand_Http : public DeviceCommand
{
    Q_OBJECT

    Q_PROPERTY(QString address READ address WRITE setAddress NOTIFY addressChanged FINAL)
    Q_PROPERTY(QString method READ method WRITE setMethod NOTIFY methodChanged FINAL)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged FINAL)
    Q_PROPERTY(QString body READ body WRITE setBody NOTIFY bodyChanged FINAL)

public:
    explicit DeviceCommand_Http(QObject *parent = nullptr);
    DeviceCommand_Http(const QString &name,
                       const QString &method,
                       const QString &path,
                       QObject *parent = nullptr);
    DeviceCommand_Http(const QString &name,
                       const QString &address,
                       const QString &method,
                       const QString &path,
                       QObject *parent = nullptr);

    QString address() const;
    void setAddress(const QString &address);

    QString method() const;
    void setMethod(const QString &method);

    QString path() const;
    void setPath(const QString &path);

    QString body() const;
    void setBody(const QString &body);

    QString protocol() const override;

    static QString protocolName();

signals:
    void addressChanged();
    void methodChanged();
    void pathChanged();
    void bodyChanged();

protected:
    QJsonObject paramsToJson() const override;
    bool loadParamsFromJson(const QJsonObject &params) override;
    QString validateParams() const override;
    QList<DeviceParamSpec *> createCreationInputFields(QObject *parent) const override;

private:
    QString m_address;
    QString m_method;
    QString m_path;
    QString m_body;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_Http *)

