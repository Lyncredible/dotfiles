hs.application.enableSpotlightForNameSearches(true)
hs.window.animationDuration = 0

local BaseKey = {"cmd", "ctrl"}
local HyperKey = {"cmd", "alt", "ctrl"}
local UniversalKey = {"cmd", "alt", "ctrl", "shift"}
local Direction = { Left = "Left", Up = "Up", Right = "Right", Down = "Down" }
local SnapTo = {
  Left = "Left",
  Right = "Right",
  Top = "Top",
  Bottom = "Bottom",
  Max = "Max",
  Center = "Center",
  Middle = "Middle",
  LeftThird = "LeftThird",
  LeftTwoThirds = "LeftTwoThirds",
  RightThird = "RightThird",
  RightTwoThirds = "RightTwoThirds"
}

function toggleAudioVideo(audioOrVideo)
  local zoom = hs.application.find("us.zoom.xos")
  local teams = hs.application.find("com.microsoft.teams")
  if not (zoom == nil) then
    if audioOrVideo == "audio" then
      hs.eventtap.keyStroke({"cmd","shift"}, "a", 0, zoom)
    else
      hs.eventtap.keyStroke({"cmd","shift"}, "v", 0, zoom)
    end
  end
  if not (teams == null) then
    if audioOrVideo == "audio" then
      hs.eventtap.keyStroke({"cmd","shift"}, "m", 0, teams)
    else
      hs.eventtap.keyStroke({"cmd","shift"}, "o", 0, teams)
    end
  end
end

hs.hotkey.bind(BaseKey, "A", function()
  toggleAudioVideo("audio")
end)

hs.hotkey.bind(BaseKey, "V", function()
  toggleAudioVideo("video")
end)

hs.hotkey.bind(BaseKey, "S", function()
  hs.spotify.playpause()
end)

hs.hotkey.bind(BaseKey, "D", function()
  hs.spotify.displayCurrentTrack()
end)

hs.hotkey.bind(BaseKey, "B", function()
  hs.spotify.previous()
end)

hs.hotkey.bind(BaseKey, "F", function()
  hs.spotify.next()
end)

function snapWindowTo(window, snapTo)
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h

  local ultraWideRatio = 21.0 / 9.0
  local widthFactor = 2.0 / 3.0
  if max.w / max.h >= ultraWideRatio then
    widthFactor = 16.0 / (max.w / max.h * 9.0)
  end

  if snapTo == SnapTo.Left then
    f.w = max.w / 2    
  elseif snapTo == SnapTo.Right then
    f.x = max.x + max.w / 2
    f.w = max.w - (f.x - max.x)
  elseif snapTo == SnapTo.Top then
    f.h = max.h / 2
  elseif snapTo == SnapTo.Bottom then
    f.y = max.y + max.h / 2
    f.h = max.h - (f.y - max.y)
  elseif snapTo == SnapTo.Max then
    -- Do nothing
  elseif snapTo == SnapTo.Center then
    f.h = max.h * 3 // 4
    f.w = f.h / 9 * 16
    f.x = max.x + (max.w - f.w) / 2
    f.y = max.y + (max.h - f.h) / 2
  elseif snapTo == SnapTo.Middle then
    f.w = max.w * widthFactor
    f.x = max.x + (max.w - f.w) / 2
  elseif snapTo == SnapTo.LeftThird then
    f.w = max.w - max.w * widthFactor
  elseif snapTo == SnapTo.RightThird then
    f.w = max.w - max.w * widthFactor
    f.x = max.x + (max.w - f.w)
  elseif snapTo == SnapTo.LeftTwoThirds then
    f.w = max.w * widthFactor
  elseif snapTo == SnapTo.RightTwoThirds then
    f.w = max.w * widthFactor
    f.x = max.x + (max.w - f.w)
  end

  window:setFrame(f)
end

function snapCurrentWindowTo(snapTo)
  local window = hs.window.focusedWindow()
  snapWindowTo(window, snapTo)
end

hs.hotkey.bind(BaseKey, "M", function()
  snapCurrentWindowTo(SnapTo.Max)
end)

hs.hotkey.bind(BaseKey, "O", function()
  snapCurrentWindowTo(SnapTo.Middle)
end)

hs.hotkey.bind(BaseKey, "C", function()
  snapCurrentWindowTo(SnapTo.Center)
end)

hs.hotkey.bind(BaseKey, "Left", function()
  snapCurrentWindowTo(SnapTo.Left)
end)

hs.hotkey.bind(BaseKey, "Right", function()
  snapCurrentWindowTo(SnapTo.Right)
end)

