local util = require("csv-analyser.util")
local filter = require("csv-analyser.filter")
local color_util = require("csv-analyser.color")
local jl = require("csv-analyser.windows.jumplist")
local main = require("csv-analyser.windows.main")
local hl = require("csv-analyser.highlight")
local csv = require("csv-analyser.csv")

local M = {}

local header
local index = {}
local hidden_entries = {}
local hidden_columns = {}
local og_buf
local main_buf
local config
local setup_called = false
local analyser_started = false

local default_config = {
    jumplist_position = "below",
    height = 15,
    width = 50,
    colors = {
        red = { fg = "#F54242" },
        orange = { fg = "#DE8D00" },
        yellow = { fg = "#C9A400" },
        green = { fg = "#00753B" },
        blue = { fg = "#026DBA" },
        purple = { fg = "#7F00C9" }
    },
    delimiter = ";",
    spacing = "  ",
}

local function get_entry_by_line_nr(data, buf, line_nr)
    for _, entry in ipairs(data) do
        if not entry.hidden and entry.locations[buf] == line_nr then
            return entry
        end
    end
end

local function create_data_objs(lines, header_row)
    for nr, line in ipairs(lines) do
        local fields = util.split_string(line, ";")
        local values = {}

        for i, entry in ipairs(fields) do
            if i < #header_row then
                table.insert(values, entry)
                --values[header_row[i]] = entry
            elseif i == #header_row then
                table.insert(values, table.concat(fields, config.spacing, i))
                --values[header_row[i]] = table.concat(fields, config.spacing, i)
            end
        end
        csv.create_entry(main_buf, line, nr, values)
    end
end

local function get_buffers_from_data(data)
    local buffers = {}
    for _, obj in ipairs(data) do
        if not obj.hidden then
            for buf, _ in pairs(obj.locations) do
                if buffers[buf] == nil then buffers[buf] = {} end
                table.insert(buffers[buf], csv.create_line(obj.fields, config.spacing, hidden_columns))
            end
        end
    end
    return buffers
end

local function remove_highlight(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")

    local eval = filter.parse_args(fields)
    if eval == nil then return end

    local amount = hl.remove_by_filter(eval)

    print(amount .. " Lines Cleared")
end

local function add_highlight(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    local color = hl.check_hl_group(fields[#fields])

    if color == nil then
        print("Invalid color, last argument must be color")
        return
    end

    table.remove(fields, #fields)
    local eval = filter.parse_args(fields)
    if eval == nil then return end

    local amount = 0
    for _, obj in ipairs(csv.get_entries()) do
        if not obj.hidden and eval.evaluate(obj) then
            hl.add(obj, color)
            amount = amount + 1
        end
    end

    print(amount .. " Lines Colored")
end

local function draw_data(header_row, data)
    for buf, buffer_content in pairs(get_buffers_from_data(data)) do
        util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, 0, -1, true, { csv.create_line(header_row, config.spacing, hidden_columns) }) end)
        util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, -1, -1, true, buffer_content) end)
    end
    hl.reapply()
end

local function buf_draw_data(buf, header_row, data)
    local buffers = get_buffers_from_data(data)
    if buffers[buf] == nil then return false end

    util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, 0, -1, true, { csv.create_line(header_row, config.spacing, hidden_columns) }) end)
    util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, -1, -1, true, buffers[buf]) end)

    hl.buf_reapply(buf)
end


