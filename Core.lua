-- Wick's Comforts
-- Core.lua: WickCore addon object, saved variables, options page, slash command.
--
-- The small conveniences most players end up installing something for. This
-- is not trying to be Leatrix Plus; it is the handful of comforts a Wick
-- user might want without adopting a large tweak suite, in the suite's own
-- chrome and profile system.
--
-- Everything is off on install. An addon that changes your interface the
-- moment it loads is a rude houseguest, and several Wick products already
-- depend on WickCore, so this one must never surprise someone who only
-- wanted bags.

local ADDON, ns = ...

local Core = WickCore
assert(Core, "Wick's Comforts requires WickCore. Enable the WickCore addon.")
ns.Core = Core

ns.version = "0.1.0"

local PROFILE_DEFAULTS = {
    -- Minimap
    squareMinimap   = false,
    hideMinimapZoom = false,
    -- Tooltips
    tipItemLevel    = false,
    tipIDs          = false,
    tipClassColor   = false,
    tipTarget       = false,
    -- Loot
    autoLoot        = false,
    confirmBoP      = false,
    -- Vendor
    autoRepair      = false,
    guildRepair     = false,
    sellJunk        = false,
    -- Quests
    autoAcceptQuests = false,
    autoTurnInQuests = false,
    -- The client's own settings, surfaced
    maxCameraZoom    = false,
    soundInBackground = false,
    hideProcGlow     = false,
    -- The one exception to everything-off: a workaround for the
    -- client's own errors, which are not a preference.
    clientFixes     = true,
    classColorHealth = false,   -- class colour on player, target, focus, boss
}

local A = Core:NewAddon("WicksComforts", {
    title    = "Wick's Comforts",
    version  = ns.version,
    savedVar = "WicksComfortsSaved",
    defaults = { profile = PROFILE_DEFAULTS, global = {} },
})
ns.A = A

-- Console variables, reached the same way everywhere. Several comforts
-- are nothing more than a setting the game already has and does not show.
local CV = rawget(_G, "C_CVar")
function ns.cvGet(name)
    if CV and CV.GetCVar then return CV.GetCVar(name) end
    local f = rawget(_G, "GetCVar")
    return f and f(name) or nil
end
function ns.cvSet(name, value)
    if CV and CV.SetCVar then return pcall(CV.SetCVar, name, value) end
    local f = rawget(_G, "SetCVar")
    if f then return pcall(f, name, value) end
end

-- Modules register here and are applied whenever settings change.
ns.modules = {}
function ns:Register(name, module)
    self.modules[name] = module
    return module
end

-- Exposed so the offline harness can drive a settings change.
_G.WicksComfortsApply = function() ns.Apply() end

function ns.Apply()
    for _, m in pairs(ns.modules) do
        if m.Apply then Core.safe(m.Apply, m) end
    end
end

-- Shared event frame; modules ask for what they need.
local events = {}
function ns:On(event, fn)
    events[event] = events[event] or {}
    table.insert(events[event], fn)
end

local frame = CreateFrame("Frame", "WicksComfortsEvents")
ns.eventFrame = frame
frame:SetScript("OnEvent", function(_, event, ...)
    if not events[event] then return end
    for _, fn in ipairs(events[event]) do
        local ok, err = pcall(fn, event, ...)
        if not ok then A:Debug(("error in %s: %s"):format(event, tostring(err))) end
    end
end)
function ns.RegisterEvents(list)
    for _, ev in ipairs(list) do pcall(frame.RegisterEvent, frame, ev) end
end

function ns.db()
    return A.db and A.db.profile or PROFILE_DEFAULTS
end

-- ============================================================
-- Lifecycle
-- ============================================================
function A:OnInitialize()
    ns.dbo = self.db
    self.db:On("OnProfileChanged", function() ns.Apply() end)
end