hs.hotkey.bind(BaseKey, "Up", function()
  snapCurrentWindowTo(SnapTo.Top)
end)

hs.hotkey.bind(BaseKey, "Down", function()
  snapCurrentWindowTo(SnapTo.Bottom)
end)

hs.hotkey.bind(BaseKey, "[", function()
  snapCurrentWindowTo(SnapTo.LeftTwoThirds)
end)

hs.hotkey.bind(BaseKey, "]", function()
  snapCurrentWindowTo(SnapTo.RightThird)
end)

hs.hotkey.bind(BaseKey, ",", function()
  snapCurrentWindowTo(SnapTo.LeftThird)
end)

hs.hotkey.bind(BaseKey, ".", function()
  snapCurrentWindowTo(SnapTo.RightTwoThirds)
end)

function shouldRetainSizeAcrossScreen(window)
  app = window:application():name()
  return app == 'iTerm2' or app == 'Terminal'
end

function moveWindowOneScreen(window, direction)
  retainSize = shouldRetainSizeAcrossScreen(window)
  ensureInScreenBounds = false

  if direction == Direction.Left then
    window:moveOneScreenWest(retainSize, ensureInScreenBounds)
  elseif direction == Direction.Right then
    window:moveOneScreenEast(retainSize, ensureInScreenBounds)
  elseif direction == Direction.Up then
    window:moveOneScreenNorth(retainSize, ensureInScreenBounds)
  elseif direction == Direction.Down then
    window:moveOneScreenSouth(retainSize, ensureInScreenBounds)
  end

  if retainSize then
    window:centerOnScreen()
  end
end

function moveAllWindowsOneScreen(direction)
  local windows = hs.window.allWindows()
  hs.fnutils.each(windows, function(window)
    moveWindowOneScreen(window, direction)
  end)
end

hs.hotkey.bind(HyperKey, "Left", function()
  local window = hs.window.focusedWindow()
  moveWindowOneScreen(window, Direction.Left)
end)

hs.hotkey.bind(HyperKey, "Right", function()
  local window = hs.window.focusedWindow()
  moveWindowOneScreen(window, Direction.Right)
end)

hs.hotkey.bind(HyperKey, "Up", function()
  local window = hs.window.focusedWindow()
  moveWindowOneScreen(window, Direction.Up)
end)

hs.hotkey.bind(HyperKey, "Down", function()
  local window = hs.window.focusedWindow()
  moveWindowOneScreen(window, Direction.Down)
end)

hs.hotkey.bind(UniversalKey, "Left", function()
  moveAllWindowsOneScreen(Direction.Left)
end)

hs.hotkey.bind(UniversalKey, "Right", function()
  moveAllWindowsOneScreen(Direction.Right)
end)

hs.hotkey.bind(UniversalKey, "Up", function()
  moveAllWindowsOneScreen(Direction.Up)
end)

hs.hotkey.bind(UniversalKey, "Down", function()
  moveAllWindowsOneScreen(Direction.Down)
end)

function centerInParent(size, parentRect)
  local left = (parentRect.x1 + parentRect.x2 - size.w) / 2.0
  local top = (parentRect.y1 + parentRect.y2 - size.h) / 2.0
  return hs.geometry.rect(left, top, size.w, size.h)
end

function codingLayout()
  local screen = hs.screen.primaryScreen()
  local windowLayout = {
      {"Code",                nil, screen, hs.layout.maximized, nil, nil},
      {"Google Chrome",       nil, screen, hs.layout.maximized, nil, nil},
      {"iTerm2",              nil, screen, nil, nil, centerInParent(hs.geometry.size(1285.0, 798.0), screen:fullFrame())},
      {"Microsoft OneNote",   nil, screen, hs.layout.maximized, nil, nil},
      {"Slack",               nil, screen, hs.layout.maximized, nil, nil},
      {"Sublime Text",        nil, screen, hs.layout.maximized, nil, nil},
  }
  hs.layout.apply(windowLayout)
end

hs.hotkey.bind(BaseKey, "P", codingLayout)

hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall:andUse("KSheet", {fn = function()
  spoon.KSheet.visible = false
end})

function toggleKSheet()
  if spoon.KSheet.visible then
    spoon.KSheet:hide()
    spoon.KSheet.visible = false
  else
    spoon.KSheet:show()
    spoon.KSheet.visible = true
  end
end

hs.hotkey.bind(BaseKey, "K", toggleKSheet)

spoon.SpoonInstall:andUse("ReloadConfiguration", {fn = function()
  spoon.ReloadConfiguration:start()
end})
