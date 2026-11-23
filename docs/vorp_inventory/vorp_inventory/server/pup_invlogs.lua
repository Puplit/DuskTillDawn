-- Detailed inventory logging: one embed field per fact, sent directly because
-- CORE.AddWebhook only takes a flat description.

PUP_INVLOG = {}

local LOGCFG <const> = CONFIG.LOGS

-- Discord's own caps: 25 fields an embed, 1024 characters a value
local FIELD_LIMIT <const> = 1024

-- os.date on the server box; the embed timestamp is Discord's receive time and can drift
local function stamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function esc(v)
    v = tostring(v == nil and "N/A" or v)
    -- backticks in a name would break any inline-code wrapping
    return (v:gsub("`", "'"))
end

-- <@id> so an admin can click straight through to the Discord account
local function discordMention(src)
    local id <const> = src and src ~= 0 and GetPlayerIdentifierByType(src, "discord")
    if not id then return "N/A" end
    return ("<@%s>"):format(id:sub(9))
end

local function steamHex(src)
    return GetPlayerIdentifierByType(src, "steam") or "N/A"
end

local function coords(src)
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return "N/A" end
    local c <const> = GetEntityCoords(ped)
    return ("%.1f, %.1f, %.1f"):format(c.x, c.y, c.z)
end

--- Character name, Discord tag, server id and character id, as one field value.
---@param src integer|nil
---@return string
function PUP_INVLOG.Player(src)
    src = tonumber(src)
    if not src or src == 0 then return "N/A" end

    local user <const> = CORE and CORE.getUser(src)
    local char <const> = user and user.getUsedCharacter

    local name = char and ("%s %s"):format(char.firstname or "?", char.lastname or "?")
        or (GetPlayerName(src) or "Unknown")
    local charId = char and char.charIdentifier or "N/A"

    return ("%s\n%s\nID: %s | Char: %s"):format(esc(name), discordMention(src), src, esc(charId))
end

-- the rest of the trail, folded into one field so it stays out of the way
local function auditValue(src)
    src = tonumber(src)
    if not src or src == 0 then return nil end

    local user <const> = CORE and CORE.getUser(src)
    local char <const> = user and user.getUsedCharacter

    local job = "N/A"
    if char then
        -- `jobGrade`, camelCase - that is what getCharacter() hands out
        local grade = char.jobGrade or char.jobgrade
        job = ("%s (grade %s)"):format(tostring(char.job), tostring(grade or "?"))
    end

    return ("Steam Name: %s\nSteam Hex: %s\nJob: %s\nCoords: %s\nServer Time: %s")
        :format(esc(GetPlayerName(src) or "?"), esc(steamHex(src)), job, coords(src), stamp())
end

--- Metadata as a json block, or nil when there is nothing worth printing.
---@param metadata table|nil
---@return string|nil
function PUP_INVLOG.Meta(metadata)
    if type(metadata) ~= "table" or not next(metadata) then return nil end
    local ok, encoded = pcall(json.encode, metadata)
    if not ok or not encoded or encoded == "{}" then return nil end
    if #encoded > 900 then encoded = encoded:sub(1, 900) .. "...(truncated)" end
    return "```json\n" .. encoded .. "\n```"
end

--- `fields` is an ordered list of {name, value} pairs; `description` is for the
--- call sites that still build their own body, and lands under the player block.
---@param data {title:string, fields:table?, description:string?, color:number?, webhook:string?, name:string?, source:integer?, target:integer?, resource:string?}
function PUP_INVLOG.Send(data)
    local webhook <const> = (data.webhook and data.webhook ~= "") and data.webhook or LOGCFG.webhook
    if not webhook or webhook == "" then return end

    local fields = {}
    local function add(name, value)
        if value == nil or value == "" then return end
        local v = tostring(value)
        if #v > FIELD_LIMIT then v = v:sub(1, FIELD_LIMIT - 16) .. "\n...(truncated)" end
        fields[#fields + 1] = { name = tostring(name), value = v, inline = false }
    end

    -- a transfer names both ends; everything else has one actor
    add(data.target and "From" or "Player", PUP_INVLOG.Player(data.source))
    if data.target then add("To", PUP_INVLOG.Player(data.target)) end

    for _, f in ipairs(data.fields or {}) do add(f[1], f[2]) end
    add("Details", data.description)

    if LOGCFG.DETAILED ~= false then add("Audit", auditValue(data.source)) end
    if data.resource and data.resource ~= "" then add("Resource", esc(data.resource)) end

    PerformHttpRequest(webhook, function() end, "POST", json.encode({
        username = data.name or LOGCFG.webhookname,
        embeds = { {
            title     = data.title,
            color     = data.color or LOGCFG.colorgiveitem,
            fields    = fields,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        } },
    }), { ["Content-Type"] = "application/json" })
end

--- Convenience wrapper for the item paths: builds the item fields then sends.
---@param action string
---@param src integer|nil
---@param info {item:string?, label:string?, amount:any, metadata:table?, serial:string?, desc:string?, container:string?, extra:string?, target:integer?, color:number?, webhook:string?, resource:string?}
function PUP_INVLOG.Item(action, src, info)
    local fields = { { "Action", esc(action) } }

    if info.item then
        local line = esc(info.item)
        if info.label and info.label ~= "" then line = ("%s (%s)"):format(line, esc(info.label)) end
        if info.amount ~= nil then line = ("%s x%s"):format(line, esc(info.amount)) end
        fields[#fields + 1] = { "Item", line }
    elseif info.amount ~= nil then
        fields[#fields + 1] = { "Amount", esc(info.amount) }
    end

    if info.serial and info.serial ~= "" then fields[#fields + 1] = { "Serial", esc(info.serial) } end
    if info.desc and info.desc ~= "" then fields[#fields + 1] = { "Description", esc(info.desc) } end
    if info.container and info.container ~= "" then fields[#fields + 1] = { "Container", esc(info.container) } end

    local meta <const> = PUP_INVLOG.Meta(info.metadata)
    if meta then fields[#fields + 1] = { "Metadata", meta } end
    if info.extra and info.extra ~= "" then fields[#fields + 1] = { "Extra", info.extra } end

    PUP_INVLOG.Send({
        title = action,
        fields = fields,
        color = info.color,
        webhook = info.webhook,
        source = src,
        target = info.target,
        resource = info.resource,
    })
end
