-- ColorPicker v2 - Florian ANAYA - 2020
-- This plugin will create a color picker in a layout view for several
-- groups of fixtures. It uses the Appearance of the macros to display
-- colors, so there is no need to mess with images.
-- The groups are defined by the user below.
-- The plugin will create master macros that change the color of all fixtures.
-- It also supports layers, so that the user can have several masters.
-- It uses executors (defined by the user) and macros. The first available
-- continuous range of macros is automatically selected.
-- It is possible to include fixtures that only have a color wheel, GrandMA
-- will pick the one that looks the more like the one asked
-- Tested GrandMA2 version: 3.7
-- external ressource used: https://static.impactsf.com/GrandMA2/index.html

-----------------------
-- Start of settings --
-----------------------

-- List of group IDs that will be used in the color picker.
-- It is NOT possible to use group names.
-- Sub groups can be created, they will have separate masters.
-- All masters will repond to the master above it in the hierarchy
-- of this table. 
groups =
{
  7,
  { 
    2,
    3,
    4,
    5,
    6,
  }
}
-- ¨Page of the execs (all execs will be on this page)
local execPage = 1

-- ID of first executor to use (There will be as many executors used as
-- there are groups declared above)
-- If one of the executors already exists, the program will not execute
local currentExecId = 101

-- The pool ID of the layout to be used.
-- If a layout already exists at this ID, it will be used anyway
-- without affecting other elements already present, but the macros
-- may overlap those other elements
local layoutId = 2

-- This is the mist of colors that will be used in the color picker.
-- they can be changed and deleted. New colors can be added.
-- They are defined by RGB or swatchbook entry (gel). A list of all gels
-- can be found in the color picker.
--  If a swatchbook color is defined, it will be used instead of RGB value.
-- Nevertheless, RGB values must be present for the macro color appearance.
-- RGB colors are defined as percent. Swatchbook colors can be defined by
-- name (ie. "MA colors"."White") or by number (ie. 1.1), but must be enclosed
-- by 'quotes' like this: '"lee"."primary red"' or '8.106'.
-- Names can be anything you like and can contain spaces,
-- but must be present and there cannot be duplicate.
-- White and other colors cannot be defined, but they will be used anyway.
-- GrandMA2 will translate the RGB the user provides to whatever is
-- available (RGBW, RGBWA+UV, or anything that is available).
local colors =
{
  {['name'] = 'White CTO', ['red'] = 100, ['green'] = 100, ['blue'] = 70, ["swatchbook"] = '"Lee"."full CT orange"'},
  {['name'] = 'White CTB', ['red'] = 100, ['green'] = 100, ['blue'] = 100, ["swatchbook"] = '8.120'},
  {['name'] = 'Red', ['red'] = 100, ['green'] = 0, ['blue'] = 0},
  {['name'] = 'Orange', ['red'] = 100, ['green'] = 50, ['blue'] = 0,},
  {['name'] = 'Yellow', ['red'] = 100, ['green'] = 100, ['blue'] = 0,},
  {['name'] = 'Lime', ['red'] = 50, ['green'] = 100, ['blue'] = 0,},
  {['name'] = 'Green', ['red'] = 0, ['green'] = 100, ['blue'] = 0,},
  {['name'] = 'Light green', ['red'] = 0, ['green'] = 100, ['blue'] = 50},
  {['name'] = 'Lavender', ['red'] = 0, ['green'] = 50, ['blue'] = 100},
  {['name'] = 'Cyan', ['red'] = 0, ['green'] = 100, ['blue'] = 100},
  {['name'] = 'Blue', ['red'] = 0, ['green'] = 0, ['blue'] = 100},
  {['name'] = 'Violet', ['red'] = 50, ['green'] = 0, ['blue'] = 100},
  {['name'] = 'Magenta', ['red'] = 100, ['green'] = 0, ['blue'] = 100},
  {['name'] = 'Pink', ['red'] = 100, ['green'] = 0, ['blue'] = 50},
}

-- Layout settings
local startX = 0
local startY = 0
local offsetX = 1
local offsetY = 1.1

--------------------------------
-- End of settings            --
-- Don't touch anything below --
--------------------------------

