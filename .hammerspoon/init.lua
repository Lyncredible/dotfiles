hs.application.enableSpotlightForNameSearches(true)

hs.hotkey.bind({"cmd", "alt"}, "M", function()
  local win = hs.window.focusedWindow()
  win:maximize()
end)

hs.hotkey.bind({"cmd", "alt"}, "O", function()
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

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Left", function()
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

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Right", function()
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

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Up", function()
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

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Down", function()
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

hs.hotkey.bind({"cmd", "alt"}, "Left", function()
  local win = hs.window.focusedWindow()
  retainSize = shouldRetainSizeAcrossScreen(win)
  ensureInScreenBounds = false
  win:moveOneScreenWest(retainSize, ensureInScreenBounds)
  if retainSize then
    win:centerOnScreen()
  end
end)

hs.hotkey.bind({"cmd", "alt"}, "Right", function()
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

hs.hotkey.bind({"cmd", "alt"}, "P", codingLayout)
