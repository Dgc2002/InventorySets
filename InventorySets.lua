--[[
    TODO
        Cleanup OnInitialize
]] --

local addonName, addon = ...

local LOGO_PATH = 'Interface\\AddOns\\InventorySets\\Artwork\\Logo'
InventorySets = LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceConsole-3.0', 'AceEvent-3.0')

---@type StdUi
local StdUi = LibStub('StdUi');
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local ldbIcon = LibStub("LibDBIcon-1.0")

InventorySets.DEFAULT_SETTINGS = {
    char = {
        sets = {},
        currentSet = nil,
        minimap = {
            hide = false
        }
    }
}

InventorySets.ITEMCOLS = {
    {name = 'Icon', width = 60, align = 'CENTER', index = 'icon', format = 'icon', sortable = false},
    {
        name = 'Item', width = 250, align = 'LEFT', index = 'name', format = 'string',
        color = function(_, _, rowData, _)
            -- @Cleanup: This is pretty sloppy but works
            local rowColor = {r = 1, g = 0, b = 0, a = 1}
            if rowData.isInInventory then
                -- Color the item name RED if it is not found in inventory
                -- Color the item name YELLOW if there are more than 0 but fewer than itemMinimum
                if rowData.itemMinimum ~= nil and rowData.itemCount < rowData.itemMinimum then
                    rowColor = {r = 1, g = 1, b = 0, a = 1}
                else
                    rowColor = {r = 0, g = 1, b = 0, a = 1}
                end
            end

            return rowColor
        end
    },
    {name = '#', width = 60, align = 'CENTER', index = 'itemCount', format = 'number'},
    {
        name = 'Min', width = 60, align = 'CENTER', index = 'itemMinimum', sortable = false,
        format = function(value, _, _)
            if value == nil then
                return '-'
            end

            return value
        end,
        color = function(_, _, rowData, _)
            -- Color this cell red if we have less than the minimum amount of an item
            if rowData.itemMinimum ~= nil and rowData.itemCount < rowData.itemMinimum then
                return {r = 1, g = 0, b = 0, a = 1}
            end
        end,
        events = {
            OnClick = function(tbl, cellFrame, _, rowData, _, _, _)
                -- Create an edit box for this cell if it doesn't exist
                if cellFrame.eBox == nil then
                    local eBox = StdUi:SimpleEditBox(cellFrame, cellFrame:GetWidth(), cellFrame:GetHeight())
                    StdUi:GlueTop(eBox, cellFrame, 0, 0)
                    eBox:SetFocus()

                    eBox:SetScript('OnEnterPressed', function(widget)
                        rowData['itemMinimum'] = tonumber(widget:GetText())

                        widget:ClearFocus()
                        widget:Hide()
                        tbl:SetData(InventorySets.db.char.sets[InventorySets.db.char.currentSet])
                    end)

                    eBox:SetScript('OnEscapePressed', function(widget)
                        widget:ClearFocus()
                        widget:Hide()
                    end)
                end

            end
        }
    },
    {
        name = 'X', width = 30, align = 'CENTER', index = 'removeItem', format = 'icon', sortable = false,
        events = {
            OnClick = function(tbl, _, _, rowData, _, _, button)
                if button == 'LeftButton' then
                    InventorySets:RemoveItemFromSet(rowData['itemId'])
                    tbl:SetData(InventorySets.db.char.sets[InventorySets.db.char.currentSet])
                end

                return true
            end
        }
    }
}

---@param setName string
---@return boolean Whether or not a set with the given name could be created
function InventorySets:CreateNewSet(setName)
    local setNameExists = self:SetExists(setName)

    if setNameExists then
        return false
    end

    self.db.char.sets[setName] = {}
    self.db.char.currentSet = setName

    self.st:SetData({})
    self.st:Update()

    local setOptions = self:GetSetDropdownOptions()
    self.dropdownMenu:SetOptions(setOptions)

    self:LoadSet(setName)
    self.dropdownMenu:SetValue(setName)

    self.newSetEditBox:ClearFocus()
    self.newSetEditBox:SetText('')

    return true
end

---Deletes a set if it exists
---@param setName string
---@return boolean Whether or not a set with the given name could be deleted
function InventorySets:DeleteSet(setName)
    local setNameExists = self:SetExists(setName)

    if not setNameExists then
        return false
    end

    self.db.char.sets[setName] = nil
    self:ClearSetTable()

    local setOptions = self:GetSetDropdownOptions()
    self.dropdownMenu:SetOptions(setOptions)

    return true
end

---@param setName string
---@return boolean Whether or not a set with the given name exists
function InventorySets:SetExists(setName)
    local setNames = self:GetSetNames()
    local setNameExists = false

    for _,v in ipairs(setNames) do
        if v == setName then
            setNameExists = true
        end
    end

    return setNameExists
end

---@param setName string
---@return boolean Whether or not a set with the given name could be loaded
function InventorySets:LoadSet(setName)
    local setNameExists = self:SetExists(setName)

    if not setNameExists then
        return false
    end

    self.db.char.currentSet = setName
    self.st:SetData(self.db.char.sets[self.db.char.currentSet])
    self.st:Update()

    return true
end

function InventorySets:ClearSetTable()
    self.db.char.currentSet = nil
    self.st:SetData({})
    self.dropdownMenu:SetValue(nil)
end

