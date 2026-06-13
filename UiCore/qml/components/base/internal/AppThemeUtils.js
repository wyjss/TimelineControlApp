.pragma library

function objectValue(object, name, fallback) {
    return object && object[name] !== undefined ? object[name] : fallback
}

function numericObjectValue(object, name, fallback) {
    var value = objectValue(object, name, fallback)
    var numericValue = Number(value)
    return !isNaN(numericValue) ? numericValue : fallback
}

function densityValue(theme, name, fallback) {
    if (theme && theme.density && theme.density[name] !== undefined)
        return Number(theme.density[name])

    if (theme && theme.metrics && theme.metrics[name] !== undefined)
        return Number(theme.metrics[name])

    return fallback
}

function metricValue(theme, name, fallback) {
    return theme && theme.metrics && theme.metrics[name] !== undefined
        ? Number(theme.metrics[name])
        : fallback
}

function typographyValue(theme, name, fallback) {
    return theme && theme.typography && theme.typography[name] !== undefined
        ? theme.typography[name]
        : fallback
}

function numericTypographyValue(theme, name, fallback) {
    return Number(typographyValue(theme, name, fallback))
}

function colorValue(theme, name, fallback) {
    return theme && theme.colors && theme.colors[name] !== undefined
        ? theme.colors[name]
        : fallback
}

function shapeValue(theme, name, fallback) {
    return theme && theme.shape && theme.shape[name] !== undefined
        ? Number(theme.shape[name])
        : fallback
}

function resolvedColorSpec(theme, colorSpec, fallback) {
    if (colorSpec === undefined || colorSpec === null)
        return fallback

    if (typeof colorSpec === "string" && theme && theme.colors
            && theme.colors[colorSpec] !== undefined) {
        return theme.colors[colorSpec]
    }

    return colorSpec
}
