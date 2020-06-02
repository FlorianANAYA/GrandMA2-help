-- AttributePicker v3 - Florian ANAYA - 2020
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
-- If the plugin doesn't work after configuring it and shows no
-- message, check the system monitor for error message, you might have
-- misstyped something that broke the code.
-- Tested GrandMA2 versions: 3.7

-----------------------
-- Start of settings --
-----------------------

-- This is the list of row the final picker will contain. You can add new
-- lines by copy/pasting one of the example line and/or editing them.
-- Each line must repect the formatting, otherwise, the plugin won't work at all.
-- GroupID :      The ID of the group that will use the line. Currently, only IDs
--                are supported. Names are not.
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
  { ["GroupID"] = 15, ["Attribute"] = "GOBO1", ["SubAttribute"] = "Index" },
  { ["GroupID"] = 15, ["Attribute"] = "ANIMATIONWHEEL", },
  { ["GroupID"] = 15, ["Attribute"] = "COLOR1",["SubAttribute"] = "Select" },
  { ["GroupID"] = 15, ["Attribute"] = "CTO",},
  { ["GroupID"] = 15, ["Attribute"] = "effectwheel",},
  { ["GroupID"] = 15, ["Attribute"] = "SHUTTER", },
}

-- The ID of the layout that will be used
local layoutId = 1

-- ID of first executor to use (There will be as many executors used as
-- there are groups declared above)
-- If one of the executors already exists, the program will not execute.
-- It must include the exec page, the format is X.XXX (ie. 1.101, 5.001 or 7.015)
local execId = 1.101


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
local nbNeededExecs = #groups
-- The ID of the last exec that is going to be used
local lastExecId = 0

-- Becomes true at the end of the script, to avoid the user to execute the
-- plugin twice without a reset of the variables
local alreadyExecuted = false
-- The handle of the progress bar
local progressBarHandle = 0
-- Predeclaration of all functions
local askForCancel, findPreRegisteredValues, findInfosForGroup, findInfos, findChildNamed, findFirstAvailableMacro, verifyFreeExecs, verifyGroups, createLayout, createMacros, removeLastWord, verifyLayout, findFixtureTypes, findPropertyNamed


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


-- Finds channel values contained in the children of the element
-- represented by the handle passed in argument.
-- Values are then added to the groupValues['index']
findPreRegisteredValues = function(handle, groupValues)
  local childrenNb = gma.show.getobj.amount(handle)
  if (type(groupValues["Values"]) ~= "table") then
    groupValues["Values"] = {}
  end
  -- 'values' is only a pointer to groupValues["Values"] to simplify the code
  for childIndex=0,childrenNb-1,1 do
    local childHandle = gma.show.getobj.child(handle, childIndex)
    local childName = gma.show.getobj.name(childHandle)
    local childFrom = tonumber(gma.show.property.get(childHandle, "From"))
    local childTo = tonumber(gma.show.property.get(childHandle, "To"))
    local childValue = (childFrom + childTo) / 2
    local index = #groupValues["Values"]+1
    groupValues["Values"][index] = {}
    groupValues["Values"][index]["Data"] = childValue
    groupValues["Values"][index]["Name"] = removeLastWord(childName)
  end 
end

