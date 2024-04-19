--[[
@author n0ne
@version 0.7.1
@noindex
--]]

function jSettingsReadFromFile(file_name)
	-- Reads variables from a ini style text file
	local f = io.open(file_name, "r")
	if not f then
		msg("No settingsfile found: " .. file_name)
		return false
	end

	local sContent = f:read("*all")
	f:close()

	return jSettingsRead(sContent)
end

function jSettingsWriteToFile(file_name, inSection, inName, inValue, bSectionOptional)
	local bSectionOptional = bSectionOptional or false

	local f = io.open(file_name, "r")
	if not f then
		msg("No settingsfile found: " .. file_name)
		return false
	end

	local sContent = f:read("*all")
	f = io.open(file_name, "w")
	sContent = jSettingsWriteKey(sContent, inSection, inName, inValue, bSectionOptional)
	f:write(sContent)
	f:close()
end

function jSettingsWriteToFileMultiple(file_name, tKeys, bSectionOptional)
	local bSectionOptional = bSectionOptional or false

	local f = io.open(file_name, "r")
	if not f then
		msg("No settingsfile found: " .. file_name)
		return false
	end

	local sContent = f:read("*all")
	f = io.open(file_name, "w")
	for _, v in pairs(tKeys) do
		sContent = jSettingsWriteKey(sContent, v[1], v[2], v[3], bSectionOptional)
	end
	f:write(sContent)
	f:close()
end

function jSettingsRead(str)
    -- Reads variables from a ini style string
	-- Format for text file is: varname=value
	-- Comments can be made with ; or // (can be inline too)
    -- Every varname will we a TABLE in the returned table, this way one variable can have multiple values
	local settingsData = {}

	for line in str:gmatch("[^\r\n]+") do
		local lineClean = _jSettingsRemoveComments(line)
		local name, value, section = _jSettingsLineProcess(lineClean)
		if name then
			value = _jSettingsReadProcessValue(value)
			-- msg("Var: " .. name .. ": " .. tostring(value))
			if settingsData[name] then
				settingsData[name][#settingsData[name]+1] = value
			else
				settingsData[name] = {value}
			end
		elseif section then
			-- Can do something with section name here
			-- msg("Section: " .. section)
		else
			-- Comments/empty/unrecognized
			-- msg ("Skipped: " .. tostring(line))
		end
	end

	-- tablePrint(settingsData)
	return settingsData
end

function _jSettingsRemoveComments(inLine)
	local lineClean = jStringExplode(inLine, ";")[1]
	lineClean = jStringExplode(lineClean, "//")[1] -- First version used // for comments
	return lineClean
end

function _jSettingsLineProcess(inLine)
	local name = inLine:match("(.+)=(.-)")
	local value = inLine:match(".+=(.+)")
	if name then
		return name, value, nil
	end
	-- else
	local section = inLine:match("%[(.+)%]")

	return name, value, section
end

function jSettingsWriteKey(str, inSection, inName, inValue, bSectionOptional)
	local bSectionOptional = bSectionOptional or false
	local newStr = ""
	local currentSection = false
	local bSucces = false

	inSection = tostring(inSection)
	inName = tostring(inName)
	inValue = tostring(inValue)
	
	for line in str:gmatch("[^\r\n]+") do

		local lineClean = _jSettingsRemoveComments(line)
		local name, value, section = _jSettingsLineProcess(lineClean)
		if section then
			if currentSection == inSection and not bSucces then
				-- We were the section we're looking for and now changing: key was not present, create...
				-- msg("creating new key")
				newStr = newStr .. inName .. "=" .. inValue .. "\n"
				bSucces = true
			end
			currentSection = section
		elseif name == inName then
			if currentSection == inSection or bSectionOptional then
				-- msg("found our key: " .. name .. "=" .. value .. " [" .. tostring(currentSection) .. "]")
				line = inName .. "=" .. inValue
				bSucces = true
			end
		end

		newStr = newStr .. line .. "\n"
	end

	if not bSucces and bSectionOptional then
		-- Neither the key nor section was found, but section is optional (backwards compatibility issue) so create at end of file
		newStr = newStr .. inName .. "=" .. inValue .. "\n"
		bSucces = true
	end
	if not bSucces then
		msg("Could not update ini value, prolly section does not exist. "  .. inName .. "=" .. inValue .. " [" .. inSection .. "]")
	end

	return newStr, bSucces
end

function jSettingsCreate(file_name, default_file, content)
	local default_file = default_file or false
    local content = content or ""
    
    if not io.open(file_name, "r") then
		local file = io.open(file_name, "w")
		if default_file then
			local file_to_read = io.open(default_file, "r")
			if not file_to_read then
				msg("jSettingsCreate(): Default file sepcified but could not open: " .. default_file)
				return false
			end
			content = file_to_read:read("a")
		end

		file:write(content)
		file:close()
		return true -- New file created
	else
		return false -- settingsfile already exists
    end
end

function _jSettingsReadProcessValue(value)
	value = jStringTrim(value)
    if value == "true" then
        value = true
    elseif value == "false" then
		value = false
	elseif jStringIsInt(value) then
		value = math.tointeger(value)
    end

    return value
end

function jSettingsGet(t, name, typeCheck)
	
	local value = t[name]
	if value == nil then
		msg("jSettingsGet(): Trying to read an empty setting: " .. name)
		return nil
	end

	
	if typeCheck == "table" then
		if type(value) ~= typeCheck then
			msg("jSettingsGet(): setting type does not match for: " .. name .. ". Wanted: " .. typeCheck .. ", got: " .. type(value))
		end
		return value
	else
		local v = value[1]
		-- msg(tostring(v) .. " : " .. tostring(tonumber(v)))
		if typeCheck == "number" and tonumber(v) then
			return v
		elseif type(v) ~= typeCheck then
			msg("jSettingsGet(): setting type does not match for: " .. name .. ". Wanted: " .. typeCheck .. ", got: " .. type(v))
		end
		return v
	end
end