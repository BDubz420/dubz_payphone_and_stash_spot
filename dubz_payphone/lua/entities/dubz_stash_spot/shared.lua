AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Stash Spot"
ENT.Author    = "Dubz"
ENT.Category  = "Dubz Entities"
ENT.Spawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "ItemCount")
    self:NetworkVar("Int", 1, "StashId")
end
