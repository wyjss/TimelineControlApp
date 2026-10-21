import QtQuick 2.14
import QtTest 1.2
import UICore.Fields 1.0
import UICore.Style 1.0

TestCase {
    name: "Initialization"

    function test_registeredTypes() {
        compare(AppField.Kind.TextField, 0)
        compare(UiStyle.LayoutMode.Horizontal, 2)
    }
}
