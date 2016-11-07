function mapStandaloneModifier()
   modifierPressed = false
   modifierUsed = false
   keyDownEvents = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()
         if not flags.shift then
            if modifierPressed then
               modifierUsed = true
               return true
            end
            if keyCode == 49 then
               modifierPressed = true
               return true
            end
         end
   end)
   keyDownEvents:start()
   keyUpEvents = hs.eventtap.new({hs.eventtap.event.types.keyUp}, function(event)
         local flags = event:getFlags()
         local keyCode = event:getKeyCode()
         if keyCode == 49 then
            if not modifierUsed then
               hs.eventtap.keyStrokes(" ")
            end
            modifierPressed = false
            modifierUsed = false
            return true
         end
         if not flags.shift then
            if modifierPressed then
               modifierUsed = true
               hs.eventtap.event.newKeyEvent({"shift"}, hs.keycodes.map[keyCode], true):post()
            end
         end
   end)
   keyUpEvents:start()
end
mapStandaloneModifier()

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
local myWatcher = hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', reloadConfig):start()
hs.alert.show('Config loaded')
