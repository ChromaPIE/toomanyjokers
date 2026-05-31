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

function tmj_native_ime_hint_pairs()
    return {
        { "SDL_IME_SHOW_UI", "1" },
    }
end

local function tmj_record_native_ime_status(ok, status)
    local mod = rawget(_G, "TMJ")
    if mod then
        mod.native_ime_ui_hint_ok = ok
        mod.native_ime_ui_hint_status = status
    end
    return ok
end

local function tmj_sdl_candidates()
    local ok, ffi = pcall(require, "ffi")
    if not ok or not ffi then return nil, "ffi unavailable" end

    pcall(function()
        ffi.cdef[[
            typedef struct SDL_Rect { int x, y; int w, h; } SDL_Rect;
            int SDL_SetHint(const char *name, const char *value);
            int SDL_SetHintWithPriority(const char *name, const char *value, int priority);
            void SDL_SetTextInputRect(SDL_Rect *rect);
            void SDL_StartTextInput(void);
            void *GetModuleHandleA(const char *lpModuleName);
            void *GetProcAddress(void *hModule, const char *lpProcName);
        ]]
    end)

    local libs = {
        { name = "ffi.C", lib = ffi.C },
    }

    if ffi.os == "Windows" then
        local loaded_kernel, kernel32 = pcall(ffi.load, "kernel32")
        if loaded_kernel and kernel32 then
            local function ptr_ok(ptr)
                return ptr ~= nil and tonumber(ffi.cast("uintptr_t", ptr)) ~= 0
            end
            for _, dll_name in ipairs({ "SDL2.dll", "SDL3.dll" }) do
                local got_module, module = pcall(kernel32.GetModuleHandleA, dll_name)
                if got_module and ptr_ok(module) then
                    libs[#libs + 1] = {
                        name = "loaded " .. dll_name,
                        set_hint = function(name, value)
                            local proc = kernel32.GetProcAddress(module, "SDL_SetHintWithPriority")
                            if ptr_ok(proc) then
                                local func = ffi.cast("int (__cdecl *)(const char *, const char *, int)", proc)
                                return func(name, value, 2) ~= 0
                            end
                            proc = kernel32.GetProcAddress(module, "SDL_SetHint")
                            if ptr_ok(proc) then
                                local func = ffi.cast("int (__cdecl *)(const char *, const char *)", proc)
                                return func(name, value) ~= 0
                            end
                            return false
                        end,
                        set_rect = function(rect)
                            local proc = kernel32.GetProcAddress(module, "SDL_SetTextInputRect")
                            if not ptr_ok(proc) then return false end
                            local func = ffi.cast("void (__cdecl *)(SDL_Rect *)", proc)
                            func(rect)
                            return true
                        end,
                        start_text_input = function()
                            local proc = kernel32.GetProcAddress(module, "SDL_StartTextInput")
                            if not ptr_ok(proc) then return false end
                            local func = ffi.cast("void (__cdecl *)(void)", proc)
                            func()
                            return true
                        end,
                    }
                end
            end
        end
    end

    for _, lib_name in ipairs({ "SDL2", "SDL2.dll", "SDL3", "SDL3.dll" }) do
        local loaded, lib = pcall(ffi.load, lib_name)
        if loaded and lib then
            libs[#libs + 1] = { name = lib_name, lib = lib }
        end
    end

    return libs, nil, ffi
end

local function tmj_try_set_sdl_hint(candidate, name, value)
    if candidate.set_hint then
        local ok, result = pcall(candidate.set_hint, name, value)
        return ok and result
    end

    local lib = candidate.lib
    local ok, result = pcall(function()
        return lib.SDL_SetHintWithPriority(name, value, 2)
    end)
    if ok then return result ~= 0 end

    ok, result = pcall(function()
        return lib.SDL_SetHint(name, value)
    end)
    return ok and result ~= 0
end

function tmj_enable_native_ime_ui()
    local mod = rawget(_G, "TMJ")
    if mod and mod.native_ime_ui_hint_attempted then
        return mod.native_ime_ui_hint_ok
    end
    if mod then mod.native_ime_ui_hint_attempted = true end

    local libs, err = tmj_sdl_candidates()
    if not libs then
        return tmj_record_native_ime_status(false, err or "SDL unavailable")
    end

    for _, candidate in ipairs(libs) do
        local all_set = true
        for _, hint in ipairs(tmj_native_ime_hint_pairs()) do
            if not tmj_try_set_sdl_hint(candidate, hint[1], hint[2]) then
                all_set = false
                break
            end
        end
        if all_set then
            return tmj_record_native_ime_status(true, "enabled through " .. candidate.name)
        end
    end

    return tmj_record_native_ime_status(false, "SDL hint unavailable")
end

function tmj_set_native_ime_rect(x, y, w, h)
    local libs, err, ffi = tmj_sdl_candidates()
    if not libs then return false, err or "SDL unavailable" end
    local rect = ffi.new("SDL_Rect")
    rect.x, rect.y, rect.w, rect.h = x, y, w, h

    for _, candidate in ipairs(libs) do
        local ok, result
        if candidate.set_rect then
            ok, result = pcall(candidate.set_rect, rect)
            ok = ok and result
        else
            ok = pcall(function()
                candidate.lib.SDL_SetTextInputRect(rect)
            end)
        end
        if ok then
            pcall(function()
                if candidate.start_text_input then
                    candidate.start_text_input()
                else
                    candidate.lib.SDL_StartTextInput()
                end
            end)
            return true, candidate.name
        end
    end

    return false, "SDL_SetTextInputRect unavailable"
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

    local ime_hints = tmj_native_ime_hint_pairs()
    assert(ime_hints[1][1] == "SDL_IME_SHOW_UI")
    assert(ime_hints[1][2] == "1")

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
