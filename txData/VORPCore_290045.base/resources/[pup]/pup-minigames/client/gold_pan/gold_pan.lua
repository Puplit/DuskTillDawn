-- GOLD PAN — swirl the pan, wash off the gravel, keep the gold.
-- Unlike the pass/fail games in this pack, the callback gets a SCORE from 0.0 to 1.0.

local callback
local active

local function start_game(game_data, game_callback)
    if active then return end
    active = true
    callback = game_callback
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'start_minigame',
        game = 'gold_pan',
        data = {
            style      = game_data.style,
            duration   = game_data.duration,   -- ms before the pan is called done
            target_min = game_data.target_min, -- rad/s, below this the wash is weak
            target_max = game_data.target_max, -- rad/s, above this gold washes out
            silt_rate  = game_data.silt_rate,  -- silt % cleared per second
            gold_rate  = game_data.gold_rate,  -- gold % lost per second per rad/s over
            hint       = game_data.hint,       -- false = no hint line
            -- live coaching under the hint; nil = the built-in wording
            slow_text  = game_data.slow_text,
            good_text  = game_data.good_text,
            fast_text  = game_data.fast_text,
        }
    })
end

RegisterNUICallback('gold_pan_end', function(data, cb)
    SetNuiFocus(false, false)
    active = false
    if cb then cb('ok') end
    if callback then callback(tonumber(data and data.score) or 0.0) end
end)

exports('gold_pan', start_game)

if Config.General.testCommands then
    RegisterCommand('test_gold_pan', function()
        exports['pup-minigames']:gold_pan({
            style = 'default',
            duration = 15000,
            target_min = 2.2,
            target_max = 5.0,
        }, function(score)
            print(('gold_pan score %.2f'):format(score))
        end)
    end)
end
