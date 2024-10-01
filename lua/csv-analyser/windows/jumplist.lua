local color = require("csv-analyser.color")
local csv = require("csv-analyser.csv")
local el = require("csv-analyser.entry-list")
local filter = require("csv-analyser.filter")
local hl = require("csv-analyser.highlight")
local main = require("csv-analyser.windows.main")
local util = require("csv-analyser.util")

local M = {}

local config
local entries = {}
local entry_added = {}
local buffer
local columns

local function csv_changed(topic, change)
    if topic == "entries_hidden" then
        if change.hidden == false then
            for _, entry in ipairs(change.entries) do
                if entry_added[entry] == true then
                    local line = el.insert(entries, entry)
                    util.buf_temp_modifiable(buffer, function()
                        vim.api.nvim_buf_set_lines(buffer, line, line, true, { csv.create_line(entry.fields, columns) })
                    end)
                end
            end
            hl.win_reapply(M)
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
        for _, entry in ipairs(change.entries) do
            local line = el.contains(entries, entry)
            if line ~= false then
                if change.hl_group == nil then
                    hl.remove(M, entry)
                else
                    hl.add(M, entry, change.hl_group)
                end
            end
        end
    end
end

function M.setup(conf)
    if conf ~= nil then config = conf end

    buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffer, "Jump List")
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })

    vim.api.nvim_create_user_command("CsvAdd", M.add_entries, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvRemove", M.remove_entries, { nargs = '?' })

    vim.api.nvim_buf_set_keymap(buffer, "n", "<CR>", '', {
        noremap=true,
        callback=M.jump_to
    })

    csv.add_csv_change_listener(csv_changed, { "entries_hidden", "columns_hidden", "highlights" })
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
    hl.win_reapply(M)
end

local previous_jump = nil
function M.jump_to()
    local win = vim.api.nvim_get_current_win()
    local row = vim.api.nvim_win_get_cursor(win)[1]

    local main_buf = main.get_buffer()

    local ns = hl.get_namespace()

    local entry = entries[row - 1]
    if entry == nil then return end

    local line = main.get_line_by_entry(entry)
    if type(line) == "boolean" then return end

    if previous_jump ~= nil then
        vim.api.nvim_buf_del_extmark(main_buf, ns, previous_jump)
    end

    win = vim.fn.bufwinid(main_buf)
    if win == -1 then return end

    if entry.highlight.group ~= nil then
        local current_bg = vim.api.nvim_get_hl(ns, { name = entry.highlight.group, create = false } ).bg
        local bg
        if current_bg ~= nil then
            bg = color.brighten(current_bg, 50)
        else
            bg = vim.api.nvim_get_hl(0, { name = "Visual", create = false }).bg
        end
        vim.api.nvim_set_hl(ns, "jump", { bg = bg })
    else
        vim.api.nvim_set_hl(ns, "jump", {
            bg = vim.api.nvim_get_hl(0, {
                name = "Visual",
                create = false }).bg
        })
    end

    vim.api.nvim_win_set_cursor(win, { line + 1, 0 })
    previous_jump = vim.api.nvim_buf_set_extmark(main_buf, ns, line, 0, {
        end_col = util.buf_get_line_length(main_buf, line),
        hl_group = "jump",
        strict = false
    })
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
    if entry_added[entry] == nil then
        entry_added[entry] = true
        local line = el.insert(entries, entry)
        util.buf_temp_modifiable(buffer, function()
            vim.api.nvim_buf_set_lines(buffer, line, line, true, { csv.create_line(entry.fields, columns) })
        end)

        local hl_group = csv.entry_get_hl_group(entry)
        if hl_group ~= nil then
            hl.add(M, entry, hl_group)
        end
    end
end

function M.add_entries(user_cmd)
    local condition = filter.parse_args(util.split_string(user_cmd.args, " "))
    if condition == nil then return end

    local count = 0

    for _, entry in ipairs(csv.get_entries()) do
        if condition.evaluate(entry) and entry_added[entry] == nil then
            entry_added[entry] = true
            count = count + 1
            if not csv.entry_is_hidden(entry) then
                local line = el.insert(entries, entry)
                util.buf_temp_modifiable(buffer, function()
                    vim.api.nvim_buf_set_lines(buffer, line, line, true, { csv.create_line(entry.fields, columns) })
                end)

                local hl_group = csv.entry_get_hl_group(entry)
                if hl_group ~= nil then
                    hl.add(M, entry, hl_group)
                end
            end
        end
    end

    print("Added " .. count .. " lines")
end

function M.remove_entries(user_cmd)
    local condition = filter.parse_args(util.split_string(user_cmd.args, " "))
    if condition == nil then return end

    local valid_entries = {}

    for _, entry in ipairs(entries) do
        if condition.evaluate(entry) then
            entry_added[entry] = nil
            el.insert(valid_entries, entry)
        end
    end

    for i = #valid_entries, 1, -1 do
        local line = el.remove_no_reindex(entries, valid_entries[i])
        util.buf_temp_modifiable(buffer, function()
            vim.api.nvim_buf_set_lines(buffer, line, line + 1, true, {})
        end)
    end
    util.array_reindex(entries)

    print("Removed " .. #valid_entries .. " lines")
end

function M.remove_entry(entry)
    entry_added[entry] = nil
    local line = el.remove(entries, entry)
    if line ~= nil then
        util.buf_temp_modifiable(buffer, function()
            vim.api.nvim_buf_set_lines(buffer, line, line + 1, true, { csv.create_line(entry.fields, columns) })
        end)
    end
end

function M.get_buffer()
    return buffer
end

function M.get_entries()
    return entries
end

function M.get_line_by_entry(entry)
    return el.contains(entries, entry)
end

function M.clear()
    vim.api.nvim_buf_delete(buffer, {})

    config = nil
    buffer = nil
    columns = nil
    entries = {}
    entry_added = {}
end

return M
