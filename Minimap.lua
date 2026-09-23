-- Wick's Comforts
-- Minimap.lua: square minimap.
--
-- Reshaping is a mask swap, which addons are still allowed to do. Zooming
-- is not: Minimap:SetZoom carries restrictions on this client, so there is
-- no mouse wheel zoom here and the options page says why.
--
-- The two clients are built differently. Forever's minimap lives inside
-- MinimapCluster.MinimapContainer, its round ring is an atlas on
-- MinimapCompassTexture, and Blizzard sets the mask from an atlas of their
-- own whenever the rotate setting changes. TBC has the older MinimapBorder
-- and a file-path mask. Both are handled here.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local M = ns:Register("minimap", {})
local Chrome = ns.Core.Chrome

local SQUARE = "Interface\\BUTTONS\\WHITE8X8"

-- Forever ships the compass ring; its absence means the older layout.
local function isModernMinimap() return rawget(_G, "MinimapCompassTexture") ~= nil end

local function roundMask()
    if isModernMinimap() then return "ui-hud-minimap-frame-generic-mask" end
    return "Interface\\CharacterFrame\\TempPortraitAlphaMask"
end

-- Every piece of round frame art, whichever client this is.
local function ringArt()
    local out = {}
    for _, name in ipairs({ "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapBorder" }) do
        local t = rawget(_G, name)
        if t then out[#out + 1] = t end
    end
    return out
end

-- The blob rings are drawn to a circle, so they bleed past a square mask.
local function setBlobScalars(scalar)
    if not Minimap then return end
    if Minimap.SetQuestBlobRingScalar then pcall(Minimap.SetQuestBlobRingScalar, Minimap, scalar) end
    if Minimap.SetArchBlobRingScalar  then pcall(Minimap.SetArchBlobRingScalar,  Minimap, scalar) end
    if Minimap.SetTaskBlobRingScalar  then pcall(Minimap.SetTaskBlobRingScalar,  Minimap, scalar) end
end

-- Forever keeps the zoom controls on the minimap itself; TBC used globals.
local function zoomControls()
    local out = {}
    if Minimap then
        if Minimap.ZoomIn then out[#out + 1] = Minimap.ZoomIn end
        if Minimap.ZoomOut then out[#out + 1] = Minimap.ZoomOut end
    end
    for _, name in ipairs({ "MinimapZoomIn", "MinimapZoomOut" }) do
        local b = rawget(_G, name)
        if b then out[#out + 1] = b end
    end
    return out
end

-- Blizzard sizes the container to their round frame art, which is larger
-- than the map inside it. With the ring hidden that surplus becomes a gap
-- between the map and the zone header, above or below depending on where
-- the header sits. Shrinking the container to the map closes it, and
-- everything anchored to the container follows.
local function mapContainer()
    return MinimapCluster and MinimapCluster.MinimapContainer
end

function M:TightenContainer()
    local c = mapContainer()
    if not c or not Minimap or not Minimap.GetSize then return end
    local w, h = Minimap:GetSize()
    if not w or w <= 0 then return end
    if not self.savedContainerSize then
        self.savedContainerSize = { c:GetSize() }
    end
    c:SetSize(w, h)
end

function M:RestoreContainer()
    local c = mapContainer()
    local saved = self.savedContainerSize
    if c and saved and saved[1] and saved[1] > 0 then
        c:SetSize(saved[1], saved[2])
    end
    self.savedContainerSize = nil
end

-- The suite's own frame in place of Blizzard's ring: one thin border and
-- fel L-brackets, the same chrome every Wick panel wears. Built on
-- Chrome so it follows the active theme without any work here.
function M:EnsureBorder()
    if self.border or not Minimap then return self.border end
    local f = CreateFrame("Frame", "WicksComfortsMinimapChrome", Minimap)
    f:SetAllPoints(Minimap)
    -- Above the map art and its blips, below anything Blizzard floats over.
    if Minimap.GetFrameLevel then f:SetFrameLevel(Minimap:GetFrameLevel() + 5) end
    Chrome:AddBorder(f)
    Chrome:AddBrackets(f)
    f:Hide()
    self.border = f
    return f
end

-- Only ever touch what has been asked for, and only put something back if
-- this addon is what changed it. A switched-off comfort must leave the
-- frame exactly as another addon or Blizzard left it.
function M:Apply()
    if not Minimap then return end
    local db = ns.db()

    if db.squareMinimap then
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, SQUARE) end
        setBlobScalars(0)
        for _, t in ipairs(ringArt()) do t:Hide() end
        local chrome = self:EnsureBorder()
        if chrome then chrome:Show() end
        self:TightenContainer()
        self.shaped = true
    elseif self.shaped then
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, roundMask()) end
        setBlobScalars(1)
        for _, t in ipairs(ringArt()) do t:Show() end
        if self.border then self.border:Hide() end
        self:RestoreContainer()
        self.shaped = false
    end

    if db.hideMinimapZoom then
        for _, b in ipairs(zoomControls()) do b:Hide() end
        self.hidZoom = true
    elseif self.hidZoom then
        for _, b in ipairs(zoomControls()) do b:Show() end
        self.hidZoom = false
    end
end

function M:Init()
    -- Blizzard reapplies their own mask and ring art when the rotate
    -- setting changes, and other addons reshape on zone changes, so the
    -- square has to be reasserted after all of it.
    ns.RegisterEvents({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "MINIMAP_UPDATE_ZOOM", "CVAR_UPDATE" })
    local function reassert()
        if ns.db().squareMinimap then
            self.shaped = false   -- force a fresh application
            M:Apply()
        end
    end
    ns:On("PLAYER_ENTERING_WORLD", reassert)
    ns:On("ZONE_CHANGED_NEW_AREA", reassert)
    ns:On("MINIMAP_UPDATE_ZOOM", reassert)
    ns:On("CVAR_UPDATE", function(_, name)
        if name == "rotateMinimap" or name == "ROTATE_MINIMAP" then reassert() end
    end)
end
