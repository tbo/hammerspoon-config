local fun = require('fun')
local map = fun.map
local iter = fun.iter
local each = fun.each
local range = fun.range
local debug = false
-- local primaryApplications = {'com.google.Chrome', 'io.alacritty'}
local primaryApplications = {'com.brave.Browser', 'net.kovidgoyal.kitty'}
local keyDownEventObserver
local keyUpEventObserver
local flagsChangedEventObserver

local keyDownListeners = {}
local keyUpListeners = {}
local flagsChangedListeners = {}

function createObserver (eventTypes, listeners)
   return hs.eventtap.new(eventTypes, function(event)
        local preventDefault = false
        each(function (handler) if handler(event) then preventDefault = preventDefault or true end end, listeners)
        return preventDefault
   end)
end

function startObservers()
   keyDownEventObserver:start()
   keyUpEventObserver:start()
   flagsChangedEventObserver:start()
end

function stopObservers()
   keyDownEventObserver:stop()
   keyUpEventObserver:stop()
   flagsChangedEventObserver:stop()
end

-- function addCustomModifier(modifierCode, modifier, standaloneCode)
--    local modifierPressed = false
--    local modifierUsed = false
--
--    local pressKey = function(mods, key)
--       stopObservers()
--       hs.eventtap.event.newKeyEvent(mods, key, true):post()
--       startObservers()
--    end
--
--    local printUmlaut = function (umlaut)
--       stopObservers()
--       hs.eventtap.keyStrokes(umlaut)
--       startObservers()
--    end
--
--    table.insert(keyDownListeners, function(event)
--          local flags = event:getFlags()
--          local keyCode = event:getKeyCode()
--          local uppercaseUmlauts = {[0] = "Ä", [31] = 'Ö', [32] = 'Ü'}
--          local lowercaseUmlauts = {[0] = "ä", [1] = 'ß', [31] = 'ö', [32] = 'ü'}
--
--          if keyCode == modifierCode then
--             modifierPressed = true
--             return true
--          end
--
--          if modifierPressed then
--             modifierUsed = true
--          end
--
--          if (flags.shift or modifierPressed) and flags.alt and uppercaseUmlauts[keyCode] then
--             printUmlaut(uppercaseUmlauts[keyCode])
--             return true
--          end
--
--          if flags.alt and lowercaseUmlauts[keyCode] then
--             printUmlaut(lowercaseUmlauts[keyCode])
--             return true
--          end
--
--          if modifierPressed then
--             pressKey({modifier}, hs.keycodes.map[keyCode])
--             return true
--          end
--    end)
--
--    table.insert(keyUpListeners, function(event)
--          if event:getKeyCode() == modifierCode then
--             if not modifierUsed then
--                pressKey({}, standaloneCode)
--             end
--             modifierPressed = false
--             modifierUsed = false
--             return true
--          end
--    end)
-- end

function addStandaloneHandler(modifierCode, modifier, standaloneHandler)
   local modifierUsed = false

   table.insert(flagsChangedListeners, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()
         if keyCode == modifierCode then
            if not flags[modifier] and not modifierUsed then
               standaloneHandler()
            end
            modifierUsed = false
         end
   end)

   table.insert(keyDownListeners, function(event)
         modifierUsed = modifierUsed or event:getFlags()[modifier]
   end)
end

function addStandaloneModifier(modifierCode, modifier, standaloneCode)
   addStandaloneHandler(
      modifierCode,
      modifier,
      function () hs.eventtap.event.newKeyEvent({}, standaloneCode, true):post() end
   )
end

function printNonRecursiveKey(key) 
  stopObservers()
  hs.eventtap.event.newKeyEvent({}, key, true):post()
  startObservers()
end

function isKitty()
    local win = hs.window.focusedWindow()
    if win then
      local app = win:application()
      if app then
        -- return app:bundleID() == 'net.kovidgoyal.kitty'
        return true
      end
    end
    return false
end

