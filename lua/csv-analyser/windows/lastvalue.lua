local csv = require("csv-analyser.csv")
local el = require("csv-analyser.entry-list")
local filter = require("csv-analyser.filter")
local hl = require("csv-analyser.highlight")
local main = require("csv-analyser.windows.main")
local util = require("csv-analyser.util")

local M =  {}

local buffer
local values = {}
local csv_entries
local config
local augroup

local function update_lastvalues()
    local main_win = vim.fn.bufwinid(main.get_buffer())
    if main_win == -1 then return end

    local main_row = vim.api.nvim_win_get_cursor(main_win)[1]

    local entry = main.get_entries()[main_row - 1]

    if csv_entries == nil then csv_entries = csv.get_entries() end

    local csv_index
    if entry == nil then
        csv_index = 1
    else
        csv_index = el.contains(csv_entries, entry)
    end

    for line, value in ipairs(values) do
        for i = csv_index, 1, -1 do
            if value.condition.evaluate(csv_entries[i]) then
                value.entry = csv_entries[i]
                break
            elseif i == 1 then
                value.entry = nil
            end
        end
        local txt
        if value.entry ~= nil then
            txt = csv.create_line(value.entry.fields, value.columns)
            vim.api.nvim_buf_set_lines(buffer, line - 1, line, true, { txt })
            local hl_group = csv.entry_get_hl_group(value.entry)
            if hl_group ~= nil then
                hl.add(M, value.entry, hl_group)
            end
        else
            txt = "NOT FOUND"
            vim.api.nvim_buf_set_lines(buffer, line - 1, line, true, { txt })
        end
    end
end

local function remove()
    local row  = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(buffer, row - 1, row, true, {})
    values[row] = nil
end

local function apply()
    local row  = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(buffer, row - 1, row, true)[1]

    if vim.api.nvim_get_mode()["mode"] == "i" then
        vim.api.nvim_input("<ESC>")
    end

    local input = util.split_string(line, " ")

    local filter_tbl = {}
    local show_tbl = {}
    local found_show = false
    for _, field in ipairs(input) do
        if field == "show" then
            found_show = true

        elseif found_show then
            table.insert(show_tbl, field)

        else
            table.insert(filter_tbl, field)
        end
    end

    if not found_show then
        print("Missing keyword 'show'")
        return
    end

    local condition = filter.parse_args(filter_tbl)
    if condition == nil then
        print("Invalid filter")
        return
    end

    for _, col in ipairs(show_tbl) do
        if util.array_contains(csv.get_header(), col) == false then
            print("Invalid column after show: " .. col)
            return
        end
    end

    values[row] = {
        input_line = line,
        condition = condition,
        columns = show_tbl
    }

    update_lastvalues()
end

local function edit()
    local row  = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(buffer, row - 1, row, true, { values[row].input_line })

    --vim.api.nvim_input("i")
end

function M.setup(conf)
    if conf ~= nil then config = conf end

    buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffer, "Last Value")

    vim.api.nvim_buf_set_keymap(buffer, "n", "q", '', { noremap = true, callback = M.close })
    vim.api.nvim_buf_set_keymap(buffer, "i", "<CR>", '', { noremap = true, callback = apply })
    vim.api.nvim_buf_set_keymap(buffer, "n", "<CR>", '', { noremap = true, callback = apply })
    vim.api.nvim_buf_set_keymap(buffer, "n", "e", '', { noremap = true, callback = edit })
    vim.api.nvim_buf_set_keymap(buffer, "n", "dd", '', { noremap = true, callback = remove })

    --augroup = vim.api.nvim_create_augroup("lastvalue" ,{})
end

function M.open()
    update_lastvalues()

    local main_win = vim.fn.bufwinid(main.get_buffer())
    if main_win == -1 then return end

    local main_width = vim.api.nvim_win_get_width(main_win)
    local main_height = vim.api.nvim_win_get_height(main_win)

    local width = main_width / 3 * 2
    local height = main_height / 3 * 2

    local main_width_middle = main_width / 2
    local main_height_middle = main_height / 2

    local width_middle = width / 2
    local height_middle = height / 2

    local win = vim.api.nvim_open_win(buffer, false, {
        relative="editor",
        row=main_height_middle - height_middle,
        col=main_width_middle - width_middle,
        width=math.floor(width),
        height=math.floor(height),
        border="single"
    })

    vim.api.nvim_set_current_win(win)
    vim.api.nvim_input("<ESC>")
end

function M.close()
    local win = vim.fn.bufwinid(buffer)
    if win == -1 then return end

    vim.api.nvim_win_close(win, false)
end

function M.toggle()
    local win = vim.fn.bufwinid(buffer)

    if win == -1 then
        M.open()
    else
        M.close()
    end
end

function M.get_buffer()
    return buffer
end

function M.get_line_by_entry(entry)
    for line, val in ipairs(values) do
        if val.entry ~= nil then
            if val.entry.index == entry.index then
                return line - 1
            end
        end
    end
    return false
end

return M
