local M = {}

function M.split_string(str, delim)
    local fields = {}

    local match = str:find(delim)
    local previous = 1

    while match ~= nil do
        table.insert(fields, str:sub(previous, match - 1))
        previous = match + 1
        match = str:find(delim, match + 1)
    end

    if previous <= #str then
        table.insert(fields, str:sub(previous, #str))
    end

    return fields
end

function M.extend_table(tbl1, tbl2)
    for key, val in pairs(tbl2) do
        tbl1[key] = val
    end
end

function M.array_contains(tbl, val)
    for key, tbl_val in ipairs(tbl) do
        if tbl_val == val then return key end
    end

    return false
end

function M.array_reindex(tbl)
    local adjusted_index = 1
    local initial_length = #tbl
    for index = 1, initial_length do
        if tbl[index] ~= nil then
            tbl[adjusted_index] = tbl[index]
            adjusted_index = adjusted_index + 1
        end
    end

    for index = adjusted_index, initial_length do
        tbl[index] = nil
    end

    return tbl
end

function M.compare_shallow_table(tbl1, tbl2)
    for key, val in pairs(tbl1) do
        if tbl2[key] ~= val then return false end
    end

    for key, val in pairs(tbl2) do
        if tbl1[key] ~= val then return false end
    end

    return true
end

function M.for_each_char(str, func)
    local index = 1
    local it = string.gmatch(str, ".")
    local ch = it()
    while ch ~= nil do
        func(ch, index)
        ch = it()
        index = index + 1
    end
end

function M.buf_get_line_length(buf, line_nr)
    local line = unpack(vim.api.nvim_buf_get_text(buf, line_nr, 0, line_nr, -1, {}))
    local len = 0
    M.for_each_char(line, function ()
        len = len + 1
    end)
    return len
end

return M
