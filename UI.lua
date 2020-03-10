local _, addonTable = ...
InventorySets = addonTable

local StdUi = LibStub('StdUi');

---@return StdUi:Window
function InventorySets:getMainWindow()
    local window = StdUi:Window(UIParent, 500, 600, 'Inventory Sets');
    window:SetPoint('CENTER');

    return window
end

---@param window Frame
---@param itemCols table<number, table>
---@return StdUi:ScrollTable
function InventorySets:getScrollingTable(window, itemCols)
    local st = StdUi:ScrollTable(window, itemCols, 14, 24);
    st:EnableSelection(true);

    StdUi:GlueTop(st, window, 0, -134);

    return st
end

---@param uiParent Frame
---@return Frame
function InventorySets:GetFilterCheckbox(uiParent)
    local onlyMissingCheckbox = StdUi:Checkbox(uiParent, 'Only show missing items')

    onlyMissingCheckbox.OnValueChanged = function(_, state, _)
        if state then
            self.st.Filter = function(_, rowData)
                if rowData.itemCount == 0 then
                    return true
                end

                if rowData.itemMinimum ~= nil and rowData.itemCount < rowData.itemMinimum then
                    return true
                end

                return false
            end
        else
            self.st.Filter = function(_, _)
                return true
            end
        end

        self.st:SetData(self.db.char.sets[self.db.char.currentSet])
        self.st:Update()
    end

    return onlyMissingCheckbox
end

---@param uiParent Frame
---@return Frame
function InventorySets:GetAddItemPanel(uiParent)
    local addItemPanel = StdUi:PanelWithTitle(uiParent, 150, 100, 'Add Item')
    local dropItemPanel = StdUi:Panel(uiParent, 50, 50)

    StdUi:GlueTop(dropItemPanel, addItemPanel, 0, -30, true)

    -- @Cleanup: This should be combined into a single function
    dropItemPanel:SetScript('OnReceiveDrag', function()
        local t, id, _ = GetCursorInfo()

        if t == 'item' then self:AddItemToSet(id) end
        ClearCursor()
    end)

    dropItemPanel:SetScript('OnMouseUp', function()
        local t, id, _ = GetCursorInfo()

        if t == 'item' then self:AddItemToSet(id) end
        ClearCursor()
    end)

    return addItemPanel
end

---@param uiParent Frame
---@return Frame
function InventorySets:GetSetNameDropdown(uiParent)
    local setOptions = self:GetSetDropdownOptions()
    local initialValue

    -- If we've got a set selected on initialization then
    -- reflect that as the initial value of the drop down
    if self.db.char.currentSet ~= nil then
        initialValue = self.db.char.currentSet
    end

    local dropdownMenu = StdUi:Dropdown(uiParent, 200, 20, setOptions, initialValue)

    return dropdownMenu
end