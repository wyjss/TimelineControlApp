.pragma library

function explicitFlagKey(key) {
    var normalizedKey = key !== undefined && key !== null ? String(key) : ""
    if (!normalizedKey.length)
        return ""

    return "hasExplicit" + normalizedKey.charAt(0).toUpperCase() + normalizedKey.slice(1)
}

function valueOf(source, key, fallback) {
    try {
        if (source !== undefined && source !== null && source[key] !== undefined)
            return source[key]
    } catch (error) {
    }

    return fallback
}

function controlValue(source, key, fallback) {
    if (source !== undefined && source !== null) {
        var explicitKey = explicitFlagKey(key)

        try {
            if (explicitKey.length > 0
                    && source[explicitKey] !== undefined
                    && !source[explicitKey]) {
                return fallback
            }

            if (source[key] !== undefined)
                return source[key]
        } catch (error) {
        }
    }

    return fallback
}

function isDefined(value) {
    return typeof value !== "undefined" && value !== null
}

function normalizedValue(value) {
    return isDefined(value) ? value : null
}

function normalizeFieldValue(value) {
    return value === undefined ? null : value
}

function objectPayload(payload) {
    return isDefined(payload) ? payload : ({})
}

function controlKey(source) {
    return String(controlValue(source, "key", ""))
}

function commitExpanded(target, nextExpanded) {
    if (target === undefined || target === null || target.setExpanded === undefined)
        return false

    target.setExpanded(!!nextExpanded)
    return true
}
