include("shared.lua")

local config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or {}
local accent = config.MarkerColor or Color(25, 178, 208)
local hideDist = config.MarkerHideDistance or 120

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

local function sendAction(container, index, amount)
    net.Start("DubzStash_Action")
    net.WriteEntity(container)
    net.WriteUInt(index, 8)
    net.WriteUInt(amount or 1, 16)
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

local function buildInventory(container, items)
    local tileW, tileH, spacing = 92, 110, 8
    local framePad, headerH = 12, 46

    local capacity = math.max(#items, 1)
    local availableWidth = ScrW() - 80 - (framePad * 2)
    local maxCols = math.max(3, math.floor((availableWidth + spacing) / (tileW + spacing)))
    local cols = math.Clamp(capacity, 1, maxCols)
    local rows = math.max(1, math.ceil(capacity / cols))
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
    label:SetText(string.format("%d item slots", #items))

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
        icon.PaintOver = function(_, w, h)
            surface.SetDrawColor(accent)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        applyIconMaterials(icon, data)

        icon.DoClick = function()
            sendAction(container, idx, 1)
            frame:Close()
        end

        icon.DoRightClick = function()
            Derma_StringRequest("Withdraw", "How many do you want to pull out?", tostring(data.quantity or 1), function(text)
                sendAction(container, idx, tonumber(text) or 1)
                frame:Close()
            end)
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

    buildInventory(ent, items)
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
