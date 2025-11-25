AddCSLuaFile()
include("shared.lua")

util.AddNetworkString("Payphone_OpenMenu")
util.AddNetworkString("Payphone_TriggerAction")

-----------------------------------------------------
-- Delivery System
-----------------------------------------------------
local DELIVERY_TIME = 180 -- 3 minutes (change if you want)

local function DeliverToStash(ply, item, amount)
    -- Find nearest stash spot
    local nearest
    local dist = 999999
    
    for _, ent in ipairs(ents.FindByClass("dubz_stash_spot")) do
        local d = ent:GetPos():DistToSqr(ply:GetPos())
        if d < dist then
            dist = d
            nearest = ent
        end
    end

    if not IsValid(nearest) then
        ply:ChatPrint("[Stash] No stash spot found!")
        return
    end

    ply:ChatPrint("[Stash] Your order will arrive in " .. (DELIVERY_TIME/60) .. " minutes.")

    timer.Simple(DELIVERY_TIME, function()
        if not IsValid(nearest) then return end
        
        local stored = nearest.StoredItems or {}
        stored[#stored+1] = {
            name = item,
            amount = amount,
            owner = ply
        }
        nearest.StoredItems = stored

        ply:ChatPrint("[Stash] Your order has arrived at the stash!")
    end)
end

-----------------------------------------------------
-- Payphone Actions Config
-----------------------------------------------------
local PayphoneActions = {
    {
        name = "Order Seed Pack",
        description = "Delivery to your stash in 3 minutes.",
        action = function(ply)
            DeliverToStash(ply, "Seed Pack", 5)
        end
    },
    {
        name = "Place Hit",
        description = "Contact underground hitmen.",
        action = function(ply)
            ply:ChatPrint("[Payphone] Your hit request was submitted.")
        end
    }
}

-----------------------------------------------------
-- Initialize
-----------------------------------------------------
function ENT:Initialize()
    self:SetModel("models/props_trainstation/payphone001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetMenuConfig(util.TableToJSON(PayphoneActions))
end

-----------------------------------------------------
-- Open Menu
-----------------------------------------------------
function ENT:Use(ply)
    if not IsValid(ply) then return end
    net.Start("Payphone_OpenMenu")
        net.WriteEntity(self)
        net.WriteString(self:GetMenuConfig())
    net.Send(ply)
end

-----------------------------------------------------
-- Execute Action
-----------------------------------------------------
net.Receive("Payphone_TriggerAction", function(_, ply)
    local id  = net.ReadUInt(8)
    local ent = net.ReadEntity()

    if not IsValid(ent) then return end

    local config = util.JSONToTable(ent:GetMenuConfig())
    if not config or not config[id] then return end

    local action = config[id]
    if action.action then
        action.action(ply)
    end
end)
