-- The phonograph menu and the staff setup menu (pup-ui, vorp_menu calling style).

PC = PC or {}
PC.MyVolume = Config.DefaultVolume

local MAIN_ID <const> = 'pup_phonograph_main'
local RECORDS_ID <const> = 'pup_phonograph_records'
local SETUP_ID <const> = 'pup_phonograph_setup'

local function requestMenu(id)
    TriggerServerEvent('pup-phonograph:server:openMenu', id)
end

local function el(label, value, desc)
    return { label = label, value = value, desc = desc, descText = desc }
end

local function openRecords(info)
    local menu = PC.Menu()
    if not menu then return end
    local elements = {}
    for _, r in ipairs(info.records or {}) do
        if type(r) == 'table' and type(r.item) == 'string' then
            elements[#elements + 1] = el(tostring(r.label or r.item), r.item, nil)
        end
    end
    pcall(menu.CloseAll)
    menu.Open('default', PC.Res, RECORDS_ID, {
        title = Lang.recordsTitle,
        subtext = Lang.recordsSubtitle,
        align = 'top-left',
        elements = elements,
    }, function(data, m)
        local cur = data and data.current
        if type(cur) ~= 'table' then return end
        m.close()
        TriggerServerEvent('pup-phonograph:server:insertRecord', info.id, cur.value)
        SetTimeout(500, function() requestMenu(info.id) end)
    end, function(_, m)
        m.close()
        requestMenu(info.id)
    end)
end

local function handle(info, value)
    local id = info.id
    if value == 'volume' then
        local n = tonumber(PC.AskValue({ title = Lang.volumeTitle, label = Lang.volumeLabel, type = 'number' }))
        if n then
            local v = PC.Clamp(n / 100.0, 0.0, 1.0)
            PC.MyVolume = v
            TriggerServerEvent('pup-phonograph:server:volume', id, v)
        end
        requestMenu(id)
    elseif value == 'distance' then
        local n = tonumber(PC.AskValue({ title = Lang.distanceTitle, label = Lang.distanceLabel, type = 'number' }))
        if n then
            TriggerServerEvent('pup-phonograph:server:radius', id, PC.Clamp(n, Config.Radius.min, Config.Radius.max))
        end
        requestMenu(id)
    elseif value == 'stop' then
        TriggerServerEvent('pup-phonograph:server:stop', id)
        PC.Tip(Lang.musicStopped, 500)
        requestMenu(id)
    elseif value == 'stopAll' then
        TriggerServerEvent('pup-phonograph:server:stopAll')
    elseif value == 'loop' then
        TriggerServerEvent('pup-phonograph:server:toggleLoop', id)
        SetTimeout(300, function() requestMenu(id) end)
    elseif value == 'play' then
        local url = PC.AskValue({ title = Lang.urlTitle, label = Lang.urlLabel, placeholder = Lang.urlPlaceholder })
        if url and url:sub(1, 4):lower() == 'http' then
            local volume = tonumber(info.volume) or PC.MyVolume
            TriggerServerEvent('pup-phonograph:server:play', id, url, volume, false, tonumber(info.radius) or Config.Radius.default)
            PC.Tip(Lang.musicStarted, 1500)
        elseif url then
            PC.Tip(Lang.badLink, 3000)
        end
    elseif value == 'records' then
        openRecords(info)
    elseif value == 'recordPlay' then
        TriggerServerEvent('pup-phonograph:server:playRecord', id)
        PC.Tip(Lang.musicStarted, 1500)
    elseif value == 'recordRemove' then
        TriggerServerEvent('pup-phonograph:server:removeRecord', id)
    elseif value == 'pickup' then
        TriggerServerEvent('pup-phonograph:server:pickup', id)
    end
end

local function openMain(info)
    local menu = PC.Menu()
    if not menu then return end
    local id = tonumber(info.id)
    if not id then return end
    info.id = id
    if info.isStaff ~= nil then PC.IsStaff = info.isStaff == true end

    -- show what the phonograph really plays at; fall back to this player's last choice
    local volume = tonumber(info.volume) or PC.MyVolume
    local radius = tonumber(info.radius) or Config.Radius.default

    local elements = {
        el(Lang.menuVolume:format(math.floor(volume * 100 + 0.5)), 'volume', Lang.menuVolumeDesc),
        el(Lang.menuDistance:format(math.floor(radius + 0.5)), 'distance', Lang.menuDistanceDesc),
        el(Lang.menuStop, 'stop', Lang.menuStopDesc),
    }
    if info.isStaff == true then
        elements[#elements + 1] = el(Lang.menuStopAll, 'stopAll', Lang.menuStopAllDesc)
    end
    if Config.LoopToggleInMenu and info.playing == true then
        elements[#elements + 1] = el(info.loop == true and Lang.menuLoopOn or Lang.menuLoopOff, 'loop', Lang.menuLoopDesc)
    end
    elements[#elements + 1] = el(Lang.menuPlay, 'play', Lang.menuPlayDesc)
    if type(info.records) == 'table' and #info.records > 0 then
        elements[#elements + 1] = el(Lang.menuRecords, 'records', Lang.menuRecordsDesc)
        if type(info.record) == 'string' and info.record ~= '' then
            elements[#elements + 1] = el(Lang.menuRecordPlay:format(tostring(info.recordLabel or info.record)),
                'recordPlay', Lang.menuRecordPlayDesc)
            elements[#elements + 1] = el(Lang.menuRecordRemove, 'recordRemove', Lang.menuRecordRemoveDesc)
        end
    end
    elements[#elements + 1] = el(Lang.menuPickup, 'pickup', Lang.menuPickupDesc)

    pcall(menu.CloseAll)
    menu.Open('default', PC.Res, MAIN_ID, {
        title = Lang.menuTitle,
        subtext = Lang.menuSubtitle,
        align = 'top-left',
        elements = elements,
    }, function(data, m)
        local cur = data and data.current
        if type(cur) ~= 'table' then return end
        local value = cur.value
        m.close()
        CreateThread(function() handle(info, value) end)
    end, function(_, m)
        m.close()
    end)
end

RegisterNetEvent('pup-phonograph:client:menu', function(info)
    if type(info) ~= 'table' or PC.Placing then return end
    openMain(info)
end)

-- staff: choose the job lock and rank, then save -----------------------------

function PC.OpenStaffSetup(pos, rot)
    local job, rank = '', 0

    local function show()
        local menu = PC.Menu()
        if not menu then return end
        pcall(menu.CloseAll)
        menu.Open('default', PC.Res, SETUP_ID, {
            title = Lang.setupTitle,
            subtext = Lang.setupSubtitle,
            align = 'top-left',
            elements = {
                el(Lang.setupJob:format(job == '' and Lang.setupNone or job), 'job', Lang.setupJobDesc),
                el(Lang.setupRank:format(rank), 'rank', Lang.setupRankDesc),
                el(Lang.setupSave, 'save', Lang.setupSaveDesc),
            },
        }, function(data, m)
            local cur = data and data.current
            if type(cur) ~= 'table' then return end
            local value = cur.value
            if value == 'save' then
                m.close()
                TriggerServerEvent('pup-phonograph:server:saveStaff', pos, rot, job, rank)
                return
            end
            m.close()
            CreateThread(function()
                if value == 'job' then
                    -- a blank answer clears the lock; cancelling keeps what was there
                    local v = PC.Ask({ title = Lang.jobTitle, label = Lang.jobLabel })
                    if v ~= nil then
                        v = v:match('^%s*(.-)%s*$')
                        if #v <= Config.StaffJobMaxLength then job = v else PC.Tip(Lang.badSetup, 3000) end
                    end
                elseif value == 'rank' then
                    local v = PC.Ask({ title = Lang.rankTitle, label = Lang.rankLabel, type = 'number' })
                    if v ~= nil then
                        local n = tonumber(v) or 0
                        rank = math.floor(PC.Clamp(n, 0, Config.StaffRankMax))
                    end
                end
                show()
            end)
        end, function(_, m)
            m.close()
            PC.Tip(Lang.placementCancelled, 2000)
        end)
    end

    show()
end
