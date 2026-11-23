-- pup_library | server-side cleaning of book HTML and the page JSON.
-- Every tag is rebuilt from scratch: only allow-listed tags and attributes come out.

Clean = {}

local function set(list)
    local t = {}
    for _, v in ipairs(list) do t[v] = true end
    return t
end

local ALLOWED_TAGS = set({
    'p', 'br', 'span', 'div', 'strong', 'b', 'em', 'i', 'u', 's', 'strike', 'del', 'ins', 'sub', 'sup',
    'small', 'big', 'mark', 'font', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'pre', 'code',
    'ul', 'ol', 'li', 'hr', 'a', 'img', 'figure', 'figcaption', 'table', 'thead', 'tbody', 'tfoot',
    'tr', 'th', 'td', 'colgroup', 'col', 'caption',
})

-- elements written without a closing tag
local VOID_ALLOWED = set({ 'br', 'hr', 'img', 'col' })

-- dropped together with everything inside them
local DROP_WITH_CONTENT = set({
    'script', 'style', 'iframe', 'frame', 'frameset', 'object', 'embed', 'noscript', 'template',
    'svg', 'math', 'textarea', 'select', 'option', 'button', 'input', 'form', 'link', 'meta', 'base',
    'title', 'head', 'audio', 'video', 'source', 'track', 'canvas',
})
-- of those, the ones HTML never closes: only the tag itself is dropped
local DROP_VOID = set({ 'embed', 'input', 'link', 'meta', 'base', 'source', 'track', 'frame' })

local ALLOWED_ATTRS = set({
    'style', 'class', 'colspan', 'rowspan', 'align', 'width', 'height', 'alt', 'title',
    'href', 'src', 'color', 'face', 'size',
})

local BAD_STYLE = { 'url(', 'expression', 'javascript', '@import', 'behavior', '\\', '&#', '<' }

local MAX_PASSES <const> = 8

--------------------------------------------------------------------------------
-- value rules
--------------------------------------------------------------------------------

-- http://, https://, nui:// or an inline base64 PNG/JPEG/GIF/WebP picture
function Clean.Url(value)
    if type(value) ~= 'string' then return nil end
    local v = value:gsub('^%s+', '')
    local low = v:lower()
    if low:sub(1, 7) == 'http://' or low:sub(1, 8) == 'https://' or low:sub(1, 6) == 'nui://' then
        return v
    end
    local mime, rest = low:match('^data:image/([%a]+);base64,(.*)$')
    if mime == 'png' or mime == 'jpeg' or mime == 'jpg' or mime == 'gif' or mime == 'webp' then
        -- the payload may only be base64 characters (whitespace is tolerated)
        if rest:find('[^%w%+/=%s]') then return nil end
        return v
    end
    return nil
end

function Clean.Style(value)
    if type(value) ~= 'string' then return nil end
    local low = value:lower()
    for _, bad in ipairs(BAD_STYLE) do
        if low:find(bad, 1, true) then return nil end
    end
    -- the browser decodes entities in the attribute before CSS sees it, so a named
    -- entity such as &lpar; could rebuild "url(". Only the harmless ones a browser
    -- itself writes into a style attribute are let through.
    for ent in low:gmatch('&(%w*)') do
        if ent ~= 'quot' and ent ~= 'amp' and ent ~= 'apos' and ent ~= 'nbsp' then return nil end
    end
    return value
end

-- the page background picture
function Clean.Background(value)
    if type(value) ~= 'string' or value == '' then return nil end
    if #value > 2048 then return nil end
    if value:find('[%s"\'%(%)%[%]{}<>\\]') then return nil end
    return Clean.Url(value)
end

-- page colour and text colour
function Clean.Colour(value)
    if type(value) ~= 'string' or value == '' then return nil end
    if #value > 40 then return nil end
    if value:find('[^%w %#%(%),%.%%]') then return nil end
    local low = value:lower()
    if low:find('url', 1, true) or low:find('expression', 1, true) then return nil end
    return value
end

--------------------------------------------------------------------------------
-- HTML
--------------------------------------------------------------------------------

local function escapeText(s)
    return (s:gsub('>', '&gt;'))
end

