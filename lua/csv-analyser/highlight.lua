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

function M.buf_reapply(buf)
    if highlights[buf] == nil then return end
    for line, hl in pairs(highlights[buf]) do
        M.add(buf, line, hl.hl_group)
    end
end

function M.add(buf, line, hl_group)
    if highlights[buf] == nil then highlights[buf] = {} end

    if highlights[buf][line] ~= nil then
        vim.api.nvim_buf_del_extmark(buf, ns, highlights[buf][line].id)
    end

    local id = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
        end_col = util.buf_get_line_length(buf, line),
        hl_group = hl_group
    })

    highlights[buf][line] = highlight.create(id, hl_group)
end

function M.remove(buf, line)
    if highlights[buf] == nil then return end

    if highlights[buf][line] ~= nil then
        vim.api.nvim_buf_del_extmark(buf, ns, highlights[buf][line].id)
        highlights[buf][line] = nil
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
