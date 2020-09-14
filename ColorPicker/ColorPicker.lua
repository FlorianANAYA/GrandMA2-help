-- ColorPicker v6 - Florian ANAYA - 2020
-- https://github.com/FlorianANAYA/GrandMA2-help
-- This plugin will create a color picker in a layout view for several
-- groups of fixtures. It automatically creates and imports images into GMA2
-- so there is no need to do it manually. It is possible to disable images for
-- performances (I think, it has not been tested). The plugin will use
-- the Appearance of the macros to display colors.
-- The groups are defined by the user below.
-- The plugin will create master macros that change the color of all fixtures.
-- It also supports layers, so that the user can have several masters.
-- It uses executors (defined by the user) and macros. The first available
-- continuous range of macros is automatically selected.
-- It is possible to include fixtures that only have a color wheel, GrandMA
-- will automatically pick the one that looks the more like the one asked
-- Note: any line that starts with -- is a comment and is not used by the plugin.
-- Don't forget that, if the plugin doesn't work and shows no message at all,
-- you might have made a typo in the config, you'll find more info in the
-- system monitor.
-- Tested GrandMA2 version: 3.7, 3.8, 3.9

-----------------------
-- Start of settings --
-----------------------

-- List of group IDs that will be used in the color picker.
-- Group IDs must be separated by commas ( , ). It is possible to use group
-- names instead of IDs, don't forget to include quotes (ie. {1, 2, "Mac Vipers", 8} )
-- Sub groups can be created, they will have separate masters (ie. {1,2,{3,4,5}} )
local groups = { 1,7,15,16 }

-- ID of first executor to use (There will be as many executors used as
-- there are groups declared above)
-- If one of the executors already exists, the program will not execute.
-- It must include the exec page, the format is X.XXX (ie. 1.101, 5.001 or 7.015)
local execId = 1.101

-- The ID of the layout to be used.
-- If a layout already exists at this ID, it will be used anyway
-- without affecting other elements already present, but the macros
-- may overlap those other elements.
local layoutId = 1

-- The fade time between colors (in seconds)
local fadeTime = 1

-- This is the list of colors that will be used in the color picker.
-- they can be changed and deleted. New colors can be added.
-- They are defined by RGB or swatchbook entry (gel). A list of all gels
-- can be found in the color picker.
--  If a swatchbook color is defined, it will be used instead of RGB value.
-- Nevertheless, RGB values must be present for the macro color appearance.
-- RGB colors are defined as percent. Swatchbook colors can be defined by
-- name (ie. "MA colors"."White") or by number (ie. 1.1), they must be enclosed
-- by 'quotes' like this: '"lee"."primary red"' or '8.106'.
-- Names can be anything you like and can contain spaces,
-- but must be present and there cannot be duplicate.
-- White and other colors cannot be defined, but they will be used anyway.
-- GrandMA2 will translate the RGB values you provide to whatever is
-- available in the fixture (RGBW, RGBWA+UV, or anything that is available).
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


-- Defines if the plugin will use images or not 
-- 'true' means that images will be generated and used, 'false' otherwise
-- I didn't test it precisely, but I think that using images is less performant
local useImages = true

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
local firstMacroId = 1
-- The current macro being used (also the current macro being searched empty)
local currentMacroId = 1
-- The ID of the last macro that is going to be used
local lastMacroId = 1
-- The total number of macros that need to be created
local nbNeededMacros = 0

-- The first image ID used
local firstImageId = 14
-- The current image being used (also the current image being searched empty)
local currentImageId = 14
-- The ID of the last image that is going to be used
local lastImageId = 14
-- The total number of images that need to be created
local nbNeededImages = 0
-- ID of the first image representing an empty color
local firstEmptyImageId = 14
-- ID of the last image representing an empty color
local lastEmptyImageId = 14
-- ID of the first image representing a full color
local firstFullImageId = 14
-- ID of the last image representing a full color
local lastFullImageId = 14

