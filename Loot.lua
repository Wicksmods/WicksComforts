-- Wick's Comforts
-- Loot.lua: auto loot and the bind on pickup prompt.
--
-- Auto loot is the game's own setting rather than anything clever. Driving
-- the console variable means it keeps working if this addon is disabled,
-- and it never fights the checkbox in Blizzard's own options.

local ADDON, ns = ...
local Core = ns.Core
local L = ns:Register("loot", {})

local CV = rawget(_G, "C_CVar")
local function cvGet(n) if CV and CV.GetCVar then return CV.GetCVar(n) end local f = rawget(_G, "GetCVar"); return f and f(n) end
local function cvSet(n, v) if CV and CV.SetCVar then return CV.SetCVar(n, v) end local f = rawget(_G, "SetCVar"); if f then return f(n, v) end end

function L:Apply()
    local db = ns.db()
    -- Only write when it differs, so a player who prefers the game's own
    -- checkbox is not fought over every settings change.
    if db.autoLoot then
        if cvGet("autoLootDefault") ~= "1" then cvSet("autoLootDefault", "1") end
    end
end

function L:Init()
    ns.RegisterEvents({ "LOOT_BIND_CONFIRM", "CONFIRM_LOOT_ROLL" })

    ns:On("LOOT_BIND_CONFIRM", function(_, slot)
        if not ns.db().confirmBoP then return end
        -- Confirming is an ordinary call, but the dialog Blizzard raises
        -- alongside it has to go or it sits there orphaned.
        if ConfirmLootSlot then Core.safe(ConfirmLootSlot, slot) end
        local popup = rawget(_G, "StaticPopup_Hide")
        if popup then Core.safe(popup, "LOOT_BIND") end
    end)
end
