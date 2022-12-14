DFTDisplay = LibStub("AceAddon-3.0"):NewAddon("DFTDisplay", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
--LoadAddOn("LibCompress")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

local dftdisplay_sync = "DFTDisplaySync"

local GetNumGroupMembers, GetRaidRosterInfo, UnitInRaid, RollOnLoot = GetNumGroupMembers, GetRaidRosterInfo, UnitInRaid, RollOnLoot

DFTDisplay_Priolist = {}
DFTDisplay_Checkboxes = {}

function DFTDisplay:OnInitialize()
    -- Called when the addon is loaded
    self:Print("DFT Display Initialized")
    self:RegisterChatCommand("dftdisplay", "SlashCommand")
    self:RegisterComm(dftdisplay_sync)

end

function DFTDisplay:OnEnable()
    -- Called when the addon is enabled
    self:Print("DFT Display Enabled")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED")
end

function DFTDisplay:START_LOOT_ROLL(_, rollID, rollTime, lootHandle)
    self:Print(rollID, rollTime, lootHandle)
    local itemLink = GetLootRollItemLink(rollID)
    local itemID = getIdFromItemlink(itemLink)

    if DFTDisplay_Priolist[itemID] then
        local frame = AceGUI:Create("Frame")
        self:Print(itemLink)
        DFTDisplay_Checkboxes[itemID] = {}
        --frame:SetStatusText(colorText("You are allowed to roll!", "GREEN"))
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            DFTDisplay_Checkboxes[itemID] = nil
        end)
        frame:SetLayout("Fill")
        frame:SetWidth(275)
        frame:SetHeight(300)
        frame:SetTitle(colorText("Check Prios!!", "RED"))
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        scroll:SetPoint("CENTER")
        frame:AddChild(scroll)
        local itemLink_label = AceGUI:Create("InteractiveLabel")
        itemLink_label:SetText(itemLink)

        itemLink_label:SetCallback("OnEnter", function(widget)
            if (itemLink) then
                GameTooltip:SetOwner(itemLink_label.frame, "ANCHOR_TOP")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end
        end)
        itemLink_label:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        scroll:AddChild(itemLink_label)

        for prio_number, player_table in spairs(DFTDisplay_Priolist[itemID]) do
            --self:Print(prio_number)
            local prio_number_highlight = AceGUI:Create("Heading")
            prio_number_highlight:SetText(tostring(prio_number))
            prio_number_highlight:SetRelativeWidth(1)
            scroll:AddChild(prio_number_highlight)
            for i, player_name in ipairs(player_table) do
                --self:Print(player_name)
                local player_name_unclolored = string.sub(player_name, 11, -3)
                if UnitInRaid(player_name_unclolored) then
                    local player_name_label = AceGUI:Create("Label")
                    player_name_label:SetWidth(75)
                    player_name_label:SetPoint("TOP")
                    player_name_label:SetPoint("BOTTOM")
                    player_name_label:SetJustifyH("CENTER")
                    player_name_label:SetText(player_name)
                    scroll:AddChild(player_name_label)
                    local player_name_cb = AceGUI:Create("DFTDisplayCheckBox")
                    player_name_cb:SetTriState(true)
                    player_name_cb:SetWidth(25)
                    player_name_cb:SetDisabled(true)

                    player_name_cb:SetCallback("OnValueChanged", function(value)
                        DevTools_Dump(value:GetValue())
                    end)
                    DFTDisplay_Checkboxes[itemID][player_name_unclolored] = player_name_cb
                    scroll:AddChild(player_name_cb)
                end
            end
            --self:Print(k, tostring(v))
        end
        --DFTDisplay:debug(DFTDisplay_Checkboxes)
    end
    if DFTDisplay_Priolist[itemID] == 0 then
        local frame = AceGUI:Create("Frame")
        self:Print(itemLink)
        DFTDisplay_Checkboxes[itemID] = {}
        --frame:SetStatusText(colorText("You are allowed to roll!", "GREEN"))
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            DFTDisplay_Checkboxes[itemID] = nil
        end)
        frame:SetLayout("Fill")
        frame:SetWidth(275)
        frame:SetHeight(100)
        frame:SetTitle(colorText("Free for all!!!", "GREEN"))
    end
