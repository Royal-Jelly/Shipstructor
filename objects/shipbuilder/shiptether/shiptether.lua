function myClearModdedBlocks()
    local bl = { self.miab.pos[1] - 100, self.miab.pos[2] - 100}
    local tr = { self.miab.pos[1] + blueprint.boundingBoxSize[1] + 100, self.miab.pos[2] + blueprint.boundingBoxSize[2] + 100}
	
    for _y = tr[2], bl[2], -1 do
        for _x = bl[1], tr[1], 1 do
            local y = tostring(math.floor(_y - bl[2]))
            local x = tostring(math.floor(_x - bl[1]))
			breakBlock({_x, _y}, "foreground")
			breakBlock({_x, _y}, "background")
        end
    end

    self.miab.buildingStage = PLACEBLOCKS
end

function scanBuilding()
	if self.miab.boundingBox == nil then
		endUnsuccessfully("Scan area is undefined")
		return
	end
	
	local anythingScanned = false
	
	local dist = world.distance({self.miab.boundingBox[3], self.miab.boundingBox[4]}, {self.miab.boundingBox[1], self.miab.boundingBox[2]})
	local xMax = dist[1]
	local yMax = dist[2]
	if xMax < 1 or yMax < 1 then
		endUnsuccessfully("Scan area is too small")
		return
	end
	
	-- scan liquids
	local pos = nil
	local liquid = nil
	for y = 0, yMax, 1 do
		for x = 0, xMax, 1 do
			pos = {self.miab.boundingBox[1] + x, self.miab.boundingBox[2] + y}
			if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- ignore pixels in areaToIgnore if it is defined
				liquid = world.liquidAt(pos)
				if (liquid) then
					blueprint.setLiquid(x, y, liquid)
				end
			end
		end
	end
	
	-- scan blocks + mods
	local matNameBack = nil
	local matNameFore = nil
	local modNameBack = nil
	local modNameFore = nil
	for y = 0, yMax, 1 do
		for x = 0, xMax, 1 do
			pos = {self.miab.boundingBox[1] + x, self.miab.boundingBox[2] + y}
			if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- ignore pixels in areaToIgnore if it is defined
				matNameBack = world.material(pos, "background")
				matNameFore = world.material(pos, "foreground")
				modNameBack = world.mod(pos, "background")
				modNameFore = world.mod(pos, "foreground")
				-- some impassable things like doors leave "metamaterial:<something>" now which cant be printed later on ...
				if matNameBack and not string.find(matNameBack, "metamaterial:") then
					-- store in blueprint
					blueprint.setBlock(x, y, matNameBack, "background")
					
					anythingScanned = true
				else
					-- store as scaffold location
					blueprint.setBlock(x, y, "miab_scaffold", "background")
				end

				-- some impassable things like doors leave "metamaterial:<something>" now which cant be printed later on ...
				if matNameFore and not string.find(matNameFore, "metamaterial:") then			
					-- store in blueprint
					blueprint.setBlock(x, y, matNameFore, "foreground")
					
					anythingScanned = true
				else
					-- store as scaffold location
					blueprint.setBlock(x, y, "miab_scaffold", "foreground")
				end

				if (modNameBack) then
					-- store in blueprint
					blueprint.setMod(x, y, modNameBack, "background")
					
					anythingScanned = true
				end

				if (modNameFore) then
					-- store in blueprint
					blueprint.setMod(x, y, modNameFore, "foreground")
					
					anythingScanned = true
				end
			end
		end
	end

	-- scan objects
	-- local objectIds = fixedObjectQuery({self.miab.boundingBox[1], self.miab.boundingBox[2]}, {self.miab.boundingBox[3], self.miab.boundingBox[4]}) -- the in game objectquery should be world wrap safe now
	local objectIds = world.objectQuery({self.miab.boundingBox[1], self.miab.boundingBox[2]}, {self.miab.boundingBox[3], self.miab.boundingBox[4]}, { withoutEntityId = entity.id() })
	if (objectIds) then
		for _, objectId in pairs(objectIds) do
			pos = world.entityPosition(objectId)
			dist = world.distance(pos, {self.miab.boundingBox[1], self.miab.boundingBox[2]})
			-- this if is needed as objects that overlap the BB but are not placed
			-- "at a block inside the BB" dont need to be copied			
			if (blueprint.isInsideBoundingBox(pos, self.miab.boundingBox)) then
				if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- ignore objects in areaToIgnore if it is defined
					-- store in blueprint
					blueprint.setObject(dist[1], dist[2], objectId, self.miab.clearArea)
					-- smash it (this is now done in dropObjects because why was I doing the same thing in two different places?)
					-- world.breakObject(objectId, true)
					
					anythingScanned = true
				end
			end
		end
	end

	if (not anythingScanned) then
		endUnsuccessfully("Scan area is empty")
	end
