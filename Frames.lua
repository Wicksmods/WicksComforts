-- Wick's Comforts
-- Frames.lua: colour on the unit frames, and a way to the one that moves them.
--
-- Moving Blizzard's frames is not here on purpose. This client has Edit
-- Mode, which does it properly and knows how to save a layout, and
-- dragging a protected frame from an addon taints it. So the option
-- below opens theirs rather than competing with it.
--
-- Colour is a different matter. UnitFrameHealthBar_Update paints every
-- bar a flat green regardless of who it belongs to, and the class colour
-- setting the game does have only covers the party and raid frames. The
-- player, target, focus and boss frames are left out, which is the gap
-- this fills.

local ADDON, ns = ...
local Core = ns.Core
local F = ns:Register("frames", {})

local function classColor(unit)
    if not UnitIsPlayer or not UnitIsPlayer(unit) then return nil end
    local _, class = UnitClass(unit)
    if not class then return nil end
    local colors = rawget(_G, "RAID_CLASS_COLORS")
    local c = colors and colors[class]
    if not c then return nil end
    return c.r, c.g, c.b
end

-- Hooking UnitFrameHealthBar_Update was the obvious way and it does not
-- work: Blizzard's own callers reach it through a local reference, so a
-- hook on the global never fires. A target frame stayed green.
--
-- Their update has a door built into it instead. It only repaints a bar
-- when lockColor is unset, so setting the colour and raising that flag
-- makes the colour stick without hooking anything and without our taint
-- going anywhere near their code.

local FRAMES = {
    { "PlayerFrame", "player" },
    { "TargetFrame", "target" },
    { "FocusFrame",  "focus"  },
    { "Boss1TargetFrame", "boss1" }, { "Boss2TargetFrame", "boss2" },
    { "Boss3TargetFrame", "boss3" }, { "Boss4TargetFrame", "boss4" },
    { "Boss5TargetFrame", "boss5" },
    { "PartyMemberFrame1", "party1" }, { "PartyMemberFrame2", "party2" },
    { "PartyMemberFrame3", "party3" }, { "PartyMemberFrame4", "party4" },
}

-- The bar hangs off the frame under several names depending on which
-- template built it, so try each rather than assume one.
local function healthBarOf(frame)
    if not frame then return nil end
    if frame.healthbar then return frame.healthbar end
    if frame.HealthBar then return frame.HealthBar end
    local content = frame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    if main and main.HealthBar then return main.HealthBar end
    return nil
end
F.HealthBarOf = healthBarOf

-- Party and raid frames already have a setting for this, so use theirs
-- rather than painting over the top of it.
local RAID_CVAR = "raidFramesDisplayClassColor"

function F:SetRaidClassColor(on)
    local set = (C_CVar and C_CVar.SetCVar) or rawget(_G, "SetCVar")
    if not set then return false end
    local ok = pcall(set, RAID_CVAR, on and "1" or "0")
    if ok and CompactRaidFrameContainer and CompactRaidFrameContainer.TryUpdate then
        pcall(CompactRaidFrameContainer.TryUpdate, CompactRaidFrameContainer)
    end
    return ok
end

function F:RaidClassColor()
    local get = (C_CVar and C_CVar.GetCVarBool) or rawget(_G, "GetCVarBool")
    if not get then return false end
    local ok, v = pcall(get, RAID_CVAR)
    return ok and v or false
end

-- Blizzard's own frame mover. Theirs saves layouts and knows which
-- frames are safe to move; ours would only taint them.
function F:OpenEditMode()
    local mgr = rawget(_G, "EditModeManagerFrame")
    if not mgr then
        ns.A:Print("this client has no Edit Mode to open.")
        return false
    end
    if mgr.CanEnterEditMode and not mgr:CanEnterEditMode() then
        ns.A:Print("Edit Mode cannot be opened right now, usually because you are in combat.")
        return false
    end
    local show = rawget(_G, "ShowUIPanel")
    if show then pcall(show, mgr) else pcall(mgr.Show, mgr) end
    return true
end

-- Never call UnitFrameHealthBar_Update ourselves.
--
-- Health is a secret value on this client. Blizzard's own code may
-- compare one; ours may not, and anything it calls inherits our taint.
-- Asking their function to redraw a bar therefore blows up inside their
-- text formatter with "attempt to compare a secret number value",
-- pointing at us. Colour is the only thing we have any business
-- touching, so repainting means setting the colour and nothing else.

function F:Repaint()
    local on = ns.db().classColorHealth
    for _, def in ipairs(FRAMES) do
        local bar = healthBarOf(rawget(_G, def[1]))
        local unit = (bar and bar.unit) or def[2]
        if bar and UnitExists and UnitExists(unit) and not bar.disconnected then
            if on then
                local r, g, b = classColor(unit)
                if r then
                    bar:SetStatusBarColor(r, g, b)
                    -- Tell their update to leave it alone from here.
                    if bar.wicksLocked == nil then bar.wicksLocked = bar.lockColor or false end
                    bar.lockColor = true
                end
            elseif bar.wicksLocked ~= nil then
                -- Hand the bar back exactly as it was found.
                bar.lockColor = bar.wicksLocked or nil
                bar.wicksLocked = nil
                bar:SetStatusBarColor(0, 1, 0)
            end
        end
    end
end

function F:Apply()
    self:Repaint()
end

function F:Init()
    self:Apply()
    ns.RegisterEvents({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "GROUP_ROSTER_UPDATE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_ENTERING_WORLD" })
    local function repaint() Core.safe(F.Apply, F) end
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "GROUP_ROSTER_UPDATE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_ENTERING_WORLD" }) do
        ns:On(e, repaint)
    end
end