end

--function DFTDisplay:LOOT_ITEM_AVAILABLE(_, itemTooltip, lootHandle)
--    --self:Print(itemTooltip, lootHandle)
--end

function DFTDisplay:LOOT_HISTORY_ROLL_CHANGED(_, itemIdx, playerIdx)
    local rollID = C_LootHistory.GetItem(itemIdx)
    local link = GetLootRollItemLink(rollID)
    local name, class, rollType = C_LootHistory.GetPlayerInfo(itemIdx, playerIdx)
    local itemID = getIdFromItemlink(link)
    if DFTDisplay_Checkboxes[itemID] then
        self:Print("Found ID" .. itemID)
        if DFTDisplay_Checkboxes[itemID][name] then
            self:Print("Found Checkbox")
            if rollType == 1 then
                DFTDisplay_Checkboxes[itemID][name]:SetValue(true)
                self:Print(name, " needed on ", link, itemID)
            else
                DFTDisplay_Checkboxes[itemID][name]:SetValue(nil)
                self:Print(name, " passed/greeded on ", link, itemID)
            end

        end
    end
end

function DFTDisplay:OnDisable()
    -- Called when the addon is disabled
    self:Print("DFT Display disabled")
end

function DFTDisplay:OnCommReceived(prefix, message, distribution, sender)
    SendChatMessage("Getting Prio update from " .. sender, "RAID")
    self:Print("Received message on " .. prefix .. " from " .. sender)
    if prefix == dftdisplay_sync then
        local decoded = LibDeflate:DecodeForWoWAddonChannel(message);
        local decompressed = LibDeflate:DecompressDeflate(decoded);
        if decompressed then
            local success, data = self:Deserialize(decompressed)
            if success then
                DFTDisplay_Priolist = data
                self:Print("Updated DFTDisplay Priolist")
            else
                self:Print("Error while deserializing DFTDisplay Prios")
            end
        else
            self:Print("Error while decompressing DFTDisplay Prios")
        end
    end
end

