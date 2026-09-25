import QtQuick

Canvas {
    id: root

    property var values: []
    property var secondaryValues: []
    property color lineColor: "#6750A4"
    property color secondaryLineColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.45)
    property bool autoScale: false
    property real maximum: 100
    property real minimum: 0
    property real lineWidth: 1.6

    antialiasing: true
    renderStrategy: Canvas.Cooperative

    onValuesChanged: requestPaint()
    onSecondaryValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onSecondaryLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function finiteValues(list) {
        var out = [];
        if (!list)
            return out;
        for (var i = 0; i < list.length; ++i) {
            var value = Number(list[i]);
            if (isFinite(value))
                out.push(value);
        }
        return out;
    }

    function drawLine(ctx, list, color, minValue, maxValue) {
        var data = finiteValues(list);
        if (data.length < 2)
            return;

        var range = Math.max(0.0001, maxValue - minValue);
        var step = width / Math.max(1, data.length - 1);

        ctx.beginPath();
        for (var i = 0; i < data.length; ++i) {
            var x = i * step;
            var normalized = Math.max(0, Math.min(1, (data[i] - minValue) / range));
            var y = height - normalized * Math.max(1, height - 2) - 1;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }

        ctx.strokeStyle = color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        var primary = finiteValues(values);
        var secondary = finiteValues(secondaryValues);
        if (primary.length < 2 && secondary.length < 2)
            return;

        var minValue = minimum;
        var maxValue = maximum;
        if (autoScale) {
            var combined = primary.concat(secondary);
            minValue = 0;
            maxValue = 1;
            for (var i = 0; i < combined.length; ++i)
                maxValue = Math.max(maxValue, combined[i]);
        }

        drawLine(ctx, values, lineColor, minValue, maxValue);
        drawLine(ctx, secondaryValues, secondaryLineColor, minValue, maxValue);
    }
}