local function hide_column(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    csv.hide_columns(fields)
end

local function show_column(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    csv.show_columns(fields)
end

local function hide_entry(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end
    csv.hide_entries_by_filter(eval)
end

local function show_entry(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end
    csv.show_entries_by_filter(eval)
end

local function jumplist_remove(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end

    local lines = jl.remove_entries(eval)
    for i = #lines, 1, -1 do
        util.buf_temp_modifiable(jl.get_buffer(), function()
            vim.api.nvim_buf_set_lines(jl.get_buffer(), lines[i], lines[i] + 1, true, {})
        end)
    end

    csv.buf_fix_line_nrs(jl.get_buffer(), jl.get_entries())

    print(#lines .. " Lines removed from the jumplist")
end

local function jumplist_add(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end

    local amount = 0
    for _, entry in ipairs(csv.get_entries()) do
        if not entry.hidden and not jl.contains_entry(entry) then
            if eval.evaluate(entry) then
                jl.add_entry(entry)
                amount = amount + 1
            end
        end
    end

    csv.buf_fix_line_nrs(jl.get_buffer(), jl.get_entries())

    buf_draw_data(jl.get_buffer(), header, jl.get_entries())
    print(amount .. " Lines added to the jumplist")
end

function M.setup(conf)
    if conf ~= nil then
        for key, item in pairs(default_config) do
            if conf[key] == nil then
                conf[key] = item
            end
        end
        config = conf

    else
        config = default_config
    end

    filter.setup({
        filters = config.filters,
        index = index
    })

    setup_called = true
end

local previous_id = nil
function M.jumplist_go()
    local win = vim.api.nvim_get_current_win()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local ns = hl.get_namespace()

    if previous_id ~= nil then
        vim.api.nvim_buf_del_extmark(main_buf, ns, previous_id)
    end

    local entry = jl.get_entries()[row - 1]
    if entry == nil then return end

    win = vim.fn.bufwinid(main_buf)
    if win == -1 then return end

    if entry.hidden then
        print("This Entry was hidden in the mean time")
        return
    end

    if entry.highlight.group ~= nil then
        local current_bg = vim.api.nvim_get_hl(ns, { name = entry.highlight.group, create = false } ).bg
        local bg
        if current_bg ~= nil then
            bg = color_util.brighten(current_bg, 50)
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

    vim.api.nvim_win_set_cursor(win, { entry.locations[main_buf] + 1, 0 })
    previous_id = vim.api.nvim_buf_set_extmark(main_buf, ns, entry.locations[main_buf], 0, {
        end_col = util.buf_get_line_length(main_buf, entry.locations[main_buf]),
        hl_group = "jump",
        strict = false
    })
end

local function parse()
    og_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_buf_get_lines(og_buf, 0, -1, true)

    header = util.split_string(buf[1], ";")

    for i, field in ipairs(header) do
        index[field] = i
    end

    table.remove(buf, 1)
    return buf
end

function M.analyser_start()
    if not setup_called then
        print("csv-analyser.setup() must be called before usage")
        return
    end

    if analyser_started then return end

    local csv_content = parse()


    hl.setup(config.colors)
    csv.setup({ header = header, spacing = config.spacing })

    jl.setup({ position = config.jumplist_position })
    main.setup({ header = header })
    main_buf = main.get_buffer()

    vim.api.nvim_buf_set_keymap(jl.get_buffer(), "n", "<leader>j", '', { callback=jl.toggle })
    vim.api.nvim_buf_set_keymap(main.get_buffer(), "n", "<leader>j", '', { callback=jl.open })
    vim.api.nvim_buf_set_keymap(jl.get_buffer(), "n", "<CR>", '', {
        noremap=true,
        callback=M.jumplist_go
    })

    create_data_objs(csv_content, header)

    --draw_data(header, csv.get_entries())
    main.draw()

    vim.api.nvim_create_user_command("CsvHide", hide_entry, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvShow", show_entry, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvHideCol", hide_column, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvShowCol", show_column, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvColor", add_highlight, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvClear", remove_highlight, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvAdd", jumplist_add, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvRemove", jumplist_remove, { nargs = '?' })
end

function M.analyser_stop()
    if main_buf ~= nil then
        jl.close()
        jl.clear()

        vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), og_buf)
        vim.api.nvim_buf_delete(main_buf, {})

        vim.api.nvim_del_user_command("CsvHide")
        vim.api.nvim_del_user_command("CsvShow")
        vim.api.nvim_del_user_command("CsvHideCol")
        vim.api.nvim_del_user_command("CsvShowCol")
        vim.api.nvim_del_user_command("CsvColor")
        vim.api.nvim_del_user_command("CsvClear")
        vim.api.nvim_del_user_command("CsvAdd")
        vim.api.nvim_del_user_command("CsvRemove")

        header = nil
        index = {}
        hidden_entries = {}
        hidden_columns = {}
        og_buf = nil
        main_buf = nil
    end
end

return M