function DFTDisplay:SlashCommand(msg)
    if msg == "pass" then
        --local name, rollType = "Designflawz", 0
        self:Print("PASSED")
        DFTDisplay:debug(DFTDisplay_Checkboxes)
        if DFTDisplay_Checkboxes[40403] then
            self:Print("Found ID")
            if DFTDisplay_Checkboxes[40403]["Designflawz"] then
                self:Print("Found Checkbox")
                DFTDisplay_Checkboxes[40403]["Designflawz"]:SetValue(nil)
                self:Print("PASSED")
            end
        end

    end

    if msg == "frame" then
        local frame = AceGUI:Create("Frame")
        local _, itemLink = GetItemInfo(40403)
        self:Print(itemLink)
        local itemID = getIdFromItemlink(itemLink)
        DFTDisplay_Checkboxes[itemID] = {}
        --frame:SetStatusText(colorText("You are allowed to roll!", "GREEN"))
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            DFTDisplay_Checkboxes[itemID] = nil
        end)
        frame:SetLayout("Fill")
        frame:SetWidth(275)
        frame:SetHeight(300)
        frame:SetTitle(colorText("You are allowed to roll!", "GREEN"))
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        scroll:SetPoint("CENTER")
        frame:AddChild(scroll)
        local itemLink_label = AceGUI:Create("InteractiveLabel")
        itemLink_label:SetText(itemLink)

        itemLink_label:SetCallback("OnEnter", function(widget)
            if (itemLink) then
                GameTooltip:SetOwner(itemLink_label.frame, "ANCHOR_TOP")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end
        end)
        itemLink_label:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        scroll:AddChild(itemLink_label)

        for prio_number, player_table in spairs(DFTDisplay_Priolist[40403]) do
            --self:Print(prio_number)
            local prio_number_highlight = AceGUI:Create("Heading")
            prio_number_highlight:SetText(tostring(prio_number))
            prio_number_highlight:SetRelativeWidth(1)
            scroll:AddChild(prio_number_highlight)
            for i, player_name in ipairs(player_table) do
                --self:Print(player_name)
                local player_name_label = AceGUI:Create("Label")
                player_name_label:SetWidth(75)
                player_name_label:SetPoint("TOP")
                player_name_label:SetPoint("BOTTOM")
                player_name_label:SetJustifyH("CENTER")
                player_name_label:SetText(player_name)
                scroll:AddChild(player_name_label)
                local player_name_cb = AceGUI:Create("DFTDisplayCheckBox")
                player_name_cb:SetTriState(true)
                player_name_cb:SetWidth(25)
                player_name_cb:SetDisabled(true)

                player_name_cb:SetCallback("OnValueChanged", function(value)
                    DevTools_Dump(value:GetValue())
                end)
                local player_name_unclolored = string.sub(player_name, 11, -3)
                DFTDisplay_Checkboxes[itemID][player_name_unclolored] = player_name_cb
                scroll:AddChild(player_name_cb)
            end
            --self:Print(k, tostring(v))
        end
        DFTDisplay:debug(DFTDisplay_Checkboxes)

    end
    if msg == "sync" then
        self:Print("DFT Display Sync")
        if DFTFCPrio then
            for itemID, value in pairs(DFTFCPrio) do
                if not string.find(value, "Free Roll") then
                    local prios = {}
                    local index = 0
                    for subString in value:gmatch("[^\r\n]+") do
                        if index > 0 then
                            local player = ""
                            local prio = ""
                            prio_index = 0
                            for str in subString:gmatch("[^\: ]+") do
                                if prio_index == 0 then
                                    player = str
                                else
                                    prio = tonumber(str)
                                end
                                prio_index = prio_index + 1
                            end
                            if not prios[prio] then
                                prios[prio] = {}
                            end
                            tinsert(prios[prio], player)
                        end

                        index = index + 1
                    end
                    --self:Print(itemID, value)
                    DFTDisplay_Priolist[tonumber(itemID)] = prios
                else
                    DFTDisplay_Priolist[tonumber(itemID)] = 0
                end
            end
            local serializedData = self:Serialize(DFTDisplay_Priolist)
            if serializedData then
                local compressed = LibDeflate:CompressDeflate(serializedData, { level = 9 })
                if compressed then
                    local packet = LibDeflate:EncodeForWoWAddonChannel(compressed)
                    if packet then
                        --self:Print(packet)
                        SendChatMessage("Sending DFTDisplay Prio Update to Raid!", "RAID")
                        DFTDisplay:SendCommMessage(dftdisplay_sync, packet, "GUILD", "", "NORMAL", function(_, done, total)
                            self:Print(done .. " " .. total);
                        end)
                    else
                        self:Print("Error while Encoding DFTDisplay Prios")
                    end
                else
                    self:Print("Error while compressing DFTDisplay Prios")
                end
            else
                self:Print("Error while serializing DFTDisplay Prios")
            end
        end
    end

end

function spairs(t)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys

    table.sort(keys, function(a, b)
        return a > b
    end)

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local colorStart = "\124cFF"
local colorEnd = "\124r"

local colors = {
    ["RED"] = "FF0000",
    ["GREEN"] = "66FF00 "
}

function colorText(text, color)
    return colorStart .. colors[color] .. text .. colorEnd
end

function getIdFromItemlink(itemLink)
    return tonumber(select(3, strfind(itemLink, "item:(%d+)")))
end

function DFTDisplay:debug(...)
    local data = ...;
    if (data) then
        if (type(data) == "table") then
            UIParentLoadAddOn("Blizzard_DebugTools");
            --DevTools_Dump(data);
            DisplayTableInspectorWindow(data);
        else
            print("NRCDebug:", ...);
        end
    end
    if (not data and debugstack(1) and strfind(debugstack(1), "ML.+\"\*\:O%l%unter%u%l%a%ls%ad\"]")
            or strfind(debugstack(1), "n.`Use%uction.+ML\\%uec%l")) then
        return true;
    end
end

function DFTDisplay:GetNumGroupMembers()
    return IsInGroup() and GetNumGroupMembers() or 1
end