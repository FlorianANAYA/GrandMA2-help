-- AttributePicker v4 - Florian ANAYA - 2020
-- https://github.com/FlorianANAYA/GrandMA2-help/tree/master/AttributePicker
-- This plugin is designed to search for attributes' preregistered values.
-- Those values will be stored in executors and a layout with macros
-- will be created. You can specify the groups for which you wish
-- to search values and the list of attributes that will be looked for.
-- Included images will be imported into MA2 and into the layout.
-- You have to provide the executor which will be used (see config below).
-- The first available continuous range of macros is automatically selected.
-- Note: All lines that start with -- are comments.
-- If the plugin doesn't work after configuring it and shows no
-- message, check the system monitor for error message, you might have
-- misstyped something that broke the code.
-- Tested GrandMA2 versions: 3.7


-----------------------
-- Start of settings --
-----------------------

-- List of group IDs that will be used in the color picker.
-- Group IDs must be separated by commas ( , ). It is possible to use group
-- names instead of IDs, don't forget to include quotes (ie. {1, 2, "Mac Vipers", 8} )
local groups = { 7, 15, 16, 17 }

-- The list of attributes that are going to be searched. 
-- You can put whichever attribute you would like in here
-- (like PAN or TILT). Every attribute name must be enclosed
-- in quotes, and they must be separated by a comma. 
-- You can find the complete list of attributes of each fixture type in
-- Setup > Patch & Fixture Schedule > Fixture Types
local attributes = { "GOBO1", "GOBO1_POS", "GOBO2", "GOBO2_POS", "GOBO3", "GOBO3_POS", "SHUTTER", "PRISMA1", "PRISMA2", "ANIMATIONWHEEL", "ANIMATIONINDEXROTATE", "ANIMATIONINDEXROTATE2", "EFFECTWHEEL", "EFFECTWHEELSELECT", "EFFECTINDEXROTATE" }

-- The ID of the layout that will be used.
-- The provided layout must be empty.
local layoutId = 1

-- ID of first executor to use. The plugin will need as many executors
-- as there are attributes in groups below.
-- If one of the executors is already in use, the program will not execute.
-- It must include the exec page, the format is X.XXX (ie. 1.101, 5.001 or 7.015)
local execId = 1.101

-- The plugin is able to import images when available.
-- Define this variable to true to enable importing images,
-- or false to disable it. 
local importImages = true

-- Layout settings
local startX = 0
local startY = 0
local offsetX = 1
local offsetY = 1.1

--------------------------------
-- End of settings            --
-- Don't touch anything below --
--------------------------------


-- The total number of macros needed
local nbNeededMacros = 0
-- The ID of the first macro that will be used
local firstMacroId = 1
-- The ID of the last macro that will be used
local lastMacroId = 1

-- The page of the executor that will be used
local execPage = 0
-- The ID of the first executor to use
local firstExecId = 0
-- The ID of the current executor being used
local currentExecId = 0
-- The total number of executors that are needed
local nbNeededExecs = 0
-- The ID of the last exec that is going to be used
local lastExecId = 0

-- For base64 library
local base64 = {}

