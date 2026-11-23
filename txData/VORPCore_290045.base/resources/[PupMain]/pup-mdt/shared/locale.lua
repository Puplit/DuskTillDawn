-- pup-mdt | locale lookup (shared). Locale files call PupMdtLocale.add(lang, table).

Locales = Locales or {}
PupMdtLocale = {}

function PupMdtLocale.add(lang, tbl)
    Locales[lang] = Locales[lang] or {}
    for k, v in pairs(tbl) do Locales[lang][k] = v end
end

-- the English dictionary with the configured language laid over it
function PupMdtLocale.strings()
    local out = {}
    for k, v in pairs(Locales['en-us'] or {}) do out[k] = v end
    if Config.Locale ~= 'en-us' then
        for k, v in pairs(Locales[Config.Locale] or {}) do out[k] = v end
    end
    return out
end

-- configured language, then English, then the key itself
function L(key, ...)
    local t = Locales[Config.Locale]
    local s = (t and t[key]) or (Locales['en-us'] and Locales['en-us'][key]) or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
