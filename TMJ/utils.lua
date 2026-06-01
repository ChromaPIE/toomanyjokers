---Essentially collects string.gmatch into a table
function string.split(str, split_by)
    str = str .. split_by
    local strs = {}
    for strng in string.gmatch(str, "(.-)" .. split_by) do
        strs[#strs + 1] = strng
    end

    return strs
end

---Takes the values of a table and turns them into keys with value true 
function table_into_hashset(tbl)
    local new = {}
    for i, v in pairs(tbl) do
        new[v] = true
    end
    setmetatable(new, {
        __newindex = function (t, k, v)
            assert(type(v) == "boolean", "misuse of hashset")
            rawset(t, k, v or nil)
        end,
        __index = function (t, k)
            if k == "set" then
                return function(self, key)
                    rawset(self, key, true)
                end
            else
                return rawget(t, k)
            end
        end
    })
    return new
end

function todo(msg, ...)
    msg = msg or ""
    error("Not yet implemented: " .. string.format(msg, ...))
end

local function tmj_utf8_continuation_byte(byte)
    return byte and byte >= 0x80 and byte <= 0xBF
end

local function tmj_utf8_char_size(byte)
    if not byte then return 0 end
    if byte < 0x80 then
        return 1
    elseif byte >= 0xC2 and byte <= 0xDF then
        return 2
    elseif byte >= 0xE0 and byte <= 0xEF then
        return 3
    elseif byte >= 0xF0 and byte <= 0xF4 then
        return 4
    end
    return 1
end

function tmj_utf8_chars(str)
    str = str or ""
    local chars = {}
    local i = 1
    while i <= #str do
        local size = tmj_utf8_char_size(string.byte(str, i))
        local valid = size == 1 or i + size - 1 <= #str
        if valid and size > 1 then
            for j = i + 1, i + size - 1 do
                if not tmj_utf8_continuation_byte(string.byte(str, j)) then
                    valid = false
                    break
                end
            end
        end
        if not valid then size = 1 end
        chars[#chars + 1] = string.sub(str, i, i + size - 1)
        i = i + size
    end
    return chars
end

function tmj_utf8_len(str)
    return #tmj_utf8_chars(str)
end

function tmj_create_unicode_input(text, max_length)
    text = text or ""
    max_length = max_length or math.huge
    local input = {
        text = "",
        max_length = max_length,
    }
    tmj_unicode_input_set(input, text)
    return input
end

function tmj_unicode_input_set(input, text)
    local chars = tmj_utf8_chars(text or "")
    local max_length = input.max_length or math.huge
    while #chars > max_length do
        table.remove(chars)
    end
    input.text = table.concat(chars)
    input.cursor = input.cursor == nil and #chars or math.min(input.cursor, #chars)
end

function tmj_unicode_input_insert(input, text)
    if not text or text == "" then return end
    local chars = tmj_utf8_chars(input.text or "")
    local insert_chars = tmj_utf8_chars(text)
    local max_length = input.max_length or math.huge
    local cursor = math.clamp(input.cursor or #chars, 0, #chars)
    local available = max_length - #chars
    if available <= 0 then
        input.cursor = cursor
        return
    end

    local inserted = 0
    for i = 1, math.min(#insert_chars, available) do
        table.insert(chars, cursor + i, insert_chars[i])
        inserted = inserted + 1
    end
    input.text = table.concat(chars)
    input.cursor = cursor + inserted
end

function tmj_unicode_input_backspace(input)
    local chars = tmj_utf8_chars(input.text or "")
    local cursor = math.clamp(input.cursor or #chars, 0, #chars)
    if cursor > 0 then
        table.remove(chars, cursor)
        cursor = cursor - 1
    end
    input.text = table.concat(chars)
    input.cursor = cursor
end

function tmj_unicode_input_delete(input)
    local chars = tmj_utf8_chars(input.text or "")
    local cursor = math.clamp(input.cursor or #chars, 0, #chars)
    if cursor < #chars then
        table.remove(chars, cursor + 1)
    end
    input.text = table.concat(chars)
    input.cursor = cursor
end

function tmj_unicode_input_move(input, amount)
    local chars = tmj_utf8_chars(input.text or "")
    input.cursor = math.clamp((input.cursor or #chars) + amount, 0, #chars)
end

function tmj_set_live_search_filter(state, text)
    local filter = text or ""
    local changed = state.thegreatfilter ~= filter
    state.thegreatfilter = filter
    state.scrolled_amount = 0
    return changed
end

function tmj_search_key_action(key, ctrl_down)
    if key == "v" and ctrl_down then return "paste" end

    return ({
        backspace = "backspace",
        delete = "delete",
        left = "left",
        right = "right",
        ["return"] = "submit",
        escape = "blur",
    })[key]
end

function tmj_held_key_repeat_count(state, held, now, initial_delay, interval)
    state = state or {}
    now = now or 0
    initial_delay = initial_delay or 0.35
    interval = interval or 0.06

    if not held then
        state.active = false
        state.next_time = nil
        return 0
    end

    if not state.active then
        state.active = true
        state.next_time = now + initial_delay
        return 0
    end

    local count = 0
    while state.next_time and now + 0.000001 >= state.next_time do
        count = count + 1
        state.next_time = state.next_time + interval
        if count >= 20 then
            state.next_time = now + interval
            break
        end
    end
    return count
end

function tmj_point_in_rect(x, y, rx, ry, rw, rh)
    if not (x and y and rx and ry and rw and rh) then return false end
    return x >= rx and y >= ry and x <= rx + rw and y <= ry + rh
end

function tmj_text_input_rect_from_node(node, room, tile_size, tile_scale)
    local t = node and (node.VT or node.T)
    if not t or not tile_size or not tile_scale then return nil end
    local room_t = (node and node.container and node.container.T) or (room and room.T) or {}
    local scale = tile_size * tile_scale
    local w = (t.w or 0) * scale
    local h = (t.h or 0) * scale
    if w <= 0 or h <= 0 then return nil end
    local x = ((t.x or 0) + (room_t.x or 0)) * scale
    local y = ((t.y or 0) + (room_t.y or 0)) * scale
    return math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h))
end

function tmj_clamp_text_input_rect(x, y, w, h, window_w, window_h)
    window_w = window_w or 0
    window_h = window_h or 0
    if window_w <= 0 or window_h <= 0 then return x, y, w, h end

    w = math.max(1, math.min(math.floor(w or 1), window_w))
    h = math.max(1, math.min(math.floor(h or 1), window_h))
    x = math.floor(x or math.floor((window_w - w) / 2))
    y = math.floor(y or math.floor(window_h * 0.75))
    x = math.max(0, math.min(x, window_w - w))
    y = math.max(0, math.min(y, window_h - h))
    return x, y, w, h
end

function tmj_stop_sdl_text_input()
    local ok, ffi = pcall(require, "ffi")
    if not ok or not ffi then return false end

    pcall(function()
        ffi.cdef[[void SDL_StopTextInput(void);]]
    end)

    local function stop(lib)
        local ok_fn, fn = pcall(function() return lib and lib.SDL_StopTextInput end)
        return ok_fn and fn and pcall(fn)
    end

    if stop(ffi.C) then return true end
    for _, lib_name in ipairs({ "SDL2", "SDL2.dll" }) do
        local loaded, lib = pcall(ffi.load, lib_name)
        if loaded and stop(lib) then return true end
    end
    return false
end

function utils_unit_tests()
    local tbl = { "1", 2, "8" }
    local tbl2 = table_into_hashset(tbl)
    tbl2:set("three")
    assert(tbl2["1"] and tbl2[2] and tbl2["8"] and tbl2.three)
    assert(not (tbl2[1] or tbl2["hello"]))
    local str = "Hello, Whats up,,a"
    local split = string.split(str, ",")
    assert(split[1] == "Hello")
    assert(split[2] == " Whats up")
    assert(split[3] == "")
    assert(split[4] == "a")
    assert(split[5] == nil)
    assert(spaceless("your mom  whore") == "yourmomwhore")
    assert(lower_spaceless("YOUR MOM    whore") == "yourmomwhore")
    assert(math.clamp(1, 2, 3) == 2)
    assert(math.clamp(4, 1, 2) == 2)

    local lan = string.char(232, 147, 157)
    local tu = string.char(229, 155, 190)
    local chao = string.char(232, 182, 133)
    local chars = tmj_utf8_chars("a" .. lan .. tu .. "b")
    assert(#chars == 4)
    assert(chars[1] == "a")
    assert(chars[2] == lan)
    assert(chars[3] == tu)
    assert(chars[4] == "b")

    local input = tmj_create_unicode_input("a" .. lan, 10)
    tmj_unicode_input_insert(input, tu .. "b")
    assert(input.text == "a" .. lan .. tu .. "b")
    assert(input.cursor == 4)
    tmj_unicode_input_backspace(input)
    assert(input.text == "a" .. lan .. tu)
    assert(input.cursor == 3)
    tmj_unicode_input_move(input, -2)
    tmj_unicode_input_insert(input, chao)
    assert(input.text == "a" .. chao .. lan .. tu)
    assert(input.cursor == 2)

    local capped = tmj_create_unicode_input("", 3)
    tmj_unicode_input_insert(capped, "ab" .. lan .. tu)
    assert(capped.text == "ab" .. lan)
    assert(capped.cursor == 3)

    local state = { thegreatfilter = "old", scrolled_amount = 7 }
    assert(tmj_set_live_search_filter(state, "new") == true)
    assert(state.thegreatfilter == "new")
    assert(state.scrolled_amount == 0)
    assert(tmj_set_live_search_filter(state, "new") == false)
    assert(state.scrolled_amount == 0)

    assert(tmj_search_key_action("v", true) == "paste")
    assert(tmj_search_key_action("v", false) == nil)
    assert(tmj_search_key_action("backspace", false) == "backspace")
    assert(tmj_search_key_action("delete", false) == "delete")
    assert(tmj_search_key_action("left", false) == "left")
    assert(tmj_search_key_action("right", false) == "right")
    assert(tmj_search_key_action("return", false) == "submit")
    assert(tmj_search_key_action("escape", false) == "blur")
    assert(tmj_search_key_action("tab", false) == nil)
    assert(tmj_search_key_action("lctrl", false) == nil)
    assert(tmj_search_key_action("rctrl", false) == nil)
    assert(tmj_search_key_action("lshift", false) == nil)
    assert(tmj_search_key_action("rshift", false) == nil)
    assert(tmj_search_key_action("lalt", false) == nil)
    assert(tmj_search_key_action("ralt", false) == nil)

    local repeat_state = {}
    assert(tmj_held_key_repeat_count(repeat_state, true, 1, 0.3, 0.05) == 0)
    assert(repeat_state.active == true)
    assert(repeat_state.next_time == 1.3)
    assert(tmj_held_key_repeat_count(repeat_state, true, 1.29, 0.3, 0.05) == 0)
    assert(tmj_held_key_repeat_count(repeat_state, true, 1.3, 0.3, 0.05) == 1)
    assert(repeat_state.next_time == 1.35)
    assert(tmj_held_key_repeat_count(repeat_state, true, 1.45, 0.3, 0.05) == 3)
    assert(tmj_held_key_repeat_count(repeat_state, false, 1.46, 0.3, 0.05) == 0)
    assert(repeat_state.active == false)
    assert(repeat_state.next_time == nil)

    assert(tmj_point_in_rect(10, 10, 10, 10, 20, 20) == true)
    assert(tmj_point_in_rect(30, 30, 10, 10, 20, 20) == true)
    assert(tmj_point_in_rect(9, 10, 10, 10, 20, 20) == false)
    assert(tmj_point_in_rect(10, 31, 10, 10, 20, 20) == false)

    local node = { VT = { x = 2, y = 3, w = 4, h = 1 } }
    local room = { T = { x = 0.5, y = 1 } }
    local x, y, w, h = tmj_text_input_rect_from_node(node, room, 20, 2)
    assert(x == 100)
    assert(y == 160)
    assert(w == 160)
    assert(h == 40)
    assert(tmj_text_input_rect_from_node({ VT = { x = 0, y = 0, w = 0, h = 1 } }, room, 20, 2) == nil)

    local cx, cy, cw, ch = tmj_clamp_text_input_rect(990, 640, 200, 80, 1000, 650)
    assert(cx == 800)
    assert(cy == 570)
    assert(cw == 200)
    assert(ch == 80)

    cx, cy, cw, ch = tmj_clamp_text_input_rect(nil, nil, nil, nil, 1000, 650)
    assert(cx >= 0 and cx < 1000)
    assert(cy >= 0 and cy < 650)
    assert(cw == 1)
    assert(ch == 1)
end

function spaceless(str)
    return string.gsub(str, "%s", "")
end

function lower_spaceless(str)
    return string.lower(spaceless(str))
end

---Calls func with every element of tbl (via pairs). If func returns one value, tbl[i] = ret1. If func returns two values, tbl[ret1] = ret2. If func returns no value, do nothing.
function table.map(tbl, func)
    for i, v in pairs(tbl) do
        local kret, vret = func(i, v)
        if vret then
            tbl[kret or i] = vret
        elseif kret then
            tbl[i] = kret
        end
    end
end

---sometimes i wonder why these functions dont exist.
function math.clamp(num, min, max)
    max = max or math.huge
    min = min or -math.huge
    assert(min <= max)
    return math.min(math.max(num, min), max)
end

function collect(iter)
    local ret = {}
    for v in iter do
        ret[#ret+1] = v
    end
    return ret
end

function is_debugplus_console_open()
    local succ, dbp = pcall(require, "debugplus.console")
    if succ and dbp and dbp.isConsoleFocused and dbp.isConsoleFocused() then
        return true
    end
end