end

function myClearArea()
	self.miab.obstructionTable = {}
	self.miab.anythingPrinted = false
	
    local bl = { self.miab.pos[1] - 100, self.miab.pos[2] - 100}
    local tr = { self.miab.pos[1] + blueprint.boundingBoxSize[1] + 100, self.miab.pos[2] + blueprint.boundingBoxSize[2] + 100}
	local entityCount = nil
	local entityIDs = {}
	local currentEntityType = nil
	

	for _y = tr[2], bl[2], -1 do
		for _x = bl[1], tr[1], 1 do
			world.destroyLiquid({_x, _y})
		end
	end
	
	entityCount = 0
	-- entityIDs = fixedEntityQuery(bl, tr) -- we should be fine with trusting the game's entityquery around the world wrap now
	entityIDs = world.entityQuery(bl, tr, { boundMode = "collisionarea", withoutEntityId = entity.id() })
	self.miab.looseEnds = {} -- this is for cleaning up rogue item drops (from stuff that drops itself in die(), where we can't get at it)
	for _, entID in pairs(entityIDs) do
		if (entityInOurBox(entID, bl, tr)) then
			currentEntityType = world.entityType(entID) -- "player", "monster", "object", "itemdrop", "projectile", "plant", "plantdrop", "effect", "npc"

			--[[if (currentEntityType == "player") or (currentEntityType == "npc") then
				entityCount = entityCount + 1
				self.miab.obstructionTable[entID] = true
			elseif (currentEntityType == "monster") then
				world.sendEntityMessage(entID, "despawn")
				if     (world.monsterType(entID) == "petweasel")
					or (world.monsterType(entID) == "petbunny")
					or (world.monsterType(entID) == "petsnake")
					or (world.monsterType(entID) == "piglett")
					or (world.monsterType(entID) == "petcat")
					or (world.monsterType(entID) == "crasberry")
					or (world.monsterType(entID) == "snugget")
					or (world.monsterType(endID) == "petorbis") then
						-- its the imortal ship pet - we have to surrender
						entityCount = entityCount + 1
				end
			else]]if (currentEntityType == "object") then
				if (world.containerSize(entID)) then
					world.containerTakeAll(entID) -- dropContents is false and the object has an inventory so we delete that inventory rather than drop it
				end
				-- here's where we compile our list of loose end item drops
				local objectBreakDrop = world.getObjectParameter(entID, "breakDropOptions")
				if (objectBreakDrop) then self.miab.looseEnds[world.entityPosition(entID)] = world.entityName(entID) end
				--
				if(world.entityName(entID) ~= "teleporter" and world.entityName(entID) ~= "avianteleporter" and world.entityName(entID) ~= "floranteleporter" and world.entityName(entID) ~= "glitchteleporter" and world.entityName(entID) ~= "humanteleporter" and world.entityName(entID) ~= "hylotlteleporter" and world.entityName(entID) ~= "novakidteleporter" and world.entityName(entID) ~= "apexshiptether" and world.entityName(entID) ~= "avianshiptether" and world.entityName(entID) ~= "floranshiptether" and world.entityName(entID) ~= "glitchshiptether" and world.entityName(entID) ~= "humanshiptether" and world.entityName(entID) ~= "hylotlshiptether" and world.entityName(entID) ~= "novakidshiptether") then -- Blacklist.
					world.breakObject(entID, true)
				end
			elseif (currentEntityType == "plant") then
				blueprint.clearBlock(world.entityPosition(entID), "foreground")
			else
				--sb.logWarn ("Modules in a Box: Unhandled Entity detected during clearArea() of type " .. currentEntityType)
			end
		end
	end

    for _y = tr[2], bl[2], -1 do
        for _x = bl[1], tr[1], 1 do
            local y = tostring(math.floor(_y - bl[2]))
            local x = tostring(math.floor(_x - bl[1]))
			breakBlock({_x, _y}, "foreground")
			breakBlock({_x, _y}, "background")
        end
    end

	if (entityCount > 0) then
		-- there are entities blocking placement
		self.miab.buildingStage = PRINTOBSTRUCTED
	else
		self.miab.buildingStage = DOUBLETAPBLOCKS
	end
end

--- Object init event.
-- Gets executed when this object is placed.
-- @param virtual if this is a virtual call?
function init(virtual)
	if virtual then return end

	object.setInteractive(true)

	-- Set handler for UI message
	message.setHandler("checkController", checkController)
end

--- Object update event
-- Gets executed when this object updates.
-- @param dt delta time, time is specified in *.object as scriptDelta (60 = 1 second)
function update(dt)
end

--- Object on container action event.
-- Gets executed when a player "does" things in the container
-- For example place item in slot, then this function gets called
function containerCallback()
	-- Check valid pod here, if it's not valid "spit" the item back out.
	local podItem = world.containerItemAt(entity.id(), 0) -- << Get item in itemSlot 0

	if podItem == nil then return end -- << Not a valid item, jump out

	if not validatePod(podItem) then -- << Not a valid pod, spit it out
		if world.containerConsume(entity.id(), podItem) then
			if world.spawnItem(podItem, entity.position()) == nil then -- << If the item was not spawned, readd to the container
				world.containerAddItems(entity.id(), podItem)
			end
		end
	end
end

-- Custom functions here

--- Message function, when user clicks button on UI
function checkController()
	local podItem = world.containerItemAt(entity.id(), 0) -- << Get item in itemSlot 0

	if podItem == nil then return end -- << Not a valid item, jump out

	-- This is the message that gets send when the button in the GUI is pressed
	-- One could just "re-check" here if it's a valid pod.
	if not validatePod(podItem) then return end -- << Don't do anything with the 

	local itemConf = root.itemConfig(podItem)

	-- For the scanner to be able to "scan" miab_breakStuff has to be FALSE!
	--[[object.setConfigParameter("miab_breakStuff", itemConf["config"]["miab_breakStuff"])
	object.setConfigParameter("miab_clearOnly", itemConf["config"]["miab_clearOnly"])
	object.setConfigParameter("miab_dumpJSON", itemConf["config"]["miab_dumpJSON"])
	object.setConfigParameter("miab_printerCount", itemConf["config"]["miab_printerCount"])	
	object.setConfigParameter("miab_basestore_blueprint", itemConf["config"]["miab_basestore_blueprint"])
	object.setConfigParameter("miab_printer_offset", itemConf["config"]["miab_printer_offset"])]]
	object.setConfigParameter("miab_dumpJSON", itemConf["config"]["miab_dumpJSON"])
	object.setConfigParameter("miab_basestore_blueprint", itemConf["config"]["miab_basestore_blueprint"])
	object.setConfigParameter("miab_fixed_area_to_ignore_during_scan_bounding_box", itemConf["config"]["miab_fixed_area_to_ignore_during_scan_bounding_box"])
	object.setConfigParameter("miab_fixed_area_to_scan_bounding_box", itemConf["config"]["miab_fixed_area_to_scan_bounding_box"])

	-- Consume pod item
	world.containerConsume(entity.id(), podItem)

	if (not readerBusy()) then
		-- Options for read process
		local readerOptions = {}
		--[[
		readerOptions.readerPosition = object.toAbsolutePosition({ 0.0, 0.0 })
		readerOptions.spawnPrinterPosition = object.toAbsolutePosition({ 0, 4 })
		readerOptions.breakStuff = config.getParameter("miab_breakStuff", true)
		readerOptions.clearOnly = config.getParameter("miab_clearOnly", false)
		readerOptions.plotJSON = config.getParameter("miab_dumpJSON", false)
		readerOptions.printerCount = config.getParameter("miab_printerCount", 1)
		readerOptions.animationDuration = 3		
		]]

		readerOptions = config.getParameter("miabScannerOptions", nil)
		readerOptions.readerPosition = object.toAbsolutePosition({ 0.0, 0.0 })
		readerOptions.spawnPrinterPosition = object.toAbsolutePosition({ 0, 4 })
		readerOptions.saveBlueprint = config.getParameter("miab_dumpJSON", false)
		readerOptions.areaToIgnore = config.getParameter("miab_fixed_area_to_ignore_during_scan_bounding_box", nil) -- [left, bottom, right, top]
		readerOptions.areaToScan = config.getParameter("miab_fixed_area_to_scan_bounding_box", nil)  or  defineAreaToScan(readerOptions.scannerSize, readerOptions.scannerOrigin) -- [left, bottom, right, top]
		readerOptions.animationDuration = 0
		
		--if (readerOptions.areaToScan ~= nil) then
			-- start reading process
			readStart(readerOptions)
		--end
	end
end

--- Object update event
-- Gets executed when this object updates.
-- @param dt delta time, time is specified in *.object as scriptDelta (60 = 1 second)
function update(dt)
	-- this needs to be polled until done
	if (self.miab == nil) then return end -- not initialized
	
	--[[if (self.miab.readingStage) then -- only accessed during read
		if (self.miab.readingStage == READBUILDING) then
			scanBuilding()
			if (self.miab.breakStuff) then destroyBlocks() end
			self.miab.readingStage = SPITOUTPRINTER
		elseif (self.miab.readingStage == SPITOUTPRINTER) then
			if (self.miab.breakStuff) then destroyBlocks() end
			-- spawnPrinterItem()
			produceJSONOutput()
			---if (not self.miab.breakStuff) then object.smash() end
			self.miab.readingStage = READSUCCESS
		elseif (self.miab.readingStage == READSUCCESS) then
			-- TODO: Check for self.
			self.miab = nil -- reset scanner state
			-- \/ This can be used to spawn an item with blueprint :D!
			self.scaned_configTable = blueprint.toConfigTable() -- save scanned table
			blueprint.Init({0, 0}) -- reset blueprint
			
			-- Start to configure writing process
			local writerOptions = {}
			local area_to_scan_bounding_box = config.getParameter("miab_fixed_area_to_scan_bounding_box", nil)
			writerOptions.writerPosition = ({area_to_scan_bounding_box[1],area_to_scan_bounding_box[2]})
			printInit(writerOptions)
			donePrinting = false -- flag to end polling	
		end
	end]]

	if (self.miab.readingStage) then -- only accessed during read
		if (self.miab.readingStage == READBUILDING) then
			if (setDefaultAnimation) then setDefaultAnimation() end
			scanBuilding()
			if (self.miab == nil) then return end
			if (self.miab.clearArea) then
				dropLiquids()
				dropObjects()
				dropBlocks()
			end
			self.miab.readingStage = SPITOUTPRINTER
		elseif (self.miab.readingStage == SPITOUTPRINTER) then
			if (self.miab.clearArea) then
				cleanUpLooseEnds()
				dropBlocks()
			end
			if (self.miab.givePrinter) then spawnShippodItem()  end  -- this spawns an invalid item at the moment
			if (self.miab.saveBlueprint) then produceJSONOutput() end
			self.miab.readingStage = DISPLAYANIMATION
		elseif (self.miab.readingStage == DISPLAYANIMATION) then
			--setScannerStatus("Scan completed successfully", "bell", "green")
			if (self.miab.animationDuration > 0) then
				displayBlueprintAnimation()
			else
				self.miab.readingStage = READSUCCESS
			end
		elseif (self.miab.readingStage == READSUCCESS) then
			endSuccessfully()

			-- Start to configure writing process
			local writerOptions = {}
			local area_to_scan_bounding_box = config.getParameter("miab_fixed_area_to_scan_bounding_box", nil)
			writerOptions.writerPosition = ({area_to_scan_bounding_box[1],area_to_scan_bounding_box[2]})
			printInit(writerOptions)
			donePrinting = false -- flag to end polling	
		end
	end

	if (self.miab.buildingStage) then -- only accessed during write
		if (self.miab.buildingStage == PRINTINITIALISE) then -- read the Blueprint to be built
			--readBlueprint()
			blueprint.fromEntityConfig()
			self.miab.buildingStage = CLEARBUILDAREA
		elseif (self.miab.buildingStage == PREVIEWBUILDAREA) then -- display the build area indicator
			if (self.miab.time_to == nil) then self.miab.time_to = (os.time() - 1) end
			if (os.time() >= self.miab.time_to) then
				self.miab.time_to = os.time() + printPreview({self.miab.pos[1], self.miab.pos[2]})
			end
		elseif (self.miab.buildingStage == CLEARBUILDAREA) then -- clear build area
			-- make sure the area we're looking at is active
			if (not world.regionActive({self.miab.pos[1], self.miab.pos[2], self.miab.pos[1] + blueprint.boundingBoxSize[1], self.miab.pos[2] + blueprint.boundingBoxSize[2]})) then
				world.loadRegion({self.miab.pos[1], self.miab.pos[2], self.miab.pos[1] + blueprint.boundingBoxSize[1], self.miab.pos[2] + blueprint.boundingBoxSize[2]})
			end
			myClearArea()
		elseif (self.miab.buildingStage == DOUBLETAPBLOCKS) then -- clear build area
			cleanUpLooseEnds()
			myClearModdedBlocks()
		elseif (self.miab.buildingStage == PLACEBLOCKS) then -- place scaffolding + blocks
			printBlocks()
		elseif (self.miab.buildingStage == PLACETILEMODS) then -- place mods on tiles
			printTileMods()
		elseif (self.miab.buildingStage == REMOVESCAFFOLD) then -- remove scaffolding
			clearScaffolding()
		elseif (self.miab.buildingStage == PLACEOBJECTS) then -- place objects
			printObjects()
		elseif (self.miab.buildingStage == PLACELIQUIDS) then -- place liquids
			printLiquids()
	 	elseif (self.miab.buildingStage == PRINTOBSTRUCTED) then -- area was obstructed
			FloatObstructed()
		elseif (self.miab.buildingStage == PRINTUNANCHORED) then -- area was in a void, no blocks could be placed
			FloatUnanchored()
		elseif (self.miab.buildingStage == PRINTSUCCESS) then
			blueprint.Init({0, 0})
			self.miab = nil
		end
	end
end

-- This function was usefull in making it so i could create shippods easier you must use two recivers in order to get a good blueprint
function defineAreaToScan(scannerSize, scannerOrigin)
	local bounds = {0, 0, 0, 0}
	local pos1 = entity.position() -- default corners are the corners of the scanner itself
	local pos2 = entity.position()
	local ents = object.getOutputNodeIds(0)
	local useScannerAsCorner = true

	-- handle different ammounts of receivers and wired or not
	--setupCorners()
	if (self.cornerCount == 0) then
		return nil
	elseif (self.cornerCount == 1) then
		-- use one corner and the scanner itself
		pos2 = world.entityPosition(self.corners[1])
	else
		-- use two corners
		pos1 = world.entityPosition(self.corners[1])
		pos2 = world.entityPosition(self.corners[2])
		useScannerAsCorner = false
	end
	
	-- find smallest X Corner coordinate of the two corners
	-- and use that for the left of the bounding box
	-- use the bigger one for right side
	-- using world.distance()
	local dist = world.distance(pos2, pos1)
	local xMax = dist[1]
	local yMax = dist[2]
	if (xMax > 1) then
		bounds[1] = pos1[1] -- left
		bounds[3] = pos2[1] -- right
		scannerCornerX = "left" -- if one of the corners is the scanner it is the left one
	elseif (xMax < 1) then
		bounds[1] = pos2[1] -- left
		bounds[3] = pos1[1] -- right
		scannerCornerX = "right" -- if one of the corners is the scanner it is the right one
	else
		return nil
	end

	-- find smallest Y Corner coordinate of the two corners
	-- and use that for the bottom of the bounding box
	-- use the bigger one for top side
	if (pos1[2] < pos2[2]) then
		bounds[2] = pos1[2] -- down
		bounds[4] = pos2[2] -- up
	elseif (pos1[2] > pos2[2]) then
		bounds[2] = pos2[2] -- down
		bounds[4] = pos1[2] -- up
	else
		return nil
	end
	
	if (useScannerAsCorner) then
		-- we have to shift a bit accoring to the size of the scanner
		-- X coordinate shift due to scanner size
		if (scannerCornerX == "left") then
			-- if the scanner is left corner
			bounds[1] = bounds[1] + (scannerSize[1] - scannerOrigin[1])
		elseif (scannerCornerX == "right") then
			-- if the scanner is right corner
			bounds[3] = bounds[3] + (scannerSize[1] - scannerOrigin[1]) - scannerSize[1] +1
		else
			return nil
		end
		-- Y coordinate is not of interest. we allways use the origin of the scanner.
		-- not adapting Y will never leed to the scanner beeing eaten by itself
	end

	-- so far we are directly ON the corners.
	-- we sorted out which one is bottom left and which one is top right
	-- we also shifted one of the corners if it was the scanner itself accoring to the size of the scanner in order not to eat the scanner itself

	-- we now apply an offset for the box.
	-- we dont want to scan AT the corners, but inside of the corners (in X direction "inside")
	-- Offsets for scanning objects:
	-- 1 block right, 0 blocks up for bottom left
	-- 1 block left, 0 blocks down for top right
	bounds[1] = bounds[1] + 1.0 --( <- offset from bottom left
	bounds[2] = bounds[2] + 0.0 --(
	bounds[3] = bounds[3] - 1.0 --( <- offset from top right corner_2
	bounds[4] = bounds[4] - 0.0 --(

	-- although this is already checked we check again if the box has a zero or negativ area
	-- "negative" meaing that what is left and right (or up and down) might be labled wrong
	dist = world.distance({bounds[3], bounds[4]}, {bounds[1], bounds[2]})
	xMax = dist[1]
	yMax = dist[2]
	if (xMax < 1) or (yMax < 1) then
		return nil
	end
	return bounds
end


function toConfigTable()
    local tbl = {}
    
    tbl.boundingBoxSize = blueprint.boundingBoxSize
    tbl.nextBlockId = blueprint.nextBlockId
    tbl.blocksTable = blueprint.blocksTable
    tbl.layoutTableBackground = blueprint.layoutTableBackground
    tbl.layoutTableForeground = blueprint.layoutTableForeground
    tbl.layoutTableBackgroundMods = blueprint.layoutTableBackgroundMods
    tbl.layoutTableForegroundMods = blueprint.layoutTableForegroundMods
    tbl.liquidTable = blueprint.liquidTable
    tbl.objectTable = blueprint.objectTable
    
    return {miab_basestore_blueprint = tbl }
end

function spawnShippodItem()
world.spawnItem("blueprintmodule", self.miab.spawnPrinterPosition, self.miab.printerCount, toConfigTable())
end



--- Function to check if the item is a valid pod
-- @param itm The item to check
-- @return true if the item is valid, false otherwise
function validatePod(itm)
	return root.itemHasTag(itm["name"], "shipmodule")
end