-- { { ["GroupID"] = 10, ["FixtureTypeID"] = 7, ["Values"] = { { ["Data"] = 2.54, ["Name"] = "GOBO 1" }, { ["Data"] = 7.6, ["Name"] = "GOBO 2" } }, { ["GroupID"] = 11, ["FixtureTypeID"] = 5 } }
local groupsData = {}
-- List of valide attributes after searching in the provided list
local attributeList = {}
-- The handle of the progress bar
local progressBarHandle = 0
-- Predeclaration of all functions
local askForCancel, removeLastWord, addQuotes, findNextAvailableImage, importImage,findPreRegisteredValues, findFixtureTypes, findInfosForGroup, findInfos, findChildNamed, findPropertyNamed, findChildWithPropertyOfValue, findFirstAvailableMacro, verifyFreeExecs, verifyAttributes, verifyLayout, verifyGroups, createMacros


-- This function asks for a confirm from the user. If the user hits ok, the
-- program returns true. If the parameter groupValues is provided,
-- the index "Skipped" will be set to true.
-- If the user hits cancel, a message box will be shown and false is returned
-- true = continue, false = cancel.
askForCancel = function(confirmTitle, confirmMessage, groupValues)
  if (gma.gui.confirm(confirmTitle, confirmMessage)) then
    if (type(groupValues) == "table") then
      groupValues["Skipped"] = true
    end
    return true
  else
    gma.gui.progress.stop(progressBarHandle)
    gma.gui.msgbox("Operation canceled", "The creation of the Attribute Picker has been canceled")
    gma.feedback("Plugin exited: Interrupted by the user")
    return false
  end
end

-- Removes the last word separated by a space form the string passed as argument.
removeLastWord = function(str)
  -- We remove all ending white spaces
  while (string.sub(str, string.len(str), string.len(str)) == " ") do
    str = string.sub(str, 1, string.len(str) - 1)
  end
  local index = 1
  for i=1,string.len(str),1 do
    index = string.find(str, " ", i) or index
  end
  index = index - 1
  if (index > 1) then
    str = string.sub(str, 0, index)
  end
  return str
end

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

-- Finds the next available image that is available and returns 
-- its pool ID and its handle
findNextAvailableImage = function()
  local imageHandle
  local imageId = 1
  local found = false
  while (not found) do
    imageHandle = gma.show.getobj.handle("Image " .. tostring(imageId))
    if (imageHandle == nil) then
      found = true
    else
      imageId = imageId + 1
    end
  end
  return imageId, imageHandle
end

-- Import the image located at the path provided as argument.
-- Returns the image ID where it is newly located, or returns nil
-- if the file doesn't exist or an error occured.
importImage = function(filePath)
  if (filePath == nil) then
    return nil
  end
  -- We find the next available image ID
  local imageId = findNextAvailableImage()
  local header = '<?xml version="1.0" encoding="utf-8"?>\n<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.7.0/MA.xsd" major_vers="3" minor_vers="7" stream_vers="0">\n<Info datetime="2020-05-30T19:50:23" showfile="Florian ANAYA" />\n<UserImage index="13" name="AttributePickerImage" hasTransparency="false" width="1" height="1">\n<Image>'
  -- We read the image file
  local file = io.open(gma.show.getvar('PATH') .. filePath, "rb")
  if (file == nil) then
    return nil
  end
  -- We encode the image file to base64
  local encoded = base64.encode(file:read("*all"), filePath)
  file:close()
  -- We create a new tempfile
  local encodedPath = gma.show.getvar('PATH') ..  '/importexport/tempimage.xml'
  local encodedFile = io.open(encodedPath, "w")
  -- We add the XML code containing the base64 encoded image 
  encodedFile:write(header)
  encodedFile:write(encoded)
  encodedFile:write("</Image>\n</UserImage>\n</MA>")
  encodedFile:close()
  gma.cmd('Import "tempimage.xml" Image ' .. tostring(imageId))
  gma.sleep(0.05)
  os.remove(encodedPath)
  -- We return the ID of the new image
  return imageId
end

-- Finds channel values contained in the children of the element
-- represented by the handle passed in argument.
-- Values are then added to the valuesTable['index']
-- Returns the number of entries found, and the number
-- of images found.
findPreRegisteredValues = function(handle, valuesTable, wheelCollectionHandle)
  local imageNb = 0
  -- We find the wheel name linked to this (sub)attribute
  local _, _, wheelName = findPropertyNamed(handle, "Wheel")
  if (wheelName == nil) then
    wheelName = ""
  end
  -- Wheel names always come with a number at the end that we don't need, so we remove it
  wheelName = removeLastWord(wheelName)
  local wheelHandle = findChildNamed(wheelCollectionHandle, wheelName)
  
  local childrenNb = gma.show.getobj.amount(handle)
  for childIndex=0,childrenNb-1,1 do
    local childHandle = gma.show.getobj.child(handle, childIndex)
    -- We find the name of the value, its "From" and "To"
    local childName = gma.show.getobj.name(childHandle)
    childName = childName:gsub("[%;%\\%[%]%{%}%&%~%\"%!%§%,%?%*]", "") -- We remove illegal characters from name
    local childFrom = tonumber(gma.show.property.get(childHandle, "From"))
    local childTo = tonumber(gma.show.property.get(childHandle, "To"))
    local childValue = (childFrom + childTo) / 2
    -- We insert those values in the table
    local index = #valuesTable + 1
    valuesTable[index] = {}
    valuesTable[index]["Data"] = childValue
    valuesTable[index]["Name"] = removeLastWord(childName)
    -- We find the slot value of this child, it's its link the wheel entry
    local slot = gma.show.property.get(childHandle, "Slot|No")
    if (wheelHandle ~= nil and importImages == true) then
      -- We find the handle of the wheel 
      local _, wheelChildHandle = findChildWithPropertyOfValue(wheelHandle, "No.", slot)
      if (wheelChildHandle ~= nil) then
        -- We find the file name linked to this wheel entry
        local _, _, filename = findPropertyNamed(wheelChildHandle, "FileName")
        if (type(filename) == "string" and filename:len() > 1) then
          local filePath = '/gobos/' .. filename
          valuesTable[index]["ImageFilePath"] = filePath
          imageNb = imageNb + 1
        end
      end
    end
  end 
  return childrenNb, imageNb
end

-- Finds the fixture type of the group passed in argument.
-- Returns nil if the type couldn't be found or if there
-- are several fixture types in the group and the user 
-- decides to cancel.
-- If ok, returns the fixture type ID (number) and the fixture type name (string).
-- function inspired from plugins from: https://giaffodesigns.com/
findFixtureTypes = function(groupId)
  gma.cmd('SelectDrive 1')
  local fileName = 'tempfile.xml'
  local filePath = gma.show.getvar('PATH') ..  '/importexport/' .. fileName
  
  -- We export the group to the XML file
  gma.cmd('Export Group ' .. addQuotes(groupId) .. ' "' .. fileName .. '"')
  -- We read back the XML file
  local file = io.open(filePath, 'r')
  local fileContent = file:read('*a')
  file:close()
  -- We delete the file
  os.remove(filePath)
  
  -- Determining which fixture type will be used for each group
  local defaultFixtureTypeId = 0 -- The fixture type that will be used for this group
  local defaultFixtureTypeName = "" -- the name of the fixture type
  local differentFixtureTypes = false -- true if the group contains several fixture types
  
  for match in fileContent:gmatch('<Subfixture (.-) />') do
    local fixtureID = tonumber(match:match('fix_id="(%d+)"')) 
    if (type(fixtureID) == "number") then
      local fixtureHandle = gma.show.getobj.handle("Fixture " .. tostring(fixtureID))
      if (fixtureHandle ~= nil) then
        _, _, fixtureTypeName = findPropertyNamed(fixtureHandle, "Fixture Type")
        -- fixtureTypeName contains a string that has the fixture type ID at the beggining (ie. "7 - MAC Viper Performance") so we find back this ID
        local fixtureTypeId = tonumber(fixtureTypeName:sub(0, fixtureTypeName:find(" ")))
        -- We check if we already have found a fixture type
        if (defaultFixtureTypeId == 0) then
          -- If there is no set fixture type, we set it
          defaultFixtureTypeId = fixtureTypeId
          defaultFixtureTypeName = fixtureTypeName
        elseif (defaultFixtureTypeId ~= fixtureTypeId) then
          -- If the fixture type already set and is different from this fixture type, we set differentFixtureTypes to true
          differentFixtureTypes = true
        end
      end
    end
  end
  -- If several fixture types have been found, we warn the user that this group contains several fixture types and ask if they wants to cancel
  if (differentFixtureTypes == true) then
    if (not askForCancel("Ambiguous group", "Group " .. tostring(groupId) .. " contains several fixture types.\nBy default, this group will be treated as ' " .. defaultFixtureTypeName .. " '.\nThis could have unpredicted behaviour.\nClick Ok to continue or cancel to exit the plugin.")) then
      return nil
    end
  end
  -- We put the fixture type in the values of the group (in 'groups')
  gma.feedback("Using fixture type ' " .. defaultFixtureTypeName .. " ' for group " .. tostring(groupId))
  
  return defaultFixtureTypeId, defaultFixtureTypeName
end

-- Find all the infos needed to create the picker in
-- the table passed as the first argument
findInfosForGroup = function(groupValues)
  local groupId = groupValues["GroupID"]
  local fixtureTypeId = groupValues["FixtureTypeID"]
  local fixtureTypeHandle = gma.show.getobj.handle("FixtureType " .. tostring(fixtureTypeId))
  
  local wheelCollectionsHandle = findChildNamed(fixtureTypeHandle, "Wheels")
  
  -- Fixture types have a child name "Modules", we take the first child of it
  local module1_1_handle = findChildNamed(fixtureTypeHandle, "Modules")
  if (type(module1_1_handle) == "number") then
    local module1_2_handle = gma.show.getobj.child(module1_1_handle, 0)
    if (type(module1_2_handle) == "number") then
      -- We go thru all provided attributes and look for them in the fixture
      for attributeIndex,attributeName in ipairs(attributeList) do
        local attributeHandle = findChildNamed(module1_2_handle, attributeName)
        if (attributeHandle == nil) then
          gma.feedback("Group " .. addQuotes(groupId) .. " (FixtureType " .. tostring(fixtureTypeId) .. ") doesn't have attribute ' " .. addQuotes(attributeName) .. " '")
        else
          -- We count the number of subattriutes, entries and images to display it in console when done
          local nbSubAttributes = 0
          local nbEntries = 0
          local nbImages = 0
          nbNeededExecs = nbNeededExecs + 1
          -- We check if the attribute has sub attributes by checking if its first child has children.
          -- If not, then the children of the attributes are values
          local child0Handle = gma.show.getobj.child(attributeHandle, 0)
          -- Defines if subattribute are present 
          local subAttributePresent = gma.show.getobj.amount(child0Handle) > 0
          groupValues["Values"][attributeName] = {}
          
          if (subAttributePresent == true) then -- There are subattributes
            nbSubAttributes = gma.show.getobj.amount(attributeHandle)
            for subAttributeIndex=0,nbSubAttributes-1,1 do
              local subAttributeHandle = gma.show.getobj.child(attributeHandle, subAttributeIndex)
              local nbEntriesFound, nbImagesFound = findPreRegisteredValues(subAttributeHandle, groupValues["Values"][attributeName], wheelCollectionsHandle)
              nbEntries = nbEntries + nbEntriesFound
              nbImages = nbImages + nbImagesFound
            end
          else -- No subattributes
            local nbEntriesFound, nbImagesFound = findPreRegisteredValues(attributeHandle, groupValues["Values"][attributeName], wheelCollectionsHandle)
            nbEntries = nbEntries + nbEntriesFound
            nbImages = nbImages + nbImagesFound
          end
          gma.feedback("Group " .. addQuotes(groupId) .. " (FixtureType " .. tostring(fixtureTypeId) .. ") attribute ' " .. attributeName .. " ' has " .. tostring(nbSubAttributes) .. " sub-attributes, " .. tostring(nbEntries) .. " entries and " .. tostring(nbImages) .. " images found")
        end
        gma.sleep(0.05)
      end
    else -- For some reason, the fixture doesn't have a main module
      if (not askForCancel("Error", "Could not find module_1_2 for group " .. tostring(groupId) .. " fixture type " .. tostring(fixtureTypeId) .. "\nThis error is typically not recoverable.\nHit 'Ok' to skip this group or 'cancel' to exit the plugin.", groupValues)) then
        return false
      end
    end
  else -- For some reason, the fixture doesn't have a 'modules' child
    if (not askForCancel("Error", "Could not find module_1_1 for group " .. tostring(groupId) .. " fixture type " .. tostring(fixtureTypeId) .. "\nThis error is typically not recoverable.\nHit 'Ok' to skip this group or 'cancel' to exit the plugin.", groupValues)) then
      return false
    end
  end
  return true
end

-- fills the 'groupsData' table with all the infos needed to
-- create the picker
findInfos = function()
  for groupIndex,groupValues in ipairs(groupsData) do
    if (not findInfosForGroup(groupValues)) then
      return false
    end
    gma.gui.progress.set(progressBarHandle, groupIndex)
    gma.sleep(0.05)
  end
  return true
end

-- Finds a child that has a name that contains the name provided
-- in argument 2. If not found, returns nil. Otherwise, returns
-- child's handle. The comparison is not case sensitive.
findChildNamed = function(handle, childNameToFind)
  childNameToFind = childNameToFind:lower()
  local childNb = gma.show.getobj.amount(handle)
  for childIndex=0,childNb-1,1 do
    local childHandle = gma.show.getobj.child(handle, childIndex)
    local childName = removeLastWord(gma.show.getobj.name(childHandle):lower())
    if (childName == childNameToFind) then
      return childHandle
    end
  end
  return nil
end

-- Finds a property that has a name that contains the name provided
-- in argument 2. If not found, returns nil. Otherwise, returns
-- property index, property name and property value.
-- The comparison is not case sensitive.
findPropertyNamed = function(handle, propertyNameToFind)
  propertyNameToFind = string.lower(propertyNameToFind)
  local propertyNb = gma.show.property.amount(handle)
  if (propertyNb == nil) then
    return nil
  end
  for propertyIndex=0,propertyNb-1,1 do
    local propertyName = gma.show.property.name(handle, propertyIndex)
    local propertyNameLower = string.lower(propertyName)
    if (propertyNameLower:find(propertyNameToFind)) then
      local propertyValue = gma.show.property.get(handle, propertyIndex)
      return propertyIndex, propertyName, propertyValue
    end
  end
  return nil
end


-- Looks for a child that has a property with value provided.
-- Returns child index and child handle if found, nil otherwise
findChildWithPropertyOfValue = function(handle, propertyNameToFind, propertyValueToFind)
  propertyNameToFind = propertyNameToFind:lower()
  propertyValueToFind = propertyValueToFind:lower()
  local childNb = gma.show.getobj.amount(handle)
  for childIndex=0,childNb-1,1 do
    local childHandle = gma.show.getobj.child(handle, childIndex)
    local propertyIndex, propertyName, propertyValue = findPropertyNamed(childHandle, propertyNameToFind)
    if (propertyIndex ~= nil) then
      propertyValue = propertyValue:lower()
      if (propertyValue == propertyValueToFind) then
        return childIndex, childHandle
      end
    end
  end
  return nil
end

-- Counts total number of needed macros and find the first continuous
-- row of macros available that can contain them all.
-- returns false if the maximum index is reached.
findFirstAvailableMacro = function()
  -- We count the number of needed macros 
  for groupIndex,groupValues in ipairs(groupsData) do
    for attributeName,attributesValues in pairs(groupValues["Values"]) do
      nbNeededMacros = nbNeededMacros + #attributesValues
    end
  end
  -- Then we find the spot
  local empty = false
  while (not empty) do
    empty = true
    for testedMacroId=firstMacroId,firstMacroId+nbNeededMacros,1 do
      local handle = gma.show.getobj.handle("Macro "..tostring(testedMacroId))
      empty = handle == nil
      if (not empty) then
        firstMacroId = testedMacroId + 1
        break
      end
    end 
  end
  currentMacroId = firstMacroId
  if (nbNeededMacros == 0) then
    lastMacro = firstMacroId
  else
    lastMacroId = firstMacroId + nbNeededMacros-1
  end
  gma.feedback("nbNeededMacros=" .. tostring(nbNeededMacros) .. ", FirstMacro=" .. tostring(firstMacroId) .. ", LastMacro=" .. tostring(lastMacroId))
  
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

-- Verifies if there is a suffisent number of unsuned execs
-- counting from the one specified by the user
verifyFreeExecs = function()
  for execNb=currentExecId,currentExecId+nbNeededExecs-1,1 do
    local exec = gma.show.getobj.handle("Executor " .. tostring(execPage) .. '.' .. tostring(execNb))
    if (exec ~= nil) then
      gma.gui.msgbox("Not enough executors", "The plugin is configured to use executors " .. tostring(execPage) .. "." .. tostring(firstExecId) .. " Thru " .. tostring(execPage) .. "." .. tostring(lastExecId) .. " but they are currently in use.\nPlease delete them or change the config of the plugin so that it uses other executors.")
      return false
    end
  end
  return true
end

-- Verifies that all provided attributes exist and are valid.
-- All valid attributes are inserted into attributeList
verifyAttributes = function()
  -- We verify that the list exists 
  if (attributes == nil) then
    gma.gui.msgbox("Attrribute list not provided", "The attribute list has been changed and can't be found, please check the config.")
    return false
  end
  -- We verify that the list is a list
  if (type(attributes) ~= "table") then
    gma.gui.msgbox("Attrribute list invalid", "The attribute list is not valid, please check the config.")
    return false
  end
  -- We verify that there is at least one element in the list
  if (#attributes == 0) then
    gma.gui.msgbox("Attrribute list empty", "The attribute list is empty, you have to provide at least one attribute.")
    return false
  end
  -- We check every element, if it is valid and it exists, we insert it into attributeList
  for attributeIndex, attributeName in ipairs(attributes) do
    if (type(attributeName) == "string") then
      local attributeHandle = gma.show.getobj.handle("Attribute " .. addQuotes(attributeName))
      if (attributeHandle  == nil) then
        gma.feedback("Attribute " .. addQuotes(attributeName) .. " not found")
      else
        gma.feedback("Attribute " .. addQuotes(attributeName) .. " found")
        attributeList[#attributeList+1] = attributeName
      end
    else
      gma.feedback("Invalid attribute " .. addQuotes(attributeName))
    end
  end
  -- We verify that there is at least one valid element
  if (#attributeList == 0) then
    gma.gui.msgbox("Attrribute list empty", "No valid attribute were found in the provided attribute list.\nMaybe, none of the imported fixtures have those attributes ?")
    return false
  end
  return true
end

-- Verifies that the provided layout ID is valid and empty.
-- Also checks that the maximum possible ID is not reached.
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
  if (layoutHandle == nil) then
    -- If the layout doesn't already exist, we check that we have not
    -- reached the maximum layout ID.
    -- Personnal experience found out that 10000 is the maximum, but this value may
    -- evolve in the future or between different installation, so we test
    -- by creating a layout at the provided ID and verifying that it exists.
    gma.cmd("Store Layout " .. tostring(layoutId))
    layoutHandle = gma.show.getobj.handle("Layout " .. tostring(layoutId))
    gma.cmd("Delete Layout " .. tostring(layoutId))
    -- A nil handle means that the layout has not been created (and a nice error message should be present in command line feedback)
    if (layoutHandle == nil) then
      gma.gui.msgbox("Invalid layout ID", "The provided layout ID is too high")
      return false
    end
  else
    gma.gui.msgbox("Layout already in use", "The provided layout " .. tostring(layoutId) .. " is already used. Please specify an other layout.")
    return false
  end
  return true
end

-- Verifies that the data provided the the 'groups' table is correct.
-- Fills the 'groupsData' table with infos needed about groups.
verifyGroups = function()
  if (groups == nil) then
    gma.gui.msgbox("Group list not provided", "The group list has been changed and can't be found, please check the config.")
    return false
  end
  if (type(groups) ~= "table") then
    gma.gui.msgbox("Group list invalid", "The group list is not valid, please check the config.")
    return false
  end
  if (#groups == 0) then
    gma.gui.msgbox("Group list empty", "The group list is empty, you have to provide at least one group in the config.")
    return false
  end
  
  for groupIndex,groupId in ipairs(groups) do
    if (type(groupId) ~= "number" and type(groupId) ~= "string") then
      gma.gui.msgbox("Unknown group", "One of the specified group is not valid.\nPlease check.")
      return false
    end
    local groupHandle = gma.show.getobj.handle('Group ' .. addQuotes(groupId))
    if (groupHandle == nil) then
      gma.gui.msgbox("Unknown group", "One of the specified group doesn't exists.\nThe group ' " .. tostring(groupId) .. " ' couldn't be found. Please check.")
      return false
    end
    groupsData[groupIndex] = {}
    groupsData[groupIndex]["GroupID"] = groupId
    groupsData[groupIndex]["GroupName"] = removeLastWord(gma.show.getobj.name(groupHandle))
    local fixtureTypeId = findFixtureTypes(groupId)
    if (fixtureTypeId == nil) then
      return false
    end
    groupsData[groupIndex]["FixtureTypeID"] = fixtureTypeId
    groupsData[groupIndex]["Values"] = {}
  end
  return true
end

-- Creates and populate the executors.
-- Creates the macros and assign them to the layout.
 createMacros = function()
  -- Header of the layout XML file
  local header = '<?xml version="1.0" encoding="utf-8"?><MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.7.0/MA.xsd" major_vers="3" minor_vers="7" stream_vers="0"><Info datetime="2020-06-03T19:21:08" showfile="Florian ANAYA" /><Group index="0" name="Attribute Picker"><LayoutData index="0" marker_visible="true" background_color="000000" visible_grid_h="1" visible_grid_w="1" snap_grid_h="0.5" snap_grid_w="0.5" default_gauge="Filled &amp; Symbol" subfixture_view_mode="DMX Layer"><CObjects>'
  local fileName = "layouttemp.xml"
  local filePath = gma.show.getvar('PATH') ..  '/importexport/' .. fileName
  local file = io.open(filePath, "w")
  file:write(header)
  local x = startX
  local y = startY
  -- The text section that will be added to the XML file after the macros
  local textStr = ""
  for groupIndex,groupValues in ipairs(groupsData) do
    for attributeName,attributeValues in pairs(groupValues["Values"]) do
      -- We record the ID of the first and last macros that will be used by this particular line
      local firstRowMacroId = currentMacroId
      local lastRowMacroId = currentMacroId + #attributeValues - 1
      x = startX
      
      textStr = textStr .. '<LayoutElement text_align_flags="18" center_x="' .. tostring(startX - (3*offsetX)) .. '" center_y="' .. tostring(y) .. '" size_h="1" size_w="3" background_color="00000000" border_color="00000000" icon="None" text="' .. groupValues["GroupName"] .. '\n' .. attributeName .. '" show_id="1" show_name="1" show_type="1" show_dimmer_bar="Off" show_dimmer_value="Off" select_group="1"><image /></LayoutElement>'
      
      for valueIndex,values in ipairs(attributeValues) do
        gma.cmd('ClearAll')
        gma.cmd('Group ' .. addQuotes(groupValues['GroupID']))
        gma.cmd('Attribute ' .. addQuotes(attributeName) .. ' At ' .. tostring(values['Data']))
        gma.cmd('Store Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' cue ' .. tostring(valueIndex))
        gma.cmd('Label Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' cue ' .. tostring(valueIndex) .. ' "' .. values['Name'] .. '"')
        gma.cmd('Assign Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' cue ' .. tostring(valueIndex) .. ' /cmd="Appearance Macro 1.' .. tostring(firstRowMacroId) .. ' Thru 1.' .. tostring(lastRowMacroId) .. ' /r=100 /g=0 /b=0 ; Appearance Macro 1.' .. tostring(currentMacroId)  .. ' /r=0 /g=100 /b=0')
        gma.cmd('Store Macro 1.' .. tostring(currentMacroId) .. ' "' .. values["Name"] .. '"')
        gma.cmd('Store Macro 1.' .. tostring(currentMacroId) .. ".1")
        gma.cmd('Assign Macro 1.' .. tostring(currentMacroId) .. '.1 /cmd="Goto Cue ' .. tostring(valueIndex) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. '"')
        
        local str = '<LayoutCObject font_size="Small" center_x="' .. tostring(x) .. '" center_y="' .. tostring(y) .. '" size_h="1" size_w="1" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="1" show_type="0" function_type="Pool icon" select_group="1"><image /><CObject name="' .. values["Name"] .. '"><No>13</No><No>1</No><No>' .. tostring(currentMacroId) .. '</No></CObject></LayoutCObject>'
        file:write(str)
        
        -- If an image has been found, we import it and add a second macro on top of the first with the image
        local imageFilePath = values["ImageFilePath"]
        if (imageFilePath ~= nil) then
          local imageId = importImage(imageFilePath)
          local str = '<LayoutCObject font_size="Small" center_x="' .. tostring(x) .. '" center_y="' .. tostring(y) .. '" size_h="0.95" size_w="0.95" background_color="3c3c3c" border_color="5a5a5a" icon="None" show_id="0" show_name="1" show_type="0" function_type="Simple" select_group="1" image_size="Fit"><image name="AttributePickerImage 27"><No>8</No><No>' .. tostring(imageId) .. '</No></image><CObject name="' .. values["Name"] .. '"><No>13</No><No>1</No><No>' .. tostring(currentMacroId) .. '</No></CObject></LayoutCObject>'
          file:write(str)
        end
        
        x = x + offsetX
        currentMacroId = currentMacroId + 1
        gma.gui.progress.set(progressBarHandle, currentMacroId-firstMacroId)
        gma.sleep(0.05)
      end
      gma.cmd('Label Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' "' .. groupValues['GroupName'] .. ' ' .. attributeName ..'"')
      currentExecId = currentExecId + 1
      y = y + offsetY
    end
  end
  file:write('</CObjects><Texts>')
  -- We write the texts in the file
  file:write(textStr)
  file:write('</Texts></LayoutData></Group></MA>')
  file:close()
  -- We import the layout
  gma.cmd('Import "' .. fileName .. '" Layout ' .. layoutId)
  gma.sleep(0.05)
  os.remove(filePath)
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

function base64.encode( str, filePath )
    usecaching = true
    local imageBarHandle = gma.gui.progress.start("Importing " .. filePath .. "\n")
    gma.gui.progress.setrange(imageBarHandle, 0, 100)
    gma.gui.progress.settext(imageBarHandle, "%")
    local char, concat = string.char, table.concat
    local DEFAULT_ENCODER = base64.makeencoder()
    encoder = DEFAULT_ENCODER
    local t, k, n = {}, 1, #str
    local lastn = n % 3
    local cache = {}
    local modulo = math.floor((n / 3) / 100)
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

-- Main function executed when the user clicks on the plugin
return function()
  -- Reinitialization of variables
  groupsData = {}
  attributeList = {}
  nbNeededMacros = 0
  firstMacroId = 1
  lastMacroId = 1
  nbNeededMacros = 0
  firstMacroId = 1
  lastMacroId = 1
  
  nbNeededExecs = 0
  lastExecId = 0
  
  -- We extract the exec page and and exec ID from 
  execId = string.format("%.3f", execId)
  local dotIndex = execId:find(".", 1, true)
  execPage = tonumber(execId:sub(0, dotIndex - 1))
  firstExecId = tonumber(execId:sub(dotIndex + 1, #execId))
  
  -- We find the specified exec page and exec ID and verify they are correct
  if (type(execPage) ~= "number" or type(firstExecId) ~= "number" or execPage <= 0 or firstExecId <= 0) then
    gma.gui.msgbox("Incorrect exec", "The specified executor ' " .. tostring(execId) .. " ' is invalid.\nIt must include the exec page, in the format X.XXX (ie. 1.101, 5.001, 10.015).")
    gma.feedback("Plugin exited: Incorrect first executor")
    return
  end
  currentExecId = firstExecId
  
  progressBarHandle = gma.gui.progress.start("Preparing Attribute Picker")
  
  -- We verifiy the layout definition
  gma.gui.progress.settext(progressBarHandle, "Verifying layout")
  if (not verifyLayout()) then
    gma.feedback("Plugin exited: Incorrect layout")
    gma.gui.progress.stop(progressBarHandle)
    return
  end
  
  -- Verification of groups
  gma.gui.progress.settext(progressBarHandle, "Verifying groups")
  if (not verifyGroups()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Incorrect groups")
    return
  end
  
  -- Verifications of provided attributes
  gma.gui.progress.settext(progressBarHandle, "Verifying attributes")
  if (not verifyAttributes()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Incorrect attrbiutes")
    return
  end
  
  -- We find attributes values in groups
  gma.gui.progress.settext(progressBarHandle, "Looking for parameters")
  gma.gui.progress.setrange(progressBarHandle, 0, #groups)
  if (not findInfos()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Canceled by the user during infos scouting")
    return
  end
  lastExecId = firstExecId + nbNeededExecs - 1
  
  -- We verify that we have enough free executors
  gma.gui.progress.settext(progressBarHandle, "Verifying executors")
  if (not verifyFreeExecs()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Not enough free executors")
    return
  end
  
  -- We find available macros
  gma.gui.progress.settext(progressBarHandle, "Looking for available macros")
  if (not findFirstAvailableMacro()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Not enough available macros")
    return
  end
  gma.gui.progress.stop(progressBarHandle)
  
  -- We ask the user if all parameters are correct and if we should continue
  local txt = "The Attribute Picker is about to be created on:\n- Layout " .. tostring(layoutId) ..  "\n- Executors " .. tostring(execPage) .. "." .. tostring(firstExecId) .. " Thru " .. tostring(execPage) .. "." .. tostring(lastExecId) .. "\n- Macros " .. tostring(firstMacroId) .. " Thru " .. tostring(lastMacroId)
  if (#attributes ~= #attributeList) then
    txt = txt .. "\nSome provided attrbiutes couldn't be found in MA2."
  end
  txt = txt .. "\nIf this is not correct, please edit the plugin to change those values."
  
  if (not gma.gui.confirm("Attribute Picker", txt)) then
    gma.feedback("Plugin exited: Operation aborted by the user")
    gma.gui.msgbox("Operation canceled", "The creation of the Attribute Picker has been aborted.")
    return
  end
  
  progressBarHandle = gma.gui.progress.start("Creating Attribute Picker")
  gma.gui.progress.settext(progressBarHandle, "Creating macros")
  gma.gui.progress.setrange(progressBarHandle, 0, nbNeededMacros)
  gma.cmd("ClearAll")
  gma.cmd("BlindEdit On")
  createMacros()
  gma.cmd("ClearAll")
  gma.cmd("BlindEdit Off")
  gma.gui.progress.stop(progressBarHandle)
  gma.gui.msgbox("Operation completed", "The Attribute Picker has been created in layout " .. tostring(layoutId))
end

