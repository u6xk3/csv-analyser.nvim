local M = {}

function M.buf_temp_modifiable(buf, func)
    local result
    if vim.api.nvim_get_option_value("modifiable", { buf = buf }) == false then
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        result = func()
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    else
        result = func()
    end
    return result
end

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

function M.table_shallow_copy(tbl)
    local tbl_cp = {}
    for key, val in pairs(tbl) do
        tbl_cp[key] = val
    end
    return tbl_cp
end

function M.table_contains(tbl, val)
    for key, tbl_val in pairs(tbl) do
        if tbl_val == val then return key end
    end

    return false
end

function M.array_extend(tbl, tbl2)
    for _, val in ipairs(tbl2) do
        tbl[#tbl+1] = val
    end
end

function M.array_contains(tbl, val)
    for key, tbl_val in ipairs(tbl) do
        if tbl_val == val then return key end
    end

    return false
end

function M.array_contains_key(tbl, key)
    for tbl_key, _ in pairs(tbl) do
        if tbl_key == key then return true end
    end

    return false
end

function M.array_remove_by_val(tbl, val)
    for i, tbl_val in ipairs(tbl) do
        if tbl_val == val then tbl[i] = nil end
    end
    M.array_reindex(tbl)
end

function M.array_reindex(tbl)
    local adjusted_index = 1
    local initial_length = 0
    for i, _ in pairs(tbl) do
        if type(i) == "number" then
            if i > initial_length then
                initial_length = i
            end
        end
    end

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
