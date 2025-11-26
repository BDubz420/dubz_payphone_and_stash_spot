AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("Payphone_OpenMenu")
util.AddNetworkString("Payphone_TriggerAction")

DUBZ_PAYPHONE = DUBZ_PAYPHONE or {}
local config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or {}

-----------------------------------------------------
-- Delivery helpers
-----------------------------------------------------
local function startMarker(ply, stash)
    if not (IsValid(ply) and IsValid(stash)) then return end
    net.Start("DubzStash_MarkerStart")
        net.WriteEntity(stash)
        net.WriteUInt(stash:GetStashId(), 12)
    net.Send(ply)
end

local function clearMarker(ply, id)
    if not IsValid(ply) then return end
    net.Start("DubzStash_MarkerClear")
        net.WriteUInt(id, 12)
    net.Send(ply)
end

net.Receive("DubzStash_MarkerClear", function(_, ply)
    local id = net.ReadUInt(12)
    clearMarker(ply, id)
end)

local function notify(ply, msg, typ)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, typ or 0, 4, msg)
    else
        ply:ChatPrint(msg)
    end
end

local function deliverToStash(ply, stash, items, delay, cost)
    if not IsValid(stash) then
        notify(ply, "[Stash] No stash spot found!", 1)
        return
    end

    local wait = delay or config.DeliveryTime or 120
    notify(ply, string.format("[Stash] Delivery queued to vent #%d in %d seconds.", stash:GetStashId(), wait), 0)

    startMarker(ply, stash)

    timer.Simple(wait, function()
        if not (IsValid(stash) and IsValid(ply)) then return end

        local added = stash:AddDelivery(items, cost)
        clearMarker(ply, stash:GetStashId())

        if added <= 0 then
            notify(ply, string.format("[Stash] Vent #%d was full; delivery failed.", stash:GetStashId()), 1)
            return
        end

        if added < #items then
            notify(ply, string.format("[Stash] Vent #%d filled up; some items were skipped.", stash:GetStashId()), 1)
        else
            notify(ply, string.format("[Stash] Order arrived at vent #%d!", stash:GetStashId()), 0)
        end
    end)
end

-----------------------------------------------------
-- Payphone Actions
-----------------------------------------------------
local function sanitizeOptions()
    config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or config or {}
    local options = {}
    for _, data in ipairs(config.Options or {}) do
        options[#options + 1] = {
            name = data.name or "Action",
            description = data.description or "",
            deliveryTime = data.deliveryTime or config.DeliveryTime or 120,
            cost = data.cost or { clean = 0, dirty = 0 }
        }
    end

    if #options <= 0 then
        options[1] = {
            name = "No services configured",
            description = "Set DUBZ_PAYPHONE.Config.Options to add buttons.",
            deliveryTime = config.DeliveryTime or 120,
            cost = { clean = 0, dirty = 0 }
        }
    end

    return options
end

local function buildMenuJson()
    local ok, encoded = pcall(util.TableToJSON, sanitizeOptions())
    if not ok then
        ErrorNoHalt("[Payphone] Failed to encode options: " .. tostring(encoded) .. "\n")
        return "[]"
    end

    return encoded or "[]"
end

local function getActionData(id)
    return (config.Options or {})[id]
end

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

    self:SetMenuConfig(buildMenuJson())
end

-----------------------------------------------------
-- Open Menu
-----------------------------------------------------
function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end

    config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or config or {}

    -- Refresh config so live changes propagate without a map restart
    self:SetMenuConfig(buildMenuJson())

    net.Start("Payphone_OpenMenu")
        net.WriteEntity(self)
        net.WriteString(self:GetMenuConfig() or "[]")
    net.Send(ply)
end

-----------------------------------------------------
-- Execute Action
-----------------------------------------------------
net.Receive("Payphone_TriggerAction", function(_, ply)
    local id  = net.ReadUInt(8)
    local ent = net.ReadEntity()

    if not (IsValid(ent) and ent:GetClass() == "dubz_payphone") then return end

    config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or config or {}

    local maxDist = 200 * 200
    if ent:GetPos():DistToSqr(ply:GetPos()) > maxDist then
        return
    end

    local action = getActionData(id)
    if not action then return end

    if isfunction(action.onSelect) then
        action.onSelect(ply)
    end

    local stash = DUBZ_PAYPHONE.GetRandomStash()
    if not IsValid(stash) then
        notify(ply, "[Payphone] No stash vents available.", 1)
        return
    end

    local items = {}
    for _, data in ipairs(action.items or {}) do
        items[#items + 1] = table.Copy(data)
    end

    deliverToStash(ply, stash, items, action.deliveryTime, action.cost)
end)
