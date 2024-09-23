local util = require("csv-analyser.util")

local M = {}

local ns
local hl_groups
local highlights = {}

local highlight = {}
function highlight.create(id, hl_group)
    return { id = id, hl_group = hl_group }
end

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

function M.win_reapply(win)
    if highlights[win] == nil then return end
    for entry, hl in pairs(highlights[win]) do
        M.add(win, entry, hl.hl_group)
    end
end

function M.add(win, entry, hl_group)
    if highlights[win] == nil then highlights[win] = {} end

    if highlights[win][entry] ~= nil then
        vim.api.nvim_buf_del_extmark(win.get_buffer(), ns, highlights[win][entry].id)
    end

    local line = win.get_line_by_entry(entry)
    if line == false then return end

    local id = vim.api.nvim_buf_set_extmark(win.get_buffer(), ns, line, 0, {
        end_col = util.buf_get_line_length(win.get_buffer(), line),
        hl_group = hl_group
    })

    highlights[win][entry] = highlight.create(id, hl_group)
end

function M.remove(win, entry)
    if highlights[win] == nil then return end

    if highlights[win][entry] ~= nil then
        vim.api.nvim_buf_del_extmark(win.get_buffer(), ns, highlights[win][entry].id)
        highlights[win][entry] = nil
    end
end

function M.check_hl_group(group)
    local checked = nil
    for key, _ in pairs(hl_groups) do
        if key == group then checked = group end
    end
    return checked
end

return M
