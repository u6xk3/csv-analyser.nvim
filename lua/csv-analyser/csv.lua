local util = require("csv-analyser.util")

local M = {}

local entries = {}

function M.setup()
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

function M.create_line(fields, spacing, hidden_columns)
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

function M.get_entries()
    return entries
end

return M
