local csv = require("csv-analyser.csv")
local hl = require("csv-analyser.highlight")
local util = require("csv-analyser.util")
local el = require("csv-analyser.entry-list")

local M = {}

local entries = {}
local buffer
local columns = {}
local config

local function csv_changed(topic, change)
    if topic == "entries_hidden" then
        if change.hidden == false then
            for _, entry in ipairs(change.entries) do
                local line = el.insert(entries, entry)
                util.buf_temp_modifiable(buffer, function()
                    vim.api.nvim_buf_set_lines(buffer, line, line, true, { csv.create_line(entry.fields, columns) })
                end)
            end
        else
            for i = #change.entries, 1, -1 do
                local line = el.remove_no_reindex(entries, change.entries[i])
                if line ~= nil then
                    util.buf_temp_modifiable(buffer, function()
                        vim.api.nvim_buf_set_lines(buffer, line, line + 1, true, {})
                    end)
                end
            end
            util.array_reindex(entries)
        end

    elseif topic == "columns_hidden" then
        if change.hidden == false then
            util.array_extend(columns, change.columns)
        else
            for _, col in ipairs(change.columns) do
                util.array_remove_by_val(columns, col)
            end
        end
        M.draw()

    elseif topic == "highlights" then
    end
end

function M.setup(conf)
    config = conf

    vim.api.nvim_win_set_hl_ns(0, hl.get_namespace())
    buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffer, "CSV")
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
    vim.api.nvim_win_set_buf(0, buffer)

    csv.add_csv_change_listener(csv_changed, { "columns_hidden", "entries_hidden", "highlights" })
    entries = util.table_shallow_copy(csv.get_entries())
    columns = { unpack(config.header) }
end

function M.draw()
    local win = vim.fn.bufwinid(buffer)
    local cursor
    if win ~= -1 then cursor = vim.api.nvim_win_get_cursor(win) end

    local content = csv.create_buffer_content(entries, columns)
    util.buf_temp_modifiable(buffer, function()
        vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { csv.create_line(config.header, columns) })
        vim.api.nvim_buf_set_lines(buffer, -1, -1, true, content)
    end)

    if cursor ~= nil then vim.api.nvim_win_set_cursor(win, cursor) end
end

function M.get_line_by_entry(entry)
    return el.contains(entries, entry)
end

function M.get_buffer()
    return buffer
end

return M
