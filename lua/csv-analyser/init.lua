local util = require("csv-analyser.util")
local filter = require("csv-analyser.filter")
local color_util = require("csv-analyser.color")
local jl = require("csv-analyser.jumplist")

local M = {}

local header
local index = {}
local entries = {}
local hidden_entries = {}
local hidden_columns = {}
local csv_content
local og_buf
local main_buf
local config
local setup_called = false
local ns

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

local function create_hl_groups(colors)
    for key, color in pairs(colors) do
        vim.api.nvim_set_hl(ns, key, {
            fg = color.fg,
            bg = color.bg
        })
    end
end

local function get_entry_by_line_nr(data, buf, line_nr)
    for _, entry in ipairs(data) do
        if not entry.hidden and entry.locations[buf] == line_nr then
            return entry
        end
    end
end

local function create_line(fields, spacing)
    local str = ""
    local hidden = false
    for i, field in ipairs(fields) do
        for _, col in ipairs(hidden_columns) do
            if i == col then hidden = true end
        end

        if not hidden then
            if str == "" then str = field
            else str = str .. spacing .. field end
        end
        hidden = false
    end
    return str
end

local data_obj = {}
function data_obj.create(line, buf, line_nr, fields)
    local buffers = {}
    local locations = {}
    table.insert(buffers, buf)
    locations[buf] = line_nr

    local data = {
        locations = locations,
        buffers = buffers,
        line = line,
        hidden = false,
        fields = fields,
        index = line_nr,
        highlight = {
            group = nil,
            ids = {}
        }
    }

    return data
end

local function create_data_objs(lines, header_row)
    local objs = {}

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
        table.insert(objs, data_obj.create(line, main_buf, nr, values))
    end

    return objs
end

local function get_buffers_from_data(data)
    local buffers = {}
    for _, obj in ipairs(data) do
        if not obj.hidden then
            for buf, _ in pairs(obj.locations) do
                if buffers[buf] == nil then buffers[buf] = {} end
                table.insert(buffers[buf], create_line(obj.fields, config.spacing))
            end
        end
    end
    return buffers
end

local function buf_fix_line_nrs(buf, data)
    local last_nr = 0
    for _, obj in ipairs(data) do
        if not obj.hidden then
            if util.array_contains_key(obj.locations, buf) then
                obj.locations[buf] = last_nr + 1
                last_nr = last_nr + 1
            end
        end
    end
end

local function fix_line_nrs(data)
    local last_nr_by_buffer = {}
    for _, obj in ipairs(data) do
        if not obj.hidden then
            for buf, _ in pairs(obj.locations) do
                if last_nr_by_buffer[buf] == nil then last_nr_by_buffer[buf] = 0 end
                obj.locations[buf] = last_nr_by_buffer[buf] + 1
                last_nr_by_buffer[buf] = last_nr_by_buffer[buf] + 1
            end
        end
    end
end

local function check_color(color)
    local checked = nil
    for key, _ in pairs(config.colors) do
        if key == color then checked = color end
    end
    return checked
end

