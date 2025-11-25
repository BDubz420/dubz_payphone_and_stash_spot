include("shared.lua")

surface.CreateFont("DubzUI_Title", {
    font = "Roboto",
    size = 30,
    weight = 800,
})

surface.CreateFont("DubzUI_Button", {
    font = "Roboto",
    size = 22,
    weight = 600,
})

net.Receive("Payphone_OpenMenu", function()
    local ent   = net.ReadEntity()
    local data  = net.ReadString()
    if not IsValid(ent) then return end

    local config = util.JSONToTable(data or "") or {}

    -----------------------------------------------------
    -- FRAME (DubzStyle 2)
    -----------------------------------------------------
    local frame = vgui.Create("DFrame")
    frame:SetSize(420, 480)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:ShowCloseButton(false)

    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(10, 10, 10)) -- black bg
        draw.RoundedBox(8, 0, 0, w, 50, Color(0, 100, 255)) -- blue header
        draw.SimpleText("PAYPHONE SERVICES", "DubzUI_Title", 20, 12, Color(255,255,255))
    end

    -----------------------------------------------------
    -- CLOSE BUTTON (X)
    -----------------------------------------------------
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(40, 40)
    closeBtn:SetPos(frame:GetWide()-45, 5)
    closeBtn:SetText("✕")
    closeBtn:SetFont("DubzUI_Title")
    closeBtn:SetTextColor(Color(255,255,255))

    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(0,0,0,150))
    end

    closeBtn.DoClick = function()
        frame:Close()
    end

    -----------------------------------------------------
    -- SCROLL PANEL
    -----------------------------------------------------
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, 60)
    scroll:SetSize(frame:GetWide()-20, frame:GetTall()-70)

    local sbar = scroll:GetVBar()
    function sbar:Paint(w, h) end
    function sbar.btnUp:Paint(w, h) end
    function sbar.btnDown:Paint(w, h) end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(0,100,255))
    end

    -----------------------------------------------------
    -- ACTION BUTTONS
    -----------------------------------------------------
    local function priceLabel(action)
        local cost = action.cost or {}
        local parts = {}
        if cost.clean and cost.clean > 0 then
            parts[#parts + 1] = string.format("$%s clean", string.Comma(math.floor(cost.clean)))
        end
        if cost.dirty and cost.dirty > 0 then
            parts[#parts + 1] = string.format("$%s dirty", string.Comma(math.floor(cost.dirty)))
        end
        return table.concat(parts, " | ")
    end

    for id, action in ipairs(config) do
        local btn = scroll:Add("DButton")
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 10)
        btn:SetTall(60)
        btn:SetText("")

        btn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20,20,20))
            draw.RoundedBox(6, 0, 0, w, 2, Color(0,100,255))
            draw.SimpleText(action.name, "DubzUI_Button", 15, 10, Color(255,255,255))
            draw.SimpleText(action.description, "DubzUI_Button", 15, 28, Color(180,180,180))
            draw.SimpleText(string.format("Delivery ~%ds", action.deliveryTime or 0), "DubzUI_Button", w - 20, 10, Color(0, 180, 120), TEXT_ALIGN_RIGHT)
            local price = priceLabel(action)
            if price ~= "" then
                draw.SimpleText(price, "DubzUI_Button", w - 20, 32, Color(255, 200, 60), TEXT_ALIGN_RIGHT)
            end
        end

        btn.DoClick = function()
            net.Start("Payphone_TriggerAction")
                net.WriteUInt(id, 8)
                net.WriteEntity(ent)
            net.SendToServer()
            frame:Close()
        end
    end
end)