-- Finds the fixture types that should be used for each groups
-- and stores this information back in the 'groups' table
-- function inspired from plugins from: https://giaffodesigns.com/
findFixtureTypes = function()
  gma.cmd('SelectDrive 1')
  local fileName = 'tempfile.xml' 
  local filePath = gma.show.getvar('PATH') ..  '/importexport/' .. fileName
  for groupIndex,groupValues in ipairs(groups) do
    local groupId = groupValues["GroupID"]
    -- We export the group to the XML file
    gma.cmd('Export Group ' .. tostring(groupId) .. ' "' .. fileName .. '"')
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
        return false
      end
    end
    -- We put the fixture type in the values of the group (in 'groups')
    groupValues["FixtureTypeID"] = defaultFixtureTypeId
    gma.feedback("Using fixture type ' " .. defaultFixtureTypeName .. " ' for group " .. tostring(groupId))
  end
  
  return true
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
              if (not askForCancel("Sub attribute not found", "The sub attribute ' " .. subAttributeName .. " ' could not be found in attribute ' " .. attributeName .. " ' for group " .. tostring(groupId) .. ", fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)) then
                return false
              end
            end
          else -- The attribute does not have sub attributes
            if (not askForCancel("Sub attribute not available", "The sub attribute ' " .. subAttributeName .. " ' is not available for group " .. tostring(groupID) .. ", fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)) then
              return false
            end
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
        if (not askForCancel("Error", "Could not find attribute ' " .. attributeName .. " ' for group " .. tostring(groupId) .. ", fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)) then
          return false
        end
      end
    else -- For some reason, the module 1 doesn't have itself a module 1
      if (not askForCancel("Error", "Could not find module_1_2 for group " .. tostring(groupId) .. " fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)) then
        return false
      end
    end
  else -- For some reason, the fixture doesn't have a module
    if (not askForCancel("Error", "Could not find module_1_1 for group " .. tostring(groupId) .. " fixture type " .. tostring(fixtureTypeId) .. "\nHit 'Ok' to skip this line or 'cancel' to exit the plugin.", groupValues)) then
      return false
    end
  end
  return true
end

-- fills the 'groups' table with all the infos needed to
-- create the picker
findInfos = function()
  for groupIndex,groupValues in ipairs(groups) do
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

-- Finds a property that has a name that contains the name provided
-- in argument 2. If not found, returns nil. Otherwise, returns
-- property index, property name and property value.
-- The comparison is not case sensitive.
findPropertyNamed = function(handle, propertyNameToFind)
  propertyNameToFind = string.lower(propertyNameToFind)
  local propertyNb = gma.show.property.amount(handle)
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

-- Counts total number of needed macros and find the first continuous
-- row of macros available that can contain them all.
-- returns false if the maximum index is reached.
findFirstAvailableMacro = function()
  for groupIndex,groupValues in ipairs(groups) do
    -- We don't count groups that are marked to be skipped because not valid
    if (groupValues["Skipped"] == nil) then
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

-- Verifys if there is a suffisent number of unsuned execs
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

-- Verifies that the data provided the the 'groups' table is correct.
-- Also inserts in the table the names of the groups for further use
verifyGroups = function()
  for groupIndex,groupValues in ipairs(groups) do
    local groupId = groupValues["GroupID"]
    -- Verification that the group id has been provided
    if (type(groupId) == "nil") then
      gma.gui.msgbox("Missing group ID", "The group ID at line " .. tostring(groupIndex) .. " is missing.\nPlease check")
      return false
    end
    -- Verification that the group ID refers an existing group
    local handle = gma.show.getobj.handle("group " .. tostring(groupId))
    if (type(handle) == "nil") then
      gma.gui.msgbox("Unknown group", "One of the specified group doesn't exists.\nThe group ' " .. tostring(groupId) .. " ' couldn't be found. Please check.")
      return false
    end
    groupValues["GroupName"] = removeLastWord(gma.show.getobj.name(handle))
    -- Verification that the attribute has been provided and that it is a string
    local attributeName = groupValues["Attribute"]
    if (type(attributeName) ~= "string") then
      gma.gui.msgbox("Invalid attribute", "The atribute provided at line " .. tostring(groupIndex) .. " is missing or invalid. Please check.")
      return false
    end
    local attributeHandle = gma.show.getobj.handle('Attribute ' .. attributeName)
    -- We verify that the attribute exists
    if (type(attributeHandle) == "nil") then
      gma.gui.msgbox("Invalid attribute", "The attribute ' " .. attributeName .. " ' at line " .. tostring(groupIndex) .. " doesn't exist. Please check.")
      return false
    end
  end
  return true
end

-- Verifies that the provided layout ID is valid.
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
  end
  return true
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

-- Creates and populate the executors.
-- Creates the macros and assign them to the layout.
 createMacros = function()
  local x = startX
  local y = startY
  for groupIndex,groupValues in ipairs(groups) do
    if (groupValues['Skipped'] ~= true) then
      -- We record the ID of the first and last macros that will be used by this particular line
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
    gma.feedback("Plugin exited: Plugin already executed without a reload")
    gma.gui.msgbox("Operation canceled", "The script has already been executed.\nIf you want to execute it again, please reload the plugin (edit the plugin and hit 'reload')")
    return
  end
  
  -- We find the specified exec page and exec ID and verify they are correct
  execPage = math.floor(execId)
  firstExecId = math.tointeger(tostring((execId - execPage) * 1000))
  if (execPage <= 0 or firstExecId <= 0) then
    gma.gui.msgbox("Incorrect exec", "The specified executor ' " .. tostring(execId) .. " ' is invalid.\nIt must include the exec page, in the format X.XXX (ie. 1.101, 5.001, 10.015).")
    gma.feedback("Plugin exited: Incorrect first executor")
    return
  end
  currentExecId = firstExecId
  lastExecId = firstExecId + nbNeededExecs - 1
  
  progressBarHandle = gma.gui.progress.start("Preparing Attribute Picker")
  
  gma.gui.progress.settext(progressBarHandle, "Verifying groups")
  if (not verifyGroups()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Incorrect groups")
    return
  end
  
  gma.gui.progress.settext(progressBarHandle, "Finding fixture types")
  if (not findFixtureTypes()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: During finding fixture types")
    return
  end
  
  gma.gui.progress.settext(progressBarHandle, "Checking availability of executors")
  if (not verifyFreeExecs()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Not enough free executors")
    return
  end
  
  alreadyExecuted = true
  
  gma.gui.progress.settext(progressBarHandle, "Looking for parameters")
  gma.gui.progress.setrange(progressBarHandle, 0, #groups)
  if (not findInfos()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Canceled by the user during infos scouting")
    return
  end
  
  -- We verifiy the layout definition
  gma.gui.progress.settext(progressBarHandle, "Verifying layout")
  if (not verifyLayout()) then
    gma.feedback("Plugin exited: Incorrect layout")
    gma.gui.progress.stop(progressBarHandle)
    return
  end
  
  gma.gui.progress.settext(progressBarHandle, "Looking for available macros")
  if (not findFirstAvailableMacro()) then
    gma.gui.progress.stop(progressBarHandle)
    gma.feedback("Plugin exited: Not enough available macros")
    return
  end
  gma.gui.progress.stop(progressBarHandle)
  
  if (not gma.gui.confirm("Attribute Picker", "The Attribute Picker is about to be created on:\n- Layout " .. tostring(layoutId) ..  "\n- Executors " .. tostring(execPage) .. "." .. tostring(firstExecId) .. " Thru " .. tostring(execPage) .. "." .. tostring(lastExecId) .. "\n- Macros " .. tostring(firstMacroId) .. " Thru " .. tostring(lastMacroId) .. "\nIf this is not correct, please edit the plugin to change those values.")) then
    gma.feedback("Plugin exited: Operation aborted by the user")
    gma.gui.msgbox("Operation canceled", "The creation of the Attribute Picker has been aborted.")
    return
  end
  
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

