import QtQuick 2.14

Canvas {
    width: 10
    height: 10
    contextType: "2d"

    onPaint: {
        var context = getContext("2d")
        context.beginPath()
        context.moveTo(2, 3)
        context.lineTo(5, 7)
        context.lineTo(8, 3)
        context.stroke()
    }
}
