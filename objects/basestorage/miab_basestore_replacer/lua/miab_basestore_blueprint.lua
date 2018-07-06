-- how many iterations should a for loop go through before the coroutine yields?
YIELDPOINT = 100000

-- blueprint storage table
blueprint = {}

function blueprint.Init(boundsSize)
	-- Blueprint functions for base scanning and printing
	-- All materials used are stored and given a numerical id
	blueprint.blocksTable = {}
	blueprint.nextBlockId = 1

	-- The actual layout of the blocks
	blueprint.layoutTableBackground = {}
	blueprint.layoutTableForeground = {}

	-- Any tile mods applied to the blocks
	blueprint.layoutTableBackgroundMods = {}
	blueprint.layoutTableForegroundMods = {}
	
	-- Any colours applied to the blocks
	blueprint.layoutTableBackgroundColours = {}
	blueprint.layoutTableForegroundColours = {}
	
	-- Liquids
	blueprint.liquidTable = {}

	-- The placement of objects
	blueprint.objectTable = {}

	-- A copy of the config table, so it doesn't go out of scope
	blueprint.configTable = {}

	-- A copy of the bounding box size, for print previewing
	blueprint.boundingBoxSize = copyTable(boundsSize)
end

------------------------------------------------------------------------------------
-- blocksTable
------------------------------------------------------------------------------------
-- Get the id for a given material name
function blueprint.blockId(matName)
	if (matName == nil) then
		return nil
	end

	local id = blueprint.blocksTable[matName]

	if (id == nil) then
		blueprint.blocksTable[matName] = blueprint.nextBlockId
		id = blueprint.nextBlockId
		blueprint.nextBlockId = blueprint.nextBlockId + 1
	end

	return id
end

-- Get the material name for a given id
function blueprint.materialFromId(id)
	for _name, _id in pairs(blueprint.blocksTable) do
		if (_id == id) then
			return _name
		end
	end

	return nil
end
------------------------------------------------------------------------------------
-- layoutTables
------------------------------------------------------------------------------------
-- Set the block id for a given material and position
function blueprint.setBlock(x, y, matName, layer)
	if (layer == "background") then
		if (blueprint.layoutTableBackground[y] == nil) then
			blueprint.layoutTableBackground[y] = {}
		end
		blueprint.layoutTableBackground[y][x] = blueprint.blockId(matName)
	elseif (layer == "foreground") then
		if (blueprint.layoutTableForeground[y] == nil) then
			blueprint.layoutTableForeground[y] = {}
		end
		blueprint.layoutTableForeground[y][x] = blueprint.blockId(matName)
	end
end

-- Get the material name of the block at a given position
function blueprint.getBlock(x, y, layer)
	local id = nil
	if (layer == "background") then
		if (blueprint.layoutTableBackground[y] ~= nil) then
			id = blueprint.layoutTableBackground[y][x]
		end
	elseif (layer == "foreground") then
		if (blueprint.layoutTableForeground[y] ~= nil) then
			id = blueprint.layoutTableForeground[y][x]
		end
	else
		return nil
	end

	if (id == nil) then
		return nil
	end

	local matName = blueprint.materialFromId(id)
	
	return matName
end
------------------------------------------------------------------------------------
-- modTables
------------------------------------------------------------------------------------
-- Set the mod id for a given material and position
function blueprint.setMod(x, y, modName, layer)
	if (layer == "background") then
		if (blueprint.layoutTableBackgroundMods[y] == nil) then
			blueprint.layoutTableBackgroundMods[y] = {}
		end
		blueprint.layoutTableBackgroundMods[y][x] = blueprint.blockId(modName)
	elseif (layer == "foreground") then
		if (blueprint.layoutTableForegroundMods[y] == nil) then
			blueprint.layoutTableForegroundMods[y] = {}
		end
		blueprint.layoutTableForegroundMods[y][x] = blueprint.blockId(modName)
	end
end

-- Get the material name of the block at a given position
function blueprint.getMod(x, y, layer)
	local id = nil
	if (layer == "background") then
		if (blueprint.layoutTableBackgroundMods[y] ~= nil) then
			id = blueprint.layoutTableBackgroundMods[y][x]
		end
	elseif (layer == "foreground") then
		if (blueprint.layoutTableForegroundMods[y] ~= nil) then
			id = blueprint.layoutTableForegroundMods[y][x]
		end
	else
		return nil
	end

	if (id == nil) then
		return nil
	end

	local modName = blueprint.materialFromId(id)
	
	return modName
