hs.application.enableSpotlightForNameSearches(true)
hs.window.animationDuration = 0

local BaseKey = {"cmd", "ctrl"}
local HyperKey = {"cmd", "alt", "ctrl"}
local UniversalKey = {"cmd", "alt", "ctrl", "shift"}
local Direction = { Left = "Left", Up = "Up", right = "Right", down = "Down" }

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

hs.hotkey.bind(BaseKey, "M", function()
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h
  window:setFrame(f)
end)

hs.hotkey.bind(BaseKey, "O", function()
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x + (max.w / 6)
  f.y = max.y + (max.h / 6)
  f.w = max.w * 2 / 3
  f.h = max.h * 2 / 3
  window:setFrame(f)
end)

hs.hotkey.bind(BaseKey, "Left", function()
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  window:setFrame(f)
end)

hs.hotkey.bind(BaseKey, "Right", function()
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x + (max.w / 2)
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  window:setFrame(f)
end)

hs.hotkey.bind(BaseKey, "Up", function()
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h / 2
  window:setFrame(f)
end)

hs.hotkey.bind(BaseKey, "Down", function()
  local window = hs.window.focusedWindow()
  local f = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y + (max.h / 2)
  f.w = max.w
  f.h = max.h / 2
  window:setFrame(f)
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
      {"Boostnote",           nil, screen, hs.layout.maximized, nil, nil},
      {"Code",                nil, screen, hs.layout.maximized, nil, nil},
      {"Google Chrome",       nil, screen, hs.layout.maximized, nil, nil},
      {"iTerm2",              nil, screen, nil, nil, centerInParent(hs.geometry.size(1285.0, 798.0), screen:fullFrame())},
      {"Microsoft OneNote",   nil, screen, hs.layout.maximized, nil, nil},
      {"Slack",               nil, screen, hs.layout.maximized, nil, nil},
      {"Sublime Text",        nil, screen, hs.layout.maximized, nil, nil},
      {"Xcode",               nil, screen, hs.layout.maximized, nil, nil},
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