local function quoteAttr(s)
    return (s:gsub('"', '&quot;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

-- Reads the attributes of an opening tag from `s`, starting at `i` (just after
-- the tag name). Returns the attribute list, the position after the closing '>'
-- and whether the tag ended in '/>'. Returns nil when the tag never closes.
local function readAttributes(s, i)
    local attrs = {}
    local len = #s
    while i <= len do
        local _, e = s:find('^[%s/]*', i)
        i = e + 1
        if i > len then return nil end
        local c = s:sub(i, i)
        if c == '>' then
            local selfClose = s:sub(i - 1, i - 1) == '/'
            return attrs, i + 1, selfClose
        end
        local name
        local ns, ne = s:find('^[^%s/>=]+', i)
        if not ns then
            i = i + 1
        else
            name = s:sub(ns, ne):lower()
            i = ne + 1
            local _, we = s:find('^%s*', i)
            local j = we + 1
            local value = nil
            if s:sub(j, j) == '=' then
                j = j + 1
                local _, we2 = s:find('^%s*', j)
                j = we2 + 1
                local q = s:sub(j, j)
                if q == '"' or q == "'" then
                    local close = s:find(q, j + 1, true)
                    if not close then return nil end
                    value = s:sub(j + 1, close - 1)
                    i = close + 1
                else
                    local vs, ve = s:find('^[^%s>]+', j)
                    if vs then
                        value = s:sub(vs, ve)
                        i = ve + 1
                    else
                        value = ''
                        i = j
                    end
                end
            end
            attrs[#attrs + 1] = { name = name, value = value }
        end
    end
    return nil
end

local function buildAttributes(attrs)
    local out = {}
    local seen = {}
    for _, a in ipairs(attrs) do
        local name, value = a.name, a.value
        if ALLOWED_ATTRS[name] and not seen[name] then
            if name == 'href' or name == 'src' then
                value = Clean.Url(value or '')
            elseif name == 'style' then
                value = Clean.Style(value or '')
            else
                value = value or ''
            end
            if value then
                seen[name] = true
                out[#out + 1] = (' %s="%s"'):format(name, quoteAttr(value))
            end
        end
    end
    return table.concat(out)
end

-- Skips past the matching "</name>" (case-insensitive). Nil when it never closes.
-- `low` is s:lower(), made once per pass by the caller (lowering a 512 KB text for
-- every dropped tag would let one save stall the server thread).
local function skipContainer(low, i, name)
    local pattern = '</' .. name
    local pos = i
    while true do
        local a = low:find(pattern, pos, true)
        if not a then return nil end
        local after = a + #pattern
        local nextc = low:sub(after, after)
        if nextc == '>' or nextc:match('[%s/]') then
            local gt = low:find('>', after, true)
            if not gt then return nil end
            return gt + 1
        end
        pos = after
    end
end

-- One cleaning pass.
local function pass(s)
    local out = {}
    local i, len = 1, #s
    local low = nil -- s:lower(), made on the first dropped container
    while i <= len do
        local lt = s:find('<', i, true)
        if not lt then
            out[#out + 1] = escapeText(s:sub(i))
            break
        end
        if lt > i then out[#out + 1] = escapeText(s:sub(i, lt - 1)) end

        local rest2 = s:sub(lt + 1, lt + 1)
        if s:sub(lt, lt + 3) == '<!--' then
            -- comment
            local e = s:find('-->', lt + 4, true)
            if not e then break end
            i = e + 3
        elseif rest2 == '!' or rest2 == '?' then
            -- doctype, processing instruction, CDATA
            local e = s:find('>', lt + 2, true)
            if not e then break end
            i = e + 1
        elseif rest2 == '/' and s:sub(lt + 2, lt + 2):match('%a') then
            -- closing tag
            local ns, ne = s:find('^%a[%w]*', lt + 2)
            local name = s:sub(ns, ne):lower()
            local gt = s:find('>', ne + 1, true)
            if not gt then break end
            if ALLOWED_TAGS[name] and not VOID_ALLOWED[name] then
                out[#out + 1] = '</' .. name .. '>'
            end
            i = gt + 1
        elseif rest2:match('%a') then
            -- opening tag
            local ns, ne = s:find('^%a[%w]*', lt + 1)
            local name = s:sub(ns, ne):lower()
            local attrs, after, selfClose = readAttributes(s, ne + 1)
            if not attrs then break end
            if DROP_WITH_CONTENT[name] then
                if DROP_VOID[name] or selfClose then
                    i = after
                else
                    low = low or s:lower()
                    local skip = skipContainer(low, after, name)
                    if not skip then break end
                    i = skip
                end
            elseif ALLOWED_TAGS[name] then
                out[#out + 1] = '<' .. name .. buildAttributes(attrs) .. '>'
                i = after
            else
                -- unknown tag: removed, its contents stay
                i = after
            end
        else
            -- a stray '<' is just text
            out[#out + 1] = '&lt;'
            i = lt + 1
        end
    end
    return table.concat(out)
end

function Clean.Html(s)
    if type(s) ~= 'string' then return '' end
    local current = s
    for _ = 1, MAX_PASSES do
        local nextValue = pass(current)
        if nextValue == current then return current end
        current = nextValue
    end
    -- still changing: make every '<' plain text
    return (current:gsub('<', '&lt;'))
end

--------------------------------------------------------------------------------
-- book JSON
--------------------------------------------------------------------------------

-- Returns the cleaned JSON string, or nil and a reason: 'large', 'pages', 'bad'.
function Clean.Book(raw)
    if type(raw) ~= 'string' then return nil, 'bad' end
    if #raw > Config.MaxBytes then return nil, 'large' end
    -- broken UTF-8 cannot be stored in the utf8mb4 column
    if not utf8.len(raw) then return nil, 'bad' end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return nil, 'bad' end
    local pages = decoded.pages
    if pages == nil then return nil, 'bad' end
    if type(pages) ~= 'table' then return nil, 'bad' end

    local count = 0
    for k in pairs(pages) do
        if math.type(k) ~= 'integer' or k < 1 then return nil, 'bad' end
        count = count + 1
    end
    if count ~= #pages then return nil, 'bad' end
    if count > Config.MaxPages then return nil, 'pages' end

    local outPages = {}
    for idx = 1, count do
        local p = pages[idx]
        if type(p) ~= 'table' then return nil, 'bad' end
        local page = { content = Clean.Html(type(p.content) == 'string' and p.content or '') }
        page.background = Clean.Background(p.background)
        page.backgroundColor = Clean.Colour(p.backgroundColor)
        page.color = Clean.Colour(p.color)
        outPages[idx] = page
    end
    if #outPages == 0 then outPages[1] = { content = '' } end

    local book = { pages = outPages }
    for _, key in ipairs({ 'frontImage', 'midImage', 'backImage' }) do
        if decoded[key] ~= nil then book[key] = Clean.Background(decoded[key]) end
    end

    local encoded = json.encode(book)
    if type(encoded) ~= 'string' then return nil, 'bad' end
    if #encoded > Config.MaxBytes then return nil, 'large' end
    return encoded
end

function Clean.NewBook()
    local pages = {}
    for i = 1, Config.NewBookPages do pages[i] = { content = '' } end
    return json.encode({ pages = pages })
end