local function remove_highlight(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")

    local eval = filter.parse_args(fields)
    if eval == nil then return end

    local amount = 0
    for _, obj in ipairs(entries) do
        if not obj.hidden and eval.evaluate(obj) then
            for buf, _ in pairs(obj.locations) do
                if obj.highlight.ids[buf] ~= nil then
                    vim.api.nvim_buf_del_extmark(buf, ns, obj.highlight.ids[buf])
                    obj.highlight.ids[buf] = nil
                end
            end
            obj.highlight.group = nil
            amount = amount + 1
        end
    end

    print(amount .. " Lines Cleared")
end

local function add_highlight(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    local color = check_color(fields[#fields])

    if color == nil then
        print("Invalid color, last argument must be color")
        return
    end

    table.remove(fields, #fields)
    local eval = filter.parse_args(fields)
    if eval == nil then return end

    local amount = 0
    for _, obj in ipairs(entries) do
        if not obj.hidden and eval.evaluate(obj) then
            for buf, line in pairs(obj.locations) do
                if obj.highlight.ids[buf] ~= nil then
                    vim.api.nvim_buf_del_extmark(buf, ns, obj.highlight.ids[buf])
                end
                obj.highlight.ids[buf] = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { end_col = util.buf_get_line_length(buf, line), hl_group = color, strict = true })
                obj.highlight.group = color
            end
            amount = amount + 1
        end
    end

    print(amount .. " Lines Colored")
end

local function reapply_highlights(data)
    for _, obj in ipairs(data) do
        if not obj.hidden then
            for buf, line in pairs(obj.locations) do
                if obj.highlight.group ~= nil then
                    obj.highlight.ids[buf] = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
                        end_col = util.buf_get_line_length(buf, line),
                        hl_group = obj.highlight.group,
                        strict = false
                    })
                end
            end
        end
    end
end

local function buf_reapply_highlights(buf, data)
    for _, obj in ipairs(data) do
        if obj.locations[buf] ~= nil and obj.highlight.group ~= nil and not obj.hidden then
            obj.highlight.ids[buf] = vim.api.nvim_buf_set_extmark(buf, ns, obj.locations[buf], 0, {
                end_col = util.buf_get_line_length(buf, obj.locations[buf]),
                hl_group = obj.highlight.group,
                strict = false
            })
        end
    end
end

local function draw_data(header_row, data)
    for buf, buffer_content in pairs(get_buffers_from_data(data)) do
        util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, 0, -1, true, { create_line(header_row, config.spacing) }) end)
        util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, -1, -1, true, buffer_content) end)
    end
    reapply_highlights(data)
end

local function buf_draw_data(buf, header_row, data)
    local buffers = get_buffers_from_data(data)
    if buffers[buf] == nil then return false end

    util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, 0, -1, true, { create_line(header_row, config.spacing) }) end)
    util.buf_temp_modifiable(buf, function () vim.api.nvim_buf_set_lines(buf, -1, -1, true, buffers[buf]) end)

    buf_reapply_highlights(buf, data)
end


