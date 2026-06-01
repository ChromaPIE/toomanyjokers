local NFS = SMODS.NFS or NFS
TMJ = assert(SMODS.current_mod)
TMJ.FUNCS = {}
TMJ.CACHES = {
    match_strings = {},
    serach_results = {},
    sorted_pools = {},
}
SMODS.load_mod_config(TMJ)
TMJ.config = TMJ.config or {}
TMJ.default_config = {
    rows = 4,
    columns = 4,
    size = 0.7,
    sensitivity = 1,
    pinned_keys = {},
    hide_undiscovered = false,
    close_on_esc = false,
    scroll_full_page = false,
    disable_cheats = false,
    arrow_key_scroll = false,
    show_all_tags = false,
    autofocus = true,
    hide_no_collection = true,
}

for i, v in pairs(TMJ.default_config) do
    if TMJ.config[i] == nil then
        TMJ.config[i] = v
    end
end

SMODS.save_mod_config(TMJ)
if _RELEASE_MODE then TMJ.config.disable_cheats = true end
local old = SMODS.save_mod_config
function SMODS.save_mod_config(mod)
    if mod == TMJ then
        for i, v in pairs(TMJ.fake_config) do
            TMJ.config[i] = tonumber(v or TMJ.config[i]) or TMJ.config[i]
        end
        TMJ.get_centers_caches.centers_that_match = {}
    end
    old(mod)
end

TMJ.DEBUG = true


local scripts = { "utils", "config", "searcher", "ui", "banner", "compat" }
local tests = {}
for i, v in ipairs(scripts) do
    assert(SMODS.load_file("TMJ/" .. v .. ".lua"))()

    if TMJ.DEBUG and _G[v.."_unit_tests"] then
        table.insert(tests, _G[v .. "_unit_tests"])
    end
end

function _G.tmj_cleanup_restart_text_input()
    if love and love.keyboard and love.keyboard.setTextInput then pcall(love.keyboard.setTextInput, false) end
    if tmj_stop_sdl_text_input then pcall(tmj_stop_sdl_text_input) end
end
TMJ.cleanup_restart_text_input = _G.tmj_cleanup_restart_text_input

if love and love.event and love.event.quit and love.event.quit ~= _G.tmj_love_event_quit_wrapper then
    local quit_ref = love.event.quit
    _G.tmj_love_event_quit_wrapper = function(code, ...)
        if code == "restart" then
            _G.tmj_cleanup_restart_text_input()
        end
        return quit_ref(code, ...)
    end
    TMJ.love_event_quit_wrapper = _G.tmj_love_event_quit_wrapper
    love.event.quit = _G.tmj_love_event_quit_wrapper
end

if SMODS and SMODS.restart_game and SMODS.restart_game ~= _G.tmj_smods_restart_game_wrapper then
    local restart_ref = SMODS.restart_game
    _G.tmj_smods_restart_game_wrapper = function(...)
        _G.tmj_cleanup_restart_text_input()
        return restart_ref(...)
    end
    TMJ.smods_restart_game_wrapper = _G.tmj_smods_restart_game_wrapper
    SMODS.restart_game = _G.tmj_smods_restart_game_wrapper
end



G.FUNCS.CloseTMJ = function()
    if TMJ.FUNCS.clear_search_input then TMJ.FUNCS.clear_search_input(false) end
    if TMJ.FUNCS.stop_search_text_input then TMJ.FUNCS.stop_search_text_input() end
    G.TMJUI:remove()
    G.TMJTAGS:remove()
    G.TMJUI = nil
    G.TMJTAGS = nil
    TMJ.thegreatfilter = ""
    G.ENTERED_FILTER = ""
    for i, v in pairs(G.TMJCOLLECTION) do
        v:remove()
    end
    TMJ.scrolled_amount = 0
end
local ourref = love.wheelmoved or function() end
function love.wheelmoved(x, y)
    ourref(x, y)
    if y and G.TMJUI then
        if TMJ.config.scroll_full_page then
            TMJ.FUNCS.scroll(-(y * TMJ.config.rows))
        else
            TMJ.FUNCS.scroll(-y * TMJ.config.sensitivity)
        end
    end
