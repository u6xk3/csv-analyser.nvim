local util = require("csv-analyser.util")
local el = require("csv-analyser.entry-list")

local M = {}

local config
local entries = {}
local buffer

function M.setup(conf)
    if conf ~= nil then config = conf end

    buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffer, "Jump List")
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
end

function M.open()
    local win = vim.fn.bufwinid(buffer)
    if win == -1 then
        win = vim.api.nvim_open_win(buffer, false, {
            split = config.position,
            win = 0,
            height = 15,
            width = 50
        })
    end

    vim.api.nvim_set_option_value("cursorline", true, { win = win })
    vim.api.nvim_set_current_win(win)
end

function M.close()
    local win = vim.fn.bufwinid(buffer)
    if win ~= -1 then
        vim.api.nvim_win_close(win, false)
    end
end

function M.toggle()
    local win = vim.fn.bufwinid(buffer)
    if win == -1 then
        M.open()
    else
        M.close()
    end
end

function M.add_entry(entry)
    entry.locations[buffer] = "fix"
    el.insert(entries, entry)
end

function M.remove_entries(condition)
    local removed_lines = {}

    for i, entry in ipairs(entries) do
        if condition.evaluate(entry) then
            table.insert(removed_lines, entry.locations[buffer])
            entry.locations[buffer] = nil
            entries[i] = nil
        end
    end

    util.array_reindex(entries)
    return removed_lines
end

function M.remove_entry(entry)
    for i = 1, #entries do
        if entries[i].index == entry.index then
            entries[i] = nil
        end
    end

    util.array_reindex(entries)
end

function M.get_buffer()
    return buffer
end

function M.get_entries()
    return entries
end

function M.contains_entry(entry)
    for i = 1, #entries do
        if entries[i].index == entry.index then return true end
    end

    return false
end

function M.clear()
    vim.api.nvim_buf_delete(buffer, {})

    config = nil
    entries = {}
end

return M
