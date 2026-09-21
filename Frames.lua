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

-- Repaint after Blizzard has painted. Hooked rather than replaced, so
-- their own logic for disconnected players and locked bars still runs
-- and we only override the colour it landed on.
function F:Paint(bar, unit)
    if not bar or not unit then return end
    if ns.db().classColorHealth == false then return end
    -- lockColor is Blizzard telling their own update to leave the colour
    -- alone, which the player frame sets permanently. Honouring it would
    -- mean never colouring the one frame you look at most, so it is
    -- exactly the flag this feature exists to override. Disconnected is
    -- different: grey means something.
    if bar.disconnected then return end
    local r, g, b = classColor(unit)
    if r then bar:SetStatusBarColor(r, g, b) end
end

function F:HookHealthBars()
    if self.hooked then return end
    local fn = rawget(_G, "UnitFrameHealthBar_Update")
    if type(fn) ~= "function" then return false end
    self.hooked = true
    hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit)
        Core.safe(F.Paint, F, bar, unit)
    end)
    -- The value changing repaints the bar too, so catch that as well or
    -- the colour flickers back to green as the health moves.
    local onValue = rawget(_G, "UnitFrameHealthBar_OnValueChanged")
    if type(onValue) == "function" then
        hooksecurefunc("UnitFrameHealthBar_OnValueChanged", function(bar)
            Core.safe(F.Paint, F, bar, bar and bar.unit)
        end)
    end
    return true
end

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
local FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame" }

function F:Repaint()
    local on = ns.db().classColorHealth
    for _, name in ipairs(FRAMES) do
        local frame = rawget(_G, name)
        local bar = frame and frame.healthbar
        if bar and bar.unit and not bar.disconnected then
            if on then
                self:Paint(bar, bar.unit)
            else
                -- Back to the flat green Blizzard uses for anyone alive
                -- and connected, without going through their code.
                bar:SetStatusBarColor(0, 1, 0)
            end
        end
    end
end

function F:Apply()
    if ns.db().classColorHealth then
        self:HookHealthBars()
    end
    self:Repaint()
end

function F:Init()
    self:Apply()
    ns.RegisterEvents({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE" })
    local function repaint() Core.safe(F.Apply, F) end
    ns:On("PLAYER_TARGET_CHANGED", repaint)
    ns:On("PLAYER_FOCUS_CHANGED", repaint)
    ns:On("GROUP_ROSTER_UPDATE", repaint)
end
