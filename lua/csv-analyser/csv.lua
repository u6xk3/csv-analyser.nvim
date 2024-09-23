local color = require("csv-analyser.color")
local el = require("csv-analyser.entry-list")
local filter = require("csv-analyser.filter")
local hl = require("csv-analyser.highlight")
local util = require("csv-analyser.util")

local M = {}

local entries = {}
local entry_is_hidden = {}
local hl_group_by_entry = {}
local hidden_columns = {}
local listeners = {}
local config
local column_index_by_name = {}

local listener_topics = {
    "columns_hidden",
    "entries_hidden",
    "highlights"
}

local function notify_listeners(topic, change)
    for _, listener in ipairs(listeners) do
        if util.array_contains(listener.topics, topic) ~= false then
            listener.callback(topic, change)
        end
    end
end

function M.setup(conf)
    config = conf

    for i, col in ipairs(config.header) do
        column_index_by_name[col] = i
    end
end

function M.add_csv_change_listener(callback, topics)
    table.insert(listeners, {
        callback=callback,
        topics = topics
    })
end

function M.create_entry(line, line_nr, fields)
    local entry = {
        line = line,
        hidden = false,
        fields = fields,
        index = line_nr,
        highlight = {
            group = nil,
            ids = {}
        }
    }

    table.insert(entries, entry)
end

function M.create_line(fields, columns, spacing)
    if spacing == nil then spacing = config.spacing end

    local line = ""
    for i, field in ipairs(fields) do
        for _, col in ipairs(columns) do
            if i == column_index_by_name[col] then
                if line == "" then line = field
                else line = line .. spacing .. field end
            end
        end
    end
    return line
end

function M.create_buffer_content(entry_list, columns, spacing)
    if spacing == nil then spacing = config.spacing end

    local content = {}
    for _, entry in ipairs(entry_list) do
        table.insert(content, M.create_line(entry.fields, columns, spacing))
    end
    return content
end

function M.show_columns(columns)
    local valid_cols = {}
    for _, col in ipairs(columns) do
        if column_index_by_name[col] == nil then
            print("Column " .. col .. " does not exist")
        elseif util.array_contains(hidden_columns, col) == false then
            print("Column " .. col .. " not hidden")
        else
            table.insert(valid_cols, col)
            util.array_remove_by_val(hidden_columns, col)
        end
    end

    if #valid_cols > 0 then
        print("Showing Columns " .. table.concat(valid_cols, ", "))
        notify_listeners("columns_hidden", { columns = valid_cols, hidden = false })
    end
end

function M.hide_columns(columns)
    local valid_cols = {}
    for _, col in ipairs(columns) do
        if column_index_by_name[col] == nil then
            print("Column " .. col .. " does not exist")
        elseif util.array_contains(hidden_columns, col) ~= false then
            print("Column " .. col .. " already hidden")
        else
            table.insert(valid_cols, col)
            table.insert(hidden_columns, col)
        end
    end

    if #valid_cols > 0 then
        print("Hiding Columns " .. table.concat(valid_cols, ", "))
        notify_listeners("columns_hidden", { columns = valid_cols, hidden = true })
    end
end

function M.hide_entries_by_filter(filter)
    local valid_entries = {}
    for _, entry in ipairs(entries) do
        if filter.evaluate(entry) and entry_is_hidden[entry] == nil then
            table.insert(valid_entries, entry)
            entry_is_hidden[entry] = true
        end
    end

    print("Hiding " .. #valid_entries .. " Lines")
    if #valid_entries > 0 then
        el.sort(valid_entries)
        notify_listeners("entries_hidden", { entries = valid_entries, hidden = true })
    end
end

function M.show_entries_by_filter(filter)
    local valid_entries = {}
    for entry, _ in pairs(entry_is_hidden) do
        if filter.evaluate(entry) then
            table.insert(valid_entries, entry)
            entry_is_hidden[entry] = nil
        end
    end

    print("Showing " .. #valid_entries .. " Lines")
    if #valid_entries > 0 then
        el.sort(valid_entries)
        notify_listeners("entries_hidden", { entries = valid_entries, hidden = false })
    end
end

function M.add_highlight_by_filter(condition, hl_group)
    local valid_entries = {}
    for _, entry in ipairs(entries) do
        if hl_group_by_entry[entry] == nil and condition.evaluate(entry) then
            table.insert(valid_entries, entry)
            hl_group_by_entry[entry] = hl_group
        end
    end

    notify_listeners("highlights", {
        entries = valid_entries,
        hl_group = hl_group
    })

    print(#valid_entries .. " Lines Colored")
end

function M.remove_highlight_by_filter(condition)
    local valid_entries = {}
    for _, entry in ipairs(entries) do
        if hl_group_by_entry[entry] ~= nil and condition.evaluate(entry) then
            table.insert(valid_entries, entry)
            hl_group_by_entry[entry] = nil
        end
    end

    notify_listeners("highlights", {
        entries = valid_entries,
        hl_group = nil
    })

    print(#valid_entries .. " Lines Cleared")
end

function M.entry_is_hidden(entry)
    return entry_is_hidden[entry]
end

function M.entry_get_hl_group(entry)
    return hl_group_by_entry[entry]
end

function M.fix_line_nrs()
    local last_nr_by_buffer = {}
    for _, obj in ipairs(entries) do
        if not obj.hidden then
            for buf, _ in pairs(obj.locations) do
                if last_nr_by_buffer[buf] == nil then last_nr_by_buffer[buf] = 0 end
                obj.locations[buf] = last_nr_by_buffer[buf] + 1
                last_nr_by_buffer[buf] = last_nr_by_buffer[buf] + 1
            end
        end
    end
end

function M.buf_fix_line_nrs(buf, data)
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

function M.get_spacing()
    return config.spacing
end

function M.get_entries()
    return entries
end

return M
