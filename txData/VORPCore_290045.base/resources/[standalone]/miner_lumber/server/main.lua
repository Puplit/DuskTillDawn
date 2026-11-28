local VorpCore = {}

TriggerEvent("getCore",function(core)
    VorpCore = core
end)

Citizen.CreateThread(function()
	for k,v in pairs(Config.Tools) do
		exports.vorp_inventory:registerUsableItem(k, function(data)
                    useditem(data.source,k,v,data)
		end)
	end
end)

function useditem(source,item,iteminfo,info)
    local _source = source
    local meta = info.item.metadata
    local durability 
    if meta ~= nil then 
        durability = meta.durability 
    end
    if durability == nil then 
        durability = Config.Tools[item].durability
    end
    TriggerClientEvent("pup_miner_lumber:itemused", _source, item, iteminfo, durability,info)
end

-- a tool that left the satchel (given, dropped, sold, stored) cannot stay in hand
AddEventHandler("vorp_inventory:Server:OnItemRemoved", function(data, src)
    if type(data) ~= "table" or not src or not Config.Tools[data.name] then return end
    local left = exports.vorp_inventory:getItemCount(src, nil, data.name)
    if (tonumber(left) or 0) <= 0 then
        TriggerClientEvent("pup_miner_lumber:forceunequip", src, data.name)
    end
end)


-- pup-perks bridge. pcall-guarded so a stopped pup-perks just means stock yield.
function perkBonus(src, key)
    local ok, res = pcall(function() return exports['pup-perks']:Bonus(src, key) end)
    return (ok and tonumber(res)) or 0
end

function logGather(source, itemName, itemLabel, count, gatherType)
    local _source = source
    local User = VorpCore.getUser(_source)
    local Character = User.getUsedCharacter
    local charID = Character.charIdentifier
    local charName = Character.firstname .. " " .. Character.lastname
    
    local identifiers = GetPlayerIdentifiers(_source)
    local steamID = ""
    local discordID = ""
    
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 6) == "steam:" then
            steamID = id
        elseif string.sub(id, 1, 8) == "discord:" then
            discordID = id
        end
    end

    if Config.DiscordWebhook ~= "YOUR_DISCORD_WEBHOOK_URL_HERE" and Config.DiscordWebhook ~= "" then
        local discordMention = ""
        if discordID ~= "" then
            discordMention = "<@" .. string.sub(discordID, 9) .. ">"
        end
        
        local timeStr = os.date("%m/%d/%Y %I:%M:%S %p")
        
        local embed = {
            {
                ["title"] = "Gather Log",
                ["color"] = 3447003,
                ["fields"] = {
                    {
                        ["name"] = "Player Information",
                        ["value"] = "**Char ID:** " .. tostring(charID) .. "\n" ..
                                   "**Name:** " .. charName .. "\n" ..
                                   "**Steam ID:** " .. steamID .. "\n" ..
                                   "**Discord ID:** " .. discordMention,
                        ["inline"] = false
                    },
                    {
                        ["name"] = "Gather Information",
                        ["value"] = "**Type:** " .. tostring(gatherType) .. "\n" ..
                                   "**Item:** " .. itemLabel .. "\n" ..
                                   "**Amount:** " .. tostring(count),
                        ["inline"] = false
                    },
                    {
                        ["name"] = "Time",
                        ["value"] = timeStr,
                        ["inline"] = false
                    }
                }
            }
        }
        
        PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- last award per player, for the prop-path rate limit below
local lastGather = {}
AddEventHandler('playerDropped', function() lastGather[source] = nil end)

-- Fastest a swing can legitimately come round again, derived from the client's
-- own cycle: hit the bar, endDelay holds the result, then swingDelay before the
-- next press is accepted. Kept in step with Config.MinigameTuning so honest
-- fast swings are never thrown away (the client drains durability either way).
local function minSwingMs()
    local t = type(Config) == 'table' and type(Config.MinigameTuning) == 'table'
        and Config.MinigameTuning or {}
    local floor = (tonumber(t.endDelay) or 400) + (tonumber(t.swingDelay) or 150)
    return math.max(250, floor - 100) -- 100ms of headroom for network jitter
end

