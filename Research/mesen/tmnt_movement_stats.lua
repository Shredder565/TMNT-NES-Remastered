-- TMNT movement stats for Mesen (Debug > Script Window, then Run).
-- Measures the turtle's walking and jumping and shows the results on the
-- game screen, so a screenshot is all that is needed. Nothing is saved.
-- RAM addresses are from the Data Crystal RAM map for TMNT (NES).

local ADDR = { area = 0x005D, scrollX = 0x00FC, y = 0x0460, x = 0x0480, yVel = 0x04B0, xVel = 0x04E0 }

local memType = nil
for _, name in ipairs({ "nesInternalRam", "nesDebug", "cpuDebug", "nesMemory", "cpu" }) do
  if emu.memType[name] ~= nil then memType = emu.memType[name]; break end
end
local function rd(a) return emu.read(a, memType) end

-- Difference between two 0-255 values, allowing for wrap-around.
local function wrap(d)
  if d > 127 then return d - 256 end
  if d < -128 then return d + 256 end
  return d
end

local prevX, prevY, prevScroll = nil, nil, nil
local groundY, stillFrames = nil, 0
local WINDOW = 60
local dxHistory, historyPos, historySum = {}, 1, 0
local bestWalk = 0             -- most pixels covered in 60 grounded frames
local xvSeen, yvSeen = {}, {}  -- distinct raw velocity bytes seen
local jump = nil               -- the jump in progress
local jumps = {}               -- finished jumps, newest first

local function note(seen, v)
  if v ~= 0 then seen[v] = true end
end

local function listSeen(seen)
  local t = {}
  for v, _ in pairs(seen) do t[#t + 1] = v end
  table.sort(t)
  local s = ""
  for i = 1, math.min(#t, 8) do s = s .. string.format("%02X ", t[i]) end
  if #t > 8 then s = s .. "+" end
  return s
end

local function line(row, text)
  emu.drawString(2, 2 + row * 9, text, 0xFFFFFF, 0x000000)
end

local function onFrame()
  local x, y, scroll = rd(ADDR.x), rd(ADDR.y), rd(ADDR.scrollX)
  local xv, yv = rd(ADDR.xVel), rd(ADDR.yVel)
  if rd(ADDR.area) == 0 or prevX == nil then
    prevX, prevY, prevScroll = x, y, scroll
    line(0, "Enter a side-scrolling area to measure")
    return
  end

  -- Movement through the level = movement on screen + how far the screen scrolled.
  local dx = wrap(x - prevX) + wrap(scroll - prevScroll)
  local dy = wrap(y - prevY)
  prevX, prevY, prevScroll = x, y, scroll
  note(xvSeen, xv); note(yvSeen, yv)

  -- Standing on the ground = height unchanged for 4 frames in a row.
  if dy == 0 then stillFrames = stillFrames + 1 else stillFrames = 0 end
  local grounded = stillFrames >= 4

  if jump == nil then
    if grounded then groundY = y end
    if groundY ~= nil and dy < 0 then
      jump = { startY = groundY, minY = y, frames = 1, upFrames = 1, dist = dx, dys = { dy }, maxFall = 0 }
    end
  else
    jump.frames = jump.frames + 1
    jump.dist = jump.dist + dx
    if #jump.dys < 16 then jump.dys[#jump.dys + 1] = dy end
    if y < jump.minY then jump.minY = y; jump.upFrames = jump.frames end
    if dy > jump.maxFall then jump.maxFall = dy end
    if grounded then
      jump.frames = jump.frames - 4          -- remove the 4 still frames used to detect landing
      jump.endY = y
      table.insert(jumps, 1, jump)
      if #jumps > 3 then table.remove(jumps) end
      jump = nil
      groundY = y
    end
  end

  -- Walking speed: pixels covered over the last 60 frames spent on the ground.
  if grounded and jump == nil then
    historySum = historySum - (dxHistory[historyPos] or 0) + math.abs(dx)
    dxHistory[historyPos] = math.abs(dx)
    historyPos = historyPos % WINDOW + 1
    if historySum > bestWalk then bestWalk = historySum end
  end

  line(0, string.format("X%3d Y%3d XV%02X YV%02X  walk %d/60f best %d", x, y, xv, yv, historySum, bestWalk))
  line(1, "XV seen " .. listSeen(xvSeen))
  line(2, "YV seen " .. listSeen(yvSeen))
  for i, j in ipairs(jumps) do
    local s = ""
    for _, d in ipairs(j.dys) do s = s .. string.format("%+d", d) end
    line(1 + i * 2, string.format("J%d rise %d up %df air %df dx %d fall %d", i, j.startY - j.minY, j.upFrames, j.frames, j.dist, j.maxFall))
    line(2 + i * 2, "   dy " .. s)
  end
end

if memType == nil then
  emu.log("Could not find a memory type this Mesen version understands.")
else
  emu.log("TMNT movement stats running. Results are drawn on the game screen.")
  emu.addEventCallback(onFrame, emu.eventType.endFrame)
end
