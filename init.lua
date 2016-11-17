local primaryApplications = {'com.google.Chrome', 'com.googlecode.iterm2'}

function addCustomModifier(modifierCode, modifier, standaloneCode)
   local modifierPressed = false
   local modifierUsed = false
   local keyDownEvents
   local keyUpEvents

   function pressKey(mods, key)
      keyDownEvents:stop()
      keyUpEvents:stop()
      hs.eventtap.event.newKeyEvent(mods, key, true):post()
      keyDownEvents:start()
      keyUpEvents:start()
   end

   local printUmlaut = function (umlaut)
      keyDownEvents:stop()
      keyUpEvents:stop()
      hs.eventtap.keyStrokes(umlaut)
      keyDownEvents:start()
      keyUpEvents:start()
   end

   keyDownEvents = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
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

   keyUpEvents = hs.eventtap.new({hs.eventtap.event.types.keyUp}, function(event)
         if event:getKeyCode() == modifierCode then
            if not modifierUsed then
               pressKey({}, standaloneCode)
            end
            modifierPressed = false
            modifierUsed = false
            return true
         end
   end)
   keyDownEvents:start()
   keyUpEvents:start()
end

function addStandaloneHandler(modifierCode, modifier, standaloneHandler)
   local modifierUsed = false

   local flagsChangedEvents = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()
         if keyCode == modifierCode then
            if not flags[modifier] and not modifierUsed then
               standaloneHandler()
            end
            modifierUsed = false
         end
   end):start()

   keyDownEvents = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
         modifierUsed = modifierUsed or event:getFlags()[modifier]
   end):start()
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

local lastPrimaryApplication = 1 
function togglePrimaryApplications ()
   local win = hs.window.focusedWindow()
   local focusedBundleID = win:application():bundleID()
   for index, value in ipairs (primaryApplications) do
      if value == focusedBundleID and focusedBundleID == primaryApplications[index] then
         lastPrimaryApplication = math.fmod(lastPrimaryApplication, 2) + 1
      end
   end
   hs.application.launchOrFocusByBundleID(primaryApplications[lastPrimaryApplication])
end

addCustomModifier(49, "shift", "space")
addStandaloneModifier(54, "cmd", "escape")
addStandaloneModifier(55, "cmd", "delete")
addStandaloneHandler(58, "alt", togglePrimaryApplications)
createAlternativeKeys()

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
