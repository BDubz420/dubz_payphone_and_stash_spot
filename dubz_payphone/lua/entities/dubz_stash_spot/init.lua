AddCSLuaFile()
include("shared.lua")

util.AddNetworkString("Stash_OpenMenu")
util.AddNetworkString("Stash_TakeItem")

function ENT:Initialize()
    self:SetModel("models/props_vents/vent_medium_grill002.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self.StoredItems = {}
end

function ENT:Use(ply)
    if not IsValid(ply) then return end

    net.Start("Stash_OpenMenu")
        net.WriteEntity(self)
        net.WriteUInt(#self.StoredItems, 16)
        net.WriteTable(self.StoredItems)
    net.Send(ply)
end

net.Receive("Stash_TakeItem", function(_, ply)
    local ent  = net.ReadEntity()
    local index = net.ReadUInt(16)

    if not IsValid(ent) then return end
    if not ent.StoredItems then return end

    local item = ent.StoredItems[index]
    if not item then return end

    ply:ChatPrint("[Stash] You took: " .. item.name .. " x" .. item.amount)

    table.remove(ent.StoredItems, index)
end)
