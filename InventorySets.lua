--[[
    TODO
Cleanup OnInitialize
Figure out how to respond to changes in a dropdown's selected value


Filters:
    [ ] Show Only Missing Items
        Use ScrollTable:SetFilter

]] --
-- Interface\Buttons\UI-CheckBox-Check
-- Interface\Buttons\UI-GroupLoot-Pass-Up
local LOGO_PATH = 'Interface\\AddOns\\InventorySets\\Artwork\\Logo'
InventorySets = LibStub('AceAddon-3.0'):NewAddon('InventorySets', 'AceConsole-3.0', 'AceEvent-3.0')
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

local itemCols = {
    {name = 'Icon', width = 60, align = 'CENTER', index = 'icon', format = 'icon', sortable = false},
    {
        name = 'Item',
        width = 250,
        align = 'LEFT',
        index = 'name',
        format = 'string',
        color = function(table, value, rowData, columnData)
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
        name = 'Min', width = 60, align = 'CENTER', index = 'itemMinimum', format = 'number',
        format = function(value, rowData, columnData)
            if value == nil then
                return '-'
            end

            return value
        end,
        color = function(table, value, rowData, columnData)
            -- Color this cell red if we have less than the minimum amount of an item
            if rowData.itemMinimum ~= nil and rowData.itemCount < rowData.itemMinimum then
                return {r = 1, g = 0, b = 0, a = 1}
            end
        end,
        events = {
            OnClick = function(tbl, cellFrame, rowFrame, rowData, columnData, rowIndex, button)
                -- Create an edit box for this cell if it doesn't exist
                if cellFrame.eBox == nil then
                    local eBox = StdUi:SimpleEditBox(cellFrame, cellFrame:GetWidth(), cellFrame:GetHeight())
                    StdUi:GlueTop(eBox, cellFrame, 0, 0)
                    eBox:SetFocus()

                    eBox:SetScript('OnEnterPressed', function(widget)
                        rowData['itemMinimum'] = tonumber(widget:GetText())

                        widget:ClearFocus()
                        widget:Hide()
                        tbl:SetData(self.db.char.sets[self.db.char.currentSet])
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
        name = 'X',
        width = 30,
        align = 'CENTER',
        index = 'removeItem',
        format = 'icon',
        sortable = false,
        events = {
            OnClick = function(tbl, cellFrame, rowFrame, rowData, columnData, rowIndex, button)
                if button == 'LeftButton' then
                    self:RemoveItemFromSet(rowData['itemId'])
                    tbl:SetData(self.db.char.sets[self.db.char.currentSet])
                end

                return true
            end
        }
    }
}


function table.pack(...)
    return { n = select("#", ...); ... }
end

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
end

function InventorySets:DeleteSet(setName)
    local setNameExists = self:SetExists(setName)

    if not setNameExists then
        return false
    end

    self.db.char.sets[setName] = nil
    self:ClearSetTable()

    local setOptions = self:GetSetDropdownOptions()
    self.dropdownMenu:SetOptions(setOptions)
end

function InventorySets:SetExists(setName)
    local setNames = self:GetSetNames()
    local setNameExists = false

    for i,v in ipairs(setNames) do
        if v == setName then
            setNameExists = true
        end
    end

    return setNameExists
end

function InventorySets:LoadSet(setName)
    local setNameExists = self:SetExists(setName)

    if not setNameExists then
        return false
    end

    self.db.char.currentSet = setName
    self.st:SetData(self.db.char.sets[self.db.char.currentSet])
    self.st:Update()
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

    -- Dropdown Menu containing existing set names
    local dropdownMenu = self:GetSetNameDropdown(window)
    self.dropdownMenu = dropdownMenu
    dropdownMenu:SetPlaceholder('-- Please Select --');
    StdUi:GlueTop(dropdownMenu, window, 0, -50, 'CENTER');

    dropdownMenu.OnValueChanged = function(widget, value)
        self:LoadSet(value)
    end

    -- Edit box used to name new sets
    local newSetEditBox = StdUi:SimpleEditBox(window, 100, 24)
    self.newSetEditBox = newSetEditBox
    StdUi:GlueBelow(newSetEditBox, dropdownMenu, -110, -10)

    newSetEditBox:SetScript('OnEnterPressed', function(widget)
        self:CreateNewSet(self.newSetEditBox:GetText())
    end)

    -- Button used to create new sets
    local newSetBtn = StdUi:Button(window, 100, 24, 'New Set')
    StdUi:GlueAfter(newSetBtn, newSetEditBox, 20, 0)

    newSetBtn:SetScript('OnClick', function(widget)
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

    local st = InventorySets:getScrollingTable(window, itemCols)
    self.st = st
    st:EnableSelection(false)
    st:SetData(data)

    local deleteSetBtn = StdUi:Button(window, 100, 24, 'Delete Set')
    StdUi:GlueAfter(deleteSetBtn, newSetBtn, 20, 0)

    deleteSetBtn:SetScript('OnClick', function()
        self:DeleteSet(self.db.char.currentSet)
    end)

    local addItemPanel = self:GetAddItemPanel(window)
    StdUi:GlueBelow(addItemPanel, st, 165, -10)

    local onlyMissingCheckbox = self:GetFilterCheckbox(window)
    StdUi:GlueBelow(onlyMissingCheckbox, st, -150, -5)
end

function InventorySets:GetFilterCheckbox(uiParent)
    local onlyMissingCheckbox = StdUi:Checkbox(uiParent, 'Only show missing items')

    onlyMissingCheckbox.OnValueChanged = function(widget, state, value)
        if state then
            self.st.Filter = function(tbl, rowData)
                if rowData.itemCount == 0 then
                    return true
                end

                if rowData.itemMinimum ~= nil and rowData.itemCount < rowData.itemMinimum then
                    return true
                end

                return false
            end
        else
            self.st.Filter = function(tbl, rowData)
                return true
            end
        end

        self.st:SetData(self.db.char.sets[self.db.char.currentSet])
        self.st:Update()
    end

    return onlyMissingCheckbox
end

function InventorySets:AddItemToSet(itemId)
    local itemExists = false
    local itemData = InventorySets:getItemDataFromId(itemId)

    for k,v in pairs(self.db.char.sets[self.db.char.currentSet]) do
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

function InventorySets:RemoveItemFromSet(itemId)
    for i,v in ipairs(self.db.char.sets[self.db.char.currentSet]) do
        if v['itemId'] == itemId then
            table.remove(self.db.char.sets[self.db.char.currentSet], i)
        end
    end
end

function InventorySets:GetAddItemPanel(uiParent)
    local addItemPanel = StdUi:PanelWithTitle(uiParent, 150, 100, 'Add Item')
    local dropItemPanel = StdUi:Panel(uiParent, 50, 50)

    StdUi:GlueTop(dropItemPanel, addItemPanel, 0, -30, true)

    -- @Cleanup: This should be combined into a single function
    dropItemPanel:SetScript('OnReceiveDrag', function()
        local t, id, info = GetCursorInfo()

        if t == 'item' then self:AddItemToSet(id) end
        ClearCursor()
    end)

    dropItemPanel:SetScript('OnMouseUp', function()
        local t, id, info = GetCursorInfo()

        if t == 'item' then self:AddItemToSet(id) end
        ClearCursor()
    end)

    return addItemPanel
end

function InventorySets:GetSetNames()
    local names = {}

    for k, _ in pairs(self.db.char.sets) do tinsert(names, k) end

    return names
end

function InventorySets:GetSetDropdownOptions()
    local setOptions = {}
    local setNames = self:GetSetNames()
    for i, v in ipairs(setNames) do
        tinsert(setOptions, {text = v, value = v})
    end

    return setOptions
end

function InventorySets:GetSetNameDropdown(parent)
    local setOptions = self:GetSetDropdownOptions()
    local initialValue = nil

    -- If we've got a set selected on initialization then
    -- reflect that as the initial value of the drop down
    if self.db.char.currentSet ~= nil then
        initialValue = self.db.char.currentSet
    end

    local dropdownMenu = StdUi:Dropdown(parent, 200, 20, setOptions, initialValue)

    return dropdownMenu
end

function InventorySets:ToggleMainWindow()
    if self.window:IsVisible() then
        self.db.char.visible = false
        self.window:Hide()
    else
        self.db.char.visible = true
        self.window:Show()
    end
end
InventorySets:RegisterChatCommand("inventorysets", "ToggleMainWindow")
InventorySets:RegisterChatCommand("is", "ToggleMainWindow")