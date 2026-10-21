.pragma library

function resolve(anchorItem, boundaryItem, desiredWidth, desiredContentHeight, popupPadding, gap) {
    var result = {
        "x": 0,
        "y": anchorItem.height + gap,
        "width": desiredWidth,
        "contentHeight": desiredContentHeight,
        "openAbove": false
    }

    if (!boundaryItem || !(boundaryItem.width > 0) || !(boundaryItem.height > 0))
        return result

    var mapped = anchorItem.mapToItem(boundaryItem, 0, 0)
    result.width = Math.max(0, Math.min(desiredWidth, boundaryItem.width))
    result.x = Math.max(
        -mapped.x,
        Math.min(0, boundaryItem.width - mapped.x - result.width)
    )

    var availableBelow = boundaryItem.height - mapped.y - anchorItem.height - gap
    var availableAbove = mapped.y - gap
    result.openAbove = desiredContentHeight + popupPadding * 2 > availableBelow
        && availableAbove > availableBelow
    var availableHeight = result.openAbove ? availableAbove : availableBelow

    result.contentHeight = Math.max(
        0,
        Math.min(desiredContentHeight, availableHeight - popupPadding * 2)
    )
    result.y = result.openAbove
        ? -gap - result.contentHeight - popupPadding * 2
        : anchorItem.height + gap
    return result
}
