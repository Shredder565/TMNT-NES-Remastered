-- TMNT movement logger for Mesen (Debug > Script Window).
-- Shows the turtle's position and speed on screen and records one line per
-- frame while you are in a side-scrolling area.
-- RAM addresses are from the Data Crystal RAM map for TMNT (NES).

local ADDR = {
  state = 0x001B, substate = 0x001C, held = 0x0032, turtle = 0x0067,
  area = 0x005D, scrollX = 0x00FC, scrollY = 0x00FD,
  y = 0x0460, x = 0x0480, yVel = 0x04B0, xVel = 0x04E0, duckAttack = 0x00D4,
}
local MAX_LINES = 7200          -- two minutes at 60 frames per second

-- Mesen has renamed its memory types between versions, so try each name.
local memType = nil
for _, name in ipairs({ "nesInternalRam", "nesDebug", "cpuDebug", "nesMemory", "cpu" }) do
  if emu.memType[name] ~= nil then memType = emu.memType[name]; break end
end

local function rd(a) return emu.read(a, memType) end

-- Try to write a file. If Mesen blocks file access, fall back to the log
-- panel at the bottom of the script window.
local file, filePath = nil, nil
if io ~= nil and emu.getScriptDataFolder ~= nil then
  local ok, folder = pcall(emu.getScriptDataFolder)
  if ok and folder ~= nil and folder ~= "" then
    filePath = folder .. "/tmnt_movement_log.csv"
    file = io.open(filePath, "w")
  end
end

local HEADER = "frame,area,state,substate,turtle,held,x,y,xvel,yvel,scrollx,scrolly,duckattack"
local function out(line)
  if file ~= nil then file:write(line .. "\n") else emu.log(line) end
end

if memType == nil then
  emu.log("Could not find a memory type this Mesen version understands.")
else
  if file ~= nil then emu.log("Recording to: " .. filePath)
  else emu.log("File access is off, so lines are printed here. Copy them from this panel.") end
  out(HEADER)

  local frame, lines = 0, 0
  emu.addEventCallback(function()
    frame = frame + 1
    local area = rd(ADDR.area)
    local x, y = rd(ADDR.x), rd(ADDR.y)
    local xv, yv = rd(ADDR.xVel), rd(ADDR.yVel)
    emu.drawString(4, 4, string.format("X %3d Y %3d  XV %02X YV %02X", x, y, xv, yv), 0xFFFFFF, 0x000000)
    if area ~= 0 and lines < MAX_LINES then
      lines = lines + 1
      out(string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
        frame, area, rd(ADDR.state), rd(ADDR.substate), rd(ADDR.turtle), rd(ADDR.held),
        x, y, xv, yv, rd(ADDR.scrollX), rd(ADDR.scrollY), rd(ADDR.duckAttack)))
      if file ~= nil and lines % 60 == 0 then file:flush() end
      if lines == MAX_LINES then
        emu.log("Reached the line limit. Recording stopped.")
        if file ~= nil then file:close(); file = nil end
      end
    end
  end, emu.eventType.endFrame)
end
