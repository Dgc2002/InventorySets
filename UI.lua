local _, addonTable = ...
InventorySets = addonTable

local StdUi = LibStub('StdUi');

---@return Frame
function InventorySets:getMainWindow()
    local window = StdUi:Window(UIParent, 500, 600, 'Inventory Sets');
    window:SetPoint('CENTER');

    return window
end

---@param window Frame
---@param itemCols table<number, table>
---@return Frame
function InventorySets:getScrollingTable(window, itemCols)
    local st = StdUi:ScrollTable(window, itemCols, 14, 24);
    st:EnableSelection(true);

    StdUi:GlueTop(st, window, 0, -134);

    return st
end
