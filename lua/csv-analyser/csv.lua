local util = require("csv-analyser.util")
local el = require("csv-analyser.entry-list")

local M = {}

local entries = {}
local hidden_entries = {}
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

function M.create_entry(buf, line, line_nr, fields)
    local locations = {}
    locations[buf] = line_nr

    local entry = {
        locations = locations,
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
        if filter.evaluate(entry) and el.contains(hidden_entries, entry) == false then
            table.insert(valid_entries, entry)
            table.insert(hidden_entries, entry)
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
    for _, entry in ipairs(hidden_entries) do
        if filter.evaluate(entry) then
            table.insert(valid_entries, entry)
            el.remove_no_reindex(hidden_entries, entry)
        end
    end
    util.array_reindex(hidden_entries)

    print("Showing " .. #valid_entries .. " Lines")
    if #valid_entries > 0 then
        el.sort(valid_entries)
        notify_listeners("entries_hidden", { entries = valid_entries, hidden = false })
    end
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