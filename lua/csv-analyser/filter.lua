local util = require("csv-analyser.util")

local M = {}

local config = {}

function M.setup(conf)
    config = conf
end

local notequal_obj = {}
function notequal_obj.create(prop, val)
    return {
        evaluate = function (data)
            if data.fields[config.index[prop]] == nil then return false end
            return data.fields[config.index[prop]] ~= val
        end
    }
end

local equal_obj = {}
function equal_obj.create(prop, val)
    return {
        evaluate = function (data)
            if data.fields[config.index[prop]] == nil then return false end
            return data.fields[config.index[prop]] == val
        end
    }
end

local matcher_obj = {}
function matcher_obj.create(prop, val)
    return {
        evaluate = function (data)
            if data.fields[config.index[prop]] == nil then return false end
            return string.find(data.fields[config.index[prop]], val) ~= nil
        end
    }
end

local or_obj = {}
function or_obj.create(equal_objs)
    return {
        evaluate = function (data)
            for _, obj in ipairs(equal_objs) do
                if obj.evaluate(data) == false then return false end
            end
            return true
        end
    }
end

local final_obj = {}
function final_obj.create(or_objs)
    return {
        evaluate = function(data)
            for _, obj in ipairs(or_objs) do
                if obj.evaluate(data) then return true end
            end
            return false
        end
    }
end

function M.parse_args(fields)
    local equal = {}

    if #fields == 1 then
        for key, filter in pairs(config.filters) do
            if key == fields[1] then fields = util.split_string(filter, " ") end
        end
    end

    for i = 1, #fields do
        if fields[i] == "==" then
            if fields[i - 1] == nil or fields[i + 1] == nil then
                print("invalid syntax")
                return
            end
            table.insert(equal, equal_obj.create(fields[i - 1], fields[i + 1]))

        elseif fields[i] == "!=" then
            if fields[i - 1] == nil or fields[i + 1] == nil then
                print("invalid syntax")
                return
            end

            table.insert(equal, notequal_obj.create(fields[i - 1], fields[i + 1]))

        elseif fields[i] == "*=" then
            if fields[i - 1] == nil or fields[i + 1] == nil then
                print("invalid syntax")
                return
            end
            table.insert(equal, matcher_obj.create(fields[i - 1], fields[i + 1]))

        elseif fields[i] == "or" then
            table.insert(equal, fields[i])
        end
    end

    local or_objs = {}
    local last = 1
    for i = 1, #equal do
        if equal[i] == "or" then
            table.insert(or_objs, or_obj.create({ unpack(equal, last, i - 1) }))
            last = i + 1

        else
            if i == #equal then
                table.insert(or_objs, or_obj.create({ unpack(equal, last, i) }))
            end
        end
    end

    return final_obj.create(or_objs)
end

return M