end
------------------------------------------------------------------------------------
-- colourTables
------------------------------------------------------------------------------------
-- Set the colour id for a given material and position
function blueprint.setColour(x, y, colour, layer)
	if (layer == "background") then
		if (blueprint.layoutTableBackgroundColours[y] == nil) then
			blueprint.layoutTableBackgroundColours[y] = {}
		end
		blueprint.layoutTableBackgroundColours[y][x] = colour
	elseif (layer == "foreground") then
		if (blueprint.layoutTableForegroundColours[y] == nil) then
			blueprint.layoutTableForegroundColours[y] = {}
		end
		blueprint.layoutTableForegroundColours[y][x] = colour
	end
end

-- Get the material name of the block at a given position
function blueprint.getColour(x, y, layer)
	local colour = nil
	if (layer == "background") then
		if (blueprint.layoutTableBackgroundColours[y] ~= nil) then
			colour = blueprint.layoutTableBackgroundColours[y][x]
		end
	elseif (layer == "foreground") then
		if (blueprint.layoutTableForegroundColours[y] ~= nil) then
			colour = blueprint.layoutTableForegroundColours[y][x]
		end
	else
		return nil
	end

	return colour
end
------------------------------------------------------------------------------------
-- liquidTable
------------------------------------------------------------------------------------
-- Set the type and amount of liquid at a given position (liquid is a table: {liquidID, liquidAmount})
function blueprint.setLiquid(x, y, liquid)
	if (blueprint.liquidTable[y] == nil) then
		blueprint.liquidTable[y] = {}
	end
	blueprint.liquidTable[y][x] = liquid
end

-- Get the type and amount of liquid at a given position (returns a table: {liquidID, liquidAmount})
function blueprint.getLiquid(x, y)
	local liquid = nil
	if (blueprint.liquidTable[y] ~= nil) then
		liquid = blueprint.liquidTable[y][x]
	end
	return liquid
