.pragma library

function valuesEqual(left, right) {
    if (left === right)
        return true

    if (left === undefined || left === null || right === undefined || right === null)
        return false

    return String(left) === String(right)
}

function optionLabel(optionData, textRole) {
    if (optionData === undefined || optionData === null)
        return ""

    if (typeof optionData === "object" && optionData[textRole] !== undefined)
        return String(optionData[textRole])

    return String(optionData)
}

function optionValue(optionData, valueRole) {
    if (optionData === undefined || optionData === null)
        return undefined

    if (typeof optionData === "object" && optionData[valueRole] !== undefined)
        return optionData[valueRole]

    return optionData
}

function indexOfValue(options, targetValue, valueRole) {
    var resolvedOptions = options && options.length !== undefined ? options : []

    for (var index = 0; index < resolvedOptions.length; ++index) {
        if (valuesEqual(optionValue(resolvedOptions[index], valueRole), targetValue))
            return index
    }

    return -1
}
