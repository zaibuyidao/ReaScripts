--[[
@author n0ne
@version 0.7.0
@noindex
--]]

function getFilesRecursive(sDir, bSkipRecursive, t)
	-- This function gets files and their path (recursivly) from a folder
	-- sDirr needs to end with a slash! ("\\")
	-- set bSkipRecursive = true to only look in the current folder
	-- t can be empty or a table. If t is a table the results from this function will be added to it
	-- the result is a table with {filename, path} as elements.
	
	local t = t or {}
	local bSkipRecursive = bSkipRecursive or false
	local i = 0
	
	-- If possbile first go recursivly into all subdirs
	if not bSkipRecursive then
		local sCurDir = reaper.EnumerateSubdirectories(sDir, i)
		while sCurDir do
			t = getFilesRecursive(sDir .. sCurDir .. "/", bSkipRecursive, t) -- changed / to \\ and back for mac (why did i have \\?)
			
			i = i + 1
			sCurDir = reaper.EnumerateSubdirectories(sDir, i)
		end
	end
	
	-- Now gather files from this dir
	i = 0
	local sCurFile = reaper.EnumerateFiles(sDir, i)
	while sCurFile do
		t[#t+1] = {sCurFile, sDir}
		
		i = i+1
		sCurFile = reaper.EnumerateFiles(sDir, i)
	end

	return t
end

function jFilesRemoveExt(fn)
	local r = fn:match("(.+)%..+")
    return r or fn -- if there is no . in the name return the original
end

function jFilesGetFilename(path)
    return path:match("^.+\\(.+)$")
end

function jFilesGetPath(path)
    return path:match("^(.+)\\.+$")
end

function jFilesGetFileModifiedTimestamp(path)
    -- Be careful with this function as the system's date and time formatting determine the output
    local cmd = 'forfiles /P "'.. jFilesGetPath(path) .. '" /M "'.. jFilesGetFilename(path) ..'" /C "cmd /c echo @fdate @ftime"'
	local result = reaper.ExecProcess(cmd, 1000):match("^.+\n(.+)\n.-$")
	if not result:match("^%d%d%d%d%-%d%d%-%d%d%s%d%d:%d%d:%d%d") then
		-- msg(result)
		reaper.ShowConsoleMsg("---\nERROR: Timestamp doesn't have the expected format. This function only works if the system date format is set as: yyyy-MM-dd HH-mm-ss\n-----\n")
		return false
	else
		return result
	end	
end

function jFilesCopyFile(source, dest)
	local cmd = 'COPY "' .. source .. '" "' .. dest .. '"'
	-- msg(cmd)
	-- local r = reaper.ExecProcess(cmd, 1000)
	local r = os.execute(cmd)
	-- msg(r)
end

-- function GetFileExtension(url)
--     return url:match("^.+(%..+)$")
-- end