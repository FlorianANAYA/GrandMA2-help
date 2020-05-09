-- AttributePicker v2 - Florian ANAYA - 2020
-- https://github.com/FlorianANAYA/GrandMA2-help/tree/master/AttributePicker
-- This plugin will create several attribute pickers in a layout view. It is
-- fully customizable and can work with virtually any attribute despite
-- its main use is making gobo picker.
-- The plugin retrieves the default values of a channels (for example, the 
-- default gobos) that you usually find by cliking on an encoder.
-- It creates executors and macros. The first available
-- continuous range of macros is automatically selected whereas
-- you must provide the executors ID (and page) that wil be used in the config below.
-- As an example, the plugin is set up for a MAC viper performance.
-- Note: All lines that start with -- are comments.
-- Tested GrandMA2 versions: 3.7

-----------------------
-- Start of settings --
-----------------------

-- This is the list of row the final picker will contain. You can add new
-- lines by copy/pasting one of the example line and/or editing them.
-- Each line must repect the formatting, otherwise, the plugin won't work at all.
-- GroupID :      The ID of the group that will use the line. Currently, only IDs
--                are supported. Names are not.
-- FixtureTypeID: The fixture type ID of the fixtures included in the group.
--                Unfortunately, it is currently impossible to retrieve the fixture
--                type from a group with a plugin. So it must be specified explicitely.
--                You can find it in
--                Setup > Patch & Fixture Schedule > Fixture Types (on the right)
-- Attribute:     The attribute name that will be in the color picker.
--                Typical values are "GOBO1", "GOBO2", "EFFECTWHEEL", "COLOR1", etc.
--                Sometimes, display names are special. You can find the real name in
--                Setup > Patch & Fixture Schedule > Fixture Types > Edit 
-- SubAttribute:  These are the "tabs" you find in the menu opened by clicking the
--                encoder.  This parameter is optional. If you don't provide it, all
--                available sub attributes will be used (note that "ALL" is not
--                a valid sub attribute). If the attribute has no subattribute,
--                you should not provide it. Otherwise the group will be ignored.
local groups =
{
  { ["GroupID"] = 15, ["FixtureTypeID"] = 7, ["Attribute"] = "GOBO1", ["SubAttribute"] = "Index" },
  { ["GroupID"] = 15, ["FixtureTypeID"] = 7, ["Attribute"] = "ANIMATIONWHEEL", },
  { ["GroupID"] = 15, ["FixtureTypeID"] = 7, ["Attribute"] = "COLOR1",["SubAttribute"] = "Select" },
  { ["GroupID"] = 15, ["FixtureTypeID"] = 7, ["Attribute"] = "CTO",},
  { ["GroupID"] = 15, ["FixtureTypeID"] = 7, ["Attribute"] = "effectwheel",},
  { ["GroupID"] = 15, ["FixtureTypeID"] = 7, ["Attribute"] = "SHUTTER", },
}

-- The ID of the layout that will be used
local layoutId = 1

-- The page of the executor that will be used
local execPage = 1

-- The ID of the first executor to use. (There will be as many executors used as
-- there are groups declared above)
local firstExecId = 101

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
-- The ID of the current executor being used
local currentExecId = firstExecId
-- The total number of executors that are needed
local nbNeededExecs = #groups
-- The ID of the last exec that is going to be used
local lastExecId = firstExecId + nbNeededExecs - 1
-- Becomes true at the end of the script, to avoid the user to execute the
-- plugin twice without a reset of the variables
local alreadyExecuted = false
-- The handle of the progress bar
local progressBarHandle = 0
-- Predeclaration of all functions
local askForCancel, findPreRegisteredValues, findInfosForGroup, findInfos, findChildNamed, findFirstAvailableMacro, verifyFreeExecs, verifyGroups, createLayout, createMacros, removeLastWord


-- This function exists because the function gma.gui.msgbox()
-- doesn't block the thread so multiple message override each other.
-- It asks for a confirm from the user. If the user hits ok, the
-- program will continue. If the parameter groupValues is provided,
-- the index "Skipped" will be set to true
-- If the user hits cancel, a message box will be shown and the plugin will stop
askForCancel = function(confirmTitle, confirmMessage, groupValues)
  if (gma.gui.confirm(confirmTitle, confirmMessage)) then
    if (type(groupValues) == "table") then
      groupValues["Skipped"] = true
    end
  else
    gma.gui.progress.stop(progressBarHandle)
    gma.gui.msgbox("Operation canceled", "The creation of the Attribute Picker has been canceled")
    exit() -- This function doesn't exist so it crashes the plugin
    end