end
------------------------------------------------------------------------------------
-- objectTable
------------------------------------------------------------------------------------
-- Store an obect at a given position
function blueprint.setObject(x, y, id, removeContents)
	-- init
	objectParameterTable = {}
	
	if (id == nil) then
		blueprint.objectTable[y][x] = objectParameterTable
		return
	end
	-- for debugging purposes
	--sb.logInfo("\n" .. sb.printJson(world.getObjectParameter(id, ""), 1))
	--

	-- read values from world
	objectParameterTable.name = world.entityName(id)
	objectParameterTable.facing = world.callScriptedEntity(id, "object.direction")
	if (objectParameterTable.facing == nil) then
		objectParameterTable.facing = 1
	end
	if (world.containerSize(id)) then
		if (removeContents) then
			objectParameterTable.contents = world.containerTakeAll(id)
		else
			objectParameterTable.contents = world.containerItems(id)
		end
	end
	
	-- check if the object has a hook for us to get its json
	objectParameterTable.jsonParameters = world.callScriptedEntity(id, "miab_jsonParameters") or {}
	-- fix for upgradeable objects (crafting tables, basically)
	local upgradeStageData = world.callScriptedEntity(id, "currentStageData")
	if (upgradeStageData) then
		mergeTable(objectParameterTable.jsonParameters, upgradeStageData.itemSpawnParameters)
		-- objectParameterTable.jsonParameters = upgradeStageData.itemSpawnParameters -- object, divulge thy secrets
		-- we need a clunky workaround here because there is a wizard loose in chucklefish's code and I can't find him to put a stop to his merry antics
		if (objectParameterTable.jsonParameters.inventoryIcon == "inventorstable2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "inventorstable3icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 3
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftingfurnace2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftingfurnace3icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 3
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftingfarm2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftinganvil2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftinganvil3icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 3
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftingfurniture2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftingmedical2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		elseif (objectParameterTable.jsonParameters.inventoryIcon == "craftingwheel2icon.png") then
			objectParameterTable.jsonParameters.startingUpgradeStage = 2
		end
	end
	--
	
	-- fix for trees
	local objectType = world.getObjectParameter(id, "objectType", "")
	if (objectType == "farmable") then
		objectParameterTable.jsonParameters.stemName = world.getObjectParameter(id, "stemName")
		objectParameterTable.jsonParameters.stemHueShift = world.getObjectParameter(id, "stemHueShift")
		objectParameterTable.jsonParameters.foliageName = world.getObjectParameter(id, "foliageName")
		objectParameterTable.jsonParameters.foliageHueShift = world.getObjectParameter(id, "foliageHueShift")
		objectParameterTable.jsonParameters.scriptStorage = world.getObjectParameter(id, "scriptStorage")
	end
	--
	
	-- placeholder for wiring fix, if and when it becomes possible
	if (world.callScriptedEntity(id, "object.outputNodeCount") > 0) then
		-- wiring would go here but is currently impossible
	end
	--
	
	-- create entry
	if (blueprint.objectTable[y] == nil) then
		blueprint.objectTable[y] = {}
	end
	blueprint.objectTable[y][x] = objectParameterTable
end
------------------------------------------------------------------------------------
-- Serialisation
------------------------------------------------------------------------------------
-- returns a table for immediate config use
function blueprint.toConfigTable()
	local tbl = {}
	
	tbl.boundingBoxSize = blueprint.boundingBoxSize
	tbl.nextBlockId = blueprint.nextBlockId
	tbl.blocksTable = blueprint.blocksTable
	tbl.layoutTableBackground = blueprint.layoutTableBackground
	tbl.layoutTableForeground = blueprint.layoutTableForeground
	tbl.layoutTableBackgroundMods = blueprint.layoutTableBackgroundMods
	tbl.layoutTableForegroundMods = blueprint.layoutTableForegroundMods
	tbl.layoutTableBackgroundColours = blueprint.layoutTableBackgroundColours
	tbl.layoutTableForegroundColours = blueprint.layoutTableForegroundColours
	tbl.liquidTable = blueprint.liquidTable
	tbl.objectTable = blueprint.objectTable
	
	return { miab_basestore_blueprint = tbl }
end

-- populates the config table and points the relevant stuff at it
function blueprint.fromEntityConfig()
	blueprint.Init({0, 0}) -- reset blueprint
	blueprint.configTable = config.getParameter("miab_basestore_blueprint", nil)

	if (blueprint.configTable ~= nil) then
		blueprint.boundingBoxSize = blueprint.configTable.boundingBoxSize
		blueprint.nextBlockId = blueprint.configTable.nextBlockId
		blueprint.blocksTable = blueprint.configTable.blocksTable
		blueprint.layoutTableBackground = blueprint.configTable.layoutTableBackground
		blueprint.layoutTableForeground = blueprint.configTable.layoutTableForeground
		blueprint.layoutTableBackgroundMods = blueprint.configTable.layoutTableBackgroundMods or {}
		blueprint.layoutTableForegroundMods = blueprint.configTable.layoutTableForegroundMods or {}
		blueprint.layoutTableBackgroundColours = blueprint.configTable.layoutTableBackgroundColours or {}
		blueprint.layoutTableForegroundColours = blueprint.configTable.layoutTableForegroundColours or {}
		blueprint.liquidTable = blueprint.configTable.liquidTable or {}
		blueprint.objectTable = blueprint.configTable.objectTable or {}
		
		for _mat, _id in pairs(blueprint.blocksTable) do
			blueprint.blocksTable[_mat] = tonumber(_id)
		end
		coroutine.yield()
		local iterations = 0
		for _y, _tbl in pairs(blueprint.layoutTableBackground) do
			for _x, _id in pairs(_tbl) do
				blueprint.layoutTableBackground[_y][_x] = tonumber(_id)
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
		iterations = 0
		for _y, _tbl in pairs(blueprint.layoutTableForeground) do
			for _x, _id in pairs(_tbl) do
				blueprint.layoutTableForeground[_y][_x] = tonumber(_id)
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
		iterations = 0
		for _y, _tbl in pairs(blueprint.layoutTableBackgroundMods) do
			for _x, _id in pairs(_tbl) do
				blueprint.layoutTableBackgroundMods[_y][_x] = tonumber(_id)
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
		iterations = 0
		for _y, _tbl in pairs(blueprint.layoutTableForegroundMods) do
			for _x, _id in pairs(_tbl) do
				blueprint.layoutTableForegroundMods[_y][_x] = tonumber(_id)
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
		iterations = 0
		for _y, _tbl in pairs(blueprint.layoutTableBackgroundColours) do
			for _x, _id in pairs(_tbl) do
				blueprint.layoutTableBackgroundColours[_y][_x] = tonumber(_id)
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
		iterations = 0
		for _y, _tbl in pairs(blueprint.layoutTableForegroundColours) do
			for _x, _id in pairs(_tbl) do
				blueprint.layoutTableForegroundColours[_y][_x] = tonumber(_id)
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
	end
end

function blueprint.DumpJSON(description, shortDescription, inventoryIcon, recipeGroup)
	description = description or "A device that will construct a building from its internal blueprint"
	shortDescription = shortDescription or "Building Printer"
	inventoryIcon = inventoryIcon or "/objects/basestorage/miab_basestore_printer/inventoryicons/_base.png"
	recipeGroup = recipeGroup or { "plain" }
	if (type(recipeGroup) == "string") then
		recipeGroup = { recipeGroup }
	end
	--local itemName = os.date("miabCustom%d%m%Yat%H%M", os.time()) -- os.date is currently verboten
	local itemName = "miabCustom" .. tostring(os.time())
	-- see: http://jsonlint.com/ for json validation tool
	local serialised = "\n"
	-- recipe file
	serialised = serialised .. serialisationHeader("assets/user/recipes", itemName .. ".recipe", itemName)
	serialised = serialised .. "{\n\t\"input\" : [\n\t\t{ \"item\" : \"titaniumbar\", \"count\" : 10 },\n\t\t{ \"item\" : \"money\", \"count\" : 400 }\n\t],\n"
	serialised = serialised .. "\t\"output\" : {\n\t\t\"item\" : \"" .. itemName .. "\", \"count\" : 1\n\t},\n"
	serialised = serialised .. tableToJSONArray("\t", "groups", recipeGroup, "\n")
	serialised = serialised .. "}\n"
	serialised = serialised .. serialisationFooter()
	-- config.patch (merged)
	serialised = serialised .. serialisationHeaderConfigA(itemName)
	serialised = serialised .. "[\n\t{\n\t\t\"op\" : \"add\",\n\t\t\"path\" : \"/defaultBlueprints/tier1/-\",\n\t\t\"value\" : { \"item\" : \"" .. itemName .. "\" }\n\t}\n]\n"
	-- config.patch (new)
	serialised = serialised .. serialisationHeaderConfigB()
	serialised = serialised .. "\t{\n\t\t\"op\" : \"add\",\n\t\t\"path\" : \"/defaultBlueprints/tier1/-\",\n\t\t\"value\" : { \"item\" : \"" .. itemName .. "\" }\n\t},\n"
	serialised = serialised .. serialisationFooter()
	-- object file
	serialised = serialised .. serialisationHeader("assets/user/objects", itemName .. ".object", itemName)
	serialised = serialised .. "{\n\t\"objectName\" : \"" .. itemName .. "\",\n\t\"rarity\" : \"Common\",\n\t\"description\" : \"".. description .. "\",\n\t\"shortdescription\" : \"" .. shortDescription .. "\",\n"
	serialised = serialised .. "\t\"race\" : \"generic\",\n\t\"category\" : \"tool\",\n\t\"price\" : 1,\n\t\"printable\" : false,\n\n"
	serialised = serialised .. "\t\"inventoryIcon\" : \"" ..inventoryIcon .. "\",\n"
	serialised = serialised .. "\t\"orientations\" : [\n\t\t{\n\t\t\t\"image\" : \"/objects/basestorage/miab_basestore_printer/miab_basestore_printer.png:<color>.<frame>\",\n"
	serialised = serialised .. "\t\t\t\"imagePosition\" : [-8, 0],\n\t\t\t\"frames\" : 5,\n\t\t\t\"animationCycle\" : 1,\n\t\t\t\"spaceScan\" : 0.1,\n\t\t\t\"direction\" : \"right\"\n\t\t}\n\t],\n\n"
	serialised = serialised .. "\t\"animation\" : \"/objects/basestorage/miab_basestore_printer/miab_basestore_printer.animation\",\n"
	serialised = serialised .. "\t\"animationParts\" : {\n\t\t\"normal_operation_image\" : \"/objects/basestorage/miab_basestore_printer/miab_basestore_printer.png\",\n"
	serialised = serialised .. "\t\t\"printer_icon\" : \"/objects/basestorage/miab_basestore_printer/miab_basestore_icons.png\"\n\t},\n"
	serialised = serialised .. "\t\"animationPosition\" : [-8, 0],\n\n"
	serialised = serialised .. "\t\"scripts\" : [\n\t\t\"/objects/basestorage/miab_basestore_printer/miab_basestore_print_activator.lua\",\n"
	serialised = serialised .. "\t\t\"/scripts/basestorage/miab_basestore_printer.lua\",\n\t\t\"/scripts/basestorage/miab_basestore_blueprint.lua\",\n"
	serialised = serialised .. "\t\t\"/scripts/basestorage/miab_basestore_util.lua\"\n\t],\n\t\"scriptDelta\" : 5,\n\t\"breakDropOptions\" : [],\n\t\"miab_printer_offset\" : [1, 0],\n\n"
	
	serialised = serialised .. "\t\"miab_basestore_blueprint\" : {\n"
	serialised = serialised .. tableToJSONArray("\t\t", "boundingBoxSize", blueprint.boundingBoxSize, ",\n")
	serialised = serialised .. tableToJSON("\t\t", "liquidTable", blueprint.liquidTable, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "blocksTable", blueprint.blocksTable, ",")
	serialised = serialised .. "\t\t\"nextBlockId\" : " .. blueprint.nextBlockId .. ",\n"
	serialised = serialised .. tableToJSON("\t\t", "layoutTableBackground", blueprint.layoutTableBackground, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "layoutTableForeground", blueprint.layoutTableForeground, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "layoutTableBackgroundMods", blueprint.layoutTableBackgroundMods, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "layoutTableForegroundMods", blueprint.layoutTableForegroundMods, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "layoutTableBackgroundColours", blueprint.layoutTableBackgroundColours, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "layoutTableForegroundColours", blueprint.layoutTableForegroundColours, ",", true)
	serialised = serialised .. tableToJSON("\t\t", "objectTable", blueprint.objectTable, "")
	serialised = serialised .. "\t}\n}\n"
	serialised = serialised .. serialisationFooter()
	--
	sb.logInfo(serialised)
end

function serialisationHRule()
	return "-------------------------------------------\n"
end

function serialisationHeader(path, file, tag)
	local header = ""
	
	header = header .. serialisationHRule()
	header = header .. "-- miab file serialisation begins\n"
	header = header .. "-- tag: " .. tag .. "\n"
	header = header .. "-- target folder: " .. path .. "\n"
	header = header .. "-- target filename: " .. file .. "\n"
	header = header .. "-- save as " .. file .. " in " .. path .. "\n"
	header = header .. serialisationHRule()
	
	return header
end

function serialisationHeaderConfigA(tag)
	local header = ""
	
	header = header .. serialisationHRule()
	header = header .. "-- miab file serialisation begins\n"
	header = header .. "-- tag: " .. tag .. "\n"
	header = header .. "-- target folder: assets/user\n"
	header = header .. "-- target filename: player.config.patch\n"
	header = header .. "-- if player.config.patch does not exist in assets/user, save as player.config patch in assets/user\n"
	header = header .. serialisationHRule()
	
	return header
end

function serialisationHeaderConfigB()
	local header = ""
	
	header = header .. serialisationHRule()
	header = header .. "-- miab file serialisation ends\n"
	header = header .. serialisationHRule()
	header = header .. "-- if player.config.patch already exists in assets/user, insert after first line\n"
	header = header .. serialisationHRule()
	
	return header
end

function serialisationFooter()
	local footer = ""
	
	footer = footer .. serialisationHRule()
	footer = footer .. "-- miab file serialisation ends\n"
	footer = footer .. serialisationHRule()
	footer = footer .. "\n"
	
	return footer
end

function tableToJSON(prefix, name, val, suffix, short)
	short = short or false
	local serialised = ""
	if (type(val) == "boolean") then
		if (val == true) then
			serialised = serialised .. prefix .. "\"" .. name .. "\" : true" .. suffix .. "\n"
		else
			serialised = serialised .. prefix .. "\"" .. name .. "\" : false" .. suffix .. "\n"
		end
	elseif (type(val) == "number") then
		serialised = serialised .. prefix .. "\"" .. name .. "\" : " .. tostring(val) .. suffix .. "\n"
	elseif (type(val) == "string") then
		serialised = serialised .. prefix .. "\"" .. name .. "\" : \"" .. val .. "\"" .. suffix .. "\n"
	elseif (type(val) == "table") then
		local _k, _v
		local itemCount, itemCurrent
		itemCount = blueprint.tablelength(val)
		itemCurrent = 0
		serialised = serialised .. prefix .. "\"" .. name .. "\" : {" .. "\n"
		for _k, _v in pairs(val) do
			itemCurrent = itemCurrent + 1
			if (itemCount == itemCurrent) then
				if (short) then
					serialised = serialised .. tableToJSONShort(prefix .. "\t", _k, _v, "") .. "\n"
				else
					serialised = serialised .. tableToJSON(prefix .. "\t", _k, _v, "")
				end
			else
				if (short) then
					serialised = serialised .. tableToJSONShort(prefix .. "\t", _k, _v, ",") .. "\n"
				else
					serialised = serialised .. tableToJSON(prefix .. "\t", _k, _v, ",")
				end
			end
			if (itemCurrent % YIELDPOINT == 0) then coroutine.yield() end
		end
		serialised = serialised .. prefix .. "}" .. suffix .. "\n"
	else
		serialised = serialised .. prefix .. "\"" .. name .. "\" : \"Serialisation error: not basic type or table\"" .. suffix .. "\n"
	end
	return serialised
end

function tableToJSONShort(prefix, name, val, suffix) -- output the table but take up less space vertically
	local serialised = ""
	if (type(val) == "boolean") then
		if (val == true) then
			serialised = serialised .. "\"" .. name .. "\" : true" .. suffix .. " "
		else
			serialised = serialised .. "\"" .. name .. "\" : false" .. suffix .. " "
		end
	elseif (type(val) == "number") then
		serialised = serialised .. "\"" .. name .. "\" : " .. tostring(val) .. suffix .. " "
	elseif (type(val) == "string") then
		serialised = serialised .. "\"" .. name .. "\" : \"" .. val .. "\"" .. suffix .. " "
	elseif (type(val) == "table") then
		local _k, _v
		local itemCount, itemCurrent
		itemCount = blueprint.tablelength(val)
		itemCurrent = 0
		serialised = serialised .. prefix .. "\"" .. name .. "\" : { "
		for _k, _v in pairs(val) do
			itemCurrent = itemCurrent + 1
			if (itemCount == itemCurrent) then
				serialised = serialised .. tableToJSONShort("", _k, _v, "")
			else
				serialised = serialised .. tableToJSONShort("", _k, _v, ",")
			end
			if (itemCurrent % YIELDPOINT == 0) then coroutine.yield() end
		end
		serialised = serialised .. "}" .. suffix
	else
		serialised = serialised .. prefix .. "\"" .. name .. "\" : \"Serialisation error: not basic type or table\"" .. suffix .. " "
	end
	return serialised
end

function tableToJSONArray(prefix, name, val, suffix) -- output the table as an array (will only catch numerically indexed values)
	local serialised = ""
	if (type(val) == "boolean") then
		if (val == true) then
			serialised = serialised .. "true" .. suffix .. " "
		else
			serialised = serialised .. "false" .. suffix .. " "
		end
	elseif (type(val) == "number") then
		serialised = serialised .. tostring(val) .. suffix .. " "
	elseif (type(val) == "string") then
		serialised = serialised .. "\"" .. val .. "\"" .. suffix .. " "
	elseif (type(val) == "table") then
		local _v
		local itemCount, itemCurrent
		itemCount = blueprint.tablelength(val)
		itemCurrent = 0
		if (name) then
			serialised = serialised .. prefix .. "\"" .. name .. "\" : [ "
		else
			serialised = serialised .. prefix .. "[ "
		end
		for _, _v in ipairs(val) do
			itemCurrent = itemCurrent + 1
			if (itemCount == itemCurrent) then
				serialised = serialised .. tableToJSONArray("", nil, _v, "")
			else
				serialised = serialised .. tableToJSONArray("", nil, _v, ",")
			end
			if (itemCurrent % YIELDPOINT == 0) then coroutine.yield() end
		end
		serialised = serialised .. "]" .. suffix
	else
		serialised = serialised .. prefix .. "\" : \"Serialisation error: not basic type or table\"" .. suffix .. " "
	end
	return serialised
end

------------------------------------------------------------------------------------
-- UTIL
------------------------------------------------------------------------------------
function blueprint.isInsideBoundingBox(pos, bBox)
	-- checks if pos x,y coordinates are inside the boundary box bBox defined by x1,y1,x2,y2
	local distBL = world.distance(pos, { bBox[1], bBox[2] })
	local distTR = world.distance(pos, { bBox[3], bBox[4] })
	
	if (distBL[1] < 0) then return false end
	if (distBL[2] < 0) then return false end
	if (distTR[1] > 0) then return false end
	if (distTR[2] > 0) then return false end

	return true
end

function blueprint.clearBlock(pos, layer)
	world.damageTiles({pos}, layer, pos, "blockish", 10000, 0)
end

function blueprint.tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

