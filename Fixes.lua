-- Wick's Comforts
-- Fixes.lua: quiet a couple of the beta client's own errors.
--
-- These are not preferences and they are not our bugs. They are places
-- where Blizzard's own code on this build reaches for something that was
-- never created, throws, and spams the error frame every reload. Each fix
-- here is conditional: it only acts when the fault is actually present,
-- so it does nothing on a client where the code is correct and it retires
-- itself the moment Blizzard patches it.
--
-- This is the one part of the addon that starts switched on, because an
-- error you did not cause and cannot act on is not a preference.

local ADDON, ns = ...
local Core = ns.Core
local F = ns:Register("fixes", {})

local function addonExists(name)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local ok, info = pcall(C_AddOns.GetAddOnInfo, name)
        return ok and info ~= nil
    end
    local f = rawget(_G, "GetAddOnInfo")
    return f and f(name) ~= nil
end

-- Blizzard_GroupFinder_VanillaStyle shares one tab handler between its
-- Classic and Mainline variants, but only the Mainline one builds
-- LFGWhoListFrame. This client loads the Classic variant, so the moment
-- the group finder switches tabs it indexes a nil and throws. The whole
-- stack is Blizzard's; nothing an addon did causes it.
--
-- Standing a plain hidden frame under that name is enough: their code
-- only calls SetShown and IsShown on it.
function F:GroupFinderWhoList()
    if rawget(_G, "LFGWhoListFrame") then return false end
    if not addonExists("Blizzard_GroupFinder_VanillaStyle") then return false end
    local f = CreateFrame("Frame", "LFGWhoListFrame", UIParent)
    f:Hide()
    f.wicksStub = true
    self.stubbedWhoList = true
    return true
end

function F:Apply()
    if ns.db().clientFixes == false then return end
    Core.safe(F.GroupFinderWhoList, F)
end

function F:Init()
    -- Early, because the group finder is loaded on entering the world and
    -- the frame has to exist before it does.
    self:Apply()
    ns.RegisterEvents({ "PLAYER_ENTERING_WORLD" })
    ns:On("PLAYER_ENTERING_WORLD", function() F:Apply() end)
end
