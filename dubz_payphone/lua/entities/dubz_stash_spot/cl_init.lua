include("shared.lua")

local function currentConfig()
    return (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or {}
end

local function accentColor()
    local cfg = currentConfig()
    return cfg.MarkerColor or Color(25, 178, 208)
end

local function markerHideDistance()
    local cfg = currentConfig()
    return cfg.MarkerHideDistance or 120
end

surface.CreateFont("DubzStash_Title", {
    font = "Roboto",
    size = 28,
    weight = 800
})

surface.CreateFont("DubzStash_Label", {
    font = "Roboto",
    size = 18,
    weight = 600
})

surface.CreateFont("DubzStash_Small", {
    font = "Roboto",
    size = 15,
    weight = 500
})

local function readNetItem()
    local item = {
        class     = net.ReadString(),
        name      = net.ReadString(),
        model     = net.ReadString(),
        quantity  = net.ReadUInt(16),
        itemType  = net.ReadString(),
        material  = net.ReadString()
    }

    local subMaterials = {}
    local subCount     = net.ReadUInt(5)
    for _ = 1, subCount do
        local idx = net.ReadUInt(5)
        subMaterials[idx] = net.ReadString()
    end

    if not table.IsEmpty(subMaterials) then
        item.subMaterials = subMaterials
    end

    return item
end

local function sendAction(container, index, amount, mode)
    net.Start("DubzStash_Action")
    net.WriteEntity(container)
    net.WriteUInt(index, 8)
    net.WriteUInt(amount or 1, 16)
    net.WriteString(mode or "world")
    net.SendToServer()
end

local function sendPayment(container, currency)
    net.Start("DubzStash_Pay")
    net.WriteEntity(container)
    net.WriteString(currency)
    net.SendToServer()
end

local function applyIconMaterials(icon, data)
    if not (data and (data.material or data.subMaterials)) then return end
    timer.Simple(0, function()
        if not (IsValid(icon) and IsValid(icon.Entity)) then return end
        if data.material and data.material ~= "" then
            icon.Entity:SetMaterial(data.material)
        end

        if data.subMaterials then
            for idx, mat in pairs(data.subMaterials) do
                icon.Entity:SetSubMaterial(idx, mat)
            end
        end
    end)
end

local function buildInventory(container, items, charges)
    local config = currentConfig()
    local accent = accentColor()
    local tileW, tileH, spacing = 92, 110, 8
    local framePad, headerH = 12, 140

    local maxSlots = math.max(config.MaxStashItems or #items, #items, 1)
    local availableWidth = ScrW() - 80 - (framePad * 2)
    local maxCols = math.max(3, math.floor((availableWidth + spacing) / (tileW + spacing)))
    local cols = math.Clamp(maxSlots, 1, maxCols)
    local rows = math.max(1, math.ceil(maxSlots / cols))
    local gridW = cols * tileW + (cols - 1) * spacing
    local gridH = rows * tileH + (rows - 1) * spacing

    local frameW = gridW + framePad * 2
    local frameH = headerH + gridH + framePad * 2

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:ShowCloseButton(false)

    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(10, 10, 10))
        draw.RoundedBox(12, 0, 0, w, 3, accent)
        draw.RoundedBox(10, framePad, framePad, w - framePad * 2, headerH - 10, Color(24, 28, 38))
        draw.SimpleText("Vent Stash #" .. (IsValid(container) and container:GetStashId() or 0), "DubzStash_Title", framePad + 8, framePad + 6, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("✕")
    close:SetFont("DubzStash_Label")
    close:SetTextColor(Color(255, 255, 255))
    close:SetSize(32, 24)
    close:SetPos(frame:GetWide() - framePad - 32, framePad + 6)
    close.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 20, 20))
    end
    close.DoClick = function() frame:Close() end

    local label = vgui.Create("DLabel", frame)
    label:SetPos(frame:GetWide() - framePad - 200, framePad + 24)
    label:SetSize(180, 16)
    label:SetFont("DubzStash_Small")
    label:SetTextColor(Color(200, 200, 200))
    label:SetText(string.format("%d / %d slots", #items, maxSlots))

    charges = charges or { clean = 0, dirty = 0 }
    local chargePanel = vgui.Create("DPanel", frame)
    chargePanel:SetPos(framePad + 6, framePad + 20)
    chargePanel:SetSize(200, 22)
    chargePanel.Paint = function(self, w, h)
        if (charges.clean or 0) <= 0 and (charges.dirty or 0) <= 0 then
            draw.SimpleText("No payment due", "DubzStash_Small", 0, h / 2, Color(160, 220, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Pay to unlock stash", "DubzStash_Small", 0, h / 2, Color(255, 200, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local function addPayButton(key, amount, x)
        if not amount or amount <= 0 then return x end
        local btn = vgui.Create("DButton", frame)
        btn:SetSize(120, 24)
        btn:SetPos(x, framePad + 44)
        btn:SetText(string.format("Pay %s $%s", key, string.Comma(amount)))
        btn:SetFont("DubzStash_Small")
        btn:SetTextColor(Color(0, 0, 0))
        btn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(255, 200, 60))
        end
        btn.DoClick = function()
            sendPayment(container, key)
            frame:Close()
        end
        return x + btn:GetWide() + 6
    end

    local nextX = framePad + 6
    nextX = addPayButton("clean", charges.clean, nextX)
    addPayButton("dirty", charges.dirty, nextX)

    local dropWrap = vgui.Create("DPanel", frame)
    dropWrap:SetPos(framePad + 6, framePad + 74)
    dropWrap:SetSize(frame:GetWide() - (framePad * 2) - 12, 52)
    dropWrap.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18))
        draw.SimpleText("Drag items here:", "DubzStash_Small", 8, 6, Color(220, 220, 220))
    end

    local function addDropTarget(label, mode, x)
        local zone = vgui.Create("DPanel", dropWrap)
        zone:SetPos(x, 24)
        zone:SetSize(140, 22)
        zone.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(24, 28, 38))
            draw.SimpleText(label, "DubzStash_Small", w / 2, h / 2, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        zone:Receiver("DubzStashItem", function(_, panels, dropped)
            if not dropped then return end
            local icon = panels[1]
            if not IsValid(icon) then return end
            sendAction(container, icon.StashIndex or 1, icon.WithdrawAmount or 1, mode)
            frame:Close()
        end)

        return x + zone:GetWide() + 8
    end

    local zoneX = 8
    zoneX = addDropTarget("Pocket", "pocket", zoneX)
    zoneX = addDropTarget("Backpack", "backpack", zoneX)
    addDropTarget("Drop to world", "world", zoneX)

    local gridWrap = vgui.Create("DPanel", frame)
    gridWrap:SetSize(gridW, gridH)
    gridWrap:SetPos((frame:GetWide() - gridW) / 2, framePad + headerH)
    gridWrap.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(24, 28, 38))
        surface.SetDrawColor(ColorAlpha(accent, 40))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local grid = vgui.Create("DIconLayout", gridWrap)
    grid:SetSpaceX(spacing)
    grid:SetSpaceY(spacing)
    grid:SetSize(gridW, gridH)
    grid:SetPos(0, 0)

    for idx, data in ipairs(items) do
        local panel = grid:Add("DPanel")
        panel:SetSize(tileW, tileH)
        panel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 180))
            draw.SimpleText(data.name, "DubzStash_Small", w / 2, h - 22, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("x" .. (data.quantity or 1), "DubzStash_Small", w / 2, h - 8, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local icon = vgui.Create("SpawnIcon", panel)
        icon:SetModel(data.model ~= "" and data.model or "models/props_junk/PopCan01a.mdl")
        icon:SetPos(6, 6)
        icon:SetSize(tileW - 12, tileW - 12)
        icon:SetTooltip(nil)
        icon:Droppable("DubzStashItem")
        icon.StashIndex = idx
        icon.WithdrawAmount = data.quantity or 1
        icon.PaintOver = function(_, w, h)
            surface.SetDrawColor(accent)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        applyIconMaterials(icon, data)

        icon.DoClick = function()
            sendAction(container, idx, 1, "world")
            frame:Close()
        end

        icon.DoRightClick = function()
            local menu = DermaMenu()
            menu:AddOption("Withdraw to world", function()
                Derma_StringRequest("Withdraw", "How many do you want to pull out?", tostring(data.quantity or 1), function(text)
                    sendAction(container, idx, tonumber(text) or 1, "world")
                    frame:Close()
                end)
            end)

            menu:AddOption("Send to pocket", function()
                Derma_StringRequest("Withdraw", "How many do you want to pocket?", tostring(data.quantity or 1), function(text)
                    sendAction(container, idx, tonumber(text) or 1, "pocket")
                    frame:Close()
                end)
            end)

            menu:AddOption("Send to backpack", function()
                Derma_StringRequest("Withdraw", "How many do you want to backpack?", tostring(data.quantity or 1), function(text)
                    sendAction(container, idx, tonumber(text) or 1, "backpack")
                    frame:Close()
                end)
            end)

            menu:Open()
        end
    end
end

net.Receive("DubzStash_Open", function()
    local ent = net.ReadEntity()
    local count = net.ReadUInt(8)
    if not IsValid(ent) then return end

    local items = {}
    for i = 1, count do
        items[i] = readNetItem()
    end
    local cleanDue = net.ReadUInt(18)
    local dirtyDue = net.ReadUInt(18)

    buildInventory(ent, items, { clean = cleanDue, dirty = dirtyDue })
end)

-- Delivery marker HUD
local markers = {}

net.Receive("DubzStash_MarkerStart", function()
    local ent = net.ReadEntity()
    local id  = net.ReadUInt(12)
    if not IsValid(ent) then return end
    markers[id] = ent
end)

net.Receive("DubzStash_MarkerClear", function()
    local id = net.ReadUInt(12)
    markers[id] = nil
end)

hook.Add("HUDPaint", "DubzStash_MarkerHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local accent = accentColor()
    local hideDist = markerHideDistance()

    for id, ent in pairs(markers) do
        if not IsValid(ent) then markers[id] = nil continue end

        local pos = ent:GetPos() + Vector(0, 0, 20)
        local screen = pos:ToScreen()
        local dist = ply:GetPos():Distance(ent:GetPos())

        draw.SimpleTextOutlined("VENT #" .. ent:GetStashId(), "DubzStash_Label", screen.x, screen.y - 20, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
        draw.SimpleTextOutlined(string.format("%dm", math.floor(dist / 12)), "DubzStash_Small", screen.x, screen.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))

        if dist <= hideDist then
            markers[id] = nil
            net.Start("DubzStash_MarkerClear")
                net.WriteUInt(id, 12)
            net.SendToServer()
        end
    end
end)
