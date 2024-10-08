local util = require("csv-analyser.util")
local filter = require("csv-analyser.filter")
local jl = require("csv-analyser.windows.jumplist")
local main = require("csv-analyser.windows.main")
local hl = require("csv-analyser.highlight")
local csv = require("csv-analyser.csv")

local M = {}

local header
local index = {}
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
        csv.create_entry(line, nr, values)
    end
end

local function remove_highlight(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")

    local eval = filter.parse_args(fields)
    if eval == nil then return end

    csv.remove_highlight_by_filter(eval)
end

local function add_highlight(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    local hl_group = hl.check_hl_group(fields[#fields])

    if hl_group == nil then
        print("Invalid color, last argument must be color")
        return
    end

    table.remove(fields, #fields)
    local eval = filter.parse_args(fields)
    if eval == nil then return end

    csv.add_highlight_by_filter(eval, hl_group)
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
    analyser_started = true

    local csv_content = parse()


    hl.setup(config.colors)
    csv.setup({ header = header, spacing = config.spacing })
    create_data_objs(csv_content, header)


    jl.setup({ position = config.jumplist_position, header = header })
    main.setup({ header = header })
    main_buf = main.get_buffer()

    vim.api.nvim_buf_set_keymap(jl.get_buffer(), "n", "<leader>j", '', { callback=jl.toggle })
    vim.api.nvim_buf_set_keymap(main.get_buffer(), "n", "<leader>j", '', { callback=jl.open })

    --draw_data(header, csv.get_entries())
    main.draw()
    jl.draw()

    vim.api.nvim_create_user_command("CsvHide", hide_entry, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvShow", show_entry, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvHideCol", hide_column, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvShowCol", show_column, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvColor", add_highlight, { nargs = '?' })
    vim.api.nvim_create_user_command("CsvClear", remove_highlight, { nargs = '?' })
end

function M.analyser_stop()
    if analyser_started then
        analyser_started = false
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
        og_buf = nil
        main_buf = nil
    end
end

return M