-- ¨Page of the execs (all execs will be on this page)
local execPage = 0
-- The total number of execs needed
local nbNeededExecs = 0
-- The ID of the first exec to be used
local firstExecId = 0
-- The current exec being used by the plugin
local currentExecId = firstExecId
-- Defines the last exec ID used
local lastExecId = 0
-- Content of the XML file that will be used to create the layout. It is initialized with a basic header
local xmlFileContent = '<?xml version="1.0" encoding="utf-8"?><MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.7.0/MA.xsd" major_vers="3" minor_vers="7" stream_vers="0"><Info datetime="2020-06-03T19:21:08" showfile="Florian ANAYA" /><Group index="0" name="Color Picker"><LayoutData index="0" marker_visible="true" background_color="000000" visible_grid_h="0" visible_grid_w="0" snap_grid_h="0.5" snap_grid_w="0.5" default_gauge="Filled &amp; Symbol" subfixture_view_mode="DMX Layer"><CObjects>'
-- Defines the content of the XML file that will hold the text (in MA2 XML, texts are further that the 
-- macros)
local textFileContent = ''

-- Strings that will be used to build the images data. They represent the hex data of a 8x8pixels BMP file
-- The first byte array is the image header and the beginning of a 2 entries palette. The second entry is 
-- completed by the script. The last part is the image data itself. There are two variants: full image and empty image
local imageBytesStart = string.char(0x42, 0x4D, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x00, 0x00, 0x00, 0x28, 0X00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
local fullImageBytesEnd = string.char(0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
local emptyImageBytesEnd = string.char(0x00, 0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF)

-- Position of the current element in the layout
local x = startX
local y = startY

-- number of colors in the color picker
local nbColors = #colors
-- The handle of the progress bar
local progressBarHandle = 0
-- Becomes true at the end of the script, to avoid the user to execute the
-- plugin twice without a reset of the variables
local alreadyExecuted = false
-- Predeclaration of functions
local addQuotes, createImage, createMacroRowAll, treatGroup, treatGroupOrArray, countNeededMacroNbInGroup, findFirstAvailableMacro, findFirstAvailableImage, verifyFreeExecs, verifyColors, verifyGroup, createGels, verifyLayout
-- Used by the base64 library
local base64 = {}

-- If the argument is a string, this functions add quotes
-- at the beginning and end of the string if it doesn't already have them.
-- If the argument is anything else, the function just uses tostring on it
addQuotes = function(str)
  if (type(str) == "string") then
    if (string.sub(str, 1, 1) ~= '"') then
      str = '"' .. str
    end
    local length = string.len(str)
    if (string.sub(str, length, length) ~= '"') then
      str = str .. '"'
    end
  else
    str = tostring(str)
  end
  return str
end

-- Creates a row of "master" macros 
createMacroRowAll = function()
  x = startX + offsetX
  y = y + offsetY
  for colorIndex, colorValues in pairs(colors) do 
    -- We create the macro and name it with the color name
    gma.cmd('Store Macro 1.' .. tostring(currentMacroId) .. ' "' .. colorValues["name"] .. '"')
    -- We assign its appearance the color
    gma.cmd('Appearance Macro 1.' .. tostring(currentMacroId) .. ' /r=' .. tostring(colorValues["red"]) .. ' /g=' .. tostring(colorValues["green"]) .. ' /b=' .. tostring(colorValues["blue"]))
    -- We add the macro to the layout XML file
    xmlFileContent = xmlFileContent .. '<LayoutCObject font_size="Small" center_x="' .. tostring(x) .. '" center_y="' .. tostring(y) .. '" size_h="1" size_w="1" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="1" show_type="0" function_type="Pool icon" select_group="1"><image /><CObject name="' .. colorValues["name"] .. '"><No>13</No><No>1</No><No>' .. tostring(currentMacroId) .. '</No></CObject></LayoutCObject>'
    x = x + offsetX
    currentMacroId = currentMacroId + 1
    gma.gui.progress.set(progressBarHandle, currentMacroId - firstMacroId)
    gma.sleep(0.05)
  end 
end

-- Treats a GMA2 group:
--  Creates the color macros
--  Copies the corresponding image for the colors
--  Adds the group name to the layout XML file
--  Adds the macro to the layout XML file
treatGroup  = function(groupPoolId)
  local groupFirstMacroId = currentMacroId -- ID of the first macro of this row
  local groupName = gma.show.getobj.label(gma.show.getobj.handle("Group ".. tostring(groupPoolId)))
  local lastMacroId = currentMacroId + nbColors -1 -- ID of the last macro of this row
  local groupFirstImageId = currentImageId -- ID of the first image of this row
  gma.cmd("ClearAll")
  -- Selection of the group
  gma.cmd("Group " .. addQuotes(groupPoolId))
  x = startX
  y = y + offsetY
  
  -- We add the group name to the layout XML file
  textFileContent = textFileContent .. '<LayoutElement text_align_flags="18" center_x="' .. tostring(startX - (2*offsetX)) .. '" center_y="' .. tostring(y) .. '" size_h="1" size_w="3" background_color="00000000" border_color="00000000" icon="None" text="' .. groupName .. '" show_id="1" show_name="1" show_type="1" show_dimmer_bar="Off" show_dimmer_value="Off" select_group="1"><image /></LayoutElement>'
  
  local cueNb = 1
  -- We iterate over all the colors of the list, for every one of them,
  -- We set the color in the programmer and store it in the cue in the sequence
  -- We assign the command to the cue to change the Appearance of macros
  -- We create the macro that will trigger the cue
  for colorId, colorValues in ipairs(colors) do
    gma.cmd('At gel ' .. colorValues["swatchbook"])
    gma.cmd('Store Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId))
    gma.cmd('Label Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' "' ..colorValues["name"] .. '"')
    gma.cmd('Assign Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' /fade=' .. tostring(fadeTime))
    gma.cmd('Store Macro 1.' .. tostring(currentMacroId))
    gma.cmd('Store Macro 1.' .. tostring(currentMacroId) .. '.1')
    gma.cmd('Assign Macro 1.' .. tostring(currentMacroId) .. '.1 /cmd="Goto Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId))
    gma.cmd('Appearance Macro 1.' .. tostring(currentMacroId) .. ' /r=' .. tostring(colorValues["red"]) .. ' /g=' .. tostring(colorValues["green"]) .. ' /b=' .. tostring(colorValues["blue"]))
    
    x = x + offsetX
    
    if (useImages) then -- Image are used
      -- We copy the corresponding empty image
      gma.cmd('Copy Image ' .. tostring(firstEmptyImageId + colorId - 1) .. ' At ' .. tostring(currentImageId))
      gma.cmd('Label Image ' .. tostring(currentImageId) .. '"' .. groupName .. ' ' .. colorValues["name"] .. '"')
      -- When the cue is triggered, the row of empty images is copied on all images of this row, and the corresponding full image is copied at the place of the current color
      gma.cmd('Assign Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' /CMD="Copy Image ' .. tostring(firstEmptyImageId) .. ' Thru ' .. tostring(lastEmptyImageId) .. ' At Image ' .. tostring(groupFirstImageId) .. ' /m ; Copy Image ' .. tostring(firstFullImageId + colorId - 1) .. ' At Image ' .. tostring(currentImageId) .. ' /m "')
      gma.cmd('Label Macro 1.' .. tostring(currentMacroId) .. ' "' .. groupName .. ' ' .. colorValues["name"] .. '"')
      -- We add the macro to the layout XML file
      xmlFileContent = xmlFileContent .. '<LayoutCObject font_size="Small" center_x="' .. tostring(x) .. '" center_y="' .. tostring(y) .. '" size_h="1" size_w="1" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="0" show_type="0" function_type="Simple" select_group="1" image_size="Fit"><image name="AttributePickerImage 27"><No>8</No><No>' .. tostring(currentImageId) .. '</No></image><CObject name="' .. colorValues["name"] .. '"><No>13</No><No>1</No><No>' .. tostring(currentMacroId) .. '</No></CObject></LayoutCObject>'
      currentImageId = currentImageId + 1
    else -- Images are not used
      -- When the cue is triggered, we name every macro '_', and name the current macro 'VVVVVVVVVVVV'
      gma.cmd('Assign Cue ' .. tostring(cueNb) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' /CMD="Label Macro 1.' .. tostring(groupFirstMacroId) .. ' Thru 1.' .. tostring(lastMacroId) .. ' _ ; Label Macro 1.' .. tostring(currentMacroId) .. ' VVVVVVVVVVVV"')
      gma.cmd('Label Macro 1.' .. tostring(currentMacroId) .. ' "_"')
      -- We add the macro to the layout XML file
      xmlFileContent = xmlFileContent .. '<LayoutCObject font_size="Small" center_x="' .. tostring(x) .. '" center_y="' .. tostring(y) .. '" size_h="1" size_w="1" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="1" show_type="0" function_type="Pool icon" select_group="1"><image /><CObject name="_"><No>13</No><No>1</No><No>' .. tostring(currentMacroId) .. '</No></CObject></LayoutCObject>'
    end
    
    cueNb = cueNb + 1
    currentMacroId = currentMacroId + 1
    gma.gui.progress.set(progressBarHandle, currentMacroId - firstMacroId)
    gma.sleep(0.05)
  end
  gma.cmd('Label Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' "Colors ' .. groupName .. '"')
  currentExecId = currentExecId + 1
end

-- Recursive function that treats a group ID or an array of group ID
treatGroupOrArray = function(groupNbOrArray)
  if (type(groupNbOrArray) == "table") then
    local macroIdOfAllRow = currentMacroId -- We store the ID of the first master macro, before the global variable "currentMacroId" is changed by the function
    local macroIdsOfGroups = {} -- table that will hold all the first macro number of the picker of the lines of this group
    createMacroRowAll() -- We create the master macros
    for index,groupPoolId in ipairs(groupNbOrArray) do
      macroIdsOfGroups[index] = currentMacroId -- We add the ID of this macro to our macro list 
      treatGroupOrArray(groupPoolId)
    end
    -- We fill the master macro lines
    for colorIndex,colorValues in ipairs(colors) do
      -- The command should only contain a + sign if necessary
      local cmd = "Macro "
      local first = true
      for macroIndex, macroId in ipairs(macroIdsOfGroups) do
        if (not first) then
          cmd = cmd .. " + "
        end
        cmd = cmd .. tostring(macroId + colorIndex -1)
        first = false
      end
      gma.cmd('Store Macro 1.' .. tostring(macroIdOfAllRow + colorIndex - 1) .. '.1')
      gma.cmd('Assign Macro 1.' .. tostring(macroIdOfAllRow + colorIndex - 1) .. '.1 /cmd="' .. cmd .. '"')
    end
  else
    -- if the paramter is not a table, we treat it as a group
    treatGroup(groupNbOrArray)
  end
end

-- Recursive function that counts the total number of macros needed for a table
-- of group ID using the amount of colors per group.
-- Also count the number of needed images
countNeededMacroNbInGroup = function(groupNbOrArray)
  nbNeededMacros = nbNeededMacros + nbColors -- we add the number of colors
  nbNeededImages = nbNeededImages + nbColors
  if (type(groupNbOrArray) == "table") then
    for groupIndex, value in ipairs(groupNbOrArray) do
      countNeededMacroNbInGroup(value)
    end 
  else
    nbNeededExecs = nbNeededExecs + 1
  end
  lastExecId = firstExecId + nbNeededExecs - 1
end

-- Count the number of total needed macros and finds the first available
-- macro ID that has a suffisant following free space.
-- Also verifies that the maximum macro ID has not been reached.
findFirstAvailableMacro = function()
  -- Count the number of needed macros
  countNeededMacroNbInGroup (groups)
  local empty = false
  while (not empty) do
    empty = true
    for testedMacroNb=currentMacroId,currentMacroId+nbNeededMacros-1,1 do
      local handle = gma.show.getobj.handle("Macro "..tostring(testedMacroNb))
      empty = handle == nil
      if (not empty) then
        currentMacroId = testedMacroNb + 1
        break
      end
    end 
  end
  firstMacroId = currentMacroId
  lastMacroId = firstMacroId + nbNeededMacros-1
  -- We check that we have not reached the maximum macro ID.
  -- I tested and found that 10000 is the maximum, but this value may
  -- evolve in the future or between different installation, so we test
  -- by storing the last macro and verifying that it exists.
  gma.cmd("Store Macro 1." .. tostring(lastMacroId))
  local macroHandle = gma.show.getobj.handle("Macro 1." .. tostring(lastMacroId))
  gma.cmd("Delete Macro 1." .. tostring(lastMacroId))
  if (macroHandle == nil) then
    gma.gui.msgbox("Not enough macros available", "The maximum number of macros has been reached.\nThere are not enough available macros to create the Color Picker.")
    return false
  end
  return true
end

-- Finds the first available image ID that has a sufficient following free
-- space. Also verifies that the maximum image ID has not been reached.
findFirstAvailableImage = function()
  local empty = false
  while (not empty) do
    empty = true
    for testedImageNb=currentImageId,currentImageId+nbNeededImages-1,1 do
      local handle = gma.show.getobj.handle("Image "..tostring(testedImageNb))
      empty = handle == nil
      if (not empty) then
        currentImageId = testedImageNb + 1
        break
      end
    end 
  end
  firstImageId = currentImageId
  lastImageId = firstImageId + nbNeededImages-1
  -- We check that we have not reached the maximum image ID.
  -- I tested and found that 10000 is the maximum, but this value may
  -- evolve in the future or between different installation, so we test
  -- by storing the last macro and verifying that it exists.
  gma.cmd("Store Image " .. tostring(lastImageId))
  local imageHandle = gma.show.getobj.handle("Image " .. tostring(lastImageId))
  gma.cmd("Delete Image " .. tostring(lastImageId))
  if (imageHandle == nil) then
    gma.gui.msgbox("Not enough images available", "The maximum number of images has been reached.\nThere are not enough available images to create the Color Picker.")
    return false
  end
  firstEmptyImageId = firstImageId
  lastEmptyImageId = firstEmptyImageId + nbColors - 1
  firstFullImageId = lastEmptyImageId + 1
  lastFullImageId = firstFullImageId + nbColors - 1
  return true
end

-- Verifys if there is a suffisent number of unsuned execs
-- counting from the one specified by the user
verifyFreeExecs = function()
  local allFree = true
  for execNb=firstExecId,firstExecId+nbNeededExecs-1,1 do
    local execHandle = gma.show.getobj.handle("Executor " .. tostring(execPage) .. '.' .. tostring(execNb))
    if (execHandle == nil) then
      gma.feedback("Executor " .. tostring(execPage) .. '.' .. tostring(execNb) .. " is not used.")
    else
      gma.feedback("Executor " .. tostring(execPage) .. '.' .. tostring(execNb) .. " is used")
      allFree = false
    end
  end
  return allFree
end

-- verifies that all colors provided have RGB and that swatchbooks
-- colors provided exist
verifyColors = function()
  for colorIndex,colorValues in ipairs(colors) do
    if (type(colorValues) ~= "table") then
      gma.gui.msgbox("Incorrect values", "Your color definition is incorrect, please check")
      return false
    end
    if (type(colorValues["name"]) ~= "string") then
      gma.gui.msgbox("Missing value", "All colors must have a name. \nColor n°" .. tostring(colorIndex) .. " doesn't have a (proper) name")
      return false
    end
    for colorIndex = 1,#colors-1,1 do
      for secondColorIndex = colorIndex+1,#colors,1 do
        if (colors[colorIndex]["name"] == colors[secondColorIndex]["name"]) then
          gma.gui.msgbox("Invalid color name", "There cannot be two colors with the same name (' " .. colors[colorIndex]["name"] .. " ')")
          return false
        end
      end
    end
    if (type(colorValues["red"]) ~= "number" or type(colorValues["green"]) ~= "number" or type(colorValues["blue"]) ~= "number") then
      gma.gui.msgbox("Missing value", "All colors must have RGB values (even if you are using a swatchbook value).\nColor ' " .. colorValues["name"] .. " ' is missing red, green or blue.")
      return false
    end
    if (type(colorValues["swatchbook"]) ~= "nil") then
      if (type(colorValues["swatchbook"]) ~= "string") then
        gma.gui.msgbox("Incorrect value", "The gel of the color ' " .. colorValues["name"] .. " ' is not correct.\nCheck that you correctly insterted 'quotes'")
        return false
      end
      if (gma.show.getobj.handle('gel ' .. colorValues["swatchbook"]) == nil) then
        gma.gui.msgbox("Unknown gel", "The gel ' " .. colorValues["swatchbook"] .. " ' is unknown in color ' " .. colorValues["name"] .. " '")
        return false
      end
    end
  end
  return true
end

verifyGroup = function(groupOrArray)
  if (type(groupOrArray) == "table") then
    for groupindex,groupId in pairs(groupOrArray) do
      if (not verifyGroup(groupId)) then
        return false
      end
    end
  else
    local handle = gma.show.getobj.handle("group " .. addQuotes(groupOrArray))
    if (handle == nil) then
      gma.gui.msgbox("Unknown group", "One of the specified group doesn't exists.\nThe group ' " .. tostring(groupOrArray) .. " ' coulnd't be found. Please check.")
      return false
    end
  end
  return true
end

verifyLayout = function()
  if (type(layoutId) ~= "number") then
    gma.gui.msgbox("Invalid layout ID", "The specified layout ID is not correct, please edit the plugin to change the specified value")
    return false
  end
  if (layoutId <= 0) then
    gma.gui.msgbox("Invalid layout ID", "The specified layout ID is not correct, please edit the plugin to change the specified value")
    return false
  end
  local layoutHandle = gma.show.getobj.handle("Layout " .. tostring(layoutId))
  if (layoutHandle == nil) then -- layout is empty
    -- We check that we have not reached the maximum layout ID.
    -- I tested and found that 10000 is the maximum, but this value may
    -- evolve in the future or between different installation, so we test
    -- by storing the provided layout and verifying that it exists.
    gma.cmd("Store Layout " .. tostring(layoutId))
    layoutHandle = gma.show.getobj.handle("Layout " .. tostring(layoutId))
    gma.cmd("Delete Layout " .. tostring(layoutId))
    if (layoutHandle == nil) then
      gma.gui.msgbox("Invalid layout ID", "The provided layout ID is too high")
      return false
    end
  else -- layout is already used
    gma.gui.msgbox("Invalid layout ID", "The provided layout is already used\nPlease edit the config of the plugin to change the layout to use\nor delete the layout")
    return false
  end
  return true
end

-- Creates template full and empty images for all colors
createImages = function()
  gma.gui.progress.settext(progressBarHandle, "Creating template images")
  gma.gui.progress.setrange(progressBarHandle, 0, nbNeededImages)
  -- We create empty images
  for colorIndex, colorValues in ipairs(colors) do
    createImage(colorValues['red']*2.55, colorValues['green']*2.55, colorValues['blue']*2.55, false, currentImageId)
    gma.cmd('Label Image ' .. tostring(currentImageId) .. ' "' .. colorValues['name'] .. ' Empty"')
    currentImageId = currentImageId + 1
    gma.gui.progress.set(progressBarHandle, currentImageId - firstImageId)
  end
  -- We create full images
  for colorIndex, colorValues in ipairs(colors) do
    createImage(colorValues['red']*2.55, colorValues['green']*2.55, colorValues['blue']*2.55, true, currentImageId)
    gma.cmd('Label Image ' .. tostring(currentImageId) .. ' "' .. colorValues['name'] .. ' Full"')
    currentImageId = currentImageId + 1
    gma.gui.progress.set(progressBarHandle, currentImageId - firstImageId)
  end
end

createGels = function()
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

-- Creates a color picker image with the corresponding rgb color at the given image ID
-- 'full' argument is a boolean defining if the created image is a full image (true) or an empty image (false)
createImage = function(red, green, blue, full, imageId)
  -- The string that will contain the image data, before being converted to base64
  local byteArray
  if (full == true) then
    byteArray = imageBytesStart .. string.char(math.floor(blue), math.floor(green), math.floor(red)) .. fullImageBytesEnd 
  else
    byteArray = imageBytesStart .. string.char(math.floor(blue), math.floor(green), math.floor(red)) .. emptyImageBytesEnd
  end
  -- We encode the image to base64
  local encoded = base64.encode(byteArray)
  
  -- Header of the XML file that will be used to import the image
  local header = '<?xml version="1.0" encoding="utf-8"?>\n<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.7.0/MA.xsd" major_vers="3" minor_vers="7" stream_vers="0">\n<Info datetime="2020-05-30T19:50:23" showfile="Florian ANAYA" />\n<UserImage index="13" name="AttributePickerImage" hasTransparency="false" width="8" height="8">\n<Image>'
  
  local encodedPath = gma.show.getvar('PATH') ..  '/importexport/tempimage.xml'
  local encodedFile = io.open(encodedPath, "w")
  -- We add the XML code containing the base64 encoded image to the file
  encodedFile:write(header)
  encodedFile:write(encoded)
  encodedFile:write("</Image>\n</UserImage>\n</MA>")
  encodedFile:close()
  -- We import the image into MA
  gma.cmd('Import "tempimage.xml" Image ' .. tostring(imageId))
  gma.sleep(0.05)
  os.remove(encodedPath)
end

-----------------------
-- base64 library
-- https://github.com/iskolbin/lbase64/blob/master/base64.lua
-- Only the encoding part has been kept
-----------------------
local extract = _G.bit32 and _G.bit32.extract
if not extract then
    if _G.bit then
        local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
        extract = function( v, from, width )
            return band( shr( v, from ), shl( 1, width ) - 1 )
        end
    elseif _G._VERSION >= "Lua 5.3" then
        extract = load[[return function( v, from, width )
            return ( v >> from ) & ((1 << width) - 1)
        end]]()
    else
        extract = function( v, from, width )
            local w = 0
            local flag = 2^from
            for i = 0, width-1 do
                local flag2 = flag + flag
                if v % flag2 >= flag then
                    w = w + 2^i
                end
                flag = flag2
            end
            return w
        end
    end
end

function base64.makeencoder( s62, s63, spad )
    local encoder = {}
    for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
        'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
        'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
        'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
        '3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
        encoder[b64code] = char:byte()
    end
    return encoder
end

function base64.encode( str )
    usecaching = true
    local imageBarHandle = gma.gui.progress.start("Importing\n")
    gma.gui.progress.setrange(imageBarHandle, 0, 100)
    gma.gui.progress.settext(imageBarHandle, "%")
    local char, concat = string.char, table.concat
    local DEFAULT_ENCODER = base64.makeencoder()
    encoder = DEFAULT_ENCODER
    local t, k, n = {}, 1, #str
    local lastn = n % 3
    local cache = {}
    local modulo = math.ceil((n / 3) / 100)
    for i = 1, n-lastn, 3 do
        if (i % modulo == 1) then
            gma.gui.progress.set(imageBarHandle, math.floor((i/n)*100))
        end
        local a, b, c = str:byte( i, i+2 )
        local v = a*0x10000 + b*0x100 + c
        local s
        if usecaching then
            s = cache[v]
            if not s then
                s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
                cache[v] = s
            end
        else
            s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
        end
        t[k] = s
        k = k + 1
    end
    if lastn == 2 then
        local a, b = str:byte( n-1, n )
        local v = a*0x10000 + b*0x100
        t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
    elseif lastn == 1 then
        local v = str:byte( n )*0x10000
        t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
    end
    gma.gui.progress.stop(imageBarHandle)
    return concat( t )
end
-----------------------
-- End of base64 library
-----------------------



-- Execution of the program when the user clicks on the plugin
return function()
  -- We check that the plugin has not already been executed without a reload
  if (alreadyExecuted) then
    gma.feedback("Plugin exited: Script already executed")
    gma.gui.msgbox("Operation canceled", "The script has already been executed.\nIf you want to create a second color picker, please reload the plugin (edit the plugin and hit 'reload')")
    return
  end
  
  -- We initialize variables (in case the plugin is executed twice without being reloaded)
  firstMacroId = 1
  currentMacroId = 1
  lastMacroId = 1
  nbNeededMacros = 0
  nbNeededExecs = 0
  firstImageId = 14
  currentImageId = 14
  lastImageId = 14
  firstEmptyImageId = 14
  lastEmptyImageId = 14
  firstFullImageId = 14
  lastFullImageId = 14
  nbNeededImages = nbColors * 2
  
  x = startX
  y = startY
  
  -- We find the specified exec page and exec ID and verify they are correct
  execPage = math.floor(execId)
  firstExecId = math.tointeger(tostring((execId - execPage) * 1000))
  if (execPage <= 0 or firstExecId <= 0) then
    gma.gui.msgbox("Incorrect exec", "The specified executor " .. tostring(execId) .. " is invalid.\nIt must include the exec page, in the format X.XXX (ie. 1.101, 5.001, 10.015).")
    gma.feedback("Plugin exited: Incorrect first executor")
    return
  end
  currentExecId = firstExecId
  
  -- We search the first available macros
  progressBarHandle = gma.gui.progress.start("Creating Color Picker")
  gma.gui.progress.settext(progressBarHandle, "Searching for available macros")
  if (not findFirstAvailableMacro()) then
    gma.feedback("Plugin exited: Not enough available macros")
    gma.gui.progress.stop(progressBarHandle)
    return
  end
  gma.feedback("nbNeededMacros=" .. tostring(nbNeededMacros) .. ", nbNeededExecs=" .. tostring(nbNeededExecs))
  
  -- If images are enabled, we search for the first available image ID
  if (useImages) then
    gma.gui.progress.settext(progressBarHandle, "Searching for available macros")
    if (not findFirstAvailableImage()) then
      gma.feedback("Plugin exited: Not enough available images (" .. nbNeededImages .. ")")
      gma.gui.progress.stop(progressBarHandle)
      return
  end
  gma.feedback('nbNeededImages=' .. tostring(nbNeededImages) .. ', FirstImageID=' .. tostring(firstImageId) .. ', LastImageID=' .. tostring(lastImageId))
  end
  
  -- We verify colors
  gma.gui.progress.settext(progressBarHandle, "Verifying colors")
  if (not verifyColors()) then
    gma.feedback("Plugin exited: Incorrect colors")
    gma.gui.progress.stop(progressBarHandle)
    return
  end
  
  -- We verify groups
  gma.gui.progress.settext(progressBarHandle, "Verifying groups")
  if (not verifyGroup(groups)) then
    gma.feedback("Plugin exited: Incorrect groups")
    gma.gui.progress.stop(progressBarHandle)
    return
  end
  
  -- We verifiy the layout definition
  gma.gui.progress.settext(progressBarHandle, "Verifying layout")
  if (not verifyLayout()) then
    gma.feedback("Plugin exited: Incorrect layout")
    gma.gui.progress.stop(progressBarHandle)
    return
  end
  
  -- We verifiy that needed execs are available
  gma.gui.progress.settext(progressBarHandle, "Verifying execs")
  if (not verifyFreeExecs()) then
    gma.feedback("Plugin exited: Not enough free executors")
    gma.gui.progress.stop(progressBarHandle)
    gma.gui.msgbox("Error: Not enough free executors", "The plugin is configured to use executors " .. tostring(execPage) .. "." .. tostring(firstExecId) .. " Thru " .. tostring(execPage) .. "." .. tostring(lastExecId) .. " but they are currently in use.\nPlease delete them or change the config of the plugin so that it uses other executors.")
    return
  end
  gma.gui.progress.stop(progressBarHandle)
  
  if (not gma.gui.confirm("Color Picker", "The Color Picker is about to be created on:\n- Layout " .. tostring(layoutId) ..  "\n- Executors " .. tostring(execPage) .. "." .. tostring(firstExecId) .. " Thru " .. tostring(execPage) .. "." .. tostring(lastExecId) .. "\n- Macros " .. tostring(firstMacroId) .. " Thru " .. tostring(lastMacroId) .. "\nIf this is not correct, please edit the plugin to change those values.")) then
    gma.feedback("Plugin exited: Operation aborted by the user")
    gma.gui.msgbox("Operation canceled", "The creation of the color picker has been aborted.")
    return
  end
    
  gma.cmd("BlindEdit on")
  progressBarHandle = gma.gui.progress.start("Creating Color Picker")
  
  -- We create the template full and empty images 
  if (useImages) then
    createImages()
  end
  
  gma.gui.progress.setrange(progressBarHandle, 0, nbNeededMacros)
  gma.gui.progress.settext(progressBarHandle, "Creating macros: ")
  createGels()
  treatGroupOrArray(groups)
  
  xmlFileContent = xmlFileContent .. '</CObjects><Texts>' .. textFileContent .. '</Texts></LayoutData></Group></MA>'
  
  local fileName = "layouttemp.xml"
  local filePath = gma.show.getvar('PATH') ..  '/importexport/' .. fileName
  local file = io.open(filePath, "w")
  file:write(xmlFileContent)
  file:close()
  
  gma.cmd('Import "' .. fileName .. '" Layout ' .. layoutId)
  gma.sleep(0.05)
  -- os.remove(filePath)
  
  gma.cmd("ClearAll")
  gma.gui.progress.settext(progressBarHandle, "Finishing up")
  gma.cmd("BlindEdit Off")
  gma.cmd('Delete Gel "ColorPicker"')
  gma.gui.progress.stop(progressBarHandle)
  alreadyExecuted = true
  gma.gui.msgbox("Operation complete", "The Color Picker has been created on layout " .. tostring(layoutId))
end


