include("shared.lua")

surface.CreateFont("DubzStash_Title", {
    font = "Roboto",
    size = 28,
    weight = 800
})

surface.CreateFont("DubzStash_Item", {
    font = "Roboto",
    size = 22,
    weight = 500
})

net.Receive("Stash_OpenMenu", function()
    local ent = net.ReadEntity()
    local count = net.ReadUInt(16)
    local items = net.ReadTable()

    if not IsValid(ent) then return end

    local frame = vgui.Create("DFrame")
    frame:SetSize(350, 400)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle("")
    frame:ShowCloseButton(false)

    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(10,10,10))
        draw.RoundedBox(8, 0, 0, w, 40, Color(0,100,255))
        draw.SimpleText("STASH STORAGE", "DubzStash_Title", 15, 8, Color(255,255,255))
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, 50)
    scroll:SetSize(330, 340)

    for i, data in ipairs(items) do
        local btn = scroll:Add("DButton")
        btn:Dock(TOP)
        btn:DockMargin(0,0,0,10)
        btn:SetTall(45)
        btn:SetText("")

        btn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20,20,20))
            draw.SimpleText(data.name .. " x" .. data.amount, "DubzStash_Item", 10, 12, Color(255,255,255))
        end

        btn.DoClick = function()
            net.Start("Stash_TakeItem")
                net.WriteEntity(ent)
                net.WriteUInt(i, 16)
            net.SendToServer()
            frame:Close()
        end
    end
end)
