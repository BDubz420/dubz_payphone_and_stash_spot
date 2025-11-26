AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("DubzStash_Open")
util.AddNetworkString("DubzStash_Action")
util.AddNetworkString("DubzStash_Pay")
util.AddNetworkString("DubzStash_MarkerStart")
util.AddNetworkString("DubzStash_MarkerClear")

DUBZ_PAYPHONE = DUBZ_PAYPHONE or {}
local config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or {}

local function refreshConfig()
    config = (DUBZ_PAYPHONE and DUBZ_PAYPHONE.Config) or config or {}
    return config
end

local function maxItems()
    local cfg = refreshConfig()
    return cfg.MaxStashItems or 40
end

local function currencyTable()
    refreshConfig()
    return config.Currencies or {}
end

local currencies = currencyTable()

DUBZ_PAYPHONE.ActiveStashSpots = DUBZ_PAYPHONE.ActiveStashSpots or {}

local function refreshStashNumbers()
    local fresh = {}
    local id = 1

    for _, ent in ipairs(DUBZ_PAYPHONE.ActiveStashSpots) do
        if IsValid(ent) then
            ent:SetStashId(id)
            fresh[#fresh + 1] = ent
            id = id + 1
        end
    end

    DUBZ_PAYPHONE.ActiveStashSpots = fresh
end

local function registerStash(ent)
    DUBZ_PAYPHONE.ActiveStashSpots[#DUBZ_PAYPHONE.ActiveStashSpots + 1] = ent
    refreshStashNumbers()
end

local function unregisterStash(ent)
    for idx, ref in ipairs(DUBZ_PAYPHONE.ActiveStashSpots) do
        if ref == ent then
            table.remove(DUBZ_PAYPHONE.ActiveStashSpots, idx)
            break
        end
    end

    refreshStashNumbers()
end

local function notify(ply, msg, typ)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, typ or 0, 4, msg)
    else
        ply:ChatPrint(msg)
    end
end

local function subMaterialsMatch(a, b)
    if (not a) and (not b) then return true end
    if (not a) or (not b) then return false end
    if table.Count(a) ~= table.Count(b) then return false end

    for idx, mat in pairs(a) do
        if b[idx] ~= mat then
            return false
        end
    end

    return true
end

local function canStack(a, b)
    if not (a and b) then return false end
    if a.class ~= b.class or a.model ~= b.model or a.itemType ~= b.itemType then return false end
    if a.material ~= b.material then return false end
    if not subMaterialsMatch(a.subMaterials, b.subMaterials) then return false end
    if (a.weaponClass or b.weaponClass) and a.weaponClass ~= b.weaponClass then return false end
    if a.entState or b.entState then return false end -- unique entity state shouldn't stack
    return true
end

local function sanitizeItem(data)
    if not data then return nil end
    local copy = table.Copy(data)
    copy.quantity = math.max(tonumber(copy.quantity) or 1, 1)
    copy.name = copy.name or copy.class or "Item"
    copy.model = copy.model or ""
    copy.itemType = copy.itemType or "entity"
    return copy
end

local function normalizeCost(cost)
    local prices = { clean = 0, dirty = 0 }
    if istable(cost) then
        prices.clean = math.max(tonumber(cost.clean) or 0, 0)
        prices.dirty = math.max(tonumber(cost.dirty) or 0, 0)
    elseif tonumber(cost) then
        prices.clean = math.max(tonumber(cost) or 0, 0)
    end
    return prices
end

local function copyCharges(tbl)
    return {
        clean = math.max(tonumber(tbl.clean) or 0, 0),
        dirty = math.max(tonumber(tbl.dirty) or 0, 0)
    }
end

local function getCurrency(id)
    currencies = currencyTable()
    return currencies[id] or {}
end

local function canPay(ply, currencyId, amount)
    local info = getCurrency(currencyId)
    if not info.canAfford then return false end
    return amount <= 0 or info.canAfford(ply, amount)
end

local function chargePlayer(ply, currencyId, amount)
    local info = getCurrency(currencyId)
    if not (info.charge and info.canAfford) then return false end
    if amount <= 0 then return true end
    if not info.canAfford(ply, amount) then return false end
    info.charge(ply, amount)
    return true
end

local function addItem(ent, data)
    if not (IsValid(ent) and data and data.class) then return false end
    data = sanitizeItem(data)
    if not data then return false end
    ent.StoredItems = ent.StoredItems or {}

    for _, stored in ipairs(ent.StoredItems) do
        if canStack(stored, data) then
            stored.quantity = (stored.quantity or 1) + (data.quantity or 1)
            ent:SetItemCount(#ent.StoredItems)
            return true
        end
    end

    if #ent.StoredItems >= maxItems() then return false end

    ent.StoredItems[#ent.StoredItems + 1] = data
    ent:SetItemCount(#ent.StoredItems)
    return true
end

local function removeItem(ent, index, amount)
    if not IsValid(ent) then return nil end
    ent.StoredItems = ent.StoredItems or {}

    local entry = ent.StoredItems[index]
    if not entry then return nil end

    local take = math.min(amount or 1, entry.quantity or 1)
    entry.quantity = (entry.quantity or 1) - take

    local removed = table.Copy(entry)
    removed.quantity = take

    if entry.quantity <= 0 then
        table.remove(ent.StoredItems, index)
    end

    ent:SetItemCount(#ent.StoredItems)
    return removed
end

local function validModelPath(path)
    return path and path ~= "" and util.IsValidModel(path)
end

local function resolveSpawnModel(data)
    if validModelPath(data.model) then
        return data.model
    end

    if data.weaponClass then
        local stored = weapons.GetStored(data.weaponClass)
        if stored and validModelPath(stored.WorldModel) then
            return stored.WorldModel
        end
    end

    return "models/props_junk/PopCan01a.mdl"
end

local function spawnWorldItem(ply, data)
    if not (IsValid(ply) and data and data.class) then return nil end

    local eyePos = ply:EyePos()
    local eyeAng = ply:EyeAngles()
    local tr = util.TraceLine({
        start = eyePos,
        endpos = eyePos + eyeAng:Forward() * 85,
        filter = ply
    })

    local pos = tr.HitPos + tr.HitNormal * 8
    if not tr.Hit then
        pos = eyePos + eyeAng:Forward() * 30
    end

    local ang = Angle(0, eyeAng.yaw, 0)
    local ent = ents.Create(data.class)
    if not IsValid(ent) then return false end

    if data.class == "spawned_weapon" then
        if not data.weaponClass then return false end

        if ent.SetWeaponClass then
            ent:SetWeaponClass(data.weaponClass)
        else
            ent.weaponClass = data.weaponClass
            ent.weaponclass = data.weaponClass
        end

        ent:SetNWString("weaponclass", data.weaponClass)
        ent:SetNWString("WeaponClass", data.weaponClass)
        ent:SetModel(resolveSpawnModel(data))

        ent.clip1   = data.clip1
        ent.clip2   = data.clip2
        ent.ammoadd = data.ammoAdd
        ent:SetNWInt("clip1", data.clip1 or 0)
        ent:SetNWInt("clip2", data.clip2 or 0)
        if data.ammoAdd then
            ent:SetNWInt("ammoadd", data.ammoAdd)
        end
    end

    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()

    if data.itemType == "weapon" and ent:IsWeapon() then
        if data.clip1 then ent:SetClip1(data.clip1) end
        if data.clip2 then ent:SetClip2(data.clip2) end
    end

    if data.material and data.material ~= "" then
        ent:SetMaterial(data.material)
    end

    if data.subMaterials then
        for idx, mat in pairs(data.subMaterials) do
            ent:SetSubMaterial(idx, mat)
        end
    end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then
        ent:PhysicsInit(SOLID_VPHYSICS)
        ent:SetMoveType(MOVETYPE_VPHYSICS)
        ent:SetSolid(SOLID_VPHYSICS)
        phys = ent:GetPhysicsObject()
    end

    if IsValid(phys) then
        phys:Wake()
    end

    return IsValid(ent) and ent or nil
end

local function findCarriedBag(ply)
    if not IsValid(ply) then return nil end
    for _, ent in ipairs(ents.FindByClass("dubz_inventory_bag")) do
        if ent.IsCarried and ent.BagOwner == ply then
            return ent
        end
    end
    return nil
end

function ENT:Initialize()
    refreshConfig()
    self:SetModel(config.StashModel or "models/props_vents/vent_medium_grill002.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self.StoredItems = self.StoredItems or {}
    self.PendingCharges = copyCharges(self.PendingCharges or { clean = 0, dirty = 0 })
    self:SetItemCount(#self.StoredItems)

    registerStash(self)
end

function ENT:OnRemove()
    unregisterStash(self)
end

local function writeNetItem(data)
    net.WriteString(data.class or "")
    net.WriteString(data.name or data.class or "Unknown Item")
    net.WriteString(data.model or "")
    net.WriteUInt(math.Clamp(data.quantity or 1, 1, 65535), 16)
    net.WriteString(data.itemType or "entity")
    net.WriteString(data.material or "")

    local subMats = data.subMaterials or {}
    net.WriteUInt(math.min(table.Count(subMats), 16), 5)
    for idx, mat in pairs(subMats) do
        net.WriteUInt(idx, 5)
        net.WriteString(mat)
    end
end

local function sendInventory(ply, ent)
    if not (IsValid(ply) and IsValid(ent)) then return end

    ent.PendingCharges = copyCharges(ent.PendingCharges or { clean = 0, dirty = 0 })
    local items = ent.StoredItems or {}

    net.Start("DubzStash_Open")
        net.WriteEntity(ent)
        net.WriteUInt(#items, 8)
        for _, data in ipairs(items) do
            writeNetItem(data)
        end
        net.WriteUInt(math.Clamp(ent.PendingCharges.clean or 0, 0, 262143), 18)
        net.WriteUInt(math.Clamp(ent.PendingCharges.dirty or 0, 0, 262143), 18)
    net.Send(ply)
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    sendInventory(ply, self)
end

net.Receive("DubzStash_Action", function(_, ply)
    local ent    = net.ReadEntity()
    local index  = net.ReadUInt(8)
    local amount = net.ReadUInt(16)
    local mode   = net.ReadString() or "world"

    if not IsValid(ent) then return end
    if ent:GetPos():DistToSqr(ply:GetPos()) > (200 * 200) then return end

    if (ent.PendingCharges.clean or 0) > 0 or (ent.PendingCharges.dirty or 0) > 0 then
        notify(ply, "[Stash] Pay for the pending delivery before taking items.", 1)
        sendInventory(ply, ent)
        return
    end

    local removed = removeItem(ent, index, math.max(amount, 1))
    if not removed then return end

    removed.quantity = math.max(removed.quantity or 1, 1)

    if mode == "backpack" then
        local bag = findCarriedBag(ply)
        if not (bag and DUBZ_INVENTORY and DUBZ_INVENTORY.AddItem) then
            notify(ply, "[Stash] You need a backpack on your back to store items.", 1)
            addItem(ent, removed)
            sendInventory(ply, ent)
            return
        end

        local copy = table.Copy(removed)
        if DUBZ_INVENTORY.AddItem(bag, copy) then
            if DUBZ_INVENTORY.SendTip then
                DUBZ_INVENTORY.SendTip(ply, string.format("Stored %s in backpack", copy.name or "item"))
            end
        else
            notify(ply, "[Stash] Backpack is full.", 1)
            addItem(ent, removed)
        end

        sendInventory(ply, ent)
        return
    end

    local spawned = 0
    local failedToSpawn = 0

    for _ = 1, removed.quantity do
        local entSpawned = spawnWorldItem(ply, removed)
        if not IsValid(entSpawned) then
            failedToSpawn = failedToSpawn + 1
            continue
        end

        if mode == "pocket" and ply.addPocketItem then
            local ok = ply:addPocketItem(entSpawned)
            if not ok then
                -- leave in world for pickup
            end
        end

        spawned = spawned + 1
    end

    local leftover = failedToSpawn
    if leftover > 0 then
        removed.quantity = leftover
        addItem(ent, removed)
    end

    sendInventory(ply, ent)
end)

net.Receive("DubzStash_Pay", function(_, ply)
    local ent      = net.ReadEntity()
    local currency = net.ReadString()

    if not IsValid(ent) then return end
    if ent:GetPos():DistToSqr(ply:GetPos()) > (200 * 200) then return end

    ent.PendingCharges = copyCharges(ent.PendingCharges or { clean = 0, dirty = 0 })
    local due = ent.PendingCharges[currency] or 0
    if due <= 0 then
        sendInventory(ply, ent)
        return
    end

    if not (getCurrency(currency).charge and getCurrency(currency).canAfford) then
        ent.PendingCharges[currency] = 0
        notify(ply, "[Stash] Currency handler missing; clearing owed balance.", 1)
        sendInventory(ply, ent)
        return
    end

    if not canPay(ply, currency, due) then
        notify(ply, string.format("[Stash] You don't have enough %s.", currency), 1)
        sendInventory(ply, ent)
        return
    end

    if not chargePlayer(ply, currency, due) then
        notify(ply, "[Stash] Payment failed.", 1)
        sendInventory(ply, ent)
        return
    end

    ent.PendingCharges[currency] = 0
    notify(ply, string.format("[Stash] Paid %s $%s.", currency, string.Comma(due)), 0)
    sendInventory(ply, ent)
end)

function ENT:AddDelivery(items, cost)
    if not items then return 0 end

    local added = 0
    for _, data in ipairs(items) do
        if addItem(self, table.Copy(data)) then
            added = added + 1
        end
    end

    if added > 0 then
        self.PendingCharges = copyCharges(self.PendingCharges or { clean = 0, dirty = 0 })
        local prices = normalizeCost(cost)
        local ratio = math.min(1, added / math.max(#items, 1))
        self.PendingCharges.clean = self.PendingCharges.clean + math.floor(prices.clean * ratio)
        self.PendingCharges.dirty = self.PendingCharges.dirty + math.floor(prices.dirty * ratio)
    end

    self:SetItemCount(#self.StoredItems)
    return added
end

function DUBZ_PAYPHONE.GetRandomStash()
    refreshStashNumbers()
    if #DUBZ_PAYPHONE.ActiveStashSpots <= 0 then return nil end
    return table.Random(DUBZ_PAYPHONE.ActiveStashSpots)
end
