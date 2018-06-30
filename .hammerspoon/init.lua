hs.application.enableSpotlightForNameSearches(true)
hs.window.animationDuration = 0

local baseKey = {"cmd", "ctrl"}
local hyperKey = {"cmd", "alt", "ctrl"}

hs.hotkey.bind(baseKey, "S", function()
  hs.spotify.playpause()
end)

hs.hotkey.bind(baseKey, "D", function()
  hs.spotify.displayCurrentTrack()
end)

hs.hotkey.bind(baseKey, "B", function()
  hs.spotify.previous()
end)

hs.hotkey.bind(baseKey, "F", function()
  hs.spotify.next()
end)

hs.hotkey.bind(baseKey, "M", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h
  win:setFrame(f)
end)

hs.hotkey.bind(baseKey, "O", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x + (max.w / 6)
  f.y = max.y + (max.h / 6)
  f.w = max.w * 2 / 3
  f.h = max.h * 2 / 3
  win:setFrame(f)
end)

hs.hotkey.bind(baseKey, "Left", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  win:setFrame(f)
end)

hs.hotkey.bind(baseKey, "Right", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x + (max.w / 2)
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  win:setFrame(f)
end)

hs.hotkey.bind(baseKey, "Up", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h / 2
  win:setFrame(f)
end)

hs.hotkey.bind(baseKey, "Down", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y + (max.h / 2)
  f.w = max.w
  f.h = max.h / 2
  win:setFrame(f)
end)

function shouldRetainSizeAcrossScreen(window)
  app = window:application():name()
  return app == 'iTerm2' or app == 'Terminal'
end

hs.hotkey.bind(hyperKey, "Left", function()
  local win = hs.window.focusedWindow()
  retainSize = shouldRetainSizeAcrossScreen(win)
  ensureInScreenBounds = false
  win:moveOneScreenWest(retainSize, ensureInScreenBounds)
  if retainSize then
    win:centerOnScreen()
  end
end)

hs.hotkey.bind(hyperKey, "Right", function()
  local win = hs.window.focusedWindow()
  local retainSize = shouldRetainSizeAcrossScreen(win)
  local ensureInScreenBounds = false
  win:moveOneScreenEast(retainSize, ensureInScreenBounds)
  if retainSize then
    win:centerOnScreen()
  end
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
  }
  hs.layout.apply(windowLayout)
end

hs.hotkey.bind(baseKey, "P", codingLayout)

local screenWatcher = hs.screen.watcher.new(codingLayout)
screenWatcher:start()

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

hs.hotkey.bind(baseKey, "K", toggleKSheet)

spoon.SpoonInstall:andUse("ReloadConfiguration", {fn = function()
  spoon.ReloadConfiguration:start()
end})
