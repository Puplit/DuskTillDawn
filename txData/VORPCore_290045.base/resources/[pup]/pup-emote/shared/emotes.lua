-- builds checked lookups from config/emotes.lua for the client and the server

local function warn(msg)
    print(('^3[pup-emote]^7 %s'):format(msg))
end

-- older saves hold upper-case labels ('HAT TIP'); lower-casing and joining with _ gives the id
local function normalise(s)
    return (tostring(s):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', ''))
end

local function build()
    local byId, categories = {}, {}
    for ci, cat in ipairs(Config.Emotes or {}) do
        local catName = type(cat) == 'table' and tostring(cat.category or ('Category ' .. ci)) or nil
        if not catName or type(cat.emotes) ~= 'table' then
            warn(('category #%d has no emotes = { ... } list, skipped'):format(ci))
        else
            local ids = {}
            for ei, e in ipairs(cat.emotes) do
                local where = ('%s #%d'):format(catName, ei)
                local id = type(e) == 'table' and e.id
                local kind, play
                if type(e) == 'table' then
                    if type(e.kit) == 'string' and e.kit ~= '' then kind, play = 'kit', e.kit
                    elseif type(e.scenario) == 'string' and e.scenario ~= '' then kind, play = 'scenario', e.scenario
                    elseif type(e.anim) == 'table' and e.anim.dict and e.anim.name then kind, play = 'anim', e.anim end
                end

                if type(id) ~= 'string' or not id:match('^[%w_]+$') then
                    warn(('%s: id must be letters, digits or _ (got %s), skipped'):format(where, tostring(id)))
                elseif id ~= id:lower() then
                    warn(('%s: id "%s" must be lower case, skipped'):format(where, id))
                elseif byId[id] then
                    warn(('%s: id "%s" is used twice, the second one is skipped'):format(where, id))
                elseif not kind then
                    warn(('%s (%s): needs kit, scenario or anim = { dict, name }, skipped'):format(where, id))
                else
                    local mode = (kind == 'kit' and (e.mode == 'upper' or e.mode == 'full')) and e.mode or nil
                    if kind ~= 'kit' then mode = 'full' end
                    byId[id] = {
                        id = id,
                        label = tostring(e.label or id),
                        category = catName,
                        kind = kind,
                        play = play,
                        mode = mode, -- nil = ask the player
                    }
                    ids[#ids + 1] = id
                end
            end
            if #ids > 0 then categories[#categories + 1] = { name = catName, ids = ids } end
        end
    end
    return byId, categories
end

local byId, categories = build()

EmoteList = {
    byId = byId,
    categories = categories,
    find = function(saved)
        if type(saved) ~= 'string' or saved == '' then return nil end
        return byId[saved] or byId[normalise(saved)]
    end,
}
