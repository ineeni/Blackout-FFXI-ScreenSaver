_addon.name = 'Blackout'
_addon.author = 'Jinxs'
_addon.version = '3.0'
_addon.commands = {'blackout'}

local texts = require('texts')
local config = require('config')

-- Localize standard library functions and Windower APIs
local math_abs, math_pi, os_clock, os_date, os_time = math.abs, math.pi, os.clock, os.date, os.time
local string_rep, coroutine_sleep, coroutine_schedule = string.rep, coroutine.sleep, coroutine.schedule
local windower_ffxi, windower_add_to_chat = windower.ffxi, windower.add_to_chat
local windower_send_command, windower_get_windower_settings = windower.send_command, windower.get_windower_settings
local texts_new = texts.new

math.randomseed(os_time())

-- Constants
local EPSILON = 0.001
local EPSILON_FACING = 0.0001
local TWO_PI = 2 * math_pi
local INACTIVE_SLEEP = 10   -- Check every 10 seconds when playing normally (near-zero overhead)

-- Default settings
local defaults = {
    idle_timeout = 300,
    disable_in_combat = true,
    disable_if_dead = true,
    show_fps_on_off = true,
    auto_enabled = true,
    minimize_enabled = true,
    minimize_timeout = 600,
    bg_alpha = 255
}

local settings = config.load(defaults)

local overlay, overlay_visible = nil, false
local last_activity_time = os_clock()
local player_id, minimized_triggered = nil, false
local last_x, last_y, last_z, last_facing

local function get_res()
    local s = windower_get_windower_settings()
    return s.ui_x_res, s.ui_y_res
end

local function create_overlay()
    if overlay then
        overlay:destroy()
        overlay = nil
    end

    overlay = texts_new()
    local w, h = get_res()

    overlay:pos(0, 0)
    overlay:size(w, h)
    overlay:bg_visible(true)
    overlay:bg_color(0, 0, 0)
    overlay:bg_alpha(settings.bg_alpha)
    overlay:text(string_rep(" ", 5000))
    overlay:draggable(false)
    overlay:hide()
    overlay_visible = false
end

local function show_overlay()
    if not overlay_visible then
        create_overlay() -- Recreate overlay to force it to the top of the text rendering layer
        if overlay then
            overlay:show()
        end
        overlay_visible = true
        if settings.show_fps_on_off then
            windower_send_command('showfps 0')
        end
        local timestamp = os_date('%H:%M:%S')
        windower_add_to_chat(207, '[Blackout] [' .. timestamp .. '] Screen Saver activated.')

        if settings.minimize_enabled then
            local delay = settings.minimize_timeout - settings.idle_timeout
            if delay <= 0 then
                minimized_triggered = true
                windower_send_command('game_minimize')
                windower_add_to_chat(207, '[Blackout] [' .. timestamp .. '] Game minimized due to inactivity.')
            else
                coroutine_schedule(function()
                    if overlay_visible and not minimized_triggered and settings.minimize_enabled then
                        minimized_triggered = true
                        windower_send_command('game_minimize')
                        local min_timestamp = os_date('%H:%M:%S')
                        windower_add_to_chat(207, '[Blackout] [' .. min_timestamp .. '] Game minimized due to inactivity.')
                    end
                end, delay)
            end
        end
    end
end

local function hide_overlay(triggered_by_user)
    if overlay_visible then
        if overlay then
            overlay:hide()
        end
        overlay_visible = false
        if settings.show_fps_on_off then
            windower_send_command('showfps 1')
        end
        if triggered_by_user then
            local timestamp = os_date('%H:%M:%S')
            windower_add_to_chat(207, '[Blackout] [' .. timestamp .. '] Screen Saver deactivated.')
        end
    end
end

local function reset_activity()
    minimized_triggered = false
    if overlay_visible then
        hide_overlay(true)
        last_activity_time = os_clock()
    else
        -- Micro-optimization: Only update timestamp at most once per second
        -- to prevent excessive local variable writes during rapid mouse movement.
        local now = os_clock()
        if now - last_activity_time > 1 then
            last_activity_time = now
        end
    end
