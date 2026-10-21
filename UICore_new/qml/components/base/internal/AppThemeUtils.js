.pragma library

function densityValue(theme, name) {
    return Number(theme.density[name])
}

function metricValue(theme, name) {
    return Number(theme.metrics[name])
}

function typographyValue(theme, name) {
    return theme.typography[name]
}

function numericTypographyValue(theme, name) {
    return Number(typographyValue(theme, name))
}

function colorValue(theme, name) {
    return theme.colors[name]
}

function shapeValue(theme, name) {
    return Number(theme.shape[name])
}

function resolvedColorSpec(theme, colorSpec) {
    if (typeof colorSpec === "string" && theme.colors[colorSpec] !== undefined)
        return theme.colors[colorSpec]

    return colorSpec
}