end


removeLastWord = function(str)
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


-- Treats all children of the element represented by the handle
-- has values, and sotres them in the 'groups' table
findPreRegisteredValues = function(handle, groupValues)
  local childrenNb = gma.show.getobj.amount(handle)
  if (type(groupValues["Values"]) ~= "table") then
    groupValues["Values"] = {}
  end
  -- 'values' is only a pointer to groupValues["Values"] to simplify the code
  local values = groupValues["Values"]
  for childIndex=0,childrenNb-1,1 do
    local childHandle = gma.show.getobj.child(handle, childIndex)
    local childName = gma.show.getobj.name(childHandle)
    local childFrom = tonumber(gma.show.property.get(childHandle, "From"))
    local childTo = tonumber(gma.show.property.get(childHandle, "To"))
    local childValue = (childFrom + childTo) / 2
    local index = #values+1
    values[index] = {}
    values[index]["Data"] = childValue
    values[index]["Name"] = removeLastWord(childName)
    gma.feedback(childName .. ": " .. childValue .. ", size=" .. index)
  end 
end

-- Find all the infos needed to create the picker in
-- the table passed as the first argument
findInfosForGroup = function(groupValues)
  local groupId = groupValues["GroupID"]
  local fixtureTypeId = groupValues["FixtureTypeID"]
  local fixtureTypeHandle = gma.show.getobj.handle("FixtureType " .. tostring(fixtureTypeId))
  -- Fixture types usually have a child name "Module 1" which itself has a child named "Module 1"
  local module1_1_handle = findChildNamed(fixtureTypeHandle, "Module")
  if (type(module1_1_handle) == "number") then
    local module1_2_handle = findChildNamed(module1_1_handle, "Module")
    if (type(module1_2_handle) == "number") then
      local attributeName = groupValues["Attribute"] 
      local attributeModuleHandle = findChildNamed(module1_2_handle, attributeName)
      -- We check that the attribute provided by the user exists
      if (type(attributeModuleHandle) == "number") then
        -- We check if the attribute has sub attributes by checking if
        -- its first child has children. If not, then the children of the
        -- attributes are values
        local child0Handle = gma.show.getobj.child(attributeModuleHandle, 0)
        -- Defines if subattribute are present 
        local subAttributePresent = gma.show.getobj.amount(child0Handle) > 0
        -- Defines if the user provided a subattribute
        local subAttributeProvided = type(groupValues["SubAttribute"]) ~= "nil"
        
        if (subAttributeProvided) then -- The user provided a sub attribute, we should use it
          local subAttributeName = groupValues["SubAttribute"]
          if (subAttributePresent) then -- The attribute has sub attributes
            local subAttributeHandle = findChildNamed(attributeModuleHandle, subAttributeName)
            if (type(subAttributeHandle) ~= "nil") then -- The sub attribute provided by the user exists
              findPreRegisteredValues(subAttributeHandle, groupValues) 
            else -- The sub attribute provided by the user doesn't exist
              askForCancel("Sub attribute not found", "The sub attribute ' " .. subAttributeName .. " ' could not be found in attribute ' " .. attributeName .. " ' for group " .. tostring(groupId) .. ", fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)
            end
          else -- The attribute does not have sub attributes
            askForCancel("Sub attribute not available", "The sub attribute ' " .. subAttributeName .. " ' is not available for group " .. tostring(groupID) .. ", fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)
          end
        else -- sub attribute not provided by user
          if (subAttributePresent) then -- The attribute has sub attributes, we get all values from all sub attributes
            local nbSubAttributes = gma.show.getobj.amount(attributeModuleHandle)
            for subAttributeIndex=0,nbSubAttributes-1,1 do
              local subAttributeHandle = gma.show.getobj.child(attributeModuleHandle, subAttributeIndex)
              findPreRegisteredValues(subAttributeHandle, groupValues)
            end
          else -- The attribute does not have sub attributes, we get values directly form the attribute
            findPreRegisteredValues(attributeModuleHandle, groupValues)
          end
        end
      else -- The attribute provided by the user doesn't exist
        askForCancel("Error", "Could not find attribute ' " .. attributeName .. " ' for group " .. tostring(groupId) .. ", fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)
      end
    else -- For some reason, the module 1 doesn't have itself a module 1
      askForCancel("Error", "Could not find module_1_2 for group " .. tostring(groupId) .. " fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)
    end
  else -- For some reason, the fixture doesn't have a module
    askForCancel("Error", "Could not find module_1_1 for group " .. tostring(groupId) .. " fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)
  end
end

-- fills the 'groups' table with all the infos needed to
-- create the picker
findInfos = function()
  for groupIndex,groupValues in ipairs(groups) do
    findInfosForGroup(groupValues)
    gma.gui.progress.set(progressBarHandle, groupIndex)
    gma.sleep(0.05)
  end
end



-- Finds a child that has a name that contains the name provided
-- in argument 2. If not found, returns nil. The comparison is
-- not case sensitive
findChildNamed = function(handle, childNameToFind)
  childNameToFind = string.lower(childNameToFind)
  local childNb = gma.show.getobj.amount(handle)
  for childIndex=0,childNb-1,1 do
    local childHandle = gma.show.getobj.child(handle, childIndex)
    local childName = string.lower(gma.show.getobj.name(childHandle))
    if (string.find(childName, childNameToFind)) then
      return childHandle
    end
  end
  return nil
end

-- Counts total number of needed macros and find the first continuous
-- row of macros available that can contain them all
findFirstAvailableMacro = function()
  for groupIndex,groupValues in ipairs(groups) do
    -- We don't count groups that are marked to be skipped because not valid
    if (type(groupValues["Skipped"]) == "nil") then
      nbNeededMacros = nbNeededMacros + #groupValues["Values"]
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
  gma.feedback("nbNeededMacros=" .. tostring(nbNeededMacros) .. ", FirstAvailableMacro=" .. tostring(firstMacroId))
end


-- Verifys if there is a suffisent number of unsuned execs
-- counting from the one specified by the user
verifyFreeExecs = function()
  for execNb=currentExecId,currentExecId+nbNeededExecs-1,1 do
    local exec = gma.show.getobj.handle("Executor " .. tostring(execPage) .. '.' .. tostring(execNb))
    if (exec ~= nil) then
      gma.gui.msgbox("Not enough execs", "The plugin is configured to use executors " .. tostring(execPage) .. "." .. tostring(firstExecId) .. " Thru " .. tostring(execPage) .. "." .. tostring(lastExecId) .. " but they are currently in use.\nPlease delete them or change the config of the plugin so that it uses other executors.")
      exit()
    end
  end
end

-- Verifies that the data provided the the 'groups' table is correct.
-- Also inserts in the table the names of the groups for further use
verifyGroups = function()
  for groupIndex,groupValues in ipairs(groups) do
    local groupId = groupValues["GroupID"]
    -- Verification that the group id has been provided
    if (type(groupId) == "nil") then
      gma.gui.msgbox("Missing group ID", "The group ID at line " .. tostring(groupIndex) .. " is missing.\nPlease check")
      exit()
    end
    -- Verification that the group ID refers an existing group
    local handle = gma.show.getobj.handle("group " .. tostring(groupId))
    if (type(handle) == "nil") then
      gma.gui.msgbox("Unknown group", "One of the specified group doesn't exists.\nThe group ' " .. tostring(groupId) .. " ' coulnd't be found. Please check.")
      exit()
    end
    groupValues["GroupName"] = removeLastWord(gma.show.getobj.name(handle))
    -- Verification that the fixture type id has been provided
    local fixtureTypeId = groupValues["FixtureTypeID"]
    if (type(fixtureTypeId) == "nil") then
      gma.gui.msgbox("Missing fixture type ID", "The fixture type ID at line " .. tostring(groupIndex) .. " is missing (group " .. tostring(groupId) .. ")\nPlease check.")
      exit()
    end
    -- Verification that the fixture type id refers an existing fixture type
    local fixtureTypeHandle = gma.show.getobj.handle("FixtureType " .. tostring(fixtureTypeId))
    if (type(fixtureTypeHandle) == "nil") then
      gma.gui.msgbox("Unknown fixture type", "The fixture type ID " .. tostring(fixtureTypeId) .. " doesn't exists (line " .. tostring(groupIndex) .. " group " .. tostring(groupId) .. ")")
      exit()
    end
    -- Verification that the attribute has been provided and that it is a string
    local attributeName = groupValues["Attribute"]
    if (type(attributeName) ~= "string") then
      gma.gui.msgbox("Invalid attribute", "The atribute provided at line " .. tostring(groupIndex) .. " is missing or invalid. Please check.")
      exit()
    end
    local attributeHandle = gma.show.getobj.handle('Attribute ' .. attributeName)
    -- We verify that the attribute exists
    if (type(attributeHandle) == "nil") then
      gma.gui.msgbox("Invalid attribute", "The attribute ' " .. attributeName .. " ' at line " .. tostring(groupIndex) .. " doesn't exist. Please check.")
      exit()
    end
  end
end

-- Creates the layout indicated in the config if it does
-- not exist yet
createLayout = function()
  local layout = gma.show.getobj.handle("Layout " .. tostring(layoutId))
  if (layout == nil) then
    gma.cmd('Store layout ' .. tostring(layoutId))
    gma.cmd('Label layout ' .. tostring(layoutId) .. '"Attribute Picker"')
  end 
end

-- Creates the macros and assign them to the layout.
-- Also creates and populate the executors
 createMacros = function()
  local x = startX
  local y = startY
  for groupIndex,groupValues in ipairs(groups) do
    if (groupValues['Skipped'] ~= true) then
      local firstRowMacroId = currentMacroId
      local lastRowMacroId = currentMacroId + #groupValues["Values"] - 1
      x = startX
      for valueIndex,values in ipairs(groupValues['Values']) do
        gma.cmd('ClearAll')
        gma.cmd('Group ' .. tostring(groupValues['GroupID']))
        gma.cmd('Attribute "' .. groupValues['Attribute'] .. '" At ' .. tostring(values['Data']))
        gma.cmd('Store Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' cue ' .. tostring(valueIndex))
        gma.cmd('Label Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' cue ' .. tostring(valueIndex) .. ' "' .. values['Name'] .. '"')
        gma.cmd('Assign Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' cue ' .. tostring(valueIndex) .. ' /cmd="Appearance Macro 1.' .. tostring(firstRowMacroId) .. ' Thru 1.' .. tostring(lastRowMacroId) .. ' /r=100 /g=0 /b=0 ; Appearance Macro 1.' .. tostring(currentMacroId)  .. ' /r=0 /g=100 /b=0')
        gma.cmd('Store Macro 1.' .. tostring(currentMacroId) .. ' "' .. values["Name"] .. '"')
        gma.cmd('Store Macro 1.' .. tostring(currentMacroId) .. ".1")
        gma.cmd('Assign Macro 1.' .. tostring(currentMacroId) .. '.1 /cmd="Goto Cue ' .. tostring(valueIndex) .. ' Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. '"')
        gma.cmd('Assign Macro 1.' .. tostring(currentMacroId) .. ' Layout ' .. tostring(layoutId) .. ' /x=' .. tostring(x) .. ' /y=' .. tostring(y))
        x = x + offsetX
        currentMacroId = currentMacroId + 1
        gma.gui.progress.set(progressBarHandle, currentMacroId-firstMacroId)
        gma.sleep(0.05)
      end
      gma.cmd('Label Executor ' .. tostring(execPage) .. '.' .. tostring(currentExecId) .. ' "' .. groupValues['GroupName'] .. ' ' .. groupValues["Attribute"] ..'"')
      currentExecId = currentExecId + 1
      y = y + offsetY
  else
      gma.feedback("Skipping line " .. tostring(groupIndex))
    end
  end
end

-- Main function executed when the user clicks on the plugin
return function()
  if (alreadyExecuted == true) then
    gma.gui.msgbox("Operation canceled", "The script has already been executed.\nIf you want to execute it again, please reload the plugin (edit the plugin and hit 'reload')") 
    exit()
  end
  verifyGroups()
  verifyFreeExecs()
  progressBarHandle = gma.gui.progress.start("Preparing Attribute Picker")
  gma.gui.progress.settext(progressBarHandle, "Looking for parameters")
  gma.gui.progress.setrange(progressBarHandle, 0, #groups)
  alreadyExecuted = true
  findInfos()
  findFirstAvailableMacro()
  gma.gui.progress.stop(progressBarHandle)
  progressBarHandle = gma.gui.progress.start("Creating Attribute Picker")
  gma.gui.progress.settext(progressBarHandle, "Creating macros")
  gma.gui.progress.setrange(progressBarHandle, 0, nbNeededMacros)
  gma.cmd("ClearAll")
  gma.cmd("BlindEdit On")
  createLayout()
  createMacros()
  gma.cmd("ClearAll")
  gma.cmd("BlindEdit Off")
  gma.gui.progress.stop(progressBarHandle)
  gma.gui.msgbox("Operation completed", "The Attribute Picker has been created in layout " .. tostring(layoutId))
end