end

-- Cache Player ID
local function update_player_id()
    local player = windower_ffxi.get_player()
    player_id = player and player.id or nil
end

-- Check character movement/combat status
local function check_game_state()
    if not player_id then
        update_player_id()
    end

    if not player_id then return end

    local player_mob = windower_ffxi.get_mob_by_id(player_id)
    if player_mob then
        -- Check movement
        local current_x = player_mob.x
        local current_y = player_mob.y
        local current_z = player_mob.z
        local current_facing = player_mob.facing

        if last_x then
            local diff_facing = math_abs(current_facing - last_facing)
            if diff_facing > math_pi then
                diff_facing = TWO_PI - diff_facing
            end

            if math_abs(current_x - last_x) > EPSILON or
               math_abs(current_y - last_y) > EPSILON or
               math_abs(current_z - last_z) > EPSILON or
               diff_facing > EPSILON_FACING then
                reset_activity()
            end
        end

        last_x = current_x
        last_y = current_y
        last_z = current_z
        last_facing = current_facing

        -- Check player status (combat/death) using player_mob.status
        -- status 1 is Engaged (combat), status 3 is Dead
        if (settings.disable_in_combat and player_mob.status == 1) or
           (settings.disable_if_dead and player_mob.status == 3) then
            reset_activity()
        end
    end
end

-- Idle monitoring loop (checks dynamically based on screensaver state)
local function idle_loop()
    while true do
        coroutine_sleep(INACTIVE_SLEEP)
        if not overlay_visible then
            check_game_state()

            -- Check if we should activate the screensaver
            if settings.auto_enabled and (os_clock() - last_activity_time >= settings.idle_timeout) then
                show_overlay()
            end
        end
    end
end

-- Register Event Listeners for direct user activity
windower.register_event('keyboard', function(dik, pressed, flags, blocked)
    if pressed then
        reset_activity()
    end
end)

windower.register_event('mouse', function(type, x, y, delta, blocked)
    -- Any mouse interaction (type 0: movement/drag, 1: left click, etc.)
    reset_activity()
end)

windower.register_event('gain focus', function()
    reset_activity()
end)

windower.register_event('prerender', function()
    if overlay_visible then
        check_game_state()
    end
end)

windower.register_event('load', function()
    create_overlay()
    update_player_id()
    coroutine_schedule(idle_loop, INACTIVE_SLEEP)
end)

windower.register_event('login', function()
    create_overlay()
    update_player_id()
end)

windower.register_event('logout', function()
    player_id = nil
    last_x, last_y, last_z, last_facing = nil, nil, nil, nil
    hide_overlay(false)
end)

windower.register_event('unload', function()
    hide_overlay(false)
    if overlay then
        overlay:destroy()
        overlay = nil
    end
end)

local function print_help()
    windower_add_to_chat(207, '[Blackout] Command Help:')
    windower_add_to_chat(207, '  //blackout - Toggles the screensaver overlay manually.')
    windower_add_to_chat(207, '  //blackout on - Manually activate the screensaver overlay.')
    windower_add_to_chat(207, '  //blackout off - Manually deactivate the screensaver overlay.')
    windower_add_to_chat(207, '  //blackout auto [on|off] - Enable/disable the automatic idle screensaver.')
    windower_add_to_chat(207, '  //blackout timeout [seconds] - Set/view the idle timeout (default 300).')
    windower_add_to_chat(207, '  //blackout minimize [on|off] - Enable/disable automatic client minimization.')
    windower_add_to_chat(207, '  //blackout minimizetimeout [seconds] - Set/view the minimize timeout (default 600).')
    windower_add_to_chat(207, '  //blackout alpha [0-255] - Set screensaver background opacity (default 255).')
    windower_add_to_chat(207, '  //blackout combat [on|off] - Enable/disable screensaver in combat.')
    windower_add_to_chat(207, '  //blackout dead [on|off] - Enable/disable screensaver when dead.')
    windower_add_to_chat(207, '  //blackout fps [on|off] - Enable/disable FPS display toggle on screen save.')
    windower_add_to_chat(207, '  //blackout status - Show current settings and status.')
    windower_add_to_chat(207, '  //blackout help - Display this help menu.')
