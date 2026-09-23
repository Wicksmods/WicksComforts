# Wick's Comforts - Changelog

## 0.9.1

### Arrow keys move the cursor in chat

This client hands the chat box the old behaviour, where the arrows steer
your character and it takes Alt and an arrow to move the cursor or bring
back what you last typed. Every other text box does the opposite. Off
until you turn it on, under the camera and client heading.

It is a property of each chat window rather than a setting, so it is
applied to all of them and again to any window you open or dock later,
which would otherwise arrive with the client default.

## 0.9.0

One version across the suite for the Forever beta. Every addon carried a
number of its own that said nothing about how finished it was, so they are
aligned here and the suite goes to 1.0.0 together at launch.

## Unreleased

- Class colour on health bars, for the player, target, focus and boss
  frames. The game paints every one the same green, and the class
  colour setting it does have only covers party and raid.
- That party and raid setting is now reachable from our options too, so
  both live in one place.
- Fixed before anyone else saw it: calling Blizzard's health bar update
  to repaint threw inside their text formatter, because health is a
  secret value and our taint made their comparison illegal. Repainting
  now sets the colour and touches nothing else.
- A button that opens Edit Mode. Moving Blizzard's frames is its job:
  it saves layouts and knows which frames are safe to move, and an
  addon dragging a protected frame only taints it.

## 0.1.0 - 2026-09-19

### First release

Small conveniences, each off until you turn it on. Installing this changes
nothing about your interface until you say so.

- Square minimap, wearing the suite's own chrome: one thin border and
  fel L-brackets in place of Blizzard's ring, following whichever theme
  you have set. The quest blob rings are squared off to match and the
  zoom buttons can be hidden.
- Tooltips: item level on equipment, item and spell IDs, class colour on
  player names, and what a unit is currently targeting.
- Auto loot, driven through the game's own setting so it keeps working
  even with this addon disabled. Optional bind on pickup confirmation.
- At a vendor: repair on arrival, optionally from guild funds, and sell
  grey items. Nothing above poor quality is ever sold, and the total is
  reported in chat.

Requires WickCore. Runs on TBC Anniversary and on Forever.

Note for Forever: the client does not allow an addon to change the
minimap zoom level, so there is no mouse wheel zoom here.
