local inspect = require('./inspect')
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

   keyDownEvents = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()
         if keyCode == modifierCode then
            modifierPressed = true
            return true
         end
         if modifierPressed then
            modifierUsed = true
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
   local keyDownEvents

   function printKey(code)
      return function () hs.eventtap.event.newKeyEvent({}, code, true):post() end
   end

   function printUmlaut(umlaut)
      return function ()
         keyDownEvents:stop()
         hs.eventtap.keyStrokes(umlaut)
         keyDownEvents:start()
      end
   end
   keyDownEvents = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()

         if flags.alt then
            if keyCode == 31 then
               printUmlaut('ö')
               -- hs.notify.show('Hammerspoon', tostring(keyCode), inspect(flags))
               return true
            end
         end
   end):start()

   -- keyUpEvents = hs.eventtap.new({hs.eventtap.event.types.keyUp}, function(event)
   -- end):start()

   hs.hotkey.bind({'alt'}, 'j', printKey('down'))
   hs.hotkey.bind({'alt'}, 'k', printKey('up'))
   hs.hotkey.bind({'alt'}, 'h', printKey('left'))
   hs.hotkey.bind({'alt'}, 'l', printKey('right'))
   -- hs.hotkey.bind({'alt'}, 'o', printUmlaut('ö'))
   -- hs.hotkey.bind({'alt', 'shift'}, 'o', printUmlaut('Ö'))
   -- hs.hotkey.bind({'alt'}, 'a', printUmlaut('ä'))
   -- hs.hotkey.bind({'alt', 'shift'}, 'a', printUmlaut('Ä'))
   -- hs.hotkey.bind({'alt'}, 'u', printUmlaut('ü'))
   -- hs.hotkey.bind({'alt', 'shift'}, 'u', printUmlaut('Ü'))
   -- hs.hotkey.bind({'alt'}, 's', printUmlaut('ß'))
end

addCustomModifier(49, "shift", "space")
addStandaloneModifier(54, "cmd", "escape")
addStandaloneModifier(55, "cmd", "delete")
-- addStandaloneHandler(58, "alt", function () hs.notify.show('test','test','test') end)
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
