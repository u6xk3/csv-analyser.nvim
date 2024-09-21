local util = require("csv-analyser.util")

local M = {}

local ns
local hl_groups
local entries = {}

local function create_hl_groups()
    for key, group in pairs(hl_groups) do
        vim.api.nvim_set_hl(ns, key, {
            fg = group.fg,
            bg = group.bg
        })
    end
end

function M.get_namespace()
    return ns
end

function M.setup(colors)
    ns = vim.api.nvim_create_namespace("")
    vim.api.nvim_set_hl_ns(ns)
    hl_groups = colors
    create_hl_groups()
end

function M.reapply()
    for _, entry in ipairs(entries) do
        M.add(entry, entry.highlight.group)
    end
end

function M.buf_reapply(buf)
    for _, entry in ipairs(entries) do
        M.buf_add(buf, entry, entry.highlight.group)
    end
end

function M.add(entry, hl_group)
    for buf, line in pairs(entry.locations) do
        if entry.highlight.ids[buf] ~= nil then
            vim.api.nvim_buf_del_extmark(buf, ns, entry.highlight.ids[buf])
        end
        entry.highlight.ids[buf] = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { end_col = util.buf_get_line_length(buf, line), hl_group = hl_group, strict = true })
    end
    entry.highlight.group = hl_group

    for _, existing in ipairs(entries) do
        if existing.index == entry.index then return end
    end

    table.insert(entries, entry)
end

function M.buf_add(buf, entry, hl_group)
    local line = entry.locations[buf]
    if line == nil then return end

    if entry.highlight.ids[buf] ~= nil then
        vim.api.nvim_buf_del_extmark(buf, ns, entry.highlight.ids[buf])
    end
    entry.highlight.ids[buf] = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { end_col = util.buf_get_line_length(buf, line), hl_group = hl_group, strict = true })
    entry.highlight.group = hl_group

    for _, existing in ipairs(entries) do
        if existing.index == entry.index then return end
    end

    table.insert(entries, entry)
end

function M.remove_by_filter(filter)
    local nr = 0
    for i, entry in ipairs(entries) do
        if filter.evaluate(entry) then
            for buf, id in pairs(entry.highlight.ids) do
                vim.api.nvim_buf_del_extmark(buf, ns, id)
                entry.highlight.ids[buf] = nil
                nr = nr + 1
            end
            entry.highlight.group = nil
            entries[i] = nil
        end
    end
    util.array_reindex(entries)

    return nr
end

function M.remove(entry)
    for buf, id in pairs(entry.highlight.ids) do
        vim.api.nvim_buf_del_extmark(buf, ns, id)
        entry.highlight.ids[buf] = nil
    end
    entry.highlight.group = nil

    for i = 1, #entries do
        if entries[i].index == entry.index then
            entries[i] = nil
        end
    end

    util.array_reindex(entries)
end

function M.check_hl_group(group)
    local checked = nil
    for key, _ in pairs(hl_groups) do
        if key == group then checked = group end
    end
    return checked
end

return M
