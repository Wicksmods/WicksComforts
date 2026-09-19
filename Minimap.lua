-- Wick's Comforts
-- Minimap.lua: square minimap.
--
-- Reshaping is just a mask swap, which addons are still allowed to do.
-- Zooming is not: Minimap:SetZoom carries restrictions on this client, so
-- there is no mouse wheel zoom here and the options page says why.

local ADDON, ns = ...
local M = ns:Register("minimap", {})

local SQUARE = "Interface\\BUTTONS\\WHITE8X8"
local ROUND  = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- The blob rings are drawn to a circle, so they bleed past a square mask.
-- Scaling them down is what every square-minimap addon does.
local function setBlobScalars(scalar)
    if not Minimap then return end
    if Minimap.SetQuestBlobRingScalar then pcall(Minimap.SetQuestBlobRingScalar, Minimap, scalar) end
    if Minimap.SetArchBlobRingScalar  then pcall(Minimap.SetArchBlobRingScalar,  Minimap, scalar) end
    if Minimap.SetTaskBlobRingScalar  then pcall(Minimap.SetTaskBlobRingScalar,  Minimap, scalar) end
end

local zoomButtons = { "MinimapZoomIn", "MinimapZoomOut", "MinimapZoomInButton", "MinimapZoomOutButton" }

-- Only ever touch what has been asked for, and only put something back if
-- this addon is what changed it. A switched-off comfort must leave the
-- frame exactly as another addon or Blizzard left it.
function M:Apply()
    if not Minimap then return end
    local db = ns.db()

    if db.squareMinimap then
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, SQUARE) end
        setBlobScalars(0)
        local border = rawget(_G, "MinimapBorder")
        if border then border:Hide() end
        self.shaped = true
    elseif self.shaped then
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, ROUND) end
        setBlobScalars(1)
        local border = rawget(_G, "MinimapBorder")
        if border then border:Show() end
        self.shaped = false
    end

    if db.hideMinimapZoom then
        for _, name in ipairs(zoomButtons) do
            local b = rawget(_G, name)
            if b then b:Hide() end
        end
        self.hidZoom = true
    elseif self.hidZoom then
        for _, name in ipairs(zoomButtons) do
            local b = rawget(_G, name)
            if b then b:Show() end
        end
        self.hidZoom = false
    end
end

function M:Init()
    -- Other addons and Blizzard's own code reshape the minimap on zone
    -- changes, so reassert after those.
    ns.RegisterEvents({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "MINIMAP_UPDATE_ZOOM" })
    local function reassert() if ns.db().squareMinimap then M:Apply() end end
    ns:On("PLAYER_ENTERING_WORLD", reassert)
    ns:On("ZONE_CHANGED_NEW_AREA", reassert)
    ns:On("MINIMAP_UPDATE_ZOOM", reassert)
end