end

local toggle_ref = G.FUNCS.toggle
function G.FUNCS.toggle(e, ...)
    if e.children and e.children[1] then
        return toggle_ref(e, ...)
    end
end

local upd_ref = love.update
function love.update(dt)
    upd_ref(dt)
    if TMJ.config.disable_ctrl_enter then
        TMJ.config.disable_cheats = true
    end
    
    if G.TMJUI and TMJ.held_arrow and TMJ.held_arrow_time and not TMJ.config.scroll_full_page then
        if love.timer.getTime() - 0.35 > TMJ.held_arrow_time then
            if love.timer.getTime() - 0.15 > TMJ.last_arrow_time then
                TMJ.last_arrow_time = love.timer.getTime()
                TMJ.FUNCS.scroll(TMJ.held_arrow == "up" and -1 or 1)
            end
        end
    end
    if TMJ.FUNCS.update_search_backspace_repeat then
        TMJ.FUNCS.update_search_backspace_repeat()
    end
end

local old = love.keypressed
local wanted_chars = table_into_hashset(collect(string.gmatch("abcdefghijklmnopqrstuvwxyz[]!", ".")))
wanted_chars["return"] = true
local unwanted_chars = collect(string.gmatch("lctrl rctrl lalt ralt", "(.-) "))
local function tmj_ctrl_down()
    return (G.CONTROLLER and G.CONTROLLER.held_keys and (G.CONTROLLER.held_keys.lctrl or G.CONTROLLER.held_keys.rctrl))
        or (love and love.keyboard and love.keyboard.isDown and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")))
end

function love.keypressed(key, scancode, isrepeat, ...)
    if key == "escape" and G.TMJUI and TMJ.config.close_on_esc then
        G.FUNCS.CloseTMJ()
        return
    end
    if key == "t" and not G.CONTROLLER.text_input_hook and not (TMJ.FUNCS.is_search_input_active and TMJ.FUNCS.is_search_input_active()) and not is_debugplus_console_open() then
        if G.TMJUI then
            if not TMJ.config.close_on_esc then
                G.FUNCS.CloseTMJ()
                return
            end
        else
            TMJ.FUNCS.reload()
            if TMJ.config.autofocus and TMJ.FUNCS.focus_search_input then
                TMJ.FUNCS.focus_search_input()
            end
            return
        end
    end
    if TMJ.config.arrow_key_scroll and G.TMJUI and not (TMJ.FUNCS.is_search_input_active and TMJ.FUNCS.is_search_input_active()) then
        local mul = ((G.CONTROLLER.held_keys.lctrl or G.CONTROLLER.held_keys.rctrl or TMJ.config.scroll_full_page) and TMJ.config.rows) or 1
        if key == "up" then
            TMJ.held_arrow = key 
            TMJ.held_arrow_time = love.timer.getTime()
            TMJ.last_arrow_time = love.timer.getTime()
            TMJ.FUNCS.scroll(-1 * mul)
        elseif key == "down" then
            TMJ.held_arrow = key 
            TMJ.held_arrow_time = love.timer.getTime()
            TMJ.last_arrow_time = love.timer.getTime()
            TMJ.FUNCS.scroll(1 * mul)
        end
    end
    if not TMJ.config.disable_cheats and key == "return" and tmj_ctrl_down() and G.TMJUI and TMJ.FUNCS.is_search_input_active and TMJ.FUNCS.is_search_input_active() then
        TMJ.FUNCS.apply_search_input()
        local first_card = G.TMJCOLLECTION[1].cards[1]
        if first_card then
            local _area
            if first_card.ability.set == 'Joker' then
                _area = G.jokers
            elseif first_card.playing_card then
                if G.hand and G.hand.config.card_count ~= 0 then
                    _area = G.hand
                else
                    _area = G.deck
                end
            elseif first_card.ability.consumeable then
                _area = G.consumeables
            end
            if _area then
                local new_card = copy_card(first_card, nil, nil, first_card.playing_card)
                new_card:add_to_deck()
                if first_card.playing_card then
                    table.insert(G.playing_cards, new_card)
                end
                _area:emplace(new_card)
            end
        end
        G.FUNCS.CloseTMJ()
        return
    end
    if TMJ.FUNCS.handle_search_keypressed and TMJ.FUNCS.handle_search_keypressed(key, isrepeat) then
        return
    end
    for _, char in pairs(unwanted_chars) do
        if G.CONTROLLER.held_keys[char] then
            return old(key, scancode, isrepeat, ...)
        end
    end
    if G.TMJUI and wanted_chars[key] and TMJ.config.autofocus and TMJ.FUNCS.focus_search_input then
        TMJ.FUNCS.focus_search_input()
        return
    end
    old(key, scancode, isrepeat, ...)
end

local old_mousepressed = love.mousepressed or function() end
function love.mousepressed(x, y, button, ...)
    if TMJ.FUNCS.handle_search_mousepressed and TMJ.FUNCS.handle_search_mousepressed(x, y, button) then
        return
    end
    return old_mousepressed(x, y, button, ...)
end

local old_textinput = love.textinput or function() end
function love.textinput(text)
    if TMJ.FUNCS.handle_search_textinput and TMJ.FUNCS.handle_search_textinput(text) then
        return
    end
    return old_textinput(text)
end

local old_textedited = love.textedited or function() end
function love.textedited(text, start, length)
    if TMJ.FUNCS.handle_search_textedited and TMJ.FUNCS.handle_search_textedited(text, start, length) then
        return
    end
    return old_textedited(text, start, length)
end

local oldrelease = love.keyreleased or function() end
function love.keyreleased(key)
    oldrelease(key)
    if key == "up" or key == "down" then
        TMJ.held_arrow = nil
    end
    if key == "backspace" and TMJ.FUNCS.stop_search_backspace_repeat then
        TMJ.FUNCS.stop_search_backspace_repeat()
    end
end

SMODS.Atlas {
    key = "modicon",
    path = "icon.png",
    px = 34,
    py = 34
}


SMODS.Atlas {
    key = "pinned",
    path = "pinned.png",
    px = 71,
    py = 95,
}

SMODS.Sticker {
    key = "pinned",
    atlas = "pinned",
    default_compat = false,
    badge_colour = HEX 'fda200',
    rate = 0,
    needs_enable_flag = true,
    should_apply = false, --i REALLY dont want this affecting normal gameplay
    no_collection = true,
}

local oldcc = copy_card
function copy_card(card, ...)
    local ret = oldcc(card, ...)
    if card.area and card.area.config.tmj then
        SMODS.Stickers.tmj_pinned:apply(ret, false)
    end
    return ret
end

local oldcuib = create_UIBox_generic_options
create_UIBox_generic_options = function(arg1, ...) --inserts the text into most collection pages without needing to hook each individual function
    if arg1 and arg1.back_func == "your_collection" and arg1.contents and arg1.contents[1] and arg1.contents[1].n == 4 and not (TMJ.config and TMJ.config.hide_collection_text) then
        table.insert(arg1.contents, {
            n = G.UIT.R,
            config = { align = "cm", minh = 0.5 },
            nodes = {
                { n = G.UIT.C, config = { align = "cm", minw = 5 }, nodes = { { n = G.UIT.T, config = { text = localize("tmj_collection_hint"), colour = G.C.WHITE, shadow = true, scale = 0.3 } } } }

            }
        })
    end
    return oldcuib(arg1, ...)
end


local old = Card.click
function Card:click(...)
    if self.area and self.area.config.tmj and G.CONTROLLER.held_keys['lctrl'] then
        TMJ.config.pinned_keys[self.config.center.key] = not TMJ.config.pinned_keys[self.config.center.key]
        TMJ.FUNCS.process_centers()
        TMJ.FUNCS.reload()
        SMODS.save_mod_config(TMJ)
    end
    old(self, ...)
end


for i, v in ipairs(tests) do
    v()
end

