hs.application.enableSpotlightForNameSearches(true)

local baseKey = {"cmd", "ctrl"}
local hyperKey = {"cmd", "alt", "ctrl"}

hs.hotkey.bind(baseKey, "M", function()
  local win = hs.window.focusedWindow()
  win:maximize()
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

hs.hotkey.bind(hyperKey, "Left", function()
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

hs.hotkey.bind(hyperKey, "Right", function()
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

hs.hotkey.bind(hyperKey, "Up", function()
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

hs.hotkey.bind(hyperKey, "Down", function()
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

hs.hotkey.bind(baseKey, "Left", function()
  local win = hs.window.focusedWindow()
  retainSize = shouldRetainSizeAcrossScreen(win)
  ensureInScreenBounds = false
  win:moveOneScreenWest(retainSize, ensureInScreenBounds)
  if retainSize then
    win:centerOnScreen()
  end
end)

hs.hotkey.bind(baseKey, "Right", function()
  local win = hs.window.focusedWindow()
  local retainSize = shouldRetainSizeAcrossScreen(win)
  local ensureInScreenBounds = false
  win:moveOneScreenEast(retainSize, ensureInScreenBounds)
  if retainSize then
    win:centerOnScreen()
  end
end)

function codingLayout()
  local screen = hs.screen.primaryScreen()
  local windowLayout = {
      {"Code",                nil, screen, hs.layout.maximized, nil, nil},
      {"Slack",               nil, screen, hs.layout.maximized, nil, nil},
      {"Google Chrome",       nil, screen, hs.layout.maximized, nil, nil},
      {"Microsoft OneNote",   nil, screen, hs.layout.maximized, nil, nil},
  }
  hs.layout.apply(windowLayout)
end

hs.hotkey.bind(baseKey, "P", codingLayout)

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