end

local function toggle_setting(key, cmd, value, name)
    local sub = value and value:lower() or ''
    if sub == 'on' then
        settings[key] = true
        config.save(settings)
        windower_add_to_chat(207, '[Blackout] ' .. name .. ' is now ENABLED.')
    elseif sub == 'off' then
        settings[key] = false
        config.save(settings)
        windower_add_to_chat(207, '[Blackout] ' .. name .. ' is now DISABLED.')
    else
        windower_add_to_chat(207, '[Blackout] ' .. name .. ' is currently ' .. (settings[key] and 'ENABLED' or 'DISABLED') .. '. Use "//blackout ' .. cmd .. ' on" or "//blackout ' .. cmd .. ' off" to change.')
    end
end

local function set_numeric_setting(key, value, name)
    local num = tonumber(value)
    if num and num > 0 then
        settings[key] = num
        config.save(settings)
        windower_add_to_chat(207, '[Blackout] ' .. name .. ' set to ' .. num .. ' seconds.')
    else
        windower_add_to_chat(207, '[Blackout] Current ' .. name .. ' is ' .. settings[key] .. ' seconds.')
    end
end

windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower() or ''
    local args = {...}

    if cmd == 'on' then
        show_overlay()
    elseif cmd == 'off' then
        hide_overlay(true)
    elseif cmd == 'auto' then
        toggle_setting('auto_enabled', 'auto', args[1], 'Auto screensaver')
    elseif cmd == 'timeout' then
        set_numeric_setting('idle_timeout', args[1], 'idle timeout')
    elseif cmd == 'minimize' then
        toggle_setting('minimize_enabled', 'minimize', args[1], 'Idle minimization')
    elseif cmd == 'minimizetimeout' or cmd == 'minimize_timeout' then
        set_numeric_setting('minimize_timeout', args[1], 'minimize timeout')
    elseif cmd == 'combat' then
        toggle_setting('disable_in_combat', 'combat', args[1], 'Disable in combat')
    elseif cmd == 'dead' then
        toggle_setting('disable_if_dead', 'dead', args[1], 'Disable if dead')
    elseif cmd == 'alpha' or cmd == 'bg_alpha' then
        local new_alpha = tonumber(args[1])
        if new_alpha and new_alpha >= 0 and new_alpha <= 255 then
            settings.bg_alpha = math.floor(new_alpha)
            config.save(settings)
            if overlay then
                overlay:bg_alpha(settings.bg_alpha)
            end
            windower_add_to_chat(207, '[Blackout] Background alpha set to ' .. settings.bg_alpha .. '.')
        else
            windower_add_to_chat(207, '[Blackout] Current background alpha is ' .. settings.bg_alpha .. ' (0-255).')
        end
    elseif cmd == 'fps' then
        toggle_setting('show_fps_on_off', 'fps', args[1], 'FPS toggle')
    elseif cmd == 'status' then
        windower_add_to_chat(207, '[Blackout] Status - Auto: ' .. (settings.auto_enabled and 'ON' or 'OFF') .. ', Timeout: ' .. settings.idle_timeout .. 's, Minimize: ' .. (settings.minimize_enabled and 'ON' or 'OFF') .. ', Minimize Timeout: ' .. settings.minimize_timeout .. 's, Alpha: ' .. settings.bg_alpha .. ', Disable in Combat: ' .. tostring(settings.disable_in_combat) .. ', Disable if Dead: ' .. tostring(settings.disable_if_dead) .. ', FPS Toggle: ' .. tostring(settings.show_fps_on_off))
    elseif cmd == 'help' or cmd == 'h' or cmd == '?' then
        print_help()
    elseif cmd == '' or cmd == 'toggle' then
        if overlay and overlay_visible then
            hide_overlay(true)
        else
            show_overlay()
        end
    else
        windower_add_to_chat(207, '[Blackout] Unknown command: "' .. cmd .. '"')
        print_help()
    end
end)