-- The first macro ID used
local firstMacroNb = 1
-- The current macro being used (also the current macro being searched empty)
local currentMacroNb = 1
-- number of colors in the color picker
local nbColors = #colors
-- The total number of macros that need to be created
local nbNeededMacros = 0
-- The total number of execs needed
local nbNeededExecs = 0
-- The handle of the progress bar
local progressBarHandle = 0
-- Becomes true at the end of the script, to avoid the user to execute the
-- plugin twice without a reset of the variables
local alreadyExecuted = false


-- Logging function
function log(message)
  gma.echo(message)
  gma.feedback(message)
end

-- Creates a row of master macros 
function createMacroRowAll()
  for colorIndex, colorValues in pairs(colors) do 
    gma.cmd('Store Macro 1.' .. tostring(currentMacroNb) .. ' "' .. "All " .. colorValues["name"] .. '"')
    gma.cmd('Appearance Macro 1.' .. tostring(currentMacroNb) .. ' /r=' .. tostring(colorValues["red"]) .. ' /g=' .. tostring(colorValues["green"]) .. ' /b=' .. tostring(colorValues["blue"]))
    currentMacroNb = currentMacroNb + 1
  end 
end

-- Recursive function that treats a group ID or an array of group ID
function treatGroupOrArray(groupNbOrArray)
  if (type(groupNbOrArray) == "table") then
    local macroIdOfAllRow = currentMacroNb -- We store the ID of the first master macro, before the global variable "currentMacroNb" is changed by the function
    local macroIdsOfGroups = {} -- table that will hold all the first macro number of the picker of the lines of this group
    createMacroRowAll() -- We create the master macros
    for index,groupPoolId in ipairs(groupNbOrArray) do
      macroIdsOfGroups[index] = currentMacroNb -- We add the ID of this macro to our macro list 
      treatGroupOrArray(groupPoolId)
    end
    -- We fill the master macro lines
    for colorIndex,colorValues in ipairs(colors) do
      local cmd = "Macro "
      for macroIndex, macroId in ipairs(macroIdsOfGroups) do
        cmd = cmd .. tostring(macroId + colorIndex -1) .. " + "
      end
      gma.cmd('Store Macro 1.' .. tostring(macroIdOfAllRow + colorIndex - 1) .. '.1')
      gma.cmd('Assign Macro 1.' .. tostring(macroIdOfAllRow + colorIndex - 1) .. '.1 /cmd="' .. cmd .. '"')
    end
  elseif (type(groupNbOrArray) == "number") then
    -- if the paramter is a number, we treat it as a group
    treatGroup(groupNbOrArray) 
  end
end