function InventorySets:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New('InventorySetsDB', InventorySets.DEFAULT_SETTINGS)

    -- Minimap Icon
    local dataobj = ldb:NewDataObject("InventorySets", {
        type = "data source",
        text = "InventorySets",
        icon = LOGO_PATH,
        OnClick = function() self:ToggleMainWindow() end
    })
    self.dataobj = dataobj
    ldbIcon:Register("InventorySets", self.dataobj, self.db.char.minimap)

    -- Main Window
    local window = InventorySets:getMainWindow()
    self.window = window
    if self.db.char.visible == false then
        window:Hide()
    end

    window:SetScript('OnHide', function(_)
        self.db.char.visible = false
    end)

    window:SetScript('OnShow', function(_)
        self.db.char.visible = true
    end)

    -- Dropdown Menu containing existing set names
    local dropdownMenu = self:GetSetNameDropdown(window)
    self.dropdownMenu = dropdownMenu
    dropdownMenu:SetPlaceholder('-- Please Select --');
    StdUi:GlueTop(dropdownMenu, window, 0, -50, 'CENTER');

    dropdownMenu.OnValueChanged = function(_, value)
        self:LoadSet(value)
    end

    -- Edit box used to name new sets
    local newSetEditBox = StdUi:SimpleEditBox(window, 100, 24)
    self.newSetEditBox = newSetEditBox
    StdUi:GlueBelow(newSetEditBox, dropdownMenu, -110, -10)

    newSetEditBox:SetScript('OnEnterPressed', function(_)
        self:CreateNewSet(self.newSetEditBox:GetText())
    end)

    -- Button used to create new sets
    local newSetBtn = StdUi:Button(window, 100, 24, 'New Set')
    StdUi:GlueAfter(newSetBtn, newSetEditBox, 20, 0)

    newSetBtn:SetScript('OnClick', function(_)
        self:CreateNewSet(self.newSetEditBox:GetText())
    end)

    -- The 'New Set' button should only be enabled when a valid
    -- set name is in the edit box
    newSetEditBox:SetScript('OnTextChanged', function(widget)
        local setNameExists = self:SetExists(widget:GetText())

        if widget:GetText() ~= '' and not setNameExists then
            newSetBtn:Enable()
        else
            newSetBtn:Disable()
        end
    end)

    local data = {}
    if self.db.char.currentSet ~= nil and self.db.char.sets[self.db.char.currentSet] ~= nil then
        data = self.db.char.sets[self.db.char.currentSet]
    end

    local st = InventorySets:getScrollingTable(window, self.ITEMCOLS)
    self.st = st
    st:EnableSelection(false)
    st:SetData(data)

    -- This should be temporary
    self:UpdateItemCounts()

    local deleteSetBtn = StdUi:Button(window, 100, 24, 'Delete Set')
    StdUi:GlueAfter(deleteSetBtn, newSetBtn, 20, 0)

    deleteSetBtn:SetScript('OnClick', function()
        self:DeleteSet(self.db.char.currentSet)
    end)

    local addItemPanel = self:GetAddItemPanel(window)
    StdUi:GlueBelow(addItemPanel, st, 165, -10)

    local onlyMissingCheckbox = self:GetFilterCheckbox(window)
    StdUi:GlueBelow(onlyMissingCheckbox, st, -150, -5)

    self:RegisterEvent('BAG_UPDATE', function()
        self:UpdateItemCounts()
    end)
end

---@param itemId number
function InventorySets:AddItemToSet(itemId)
    local itemExists = false
    local itemData = InventorySets:getItemDataFromId(itemId)

    for _,v in pairs(self.db.char.sets[self.db.char.currentSet]) do
        if v['itemId'] == itemData['itemId'] then
            itemExists = true
        end
    end

    if itemExists then
        return
    end

    tinsert(self.db.char.sets[self.db.char.currentSet], itemData)

    self.st:SetData(self.db.char.sets[self.db.char.currentSet])
end

---@param itemId number
function InventorySets:RemoveItemFromSet(itemId)
    for i,v in ipairs(self.db.char.sets[self.db.char.currentSet]) do
        if v['itemId'] == itemId then
            table.remove(self.db.char.sets[self.db.char.currentSet], i)
        end
    end
end

function InventorySets:UpdateItemCounts()
    local itemsData = {}
    for i, v in ipairs(self.db.char.sets[self.db.char.currentSet]) do
        local itemData = InventorySets:getItemDataFromId(v['itemId'])
        itemData['itemMinimum'] = v['itemMinimum']
        tinsert(itemsData, itemData)
    end

    self.db.char.sets[self.db.char.currentSet] = itemsData
    self.st:SetData(itemsData)
end


---@return table
function InventorySets:GetSetNames()
    local names = {}

    for k, _ in pairs(self.db.char.sets) do tinsert(names, k) end

    return names
end

---@return table
function InventorySets:GetSetDropdownOptions()
    local setOptions = {}
    local setNames = self:GetSetNames()
    for _, v in ipairs(setNames) do
        tinsert(setOptions, {text = v, value = v})
    end

    return setOptions
end

function InventorySets:ToggleMainWindow()
    if self.window:IsVisible() then
        self.window:Hide()
    else
        self.window:Show()
    end
end
InventorySets:RegisterChatCommand("inventorysets", "ToggleMainWindow")
InventorySets:RegisterChatCommand("is", "ToggleMainWindow")