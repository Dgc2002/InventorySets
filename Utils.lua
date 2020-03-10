local _, addonTable = ...
InventorySets = addonTable


---@param message string
function InventorySets:say(message)
    DEFAULT_CHAT_FRAME:AddMessage('[InventorySets] ' .. message)
end

---@param itemId number
---@return boolean
function InventorySets:itemIsInInventory(itemId)
    return GetItemCount(itemId) >= 1
end

---@param itemId number
---@return table<string, any>
function InventorySets:getItemDataFromId(itemId)
    local itemCount = GetItemCount(itemId)
    local inInventory = itemCount > 0
    local itemName, _, _, _, _, _, _, _, _, itemIcon, _, _, _, _, _, _, _ = GetItemInfo(itemId)

    return {name = itemName, itemId = itemId, icon = itemIcon, isInInventory = inInventory, itemCount = itemCount, removeItem = [[Interface\BUTTONS\UI-Panel-MinimizeButton-Up]]}
end

---@param itemIds table<number>
---@return table<number, table<string, any>>
function InventorySets:getItemDataFromIds(itemIds)
    local itemData = {}
    for _, itemId in pairs(itemIds) do
        tinsert(itemData, self:getItemDataFromId(itemId))
    end

    return itemData
end


---@param tbl QuestTag
---@param indent number
---@return string
function InventorySets:tprint(tbl, indent)
    if not indent then indent = 0 end
    local toprint = string.rep(" ", indent) .. "{\r\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        if (type(k) == "number") then
            toprint = toprint .. "[" .. k .. "] = "
        elseif (type(k) == "string") then
            toprint = toprint .. k .. "= "
        end
        if (type(v) == "number") then
            toprint = toprint .. v .. ",\r\n"
        elseif (type(v) == "string") then
            toprint = toprint .. "\"" .. v .. "\",\r\n"
        elseif (type(v) == "table") then
            toprint = toprint .. InventorySets:tprint(v, indent + 2) .. ",\r\n"
        else
            toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
        end
    end
    toprint = toprint .. string.rep(" ", indent - 2) .. "}"
    return toprint
end