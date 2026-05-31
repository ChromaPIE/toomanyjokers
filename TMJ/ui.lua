---@diagnostic disable: unbalanced-assignments
function TMJ.FUNCS.ui_box()
    local def = TMJ.FUNCS.inner_nodes()
    return UIBox {
        definition = { n = G.UIT.ROOT, config = { align = 'cm', r = 0.01 }, nodes = {
            UIBox_dyn_container(def) } },
        config = { align = 'cli', offset = { x = -1, y = G.ROOM.T.h - 2.333 }, instance_type = "POPUP", major = G.ROOM_ATTACH, bond = 'Weak' }
    }
end

G.ENTERED_FILTER = ""
TMJ.thegreatfilter = ""

local TMJ_BACKSPACE_REPEAT_DELAY = 0.3
local TMJ_BACKSPACE_REPEAT_INTERVAL = 0.05

local function tmj_search_display_text(input)
    local chars = tmj_utf8_chars(input.text or "")
    local cursor = math.clamp(input.cursor or #chars, 0, #chars)
    local max_visible = 28
    local start = math.max(1, cursor - max_visible + 2)
    if #chars - start + 1 < max_visible then
        start = math.max(1, #chars - max_visible + 1)
    end
    local finish = math.min(#chars, start + max_visible - 1)
    local out = {}
    if start > 1 then out[#out + 1] = "..." end
    for i = start, finish do
        if input.active and cursor == i - 1 then out[#out + 1] = "|" end
        out[#out + 1] = chars[i]
    end
    if input.active and cursor >= finish then out[#out + 1] = "|" end
    if finish < #chars then out[#out + 1] = "..." end
    if input.active and input.composition and input.composition ~= "" then
        out[#out + 1] = "[" .. input.composition .. "]"
    end
    local text = table.concat(out)
    if text == "" and input.active then text = "|" end
    return text
end

function TMJ.FUNCS.ensure_search_input()
    TMJ.search_input = TMJ.search_input or tmj_create_unicode_input(G.ENTERED_FILTER or "", 100)
    TMJ.search_input.max_length = 100
    TMJ.FUNCS.refresh_search_input_display()
    return TMJ.search_input
end

function TMJ.FUNCS.refresh_search_input_display(recalculate)
    if not TMJ.search_input then return end
    TMJ.search_input.display_text = tmj_search_display_text(TMJ.search_input)
    G.ENTERED_FILTER = TMJ.search_input.text or ""
    if recalculate and G.TMJUI then
        G.TMJUI:recalculate(true)
    end
end

function TMJ.FUNCS.start_search_text_input()
    if love and love.keyboard and love.keyboard.setTextInput then
        if not TMJ.search_text_input_started then
            TMJ.prev_love_text_input = love.keyboard.hasTextInput and love.keyboard.hasTextInput() or false
        end
        local native_ime_enabled = tmj_enable_native_ime_ui()
        if native_ime_enabled and not TMJ.native_ime_ui_text_input_restarted and love.keyboard.hasTextInput and love.keyboard.hasTextInput() then
            love.keyboard.setTextInput(false)
            TMJ.native_ime_ui_text_input_restarted = true
        end
        local node = G.TMJUI and G.TMJUI.get_UIE_by_ID and G.TMJUI:get_UIE_by_ID("TMJTEXTINP")
        local x, y, w, h = tmj_text_input_rect_from_node(node, G.ROOM, G.TILESIZE, G.TILESCALE)
        local window_w, window_h
        if love.graphics and love.graphics.getDimensions then
            window_w, window_h = love.graphics.getDimensions()
        elseif love.graphics and love.graphics.getWidth and love.graphics.getHeight then
            window_w, window_h = love.graphics.getWidth(), love.graphics.getHeight()
        end
        x, y, w, h = tmj_clamp_text_input_rect(x, y, w or 360, h or 40, window_w, window_h)
        love.keyboard.setTextInput(true, x, y, w, h)
        TMJ.search_text_input_started = true
        tmj_set_native_ime_rect(x, y, w, h)
    end
end

function TMJ.FUNCS.stop_search_text_input()
    if TMJ.FUNCS.stop_search_backspace_repeat then
        TMJ.FUNCS.stop_search_backspace_repeat()
    end
    if love and love.keyboard and love.keyboard.setTextInput and TMJ.search_text_input_started then
        love.keyboard.setTextInput(TMJ.prev_love_text_input or false)
    end
    TMJ.prev_love_text_input = nil
    TMJ.search_text_input_started = false
    if TMJ.search_input then
        TMJ.search_input.active = false
        TMJ.search_input.composition = ""
        TMJ.FUNCS.refresh_search_input_display()
    end
end

function TMJ.FUNCS.focus_search_input()
    local input = TMJ.FUNCS.ensure_search_input()
    input.active = true
    input.composition = ""
    TMJ.FUNCS.refresh_search_input_display(true)
    TMJ.FUNCS.start_search_text_input()
end

function TMJ.FUNCS.blur_search_input()
    if not TMJ.search_input then return end
    TMJ.FUNCS.stop_search_text_input()
    TMJ.FUNCS.refresh_search_input_display(true)
end

function TMJ.FUNCS.is_search_input_active()
    return G.TMJUI and TMJ.search_input and TMJ.search_input.active
end

function TMJ.FUNCS.clear_search_input(recalculate)
    local input = TMJ.FUNCS.ensure_search_input()
    tmj_unicode_input_set(input, "")
    input.cursor = 0
    input.composition = ""
    TMJ.FUNCS.refresh_search_input_display(recalculate)
end

function TMJ.FUNCS.update_live_search(force_reload)
    local input = TMJ.FUNCS.ensure_search_input()
    local changed = tmj_set_live_search_filter(TMJ, input.text or "")
    if G.TMJUI and (changed or force_reload) then
        TMJ.FUNCS.reload()
    end
    return changed
end

function TMJ.FUNCS.apply_search_input()
    local input = TMJ.FUNCS.ensure_search_input()
    tmj_set_live_search_filter(TMJ, input.text or "")
    TMJ.FUNCS.stop_search_text_input()
    TMJ.FUNCS.refresh_search_input_display(false)
    TMJ.FUNCS.reload()
end

local function tmj_normalize_input_text(text)
    return (text or ""):gsub("\r", " "):gsub("\n", " ")
end

function TMJ.FUNCS.insert_search_text(text)
    local input = TMJ.FUNCS.ensure_search_input()
    tmj_unicode_input_insert(input, tmj_normalize_input_text(text))
    input.composition = ""
    TMJ.FUNCS.refresh_search_input_display(false)
    TMJ.FUNCS.update_live_search()
end

function TMJ.FUNCS.backspace_search_input(count)
    local input = TMJ.FUNCS.ensure_search_input()
    for _ = 1, count or 1 do
        tmj_unicode_input_backspace(input)
    end
    input.composition = ""
    TMJ.FUNCS.refresh_search_input_display(false)
    TMJ.FUNCS.update_live_search()
end

local function tmj_now()
    return love and love.timer and love.timer.getTime and love.timer.getTime() or 0
end

function TMJ.FUNCS.start_search_backspace_repeat()
    TMJ.search_backspace_repeat = TMJ.search_backspace_repeat or {}
    tmj_held_key_repeat_count(
        TMJ.search_backspace_repeat,
        true,
        tmj_now(),
        TMJ_BACKSPACE_REPEAT_DELAY,
        TMJ_BACKSPACE_REPEAT_INTERVAL
    )
end

function TMJ.FUNCS.stop_search_backspace_repeat()
    if not TMJ.search_backspace_repeat then return end
    tmj_held_key_repeat_count(
        TMJ.search_backspace_repeat,
        false,
        tmj_now(),
        TMJ_BACKSPACE_REPEAT_DELAY,
        TMJ_BACKSPACE_REPEAT_INTERVAL
    )
end

function TMJ.FUNCS.update_search_backspace_repeat()
    if not TMJ.FUNCS.is_search_input_active() or not TMJ.search_backspace_repeat or not TMJ.search_backspace_repeat.active then
        return
    end
    local held = love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("backspace")
    local count = tmj_held_key_repeat_count(
        TMJ.search_backspace_repeat,
        held,
        tmj_now(),
        TMJ_BACKSPACE_REPEAT_DELAY,
        TMJ_BACKSPACE_REPEAT_INTERVAL
    )
    if count > 0 then
        TMJ.FUNCS.backspace_search_input(count)
    end
end

local function tmj_ctrl_down()
    return (G.CONTROLLER and G.CONTROLLER.held_keys and (G.CONTROLLER.held_keys.lctrl or G.CONTROLLER.held_keys.rctrl))
        or (love and love.keyboard and love.keyboard.isDown and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")))
end

function TMJ.FUNCS.handle_search_textinput(text)
    if not G.TMJUI or is_debugplus_console_open() then return false end
    if not TMJ.FUNCS.is_search_input_active() then
        if not TMJ.config.autofocus then return false end
        TMJ.FUNCS.focus_search_input()
    end
    TMJ.FUNCS.insert_search_text(text)
    return true
end

function TMJ.FUNCS.handle_search_textedited(text)
    if not G.TMJUI or is_debugplus_console_open() then return false end
    if not TMJ.FUNCS.is_search_input_active() then
        if not TMJ.config.autofocus then return false end
        TMJ.FUNCS.focus_search_input()
    end
    TMJ.search_input.composition = tmj_normalize_input_text(text)
    TMJ.FUNCS.refresh_search_input_display(true)
    TMJ.FUNCS.start_search_text_input()
    return true
end

function TMJ.FUNCS.handle_search_keypressed(key, isrepeat)
    if not G.TMJUI or is_debugplus_console_open() then return false end
    local active = TMJ.FUNCS.is_search_input_active()
    local action = tmj_search_key_action(key, tmj_ctrl_down())
    if action == "paste" and (active or TMJ.config.autofocus) then
        TMJ.FUNCS.focus_search_input()
        local clipboard = (G.F_LOCAL_CLIPBOARD and G.CLIPBOARD or (love.system and love.system.getClipboardText and love.system.getClipboardText())) or ""
        TMJ.FUNCS.insert_search_text(clipboard)
        return true
    end
    if not active then return false end
    if not action then return false end

    if action == "backspace" then
        if not isrepeat then
            TMJ.FUNCS.backspace_search_input(1)
            TMJ.FUNCS.start_search_backspace_repeat()
        end
    elseif action == "delete" then
        tmj_unicode_input_delete(TMJ.search_input)
        TMJ.FUNCS.refresh_search_input_display(false)
        TMJ.FUNCS.update_live_search()
    elseif action == "left" then
        tmj_unicode_input_move(TMJ.search_input, -1)
        TMJ.FUNCS.refresh_search_input_display(true)
    elseif action == "right" then
        tmj_unicode_input_move(TMJ.search_input, 1)
        TMJ.FUNCS.refresh_search_input_display(true)
    elseif action == "submit" then
        TMJ.FUNCS.apply_search_input()
    elseif action == "blur" then
        TMJ.FUNCS.blur_search_input()
    end

    return true
end

function TMJ.FUNCS.search_input_contains_point(x, y)
    local node = G.TMJUI and G.TMJUI.get_UIE_by_ID and G.TMJUI:get_UIE_by_ID("TMJTEXTINP")
    local rx, ry, rw, rh = tmj_text_input_rect_from_node(node, G.ROOM, G.TILESIZE, G.TILESCALE)
    return tmj_point_in_rect(x, y, rx, ry, rw, rh)
end

function TMJ.FUNCS.handle_search_mousepressed(x, y, button)
    if not G.TMJUI or is_debugplus_console_open() or button ~= 2 then return false end
    if not TMJ.FUNCS.search_input_contains_point(x, y) then return false end
    TMJ.FUNCS.focus_search_input()
    TMJ.FUNCS.clear_search_input(true)
    TMJ.FUNCS.update_live_search()
    return true
end

function TMJ.FUNCS.search_input_node()
    local input = TMJ.FUNCS.ensure_search_input()
    return {
        n = G.UIT.C,
        config = {
            id = "TMJTEXTINP",
            align = "cm",
            padding = 0.05,
            r = 0.1,
            hover = true,
            colour = input.active and darken(copy_table(G.C.RED), 0.3) or G.C.RED,
            minw = 3,
            minh = 1,
            button = "SelectTMJSearchInput",
            shadow = true
        },
        nodes = {
            {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.05, r = 0.1, colour = G.C.CLEAR },
                nodes = {
                    { n = G.UIT.T, config = { ref_table = input, ref_value = "display_text", scale = 0.4, colour = G.C.UI.TEXT_LIGHT, id = "TMJTEXTINP_TEXT" } }
                }
            }
        }
    }
end

G.FUNCS.SelectTMJSearchInput = function()
    TMJ.FUNCS.focus_search_input()
end

function TMJ.FUNCS.inner_nodes()
    local text = TMJ.FUNCS.search_input_node()
    return {
        {
            n = G.UIT.R,
            config = { minw = G.ROOM.T.w * 0.25, padding = 0.05, align = "cm" },
            nodes = {
                { n = G.UIT.T, config = { text = localize("tmj_focus_searchbar"), colour = G.C.WHITE, scale = 0.35 } },
            }
        },
        { n = G.UIT.R, config = { align = "cm", r = 0.01, colour = G.C.BLACK, emboss = 0.05 }, nodes = { { n = G.UIT.C, nodes = TMJ.FUNCS.make_card_areas() } } }, --cardareas
        {
            n = G.UIT.R,
            config = { align = "cm" },
            nodes = {
                text
            },
        }, --textbox
        {
            n = G.UIT.R,
            config = { align = "cm", maxh = 1 },
            nodes = {
                UIBox_button({
                    colour = G.C.RED,
                    button = "CloseTMJ",
                    label = { localize("tmj_close") },
                    minw = 3,
                    focus_args = { snap_to = true },
                }),
            }
        },
        {
            n = G.UIT.R,
            config = { minw = G.ROOM.T.w * 0.25, padding = 0.05, align = "cm" },
            nodes = {
                { n = G.UIT.T, config = { text = localize("tmj_search_hint"), colour = G.C.WHITE, scale = 0.35 } },
            }
        },
        {
            n = G.UIT.R,
            config = { minw = G.ROOM.T.w * 0.25, padding = 0.05, align = "cm" },
            nodes = {
                { n = G.UIT.T, config = { text = localize("tmj_pin_hint"), colour = G.C.WHITE, scale = 0.35 } },
            }
        },
    }
end

function TMJ.FUNCS.make_card_areas()
    G.TMJCOLLECTION = {}
    local card_limit = TMJ.config.columns
    local num_areas = TMJ.config.rows
    local card_scale = 1 / TMJ.config.size
    local areas = {}
    for i = 1, num_areas do
        local area = CardArea(                                                                   --insert this cardarea into the table we feed to our ui
            0, 0,                                                                                --position
            card_limit * G.CARD_W / card_scale,                                                  --width of cardarea
            0.95 * G.CARD_H / card_scale,                                                        --height of cardarea
            { card_limit = card_limit, type = 'title_2', highlight_limit = 0, collection = true }) --basic config for a cardarea
        area.config.tmj = true
        G.TMJCOLLECTION[i] = area
        table.insert(areas, {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.07 / card_scale, no_fill = true, scale = 1 / card_scale },
            nodes = { { n = G.UIT.O, config = { object = area } } }
        })
    end
    return areas
end

TMJ.scrolled_amount = 0
function TMJ.FUNCS.make_cards()
    local size_div = 1 / TMJ.config.size
    local initial_offset = TMJ.config.columns * TMJ.scrolled_amount
    local centers = TMJ.FUNCS.get_centers(TMJ.thegreatfilter, initial_offset, TMJ.config.columns * TMJ.config.rows)


    local edition
    local edition_match = string.match(TMJ.thegreatfilter, "{edition:.+}")
    if edition_match then
        local subbed = edition_match:gsub("{edition:", "")
        subbed = string.sub(subbed, 1, #subbed-1)
        edition = subbed
    end
    for row = 1, TMJ.config.rows do
        for col = 1, TMJ.config.columns do
            local indice = (row - 1) * TMJ.config.columns + col
            local key = centers[indice]
            local center = G.P_CENTERS[key]
            if center and center.key then
                local old = copy_table(G.GAME.used_jokers)
                local card = Card(G.TMJCOLLECTION[row].T.x + G.TMJCOLLECTION[row].T.w / 2, G.TMJCOLLECTION[row].T.y,
                    G.CARD_W / (size_div or 1),
                    G.CARD_H / (size_div or 1), nil, key)
                if edition then
                    card.edition = card.edition or {}
                    card.edition[edition] = true
                    card.edition.key = "e_"..edition
                end
                if TMJ.config.pinned_keys[key] then
                    SMODS.Stickers.tmj_pinned:apply(card, true)
                end
                if BANNERMOD and BANNERMOD.is_disabled(key) then
                    card.debuff = true
                end
                card.sticker = get_joker_win_sticker(key)
                G.TMJCOLLECTION[row]:emplace(card)
                if string.sub(key, 1, 1) == "e" and not edition then
                    if not card.edition then card.edition = {} end
                    card.edition[string.sub(key, 3)] = true
                end
                G.GAME.used_jokers = old
            end
        end
    end
end

function TMJ.FUNCS.scroll(y)
    local prev_amt = TMJ.scrolled_amount
    TMJ.scrolled_amount = TMJ.scrolled_amount + y
    if math.floor(TMJ.scrolled_amount) == math.floor(prev_amt) then
        return
    end

    if TMJ.scrolled_amount >= 0 then
        TMJ.FUNCS.reload()
    else
        TMJ.scrolled_amount = 0
        if prev_amt > 0 then
            TMJ.FUNCS.reload()
        end
    end
end

function TMJ.FUNCS.reload()
    if G.TMJUI then
        G.TMJUI:remove()
        G.TMJTAGS:remove()
    end
    local input = TMJ.FUNCS.ensure_search_input()
    G.TMJUI = TMJ.FUNCS.ui_box()
    TMJ.FUNCS.make_cards()
    G.TMJUI:recalculate()
    if input.active then
        TMJ.FUNCS.start_search_text_input()
    end
    TMJ.FUNCS.make_tag_stuff()
end


function TMJ.FUNCS.make_tag_stuff()
    local major = assert(G.TMJUI)
    local uib = UIBox {
        definition = { n = G.UIT.ROOT, config = { align = 'cm', r = 0.01 }, nodes = {
            UIBox_dyn_container(TMJ.FUNCS.inner_tags()) } },
        config = { align = 'cr', offset = { x = 0, y = 0 }, instance_type = "POPUP", major = major, bond = 'Weak' }
    }
    G.TMJTAGS = uib

    TMJ.FUNCS.place_tags_before_tmjui()
end

function TMJ.FUNCS.place_tags_before_tmjui()
    local tmjui, uiindex = G.TMJUI
    local tmjtags, tagsindex = G.TMJTAGS
    for i, v in ipairs(G.I.POPUP) do
        if v == tmjtags then
            tagsindex = i
        elseif v == tmjui then
            uiindex = i
        end
        if uiindex and tagsindex then
            local put_tags = math.min(uiindex, tagsindex)
            local put_ui = put_tags == uiindex and tagsindex or uiindex
            G.I.POPUP[put_tags], G.I.POPUP[put_ui] = tmjtags, tmjui
            break
        end
    end
end

function TMJ.FUNCS.inner_tags()
    local tags = {}
    local mods = TMJ.FUNCS.get_valid_mods()
    local max_rows = 12
    local num_cols = math.ceil(#mods/max_rows)
    for i = 0, math.ceil(#mods/num_cols) do
        local cur_mods = {}
        for j = 1, num_cols do
            cur_mods[#cur_mods+1] = mods[i*num_cols+j] --lea ?!?!??!
        end
        local tags_nodes = {}
        for _, v in ipairs(cur_mods) do
            tags_nodes[#tags_nodes+1] = TMJ.FUNCS.buildModtag(v)
        end
        tags[#tags+1] = {n = G.UIT.R, nodes = tags_nodes}
    end


    return {{
        n = G.UIT.C,
        nodes = tags
    }}
end

function TMJ.FUNCS.get_valid_mods()
    if TMJ.MODCACHE then return TMJ.MODCACHE end
    local ret = {}
    local has_centers = {}
    for _, v in pairs(G.P_CENTERS) do
        if v.original_mod and v.original_mod.id then
            has_centers[v.original_mod.id] = true
        end
    end
    for i, v in pairs(SMODS.Mods) do
        if v.can_load and v.name and (has_centers[v.id] or TMJ.config.show_all_tags) then
            table.insert(ret, v)
        end
    end


    TMJ.MODCACHE = ret
    return ret
end



function TMJ.FUNCS.getModtagInfo(mod)
    local tag_pos, tag_message, tag_atlas = { x = 0, y = 0 }, "tmj_this_mods_cards", mod.prefix and mod.prefix .. '_modicon' or 'modicon'
    local specific_vars = {mod.display_name}

    return tag_atlas, tag_pos, tag_message, specific_vars
end

function TMJ.FUNCS.buildModtag(mod)
    local tag_atlas, tag_pos, tag_message, specific_vars = TMJ.FUNCS.getModtagInfo(mod)

    local tag_sprite_tab = nil
    local units = SMODS.pixels_to_unit(34) * 2
    local animated = G.ANIMATION_ATLAS[tag_atlas] or nil
    local tag_sprite
    if animated then
      tag_sprite = AnimatedSprite(0, 0, 0.8*1, 0.8*1, animated or G.ASSET_ATLAS[tag_atlas] or G.ASSET_ATLAS['tags'], tag_pos)
    else
      tag_sprite = Sprite(0, 0, 0.8*1, 0.8*1, G.ASSET_ATLAS[tag_atlas] or G.ASSET_ATLAS['tags'], tag_pos)
    end
    tag_sprite.T.scale = 1
    tag_sprite_tab = {n= G.UIT.C, config={align = "cm", padding = 0}, nodes={
        {n=G.UIT.O, config={w=units, h=units, colour = G.C.BLUE, object = tag_sprite, focus_with_object = true}},
    }}
    tag_sprite:define_draw_steps({
        {shader = 'dissolve', shadow_height = 0.05},
        {shader = 'dissolve'},
    })
    tag_sprite.float = true
    tag_sprite.states.hover.can = true
    tag_sprite.states.click.can = true
    tag_sprite.states.drag.can = false
    tag_sprite.states.collide.can = true

    tag_sprite.hover = function(_self)
        if not G.CONTROLLER.dragging.target or G.CONTROLLER.using_touch then 
            if not _self.hovering and _self.states.visible then
                _self.hovering = true
                if _self == tag_sprite then
                    _self.hover_tilt = 3
                    _self:juice_up(0.05, 0.02)
                    play_sound('paper1', math.random()*0.1 + 0.55, 0.42)
                    play_sound('tarot2', math.random()*0.1 + 0.55, 0.09)
                end
                tag_sprite.ability_UIBox_table = generate_card_ui({set = "Other", discovered = false, key = tag_message}, nil, specific_vars, 'Other', nil, false)
                _self.config.h_popup =  G.UIDEF.card_h_popup(_self)
                _self.config.h_popup_config ={align = 'bm', offset = {x= 0,y=0.3},parent = _self}
                Node.hover(_self)
                if _self.children.alert then 
                    _self.children.alert:remove()
                    _self.children.alert = nil
                    G:save_progress()
                end
            end
        end
    end
    tag_sprite.click = function(self)
        play_sound('button', 1, 0.3)
        G.ROOM.jiggle = G.ROOM.jiggle + 0.5
        if G.CONTROLLER.held_keys.lshift then
            G.FUNCS.CloseTMJ()
            G.FUNCS["openModUI_" .. mod.id](self)
        else
            TMJ.thegreatfilter = "%%%%"..mod.name
            TMJ.FUNCS.clear_search_input(false)
            TMJ.scrolled_amount = 0
            TMJ.FUNCS.reload()
        end
    end
    tag_sprite.stop_hover = function(_self) _self.hovering = false; Node.stop_hover(_self); _self.hover_tilt = 0 end


    return tag_sprite_tab
end