function addVimQuickFileNavigation() 
  local log = hs.logger.new('mymodule','debug')
  local modifierPressed = false
  local modifierUsed = false

  function reset()
    modifierPressed = false
    modifierUsed = false
  end

  table.insert(keyDownListeners, function(event)
    if not isKitty() then
      return false
    end

    local keyCode = event:getKeyCode()
    if keyCode == 3 and next(event:getFlags()) == nil then 
      modifierPressed = true
      return true
    end
    if modifierPressed then
      if keyCode == 38 then 
        printNonRecursiveKey('f19')
        modifierUsed = true
        return true
      end
      if keyCode == 40 then 
        printNonRecursiveKey('f20')
        modifierUsed = true
        return true
      end
      if not modifierUsed then 
        printNonRecursiveKey('f')
      end 
    end
    reset()
    return false 
  end)

  table.insert(keyUpListeners, function(event)
    if not isKitty() then
      reset()
      return false
    end
    if event:getKeyCode() == 3 and next(event:getFlags()) == nil then
      if modifierPressed and not modifierUsed then 
        printNonRecursiveKey('f')
      end
      if modifierPressed and modifierUsed then 
        printNonRecursiveKey('f18')
      end
      reset()
    end
    return false 
  end)
end

function createAlternativeKeys(hotkeyDefinitions)
  function printKey(code)
    return function () hs.eventtap.event.newKeyEvent({}, code, true):post() end
  end

  hs.hotkey.bind({'alt'}, 'j', printKey('down'))
  hs.hotkey.bind({'alt'}, 'k', printKey('up'))
  hs.hotkey.bind({'alt'}, 'h', printKey('left'))
  hs.hotkey.bind({'alt'}, 'l', printKey('right'))
end

function openApp(bundleID)
  return function () hs.application.launchOrFocusByBundleID(bundleID) end
end

local currentPrimaryApplication = 1
function togglePrimaryApplications ()
  local win = hs.window.focusedWindow()
  if win then
    local app = win:application()
    if app then
      local focusedBundleID = app:bundleID()
      for index, value in ipairs (primaryApplications) do
        if value == focusedBundleID and index == currentPrimaryApplication then
          currentPrimaryApplication = math.fmod(index, 2) + 1
        end
      end
    end
  end
  hs.application.launchOrFocusByBundleID(primaryApplications[currentPrimaryApplication])
end

keyDownEventObserver = createObserver({hs.eventtap.event.types.keyDown}, keyDownListeners)
keyUpEventObserver = createObserver({hs.eventtap.event.types.keyUp}, keyUpListeners)
flagsChangedEventObserver = createObserver({hs.eventtap.event.types.flagsChanged}, flagsChangedListeners)

hs.hotkey.bind({'alt'}, 'd', function ()
  debug = not debug
  hs.notify.show('Hammerspoon', 'debug toggled', '')
end)

-- addCustomModifier(49, "shift", "space")
-- addStandaloneModifier(55, "cmd", "delete")
-- addStandaloneModifier(54, "cmd", "escape")
addStandaloneHandler(55, "cmd", togglePrimaryApplications)

-- hs.hotkey.bind('shift','escape',togglePrimaryApplications)
-- createAlternativeKeys()
addVimQuickFileNavigation()
startObservers()

local printUmlaut = function (umlaut)
  return function ()
    -- stopObservers()
    hs.eventtap.keyStrokes(umlaut)
    -- startObservers()
  end
end
hs.hotkey.bind({'ctrl'}, 'a', printUmlaut('ä'))
hs.hotkey.bind({'ctrl', 'shift'}, 'a', printUmlaut('g'))
hs.hotkey.bind({'ctrl'}, 'o', printUmlaut('ö'))
hs.hotkey.bind({'ctrl', 'shift'}, 'o', printUmlaut('Ö'))
hs.hotkey.bind({'ctrl'}, 'u', printUmlaut('ü'))
hs.hotkey.bind({'ctrl', 'shift'}, 'u', printUmlaut('Ü'))
hs.hotkey.bind({'ctrl'}, 's', printUmlaut('ß'))
hs.hotkey.bind({'cmd'}, '3', openApp('com.jetbrains.intellij.ce'))
hs.hotkey.bind({'cmd'}, '1', openApp(primaryApplications[1]))
hs.hotkey.bind({'cmd'}, '2', openApp(primaryApplications[2]))
-- local uppercaseUmlauts = {[0] = "Ä", [31] = 'Ö', [32] = 'Ü'}
-- local lowercaseUmlauts = {[0] = "ä", [1] = 'ß', [31] = 'ö', [32] = 'ü'}

-- Reload config when any lua file in config directory changes
function reloadConfig(files)
  doReload = false
  for _,file in pairs(files) do
    if file:sub(-4) == '.lua' then
      doReload = true
    end
  end
  if doReload then
    hs.reload()
  end
end
local myWatcher = hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/init.lua', reloadConfig):start()
hs.notify.show('Hammerspoon', 'Configuration loaded', '')
