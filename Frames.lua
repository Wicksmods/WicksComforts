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

-- Two attempts at this were wrong, and both are worth writing down.
--
-- Hooking UnitFrameHealthBar_Update does nothing: Blizzard reaches it
-- through a local reference, so a hook on the global never fires.
--
-- Their update has a door in it, lockColor, and using it broke the game.
-- Setting a field on a frame Blizzard created puts a tainted value in
-- their table. When their code reads it the execution becomes tainted,
-- and the next thing it does is compare secret health in the status text
-- formatter, which is illegal for tainted code. Every target change threw
-- from inside TextStatusBar, blaming us.
--
-- So the rule here is that we never write to their frames, never call a
-- method on them, and never ask them to redraw. We put a bar of our own
-- on top and keep it in step by reading theirs. Reading is free. Their
-- bar is still underneath doing exactly what it always did; ours is the
-- one you see, and it is coloured by class.
--
-- The value, minimum and maximum are secret numbers. They are handed
-- straight from their bar to ours and never compared, which is the one
-- thing allowed with a secret.

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

-- A flat fill, not a copy of theirs. Their bar is drawn from an atlas,
-- so asking for its texture hands back the whole sheet: setting that on
-- a bar of ours drew the sheet's stripes across the health bar. A solid
-- block tinted to the class colour is both correct and the house style.
local FILL = "Interface\\BUTTONS\\WHITE8X8"

-- Ours, parented to theirs so it inherits their position, their size and
-- whether they are shown at all. Creating a child is not a write to the
-- parent; nothing about their table changes.
local overlays = setmetatable({}, { __mode = "k" })

local function overlayFor(bar)
    local ov = overlays[bar]
    if ov then return ov end
    ov = CreateFrame("StatusBar", nil, bar)
    ov:SetAllPoints(bar)
    ov:SetFrameLevel(bar:GetFrameLevel() + 1)
    ov:SetStatusBarTexture(FILL)
    ov:Hide()
    overlays[bar] = ov
    return ov
end
F.OverlayFor = overlayFor

-- The only place the secrets are handled, and they are only moved.
local function follow(ov, bar)
    local mn, mx = bar:GetMinMaxValues()
    ov:SetMinMaxValues(mn, mx)
    ov:SetValue(bar:GetValue())
end

-- Party and raid frames already have a setting for this, so use theirs
-- rather than painting over the top of it.
local RAID_CVAR = "raidFramesDisplayClassColor"

-- Set the variable and nothing else. Asking CompactRaidFrameContainer to
-- refresh from here ran their update in our execution: the needsUpdate
-- flag it wrote onto every compact frame was a tainted value, their
-- OnUpdate read it, and the next line compared a secret colour component
-- and threw, blaming us. Blizzard's own CVar handler does the refresh.
function F:SetRaidClassColor(on)
    local set = (C_CVar and C_CVar.SetCVar) or rawget(_G, "SetCVar")
    if not set then return false end
    return (pcall(set, RAID_CVAR, on and "1" or "0"))
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

function F:Repaint()
    local on = ns.db().classColorHealth
    local live = false
    for _, def in ipairs(FRAMES) do
        local bar = healthBarOf(rawget(_G, def[1]))
        if bar then
            local unit = bar.unit or def[2]
            local r, g, b
            if on and UnitExists and UnitExists(unit) and bar:IsShown() then
                r, g, b = classColor(unit)
            end
            if r then
                local ov = overlayFor(bar)
                ov:SetStatusBarColor(r, g, b)
                follow(ov, bar)
                ov:Show()
                live = true
            else
                local ov = overlays[bar]
                if ov then ov:Hide() end
            end
        end
    end
    self.live = live
    return live
end

-- Health moves constantly and the only way to know is to look, because
-- the events that would tell us carry values we may not read. Following
-- their bar a few times a second is cheap and cannot go out of step.
local TICK = 0.05

function F:Tick()
    for bar, ov in pairs(overlays) do
        if ov:IsShown() then
            if bar:IsShown() then follow(ov, bar) else ov:Hide() end
        end
    end
end

function F:Apply()
    self:Repaint()
    local driver = self.driver
    if not driver then
        driver = CreateFrame("Frame")
        self.driver = driver
        driver.elapsed = 0
        driver:SetScript("OnUpdate", function(d, dt)
            d.elapsed = d.elapsed + dt
            if d.elapsed < TICK then return end
            d.elapsed = 0
            Core.safe(F.Tick, F)
        end)
    end
    -- Nothing coloured means nothing to follow, so stop looking.
    if self.live then driver:Show() else driver:Hide() end
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
