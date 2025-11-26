if SERVER then
    AddCSLuaFile()
end

-- Configuration for Dubz Payphone and Stash Spot
-- Adjust delivery items, timing, and visuals here.

DUBZ_PAYPHONE = DUBZ_PAYPHONE or {}

local color = Color

DUBZ_PAYPHONE.Config = {
    DeliveryTime = 120, -- seconds
    MarkerHideDistance = 120, -- HUD marker disappears when within this distance
    MarkerColor = color(25, 178, 208),
    StashModel = "models/props_vents/vent_medium_grill002.mdl",
    MaxStashItems = 40,

    -- Currency handlers are intentionally basic; override these with your own
    -- wallet functions if your gamemode uses custom money implementations.
    Currencies = {
        clean = {
            label = "Clean Cash",
            get = function(ply)
                if ply.getDarkRPVar then return ply:getDarkRPVar("money") or 0 end
                if ply.getDarkRPVar then return ply:getDarkRPVar("Money") or 0 end
                if ply.GetMoney then return ply:GetMoney() end
                return ply:GetNWInt("clean_cash", 0)
            end,
            canAfford = function(ply, amount)
                if ply.canAfford then return ply:canAfford(amount) end
                local balance = 0
                if ply.getDarkRPVar then
                    balance = ply:getDarkRPVar("money") or ply:getDarkRPVar("Money") or 0
                end
                return balance >= amount
            end,
            charge = function(ply, amount)
                if amount <= 0 then return end
                if ply.addMoney then ply:addMoney(-amount) return end
                if ply.AddMoney then ply:AddMoney(-amount) return end
                if ply.canAfford and not ply:canAfford(amount) then return end
                ply:SetNWInt("clean_cash", math.max((ply:GetNWInt("clean_cash", 0) or 0) - amount, 0))
            end
        },
        dirty = {
            label = "Dirty Cash",
            get = function(ply)
                if ply.GetDirtyMoney then return ply:GetDirtyMoney() end
                return (ply.getDarkRPVar and (ply:getDarkRPVar("dirtymoney")
                    or ply:getDarkRPVar("DirtyMoney")
                    or ply:getDarkRPVar("dirty_money"))) or ply:GetNWInt("DirtyMoney", ply:GetNWInt("dirty_cash", 0))
            end,
            canAfford = function(ply, amount)
                local balance = 0
                if ply.GetDirtyMoney then
                    balance = ply:GetDirtyMoney()
                elseif ply.getDarkRPVar then
                    balance = ply:getDarkRPVar("dirtymoney")
                        or ply:getDarkRPVar("DirtyMoney")
                        or ply:getDarkRPVar("dirty_money")
                        or 0
                else
                    balance = ply:GetNWInt("DirtyMoney", ply:GetNWInt("dirty_cash", 0))
                end
                return (balance or 0) >= amount
            end,
            charge = function(ply, amount)
                if amount <= 0 then return end

                if ply.TakeDirtyMoney then
                    ply:TakeDirtyMoney(amount)
                    return
                end

                if ply.setDarkRPVar then
                    local balance = (ply:getDarkRPVar("dirtymoney")
                        or ply:getDarkRPVar("DirtyMoney")
                        or ply:getDarkRPVar("dirty_money")
                        or 0) - amount
                    ply:setDarkRPVar("dirtymoney", math.max(balance, 0))
                    return
                end

                local fallback = ply:GetNWInt("DirtyMoney", ply:GetNWInt("dirty_cash", 0))
                ply:SetNWInt("DirtyMoney", math.max(fallback - amount, 0))
                ply:SetNWInt("dirty_cash", math.max((ply:GetNWInt("dirty_cash", 0) or 0) - amount, 0))
            end
        }
    },

    Options = {
        {
            name = "Buy Coke Growing Seeds",
            description = "Order a bundle of coke seeds to your stash.",
            deliveryTime = 90,
            cost = { clean = 2500, dirty = 1800 },
            items = {
                {
                    class = "drug_coke_seed",
                    name = "Coke Seed",
                    model = "models/props_lab/box01a.mdl",
                    quantity = 5,
                    itemType = "entity"
                }
            }
        },
        {
            name = "Chemist Instruction Book",
            description = "Assign yourself as a chemist and unlock basic supplies.",
            cost = { clean = 1000, dirty = 800 },
            onSelect = function(ply)
                if ply.changeTeam and RPExtraTeams then
                    for id, job in ipairs(RPExtraTeams) do
                        if job.command == "chemist" then
                            ply:changeTeam(id, true)
                            break
                        end
                    end
                end
            end,
            items = {
                {
                    class = "drug_instruction_book",
                    name = "Chemistry Handbook",
                    model = "models/props_lab/binderredlabel.mdl",
                    quantity = 1,
                    itemType = "entity"
                }
            }
        },
        {
            name = "Weed Starter Pack",
            description = "Seeds and soil delivered straight to your vent stash.",
            cost = { clean = 1500, dirty = 1200 },
            items = {
                {
                    class = "drug_weed_seed",
                    name = "Weed Seed",
                    model = "models/props_borealis/bluebarrel001.mdl",
                    quantity = 3,
                    itemType = "entity",
                },
                {
                    class = "drug_soil_bag",
                    name = "Soil Bag",
                    model = "models/props_junk/garbage_bag001a.mdl",
                    quantity = 2,
                    itemType = "entity",
                }
            }
        },
        {
            name = "Request Anonymous Drop",
            description = "A random utility item shows up at a stash spot.",
            deliveryTime = 45,
            cost = { clean = 500, dirty = 400 },
            items = {
                {
                    class = "spawned_weapon",
                    weaponClass = "weapon_crowbar",
                    name = "Crowbar",
                    model = "models/weapons/w_crowbar.mdl",
                    quantity = 1,
                    itemType = "weapon",
                    clip1 = 0,
                    clip2 = 0
                }
            }
        }
    }
}
