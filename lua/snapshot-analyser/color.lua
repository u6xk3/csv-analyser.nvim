local util = require("snapshot-analyser.util")

local M = {}

local function get_rgb(color)
    local r_hex, g_hex, b_hex = "", "", ""
    local color_str
    if type(color) == "number" then
        color_str = string.format("#%06X", color)
    else
        color_str = color
    end

    util.for_each_char(color_str, function (ch, i)
        if i >= 2 and i < 4 then
            r_hex = r_hex .. ch
        elseif i >= 4 and i < 6 then
            g_hex = g_hex .. ch
        elseif i >= 6 then
            b_hex = b_hex .. ch
        end
    end)

    return tonumber(r_hex, 16) , tonumber(g_hex, 16), tonumber(b_hex, 16)
end

function M.darken(color, percent)
    local r, g, b = get_rgb(color)

    if r == nil or g == nil or b == nil then
        print("Invalid hex string")
        return
    end

    r = math.max(r - (r / 100 * percent), 0)
    g = math.max(g - (g / 100 * percent), 0)
    b = math.max(b - (b / 100 * percent), 0)

    return string.format("#%02X%02X%02X", r, g, b)
end

function M.brighten(color, percent)
    local r, g, b = get_rgb(color)

    if r == nil or g == nil or b == nil then
        print("Invalid hex string")
        return
    end

    r = math.min(r + (r / 100 * percent), 255)
    g = math.min(g + (g / 100 * percent), 255)
    b = math.min(b + (b / 100 * percent), 255)

    return string.format("#%02X%02X%02X", r, g, b)
end

return M
