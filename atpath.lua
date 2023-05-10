-- atpath.lua: access values deep inside modules and tables, using path strings.

local assert = assert
local type = type
local tonumber = tonumber
local tostring = tostring
local ssub = string.sub
local sgsub = string.gsub
local sgmatch = string.gmatch
local sformat = string.format
local tremove = table.remove

local M = {}
M.options = {
    -- If not quoted by ' or ", try convert the quoted path segment to number; set this to falsy to skip this behaviour
    auto_convert_to_number = true,
    -- If not quoted by ' or ", try convert the quoted path segment to boolean; set this to falsy to skip this behaviour
    auto_convert_to_boolean = true,
    -- Used by `at_module(path)`; replace this to use another require function in place of the default one
    require = _G.require,
}

local function hex_to_char(hexstr) return string.char(tonumber(hexstr, 16)) end
local function parse_segment(segment)
    -- literal key
    if #segment >= 2 then
        local first, last = ssub(segment, 1, 1), ssub(segment, -1, -1)
        if
            (first == [[']] and last == [[']])
            or (first == [["]] and last == [["]])
        then
            return ssub(segment, 2, -2)
        end
    end
    -- tonumber
    if M.options.auto_convert_to_number then
        local num = tonumber(segment)
        if type(num) == 'number' then return num end
    end
    -- toboolean
    if M.options.auto_convert_to_boolean then
        if segment == 'true' then return true
        elseif segment == 'false' then return false end
    end
    -- de-escape
    segment = sgsub(segment, [[%%(%x%x)]], hex_to_char)
    return segment
end

---Parse a path into a series of keys, with some helpful info.
---@param path string Path that specifies keys.
---@return {[number]: string, is_absolute: boolean} Result done parsed.
function M.parse(path)
    local is_absolute
    -- check absolute
    if ssub(path, 1, 1) == '/' then
        path = ssub(path, 2, -1)
        is_absolute = true
    else
        is_absolute = false
    end
    local result = {}
    for segment in sgmatch(path, [[([^/]*)/?]]) do
        if segment == '' or segment == '.' then
            -- empty or dot: do nothing
        elseif segment == '..' then
            -- double dot: one layer atop
            assert(#result > 0, "The segment \"..\" makes the path goes beyond the top layer!")
            result[#result] = nil
        else
            -- normal segment
            result[#result+1] = parse_segment(segment)
        end
    end
    result.is_absolute = is_absolute
    return result
end

local function char_to_hex(char) return string.upper(sformat([[%%%02x]], string.byte(char))) end
local function build_segment(segment)
    if segment == "." then return "%2e" end
    if segment == ".." then return "%2e%2e" end
    local segment_type = type(segment)
    local need_literal_quote
    if segment_type == 'string' then
        -- anti-tonumber
        local num = tonumber(segment)
        if type(num) == 'number' then
            need_literal_quote = true
        end
        -- anti-toboolean
        if segment == 'true' or segment == 'false' then
            need_literal_quote = true
        end
        need_literal_quote = need_literal_quote or false
    elseif segment_type == 'number' or segment_type == 'boolean' then
        segment = tostring(segment)
        need_literal_quote = false
    else
        error("Segment is not of a valid type!: " .. segment_type)
    end
    -- escape
    segment = sgsub(segment, [[([^%w._+-])]], char_to_hex)
    if need_literal_quote then segment = sformat([['%s']], segment) end
    return segment
end

---Build a series of keys into a path.
---@param keys {[integer]: string|number|boolean} Array of keys.
---@param modulename? string (Optional) Module name to look at. If given, the result path is an absolute path.
---@param i? number (Optional) Starting index of `keys`, to select only a range of keys to build. Defaults to 1.
---@param j? number (Optional) Ending index of `keys`, to select only a range of keys to build. Defaults to -1 (the last).
function M.build(keys, modulename, i, j)
    local n = #keys
    i = i or 1
    i = (i >= 0) and i or (i + n + 1)
    j = j or -1
    j = (j >= 0) and j or (j + n + 1)

    local segments = {}
    if modulename then
        segments[#segments+1] = build_segment(modulename)
    end
    for iKey = i, j do if keys[iKey] ~= nil then
        segments[#segments+1] = build_segment(keys[iKey])
    end end
    local result = table.concat(segments, '/')
    -- Use absolute path when meaning looking into a module
    if modulename ~= nil then result = '/' .. result end
    return result
end

local function inner_at(t, parsed)
    local current = t
    for i = 1, #parsed do
        if type(current) ~= 'table' then
            error(
                "Unable to index at the given path, some value in the middle of the process is not table:\n"
                .. "current path: " .. M.build(parsed, nil, 1, i-1) .. "\n"
                .. "current value: " .. tostring(current) .. "\n"
                .. "remaining path to access: " .. M.build(parsed, nil, i, -1)
            )
        end
        current = current[parsed[i]]
    end
    return current
end

---Access the table using a path.
---@param t table Table to access.
---@param path string Path that specifies a series of keys.
---@return any value Accessed result.
function M.at(t, path)
    local parsed = M.parse(path)
    assert(parsed.is_absolute == false, "The path should be relative!: " .. path)
    return inner_at(t, parsed)
end

---Search for a module, then access the module using a path.
---@param path string Path that specifies a series of keys.
---@return any value Accessed result.
function M.at_module(path)
    local parsed = M.parse(path)
    assert(parsed.is_absolute == true, "The path should be absolute!: " .. path)
    local module = M.options.require(parsed[1])
    tremove(parsed, 1)
    return inner_at(module, parsed)
end

return M