function A:OnEnable()
    for _, m in pairs(ns.modules) do
        if m.Init then Core.safe(m.Init, m) end
    end
    ns.Apply()
    self:Print("loaded. /wcomfort for the options, everything starts off.")

    self:RegisterLauncher({
        onClick = function(addon) addon:OpenOptions() end,
        tooltip = function(tt)
            tt:AddLine(Core.Chrome:TitleMarkup("Wick's Comforts"))
            tt:AddLine("Click for the options.", 0.5, 0.5, 0.5)
        end,
    })

    self:RegisterOptions(function(page, addon)
        local O = Core.Options
        local db = addon.db.profile
        local function toggle(label, key, y, note)
            y = O:Check(page, label, function() return db[key] == true end,
                function(v) db[key] = v; ns.Apply() end, y)
            if note then y = O:Note(page, note, y) end
            return y
        end

        local y = O:Heading(page, "Minimap", 0)
        y = toggle("Square minimap", "squareMinimap", y)
        y = toggle("Hide the minimap zoom buttons", "hideMinimapZoom", y)
        y = O:Note(page, "This client does not let an addon change the minimap zoom level, so there is no mouse wheel zoom here.", y)

        y = O:Heading(page, "Tooltips", y - 6)
        y = toggle("Item level on items", "tipItemLevel", y)
        y = toggle("Item and spell IDs", "tipIDs", y)
        y = toggle("Class colour on player names", "tipClassColor", y)
        y = toggle("Show what a unit is targeting", "tipTarget", y)

        y = O:Heading(page, "Looting", y - 6)
        y = toggle("Auto loot", "autoLoot", y, "Sets the game's own auto loot setting, so it keeps working when this addon is off.")
        y = toggle("Confirm bind on pickup loot", "confirmBoP", y)

        y = O:Heading(page, "At a vendor", y - 6)
        y = toggle("Repair automatically", "autoRepair", y)
        y = toggle("Use guild funds to repair when allowed", "guildRepair", y)
        y = toggle("Sell junk automatically", "sellJunk", y, "Grey quality items only. Nothing else is ever sold.")

        y = O:Heading(page, "Quests", y - 6)
        y = toggle("Accept quests automatically", "autoAcceptQuests", y)
        y = toggle("Hand quests in automatically", "autoTurnInQuests", y)
        y = O:Note(page, "Hold Shift at any npc to get the normal dialogs back. A quest that offers a choice of rewards is never handed in for you, because there is no way to know which one you wanted.", y)

        y = O:Heading(page, "The camera and the client", y - 6)
        y = toggle("Zoom the camera out further", "maxCameraZoom", y, "Raises the game's own maximum zoom setting to the highest this client accepts.")
        y = toggle("Keep sound playing when the game is in the background", "soundInBackground", y)
        y = toggle("Hide the proc glow on action buttons", "hideProcGlow", y, "The spinning yellow overlay when a spell lights up. The button still changes as it always did; only the overlay goes.")

        y = O:Heading(page, "Unit frames", y - 6)
        y = O:Check(page, "Class colour on health bars", function() return db.classColorHealth == true end,
            function(v) db.classColorHealth = v; ns.Apply() end, y)
        y = O:Note(page, "The game paints every health bar the same green. This colours the player, target, focus, boss and party frames by class. Party and raid frames have a setting of their own, below.", y)
        y = O:Note(page, "Done by laying a bar of ours over Blizzard's rather than recolouring theirs, because changing anything on their unit frames taints them and this client will not let tainted code read health. If you have the numbers turned on inside the bar, they sit behind the colour.", y)
        y = O:Check(page, "Class colour on party and raid frames",
            function() return ns.modules.frames and ns.modules.frames:RaidClassColor() end,
            function(v) if ns.modules.frames then ns.modules.frames:SetRaidClassColor(v) end end, y)
        y = O:Note(page, "This one is the game's own setting, set from here so both live in one place.", y)
        y = O:Button(page, "Move frames", function()
            if ns.modules.frames then ns.modules.frames:OpenEditMode() end
        end, y - 2, 110)
        y = O:Note(page, "Opens the game's Edit Mode, which is what moves Blizzard's frames on this client. Doing it ourselves would taint them and it already saves layouts, so there is nothing to gain.", y)

        y = O:Heading(page, "Client errors", y - 6)
        y = O:Check(page, "Quiet errors the game itself throws", function() return db.clientFixes ~= false end,
            function(v) db.clientFixes = v; ns.Apply() end, y)
        y = O:Note(page, "Only acts where the fault is present. Right now it stands in a frame the Vanilla-style group finder expects and this build never creates, which otherwise throws every time you reload. Switching this off takes effect after a reload.", y)

        y = O:ProfileSection(page, addon, y - 8)
    end)
end

-- ============================================================
-- Slash command
-- ============================================================
A:RegisterSlash(function(_, msg)
    msg = Core.trim((msg or ""):lower())
    if msg == "" or msg == "options" or msg == "config" then A:OpenOptions() return end
    if msg == "status" then
        local db = ns.db()
        local on = {}
        for key, value in pairs(db) do
            if value == true then on[#on + 1] = key end
        end
        table.sort(on)
        A:Print(#on > 0 and ("on: " .. table.concat(on, ", ")) or "everything is off.")
        return
    end
    A:Print("commands: options | status")
end, "/wcomfort", "/wcomforts")
