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
    Options = {
        {
            name = "Buy Coke Growing Seeds",
            description = "Order a bundle of coke seeds to your stash.",
            deliveryTime = 90,
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
            name = "Buy Weed Starter Pack",
            description = "Seeds and soil delivered straight to your vent stash.",
            items = {
                {
                    class = "drug_weed_seed",
                    name = "Weed Seed",
                    model = "models/props_borealis/bluebarrel001.mdl",
                    quantity = 3,
                    itemType = "entity"
                },
                {
                    class = "drug_soil_bag",
                    name = "Soil Bag",
                    model = "models/props_junk/garbage_bag001a.mdl",
                    quantity = 2,
                    itemType = "entity"
                }
            }
        },
        {
            name = "Request Anonymous Drop",
            description = "A random utility item shows up at a stash spot.",
            deliveryTime = 45,
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
