-- Two backends behind one export: Config.SafeCrack.useQadrSafe = true uses qadr-safe (the native RDR2 dial)
-- when it is started, otherwise the built-in NUI safe. Both take {style, difficulty, attempts}.

-- Locals
local callback
local active -- one flag per game, so a stuck game cannot block the others
-- FUNCTIONS

-- Is the native dial available right now?
local function qadr_ready()
    return Config.SafeCrack.useQadrSafe and GetResourceState('qadr-safe') == 'started'
end

-- Function to start game
local function start_game(game_data, game_callback)
    if active then return end

    if qadr_ready() then
        active = true
        -- createSafe BLOCKS until the player wins, fails or cancels, so it has to run off the caller's thread
        CreateThread(function()
            -- PIN COUNT
            local locks = tonumber(game_data.pins)
            if not locks and type(game_data.combination) == 'table' and #game_data.combination > 0 then
                locks = #game_data.combination
            end
            locks = math.floor(locks or tonumber(game_data.difficulty) or 3)
            if locks < 1 then locks = 1 end
            if locks > 5 then locks = 5 end

            -- The NUMBERS are always freshly rolled, never the configured ones
            local combination = {}
            for i = 1, locks do
                combination[i] = math.random(0, 99) -- 0-99 ONLY; outside that the dial can never line up
            end

            -- backdrop defaults on (the bank-vault door art)
            local ok = exports['qadr-safe']:createSafe(combination, {
                backdrop = game_data.backdrop ~= false,
                freeze   = game_data.freeze ~= false,
            })

            active = false
            if game_callback then game_callback(ok == true) end
        end)
        return
    end

    active = true
    callback = game_callback
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'start_minigame',
        game = 'safe_crack',
        data = {
            style = game_data.style,
            difficulty = game_data.difficulty,
            -- 0 or nil = unlimited guesses
            attempts = game_data.attempts
        }
    })
end

-- NUI

-- Nui callback to end game
RegisterNUICallback('safe_crack_end', function(data)
    SetNuiFocus(false, false)
    active = false
    if callback then callback(data.success) end
end)

-- EXPORT

exports('safe_crack', start_game)

-- TEST

if Config.General.testCommands then
    RegisterCommand('test_safe_crack', function()
        exports['pup-minigames']:safe_crack({
            style = 'default', -- Style template
            difficulty = 3 -- number of pins/locks; 1-5
        }, function(success)
            if success then
                print('safe_crack success')
            else
                print('safe_crack fail')
            end
        end)
    end)
end
