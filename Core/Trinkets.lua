local _, ns = ...

--Trinkets in a plan: by item name, as 'Trinket 1' or 'Trinket 2' for whatever is in the top or bottom trinket slot at the
--pull, or as 'item:<id>'. A trinket gets a countdown and a reminder to use it, like a spell

local TRINKET_SLOTS = { 13, 14 }

local function ItemInfo(itemId, slot)
    local _, spellId = C_Item.GetItemSpell(itemId)
    return {
        itemId = itemId,
        slot = slot,
        name = C_Item.GetItemNameByID(itemId),
        icon = (slot and GetInventoryItemTexture("player", slot)) or C_Item.GetItemIconByID(itemId),
        spellId = spellId
    }
end

--The equipped trinkets, top slot first: { index, slot, itemId, name, icon, spellId of the use effect or nil }
function ns:GetEquippedTrinkets()
    local trinkets = {}
    for index, slot in ipairs(TRINKET_SLOTS) do
        local itemId = GetInventoryItemID("player", slot)
        if itemId then
            local trinket = ItemInfo(itemId, slot)
            trinket.index = index
            table.insert(trinkets, trinket)
        end
    end
    return trinkets
end

--The trinket a plan entry means, or nil when it isn't a trinket that is equipped (or an item id)
function ns:FindTrinket(entry)
    local lower = entry:lower():match('^%s*(.-)%s*$')
    local slotIndex = tonumber(lower:match('^trinket%s*([12])$'))
    local itemId = tonumber(lower:match('^item:(%d+)$'))
    for _, trinket in ipairs(ns:GetEquippedTrinkets()) do
        if trinket.index == slotIndex or trinket.itemId == itemId or (trinket.name and trinket.name:lower() == lower) then
            return trinket
        end
    end
    if itemId then
        local trinket = ItemInfo(itemId)
        if trinket.name or trinket.icon then
            return trinket
        end
    end
end

--The entry of an equipped trinket whose use effect is this spell, for MRT notes that name trinkets by their spell
function ns:TrinketEntryForSpell(spellId)
    for _, trinket in ipairs(ns:GetEquippedTrinkets()) do
        if trinket.spellId == spellId and trinket.name then
            return trinket.name
        end
    end
end
