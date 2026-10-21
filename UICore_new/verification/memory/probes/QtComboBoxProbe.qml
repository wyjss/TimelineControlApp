import QtQuick 2.14
import QtQuick.Controls 2.14

ComboBox {
    width: 180
    height: 36
    model: [
        { "label": "A", "value": "a" },
        { "label": "B", "value": "b" }
    ]
    textRole: "label"
}
