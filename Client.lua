-- Wick's Comforts
-- Client.lua: settings the game has but does not put in its own panel.
--
-- Both of these are console variables. Driving the variable rather than
-- reimplementing the behaviour means they survive this addon being
-- disabled, and nothing here fights Blizzard's own options.

local ADDON, ns = ...
local Core = ns.Core
local C = ns:Register("client", {})

local ZOOM  = "cameraDistanceMaxZoomFactor"
local SOUND = "Sound_EnableSoundWhenGameIsInBG"

-- The client refuses a factor above its own ceiling, and the ceiling has
-- moved between expansions. Walk down from the highest any build has
-- allowed and keep the first one that sticks.
local CANDIDATES = { 4.0, 3.4, 2.6, 1.9 }

function C:MaxZoom()
    local best = self.found
    if best then return best end
    for _, v in ipairs(CANDIDATES) do
        ns.cvSet(ZOOM, tostring(v))
        local got = tonumber(ns.cvGet(ZOOM) or "")
        if got and math.abs(got - v) < 0.01 then
            self.found = v
            return v
        end
    end
    return nil
end

function C:Apply()
    local db = ns.db()

    if db.maxCameraZoom then
        local v = self:MaxZoom()
        if v and tonumber(ns.cvGet(ZOOM) or "") ~= v then ns.cvSet(ZOOM, tostring(v)) end
    elseif self.found then
        -- Only put it back if we were the one who moved it.
        ns.cvSet(ZOOM, "1")
        self.found = nil
    end

    if db.soundInBackground then
        if ns.cvGet(SOUND) ~= "1" then ns.cvSet(SOUND, "1") end
    end
end

function C:Init()
    -- The camera factor is reset on some loading screens, so put it back
    -- once the world is there rather than only at login.
    ns.RegisterEvents({ "PLAYER_ENTERING_WORLD" })
    ns:On("PLAYER_ENTERING_WORLD", function() Core.safe(C.Apply, C) end)
end