function treatGroup (groupPoolId)
  local firstMacroId = currentMacroNb -- ID of the first macro of this row
  local lastMacroId = currentMacroNb + nbColors -- ID of the last macro of this row
  gma.cmd("ClearAll")
  gma.cmd("Group " .. tostring(groupPoolId))
  local cueNb = 1
  -- We iterate over all the colors of the list, for every one of them,
  -- We set the color in the programmer and store it in the cue in the sequence
  -- We assign the command to the cue to change the Appearance of macros
  -- We create the macro that will trigger the cue
  for colorId, colorValues in ipairs(colors) do
    --gma.cmd('Attribute "colorrgb1" At ' .. colorValues["red"])
    --gma.cmd('Attribute "colorrgb2" At ' .. colorValues["green"])
    --gma.cmd('Attribute "colorrgb3" At ' .. colorValues["blue"])
    gma.cmd('At gel ' .. colorValues["swatchbook"])
    gma.cmd('Store Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId))
    gma.cmd('Label Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' "' ..colorValues["name"] .. '"')
    gma.cmd('Assign Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' /CMD="Label Macro 1.' .. tostring(firstMacroId) .. ' Thru 1.' .. tostring(lastMacroId-1) .. ' _ ; Label Macro 1.' .. tostring(currentMacroNb) .. ' VVVVVVVVVVVV')
    gma.cmd('Store Macro 1.' .. tostring(currentMacroNb))
    gma.cmd('Label Macro 1.' .. tostring(currentMacroNb) .. ' "_"')
    gma.cmd('Store Macro 1.' .. tostring(currentMacroNb) .. '.1')
    gma.cmd('Assign Macro 1.' .. tostring(currentMacroNb) .. '.1 /cmd="Goto Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId))
    gma.cmd('Appearance Macro 1.' .. tostring(currentMacroNb) .. ' /r=' .. tostring(colorValues["red"]) .. ' /g=' .. tostring(colorValues["green"]) .. ' /b=' .. tostring(colorValues["blue"]))
    cueNb = cueNb + 1
    currentMacroNb = currentMacroNb + 1
    gma.gui.progress.set(progressBarHandle, currentMacroNb - firstMacroNb)
    gma.sleep(0.05)
  end
  gma.cmd('Label Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' "Colors ' .. gma.show.getobj.label(gma.show.getobj.handle("Group ".. tostring(groupPoolId))) .. '"')
  currentExecId = currentExecId + 1
end

-- Recursive function that counts the total number of macros needed for a table
-- of group ID using the amount of colors per group.
-- It also counts the number of execs needed
function countNeededMacroNbInGroup(groupNbOrArray)
  nbNeededMacros = nbNeededMacros + nbColors -- we add the number of colors
  nbNeededExecs = nbNeededExecs + 1
  if (type(groupNbOrArray) == "table") then
    for groupIndex, value in ipairs(groupNbOrArray) do
      countNeededMacroNbInGroup(value)
    end 
  end
end

-- Count the number of total needed macros and finds the first available
-- macro ID that has a suffisant following free space
function findFirstAvailableMacro()
  countNeededMacroNbInGroup(groups)
  local empty = false
  while (not empty) do
    empty = true
    for testedMacroNb=currentMacroNb,currentMacroNb+nbNeededMacros,1 do
      local clss = gma.show.getobj.class(gma.show.getobj.handle("Macro "..tostring(testedMacroNb)))
      empty = clss == nil
      if (not empty) then
        currentMacroNb = testedMacroNb + 1
        break
      end
    end 
  end
  firstMacroNb = currentMacroNb
end

-- Verifys if there is a suffisent number of unsuned execs
-- counting from the one specified by the user
function verifyFreeExecs()
  local allFree = true
  for execNb=currentExecId,currentExecId+nbNeededExecs,1 do
    local exec = gma.show.getobj.handle("Executor " .. tostring(execPage) .. '.' .. tostring(execNb))
    if (exec ~= nil) then
      allFree = false
    end
  end
  return allFree
end

-- verifies that all colors provided have RGB and that swatchbooks
-- colors provided exist
function verifyColors()
  local allGood = true
  for colorIndex,colorValues in ipairs(colors) do
    if (type(colorValues) ~= "table") then
      gma.gui.msgbox("Incorrect values", "Your color definition is incorrect, please check")
      exit()
    end
    if (type(colorValues["name"]) ~= "string") then
      gma.gui.msgbox("Missing value", "All colors must have a name. \nColor n°" .. tostring(colorIndex) .. " doesn't have a (proper) name")
      exit()
    end
    for colorIndex = 1,#colors-1,1 do
      for secondColorIndex = colorIndex+1,#colors,1 do
        if (colors[colorIndex]["name"] == colors[secondColorIndex]["name"]) then
          gma.gui.msgbox("Invalid color name", "There cannot be two colors with the same name (' " .. colors[colorIndex]["name"] .. " ')")
          exit()
        end
      end
    end
    if (type(colorValues["red"]) ~= "number" or type(colorValues["green"]) ~= "number" or type(colorValues["blue"]) ~= "number") then
      gma.gui.msgbox("Missing value", "All colors must have RGB values (even if you are using a swatchbook value).\nColor ' " .. colorValues["name"] .. " ' is missing red, green or blue.")
      exit()
    end
    if (type(colorValues["swatchbook"]) ~= "nil") then
      if (type(colorValues["swatchbook"]) ~= "string") then
        gma.gui.msgbox("Incorrect value", "The gel of the color ' " .. colorValues["name"] .. " ' is not correct.\nCheck that you correctly insterted 'quotes'")
        exit()
      end
      if (gma.show.getobj.handle('gel ' .. colorValues["swatchbook"]) == nil) then
        gma.gui.msgbox("Unknown gel", "The gel ' " .. colorValues["swatchbook"] .. " ' is unknown in color ' " .. colorValues["name"] .. " '")
        exit()
      end
    end
  end
end


function verifyGroup(groupOrArray)
  if (type(groupOrArray) == "table") then
    for groupindex,groupId in pairs(groupOrArray) do
      verifyGroup(groupId)
    end
  else
    local handle = gma.show.getobj.handle("group " .. tostring(groupOrArray))
    if (type(handle) == "nil") then
      gma.gui.msgbox("Unknown group", "One of the specified group doesn't exists.\nThe group ' " .. tostring(groupOrArray) .. " ' coulnd't be found. Please check.")
      exit()
    end
  end
end

function createGels()
  gma.cmd('Delete Gel "ColorPicker"')
  gma.cmd('Store Gel "ColorPicker"')
  for colorIndex,colorValues in ipairs(colors) do
    if (type(colorValues["swatchbook"]) == "nil") then
      gma.cmd('Store Gel "ColorPicker"."' .. colorValues["name"] .. '"')
      gma.cmd('Assign Gel "ColorPicker"."' .. colorValues["name"] .. '" /color="' .. colorValues['red'] .. ' ' .. colorValues['green'] .. ' ' .. colorValues['blue'] .. '"')
      colorValues["swatchbook"] = '"ColorPicker"."' .. colorValues["name"] .. '"'
    end
  end
end

-- Creates and names the layout if it doesn't already exists
function createLayout()
  local layout = gma.show.getobj.handle("Layout " .. tostring(layoutId))
  if (layout == nil) then
    gma.cmd('Store layout ' .. tostring(layoutId))
    gma.cmd('Label layout ' .. tostring(layoutId) .. '"Color Picker"')
  end
  local x = startX
  local y = startY
  gma.gui.progress.settext(progressBarHandle, "Creating layout: ")
  for macroOffset=0,nbNeededMacros,1 do
    gma.gui.progress.set(progressBarHandle, macroOffset)
    local macroId = firstMacroNb + macroOffset
    gma.cmd('Assign Macro 1.' .. tostring(macroId) .. ' Layout ' .. tostring(layoutId) .. ' /x=' .. tostring(x) .. ' /y=' .. tostring(y))
    if (macroOffset % nbColors == nbColors - 1) then
      y = y + offsetY
      x = startX
    else
      x = x + offsetX
    end
  end
end


-- Execution of the program when the user clicks on the plugin
return function()
  if (not alreadyExecuted) then
    if (gma.gui.confirm("Color Picker", "You are about to create a Color Picker on layout " .. tostring(layoutId) .. ".\nBefore continuing, you should have set up the parameters of the script by editing the plugin.")) then
      findFirstAvailableMacro()
      verifyColors()
      verifyGroup(groups)
      if (not verifyFreeExecs()) then
        gma.gui.msgbox("No space for execs", "There is not enough executor left, please specify an other executor ID.\nCheck the page you specified is the one you were thinking about.")
      else
        gma.cmd("BlindEdit on")
        progressBarHandle = gma.gui.progress.start("Creating Color Picker") 
        gma.gui.progress.setrange(progressBarHandle, 0, nbNeededMacros)
        gma.gui.progress.settext(progressBarHandle, "Creating macros: ")
        createGels()
        treatGroupOrArray(groups)
        gma.cmd("ClearAll")
        createLayout()
        gma.gui.progress.settext(progressBarHandle, "Finishing up")
        gma.cmd("BlindEdit Off")
        gma.cmd('Delete Gel "ColorPicker"')
        gma.gui.progress.stop(progressBarHandle)
        alreadyExecuted = true
        gma.gui.msgbox("Operation complete", "The Color Picker has been created on layout " .. tostring(layoutId))
      end
    else
      gma.gui.msgbox("Operation canceled", "The creation of the color picker has been aborted")
    end
  else
    gma.gui.msgbox("Operation canceled", "The script has already been executed.\nIf you want to create a second color picker, please reload the plugin (edit the plugin and hit 'reload')")
  end
end