local function hide_column(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    local win_main = vim.fn.bufwinid(main_buf)
    local win_jl = vim.fn.bufwinid(jl.get_buffer())

    local cursor_main
    local cursor_jl
    if win_main ~= -1 then cursor_main = vim.api.nvim_win_get_cursor(win_main) end
    if win_jl ~= -1 then cursor_jl = vim.api.nvim_win_get_cursor(win_jl) end

    local cols = {}
    for _, field in ipairs(fields) do
        if index[field] == nil then
            print("Invalid Column " .. field)
        else
            table.insert(cols, index[field])
        end
    end

    if #cols == 0 then return end

    for _, hidden in ipairs(hidden_columns) do
        for _, col in ipairs(cols) do
            if hidden == col then
                print("Column " .. user_cmd.args .. " already hidden")
                return
            end
        end
    end

    util.extend_table(hidden_columns, cols)

    draw_data(header, entries)

    if cursor_main ~= nil then vim.api.nvim_win_set_cursor(win_main, cursor_main) end
    if cursor_jl ~= nil then vim.api.nvim_win_set_cursor(win_jl, cursor_jl) end

    print("Hid column(s) " .. user_cmd.args)
end

local function show_column(user_cmd)
    local fields = util.split_string(user_cmd.args, " ")
    local win_main = vim.fn.bufwinid(main_buf)
    local win_jl = vim.fn.bufwinid(jl.get_buffer())

    local cursor_main
    local cursor_jl
    if win_main ~= -1 then cursor_main = vim.api.nvim_win_get_cursor(win_main) end
    if win_jl ~= -1 then cursor_jl = vim.api.nvim_win_get_cursor(win_jl) end

    local cols = {}
    for _, field in ipairs(fields) do
        if index[field] == nil then
            print("Invalid Column " .. field)
        else
            table.insert(cols, index[field])
        end
    end

    if #cols == 0 then return end

    local i = 1
    while i <= #hidden_columns do
        for _, col in ipairs(cols) do
            if hidden_columns[i] == col then
                table.remove(hidden_columns, i)
            end
        end
        i = i + 1
    end

    draw_data(header, entries)

    if cursor_main ~= nil then vim.api.nvim_win_set_cursor(win_main, cursor_main) end
    if cursor_jl ~= nil then vim.api.nvim_win_set_cursor(win_jl, cursor_jl) end

    print("Showed column(s) " .. user_cmd.args)
end

local function hide_entry(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end

    local amount = 0
    for i = #entries, 1, -1 do
        if not entries[i].hidden then
            if eval.evaluate(entries[i]) then
                entries[i].hidden = true
                table.insert(hidden_entries, entries[i])
                for buf, line in ipairs(entries[i].locations) do
                    util.buf_temp_modifiable(buf, function() vim.api.nvim_buf_set_lines(buf, line, line + 1, true, {}) end)
                    entries[i].locations[buf] = "hidden"
                end
                amount = amount + 1
            end
        end
    end

    table.sort(hidden_entries, function (a, b)
        return a.index < b.index
    end)

    fix_line_nrs(entries)
    print(amount .. " Entries hidden")
end

local function show_entry(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end

    local amount = 0
    for _, obj in ipairs(hidden_entries) do
        if eval.evaluate(obj) then
            obj.hidden = false
            amount = amount + 1
        end
    end

    fix_line_nrs(entries)

    local i = 1
    while i <= #hidden_entries do
        if hidden_entries[i].hidden == false then
            for buf, line in pairs(hidden_entries[i].locations) do
                util.buf_temp_modifiable(buf, function()
                    vim.api.nvim_buf_set_lines(buf, line, line, true, { create_line(hidden_entries[i].fields, config.spacing) })
                end)
                if hidden_entries[i].highlight.group ~= nil then
                    hidden_entries[i].highlight.ids[buf] =
                    vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
                        end_col = util.buf_get_line_length(buf, line),
                        hl_group = hidden_entries[i].highlight.group,
                        strict = false
                    })
                end
            end
            table.remove(hidden_entries, i)
            i = i - 1
        end
        i = i + 1
    end

    print(amount .. " Entries shown")
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

    buf_fix_line_nrs(jl.get_buffer(), jl.get_entries())

    print(#lines .. " Lines removed from the jumplist")
end

local function jumplist_add(user_cmd)
    local eval = filter.parse_args(util.split_string(user_cmd.args, " "))
    if eval == nil then return end

    local amount = 0
    for _, entry in ipairs(entries) do
        if not entry.hidden and not jl.contains_entry(entry) then
            if eval.evaluate(entry) then
                jl.add_entry(entry)
                amount = amount + 1
            end
        end
    end

    buf_fix_line_nrs(jl.get_buffer(), jl.get_entries())

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

function M.analyser_start()
    if not setup_called then
        print("csv-analyser.setup() must be called before usage")
        return
    end

    if main_buf ~= nil then return end

    ns = vim.api.nvim_create_namespace("")
    M.parse()
    main_buf = vim.api.nvim_create_buf(false, true)
    jl.setup({ position = config.jumplist_position })

    vim.api.nvim_buf_set_name(main_buf, "CSV")
    vim.api.nvim_set_option_value("modifiable", false, { buf = main_buf })

    vim.api.nvim_win_set_hl_ns(0, ns)
    vim.api.nvim_win_set_buf(0, main_buf)

    vim.api.nvim_buf_set_keymap(jl.get_buffer(), "n", "<leader>j", '', { callback=jl.toggle })
    vim.api.nvim_buf_set_keymap(main_buf, "n", "<leader>j", '', { callback=jl.open })
    vim.api.nvim_buf_set_keymap(jl.get_buffer(), "n", "<CR>", '', {
        noremap=true,
        callback=M.jumplist_go
    })

    entries = create_data_objs(csv_content, header)

    draw_data(header, entries)
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
        entries = {}
        hidden_entries = {}
        hidden_columns = {}
        csv_content = nil
        og_buf = nil
        main_buf = nil
    end
end

function M.parse()
    og_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_buf_get_lines(og_buf, 0, -1, true)

    header = util.split_string(buf[1], ";")

    for i, field in ipairs(header) do
        index[field] = i
    end

    table.remove(buf, 1)

    csv_content = buf

    create_hl_groups(config.colors)

    vim.api.nvim_set_hl_ns(ns)
end

return M
