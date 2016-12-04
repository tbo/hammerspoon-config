local fun = require('fun')
local map = fun.map
local iter = fun.iter
local each = fun.each
local range = fun.range
local debug = false
local primaryApplications = {'com.google.Chrome', 'com.googlecode.iterm2'}
local keyDownEventObserver
local keyUpEventObserver
local flagsChangedEventObserver

local keyDownListeners = {}
local keyUpListeners = {}
local flagsChangedListeners = {}

function createObserver (eventTypes, listeners)
   return hs.eventtap.new(eventTypes, function(event)
        local preventDefault = false
        each(function (handler) if handler(event) then preventDefault = true end end, listeners)
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

function addCustomModifier(modifierCode, modifier, standaloneCode)
   local modifierPressed = false
   local modifierUsed = false

   local pressKey = function(mods, key)
      stopObservers()
      hs.eventtap.event.newKeyEvent(mods, key, true):post()
      startObservers()
   end

   local printUmlaut = function (umlaut)
      stopObservers()
      hs.eventtap.keyStrokes(umlaut)
      startObservers()
   end

   table.insert(keyDownListeners, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()
         local uppercaseUmlauts = {[0] = "Ä", [31] = 'Ö', [32] = 'Ü'}
         local lowercaseUmlauts = {[0] = "ä", [1] = 'ß', [31] = 'ö', [32] = 'ü'}

         if keyCode == modifierCode then
            modifierPressed = true
            return true
         end

         if modifierPressed then
            modifierUsed = true
         end

         if (flags.shift or modifierPressed) and flags.alt and uppercaseUmlauts[keyCode] then
            printUmlaut(uppercaseUmlauts[keyCode])
            return true
         end

         if flags.alt and lowercaseUmlauts[keyCode] then
            printUmlaut(lowercaseUmlauts[keyCode])
            return true
         end

         if modifierPressed then
            pressKey({modifier}, hs.keycodes.map[keyCode])
            return true
         end
   end)

   table.insert(keyUpListeners, function(event)
         if event:getKeyCode() == modifierCode then
            if not modifierUsed then
               pressKey({}, standaloneCode)
            end
            modifierPressed = false
            modifierUsed = false
            return true
         end
   end)
end

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

function createAlternativeKeys(hotkeyDefinitions)
   function printKey(code)
      return function () hs.eventtap.event.newKeyEvent({}, code, true):post() end
   end

   hs.hotkey.bind({'alt'}, 'j', printKey('down'))
   hs.hotkey.bind({'alt'}, 'k', printKey('up'))
   hs.hotkey.bind({'alt'}, 'h', printKey('left'))
   hs.hotkey.bind({'alt'}, 'l', printKey('right'))
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
addCustomModifier(49, "shift", "space")
addStandaloneModifier(54, "cmd", "escape")
addStandaloneModifier(55, "cmd", "delete")
addStandaloneHandler(58, "alt", togglePrimaryApplications)
createAlternativeKeys()
startObservers()

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
