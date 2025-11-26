AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Payphone"
ENT.Author    = "Dubz"
ENT.Category = "Dubz Entities"
ENT.Spawnable = true

-- Action config sent from server to UI
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "MenuConfig") -- JSON-encoded actions
end
