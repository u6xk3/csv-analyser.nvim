local util = require("csv-analyser.util")

local M = {}

function M.contains(entry_list, entry)
    for i, el_entry in ipairs(entry_list) do
        if el_entry.index == entry.index then return i end
    end
    return false
end

function M.sort(entry_list)
    table.sort(entry_list, function (a, b)
        return a.index < b.index
    end)
end

function M.insert(entry_list, entry)
    if M.contains(entry_list, entry) ~= false then return end

    if #entry_list == 0 then
        table.insert(entry_list, 1, entry)
        return 1
    end

    if entry.index < entry_list[1].index then
        table.insert(entry_list, 1, entry)
        return 1
    elseif entry.index > entry_list[#entry_list].index then
        table.insert(entry_list, #entry_list + 1, entry)
        return #entry_list + 1
    end

    for i = 1, #entry_list do
        if entry_list[i].index > entry.index then
            table.insert(entry_list, i , entry)
            return i
        end
    end
end

function M.remove(entry_list, entry)
    local index
    for i, el_entry in ipairs(entry_list) do
        if el_entry.index == entry.index then
            entry_list[i] = nil
            index = i
        end
    end
    util.array_reindex(entry_list)
    return index
end

function M.remove_no_reindex(entry_list, entry)
    local index
    for i, el_entry in pairs(entry_list) do
        if el_entry.index == entry.index then
            entry_list[i] = nil
            index = i
        end
    end
    return index
end

return M
