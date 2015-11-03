module(..., package.seeall)

local function getFullPath(filename, baseDirectory)
	return system.pathForFile(filename, baseDirectory or system.DocumentsDirectory)
end

function fileExists(filename, baseDirectory)
	local path = system.pathForFile(filename, baseDirectory or system.DocumentsDirectory)
   	file = io.open(path, "r")
   	if file then
   		io.close(file)
   		return true
   	else
   		return false
   	end
end

function delete (filename, baseDirectory)
	local path = getFullPath(filename,baseDirectory or system.DocumentsDirectory)
	
   	file = io.open(path, "w")
   	if file then
    	io.close(file)
        os.remove(path)
   	end
end

function write(data, filename, baseDirectory)
	local baseDirectory = baseDirectory or system.DocumentsDirectory
	local path = getFullPath(filename,baseDirectory)
	
	-- Docs say it should just overwrite, but on some devices this isn't the case.
	-- It's best to just delete, and start over.
	if (fileExists(filename,baseDirectory)) then
		delete(filename,baseDirectory)
	end

	local file = io.open(path,"wb")
	if (file) then
		file:write(data)
		io.close(file)
		return true
	end

	return false
end