RegisterServerEvent('pup_miner_lumber:addItem')
AddEventHandler('pup_miner_lumber:addItem', function(thetype, itemused, gathermode)
    local _source = source

    -- ANTI-CHEAT
    local nodes = Config.Nodes and Config.Nodes[thetype]
    if not nodes then
        print(("[pup_miner_lumber] node data missing for '%s' - is data.lua still in shared_scripts? Gather rejected.")
            :format(tostring(thetype)))
        return
    end

    if gathermode == 'object' then
        local now = GetGameTimer()
        local last = lastGather[_source] or 0
        local floor = minSwingMs()
        if (now - last) < floor then
            print(string.format("[pup_miner_lumber] Player %s (ID: %s) swung again after %dms (floor %dms) - ignored.",
                GetPlayerName(_source), _source, now - last, floor))
            return
        end
        lastGather[_source] = now
    else
        local playerPed = GetPlayerPed(_source)
        local playerCoords = GetEntityCoords(playerPed)
        local isNearNode = false

        for _, location in ipairs(nodes) do
            local dist = #(playerCoords - vector3(location.x, location.y, location.z))
            if dist < 10.0 then -- Allow 10 units for network latency/movement
                isNearNode = true
                break
            end
        end

        if not isNearNode then
            -- Potential exploiter: triggering event from too far away
            print(string.format("[pup_miner_lumber] Player %s (ID: %s) tried to add item from too far! (Type: %s)", GetPlayerName(_source), _source, thetype))
            return
        end
    end

    local itemcount = exports.vorp_inventory:getItemCount(_source,nil,itemused)
    if itemcount <= 0 then
        VorpCore.NotifyRightTip(_source, language.noaxe .. itemused .. language.noaxe2, 3000)
        return
    end

    -- pup-perks: civ XP per validated good swing. thetype is safe as the kind here
    pcall(function() exports['pup-perks']:Award(_source, thetype) end)

    local Character = VorpCore.getUser(_source).getUsedCharacter
    local job = Character.job
    local gather = Config.Gather[thetype]
    local chance = math.random(1, 10)
    local reward = {}
    for k, v in pairs(gather.rewards) do
        if v.chance >= chance then
            table.insert(reward, v)
        end
    end
    local amount2 = keysx(reward)
    if amount2 ~= 0 then
        local chance2 = math.random(1, keysx(reward))
        local count = math.random(1, reward[chance2].max)
        if containsjob(job, gather.jobs) then
            count = count + gather.jobBonus
        end
        -- pup-perks: Rich Seam stacks ON TOP of the job bonus rather than replacing it
        count = count + perkBonus(_source, 'gather_yield')

        -- job pack first (pup-misc storagebox); pockets only when there is no pack or it is full
        local packed, packLabel = false, nil
        pcall(function()
            packed, packLabel = exports['pup-misc']:PackStore(_source, thetype, reward[chance2].item, count)
        end)
        if packed then
            logGather(_source, reward[chance2].item, reward[chance2].label, count, thetype)
            VorpCore.NotifyRightTip(_source, language.youfound .. reward[chance2].label .. language.inpack .. (packLabel or "pack"), 3000)
            return
        end

        local canCarry2 = exports.vorp_inventory:canCarryItems(_source,count)

        if canCarry2 == false then
            VorpCore.NotifyRightTip(_source, language.cantcarry, 3000)
        elseif canCarry2 then
            local canCarry = exports.vorp_inventory:canCarryItem(_source, reward[chance2].item, count)
            if canCarry then
                exports.vorp_inventory:addItem(_source, reward[chance2].item, count,nil)
                logGather(_source, reward[chance2].item, reward[chance2].label, count, thetype)
                VorpCore.NotifyRightTip(_source, language.youfound .. reward[chance2].label, 3000)
            else
                VorpCore.NotifyRightTip(_source, language.cantcarry .. reward[chance2].label, 3000)
            end
        end
    end
end)


RegisterServerEvent('pup_miner_lumber:removeitem')
AddEventHandler('pup_miner_lumber:removeitem', function(item,itemdata)
	local _source = source
    local id = itemdata.item.mainid
    exports.vorp_inventory:subItemID(_source, id, nil)
    VorpCore.NotifyRightTip( _source, language.axebroken, 2000)
end)

-- Durability bar: swings left are counted in metadata.durability; this mirrors
-- them as a percentage into the item's durability field, which the satchel draws
-- as a coloured bar. The item needs a durability value in the items table or
-- vorp refuses the write.
function showDurability(src, itemId, itemName, left)
    local cfg = Config.Tools[itemName]
    local max = cfg and tonumber(cfg.durability)
    if not max or max <= 0 or not itemId then return end
    local pct = math.floor(((tonumber(left) or 0) / max) * 100)
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    pcall(function()
        exports.vorp_inventory:setItemDurability(src, tonumber(itemId), pct)
    end)
end

RegisterServerEvent('pup_miner_lumber:updateitem')
AddEventHandler('pup_miner_lumber:updateitem', function(item,newdura,itemdata)
    local _source = source
    local itemmetadata = itemdata.item
    if itemmetadata.metadata ~= nil then 
        local meta = itemmetadata.metadata
        local description = meta.description
        if description ~= nil then 
            if string.match(description,language.durability) then
                local newstring = string.gsub(meta.description, language.durability.."%d+", language.durability..newdura)
                meta.description = newstring
                meta.durability = newdura
            else
                meta.description = meta.description.." <br> "..language.durability..newdura
                meta.durability = newdura
            end
        else
            meta.description = language.durability..newdura
            meta.durability = newdura
        end
        exports.vorp_inventory:setItemMetadata(_source, itemmetadata.mainid,meta,1,nil)
        showDurability(_source, itemmetadata.mainid, item, newdura)
    end
end)
