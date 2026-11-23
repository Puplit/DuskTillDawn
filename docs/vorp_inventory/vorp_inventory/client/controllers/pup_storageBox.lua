-- pup_StorageBox bridge - client controller

-- Right-click "Transfer to box" in a secondary panel, target box already stamped TEMPORARY
RegisterNUICallback("PupBoxDebug", function(data, cb)
    local extra = ""
    if type(data) == "table" and type(data.extra) == "table" then
        local parts = {}
        for k, v in pairs(data.extra) do parts[#parts + 1] = ("%s=%s"):format(tostring(k), tostring(v)) end
        extra = table.concat(parts, "  ")
    end
    print(("^5[boxdebug:nui]^7 %s   %s"):format(tostring(type(data) == "table" and data.msg or "?"), extra))
    if cb then cb({}) end
end)

function NUIService.NUIPupSendItemToBox(obj, cb)
    local item        = obj.item
    local sourceInvId = tostring(obj.sourceInvId or "")
    local invType     = tostring(obj.invType or "custom")
    local targetBoxId = tostring(obj.targetBoxId or "")
    local qty         = tonumber(obj.qty) or 1

    print(("^5[boxdebug:client]^7 SendItemToBox item=%s id=%s src=%s type=%s box=%s qty=%s")
        :format(tostring(item and item.name), tostring(item and item.id),
                sourceInvId, invType, targetBoxId, tostring(qty)))

    if item and sourceInvId ~= "" and targetBoxId ~= "" and qty > 0 then
        TriggerServerEvent("pup_inventory:sendToBox", sourceInvId, item.id, item.name, qty, item.metadata, targetBoxId, invType)
        print("^5[boxdebug:client]^7 fired pup_inventory:sendToBox")
    else
        print(("^1[boxdebug:client]^7 NOT FIRED - item=%s sourceInvId='%s' targetBoxId='%s' qty=%s")
            :format(tostring(item ~= nil), sourceInvId, targetBoxId, tostring(qty)))
    end

    if cb then cb({}) end
end

-- Same, but the chosen box has never been used, so the server stamps it first
function NUIService.NUIPupSendItemToNewBox(obj, cb)
    local item           = obj.item
    local sourceInvId    = tostring(obj.sourceInvId or "")
    local invType        = tostring(obj.invType or "custom")
    local targetItemId   = tonumber(obj.targetItemId)
    local targetItemName = tostring(obj.targetItemName or "")
    local qty            = tonumber(obj.qty) or 1

    if item and sourceInvId ~= "" and targetItemId and targetItemName ~= "" and qty > 0 then
        TriggerServerEvent("pup_inventory:sendToNewBox", sourceInvId, item.id, item.name, qty, item.metadata, targetItemId, targetItemName, invType)
    end

    if cb then cb({}) end
end

-- Drag a stamped storage box from the satchel into a container: instead of moving the box itself
function NUIService.NUIPupDepositBoxToInv(obj, cb)
    local item       = obj.item
    local targetType = tostring(obj.targetType or "")
    local targetId   = tostring(obj.targetId or "")

    if item and targetType ~= "" and targetId ~= "" then
        local metadata = item.metadata
        if type(metadata) == "string" then
            local ok, decoded = pcall(json.decode, metadata)
            if ok then metadata = decoded end
        end

        if type(metadata) == "table" and metadata.boxId then
            TriggerServerEvent("pup_storagebox:depositBoxToInv", item.id, item.name, metadata, targetType, targetId)
        end
    end

    if cb then cb({}) end
end

-- job packs: right-click Unload / Filter on a stamped pack in the satchel
local function packMeta(item)
    local metadata = item and item.metadata
    if type(metadata) == "string" then
        local ok, decoded = pcall(json.decode, metadata)
        if ok then metadata = decoded end
    end
    if type(metadata) == "table" and metadata.boxId then return metadata end
    return nil
end

function NUIService.NUIPupPackUnload(obj, cb)
    local meta = packMeta(obj.item)
    if meta then
        TriggerServerEvent("pup_storagebox:packUnload", obj.item.id, meta.boxId,
            tostring(obj.targetType or ""), obj.targetId ~= nil and tostring(obj.targetId) or "", obj.drop == true)
    end
    if cb then cb({}) end
end

function NUIService.NUIPupPackFilter(obj, cb)
    local meta = packMeta(obj.item)
    if meta then
        TriggerServerEvent("pup_storagebox:packFilter", obj.item.id, meta.boxId)
    end
    if cb then cb({}) end
end

-- pack filter: pup-misc sends the tick list, the page draws it as a dialog
AddEventHandler("pup_storagebox:packFilterNUI", function(data)
    if type(data) ~= "table" then return end
    SendNUIMessage({ action = "pup_packFilter", data = data })
end)

function NUIService.NUIPupPackFilterSet(obj, cb)
    if obj and obj.itemId and obj.boxId then
        TriggerServerEvent("pup_storagebox:packFilterSet", tonumber(obj.itemId), tostring(obj.boxId),
            type(obj.filter) == "table" and obj.filter or {}, obj.all == true)
    end
    if cb then cb({}) end
end
RegisterNUICallback("PupPackFilterSet", NUIService.NUIPupPackFilterSet)

RegisterNUICallback("PupSendItemToBox", NUIService.NUIPupSendItemToBox)
RegisterNUICallback("PupSendItemToNewBox", NUIService.NUIPupSendItemToNewBox)
RegisterNUICallback("PupDepositBoxToInv", NUIService.NUIPupDepositBoxToInv)
RegisterNUICallback("PupPackUnload", NUIService.NUIPupPackUnload)
RegisterNUICallback("PupPackFilter", NUIService.NUIPupPackFilter)

-- Events from pup_StorageBox

-- The UI has to know which item names ARE boxes so it can offer "Transfer to box" and block a used one from being listed
local pupNoBoxInStoreMsg = "You cannot put a used storage box up for sale. Empty it first."
local pupBoxNames = {}
local pupPackNames = {} -- subset of box names that are job packs (Unload / Filter menu)

AddEventHandler("pup_storagebox:boxNamesToNUI", function(names, noBoxInStoreMsg, packs)
    if noBoxInStoreMsg and noBoxInStoreMsg ~= "" then
        pupNoBoxInStoreMsg = noBoxInStoreMsg
    end
    pupBoxNames = names or {}
    pupPackNames = packs or {}
    SendNUIMessage({ action = "pup_boxNames", names = pupBoxNames, packs = pupPackNames })
end)

-- The broadcast above can land before the NUI page exists (both resources start at boot)
RegisterNUICallback("PupRequestBoxNames", function(_, cb)
    if #pupBoxNames == 0 then
        TriggerEvent("pup_storagebox:requestBoxNames")
    end
    if cb then cb({ names = pupBoxNames, packs = pupPackNames }) end
end)

-- A box item was removed from the satchel while its panel was open: close just the secondary panel, leave the satchel up
RegisterNetEvent("pup_storagebox:closeBoxPanel")
AddEventHandler("pup_storagebox:closeBoxPanel", function()
    SendNUIMessage({ action = "pup_closeSecondary" })
end)

RegisterNUICallback("PupBoxBlockStore", function(_, cb)
    CORE.NotifyRightTip(pupNoBoxInStoreMsg, 4000)
    if cb then cb({}) end
end)

-- owner tipped a loaded box onto their own shelves; storagebox reads it and
-- pup_mercantile decides what may be stocked and at what price
RegisterNUICallback("PupBoxDumpToStore", function(data, cb)
    if cb then cb({}) end
    if type(data) ~= "table" or not data.boxId then return end
    TriggerServerEvent("pup_storagebox:dumpToStore", data.id, tostring(data.boxId))
end)
