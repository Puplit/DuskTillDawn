NUIService = {}
function NUIService.OpenClanInventory(clanName, clanId, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "clan",
        title = "" .. clanName .. "",
        clanid = clanId,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
end

function NUIService.NUIMoveToClan(obj)
    TriggerServerEvent("pup_camps:MoveToClan", json.encode(obj))
end

-- camp storage only: pup_camps reorders and saves the stash, then reloads the panel
function NUIService.NUISortClanInventory(obj)
    TriggerServerEvent("pup_camps:SortClanInventory", json.encode(obj))
end

-- the hand-arranged order, saved when Save is pressed
function NUIService.NUIChangeOrderClan(obj)
    TriggerServerEvent("pup_camps:ChangeOrderClan", json.encode(obj))
end

function NUIService.NUITakeFromClan(obj)
    if not InvPending then
        InvPending = true
        TriggerServerEvent("pup_camps:TakeFromClan", json.encode(obj))
    end
end

function NUIService.OpenContainerInventory(ContainerName, Containerid, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "Container",
        title = "" .. ContainerName .. "",
        Containerid = Containerid,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
end

function NUIService.NUIMoveToContainer(obj)
    TriggerServerEvent("pup-Container:MoveToContainer", json.encode(obj))
end

function NUIService.NUITakeFromContainer(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("pup-Container:TakeFromContainer", json.encode(obj))
    end
end

function NUIService.OpenHorseInventory(horseTitle, horseId, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "horse",
        title = horseTitle,
        horseid = horseId,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
    TriggerEvent("vorp_stables:setClosedInv", true)
end

function NUIService.NUIMoveToHorse(obj)
    TriggerServerEvent("vorp_stables:MoveToHorse", json.encode(obj))
end

function NUIService.NUITakeFromHorse(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("vorp_stables:TakeFromHorse", json.encode(obj))
    end
end

function NUIService.NUIMoveToStore(obj)
    TriggerServerEvent("pup_mercantile:MoveToStore", json.encode(obj))
end

function NUIService.NUITakeFromStore(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("pup_mercantile:TakeFromStore", json.encode(obj))
    end
end

function NUIService.OpenStoreInventory(StoreName, StoreId, capacity, geninfox)
    StoreSynMenu = true
    GenSynInfo   = geninfox
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "store",
        title = StoreName,
        StoreId = StoreId,
        capacity = capacity,
        geninfo = GenSynInfo,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
    TriggerEvent("pup_mercantile:setClosedInv", true)
end

function NUIService.OpenstealInventory(stealName, stealId, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "steal",
        title = stealName,
        stealId = stealId,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
    TriggerEvent("vorp_stables:setClosedInv", true)
end

function NUIService.NUIMoveTosteal(obj)
    TriggerServerEvent("pup-search:MoveTosteal", json.encode(obj))
end

function NUIService.NUITakeFromsteal(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("pup-search:TakeFromsteal", json.encode(obj))
    end
end

function NUIService.OpenCartInventory(cartName, wagonId, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "cart",
        title = cartName,
        wagonid = wagonId,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
    TriggerEvent("vorp_stables:setClosedInv", true)
end

function NUIService.NUIMoveToCart(obj)
    TriggerServerEvent("vorp_stables:MoveToCart", json.encode(obj))
end

function NUIService.NUITakeFromCart(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("vorp_stables:TakeFromCart", json.encode(obj))
    end
end

function NUIService.OpenHouseInventory(houseName, houseId, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "house",
        title = houseName,
        houseId = houseId,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
end

function NUIService.NUIMoveToHouse(obj)
    TriggerServerEvent("vorp_housing:MoveToHouse", json.encode(obj))
end

function NUIService.NUITakeFromHouse(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("vorp_housing:TakeFromHouse", json.encode(obj))
    end
end

function NUIService.OpenHideoutInventory(hideoutName, hideoutId, capacity)
    UTILS.APPLY_POSFX()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "display",
        type = "hideout",
        title = hideoutName,
        hideoutId = hideoutId,
        capacity = capacity,
        search = CONFIG.INVENTORY_UI.SEARCH_BAR.ENABLE,
    })
    IS_INV_OPEN = true
    NUI_SERVICE.INVENTORY.GET_LOAD()
end

-- hideout stash ordering: A to Z, and the hand-arranged order on Save
function NUIService.NUISortHideoutInventory(obj)
    TriggerServerEvent("pup_hideouts:SortHideoutInventory", json.encode(obj))
end

function NUIService.NUIChangeOrderHideout(obj)
    TriggerServerEvent("pup_hideouts:ChangeOrderHideout", json.encode(obj))
end

function NUIService.NUIMoveToHideout(obj)
    TriggerServerEvent("pup_hideouts:MoveToHideout", json.encode(obj))
end

function NUIService.NUITakeFromHideout(obj)
    if not InvPending then
        InvPending = true

        TriggerServerEvent("pup_hideouts:TakeFromHideout", json.encode(obj))
    end
end
