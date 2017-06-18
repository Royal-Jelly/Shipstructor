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
	object.setConfigParameter("miab_breakStuff", itemConf["config"]["miab_breakStuff"])
	object.setConfigParameter("miab_clearOnly", itemConf["config"]["miab_clearOnly"])
	object.setConfigParameter("miab_dumpJSON", itemConf["config"]["miab_dumpJSON"])
	object.setConfigParameter("miab_printerCount", itemConf["config"]["miab_printerCount"])
	object.setConfigParameter("miab_fixed_area_to_ignore_during_scan_bounding_box", itemConf["config"]["miab_fixed_area_to_ignore_during_scan_bounding_box"])
	object.setConfigParameter("miab_fixed_area_to_scan_bounding_box", itemConf["config"]["miab_fixed_area_to_scan_bounding_box"])
	object.setConfigParameter("miab_basestore_blueprint", itemConf["config"]["miab_basestore_blueprint"])
	object.setConfigParameter("miab_printer_offset", itemConf["config"]["miab_printer_offset"])

	if (not readerBusy()) then
		-- Set options for read process
		local readerOptions = {}
		readerOptions = config.getParameter("miabScannerOptions", nil)
		readerOptions.readerPosition = object.toAbsolutePosition({ 0.0, 0.0 })
		readerOptions.spawnPrinterPosition = object.toAbsolutePosition({ 0, 4 })
		
		-- start reading process
		readStart(readerOptions)
	end
end

--- Object update event
-- Gets executed when this object updates.
-- @param dt delta time, time is specified in *.object as scriptDelta (60 = 1 second)
function update(dt)
	-- this needs to be polled until done
	if (self.miab == nil) then return end -- not initialized
	
	if (self.miab.readingStage) then -- only accessed during read
		if (self.miab.readingStage == READBUILDING) then
			scanBuilding()
			if (self.miab.breakStuff) then destroyBlocks() end
			self.miab.readingStage = SPITOUTPRINTER
		elseif (self.miab.readingStage == SPITOUTPRINTER) then
			if (self.miab.breakStuff) then destroyBlocks() end
			spawnShippodItem() -- Generates a Ship Pod that is broken atm
			produceJSONOutput()
			if (not self.miab.breakStuff) then object.smash() end
			self.miab.readingStage = READSUCCESS
		elseif (self.miab.readingStage == READSUCCESS) then
			self.miab = nil -- reset scanner state
			self.scaned_configTable = blueprint.toConfigTable() -- save scanned table
			blueprint.Init({0, 0}) -- reset blueprint
			
			-- Start to configure writing process
			local writerOptions = {}
			local area_to_scan_bounding_box = config.getParameter("miabScannerOptions.areaToScan", nil)
			writerOptions.writerPosition = ({area_to_scan_bounding_box[1],area_to_scan_bounding_box[2]})
			writerOptions.spawnUnplacablesPosition = object.toAbsolutePosition({ 0, 4 })
			printInit(writerOptions)
			donePrinting = false -- flag to end polling
		end
	end

	if (self.miab.buildingStage) then -- only accessed during write
		if (not donePrinting) then
			-- needs to be polled
			donePrinting = printModule_modified_copy_from_miab_basestore_printer()
		else
			self.miab = nil
			--object.smash()
		end	
	end
end

function setScannerStatus(status, sound, colour)
end

function printModule_modified_copy_from_miab_basestore_printer()
	if (self.miab == nil) then return false end -- not initialized

	if (self.miab.buildingStage == PRINTINITIALISE) then -- read the Blueprint to be built
		--sb.logInfo("3.1 - PRINTINITIALISE")
		readBlueprint()
	elseif (self.miab.buildingStage == PREVIEWBUILDAREA) then -- display the build area indicator
		--sb.logInfo("3.2 - PREVIEWBUILDAREA")
		self.miab.buildingStage = PLACEBLOCKS
	elseif (self.miab.buildingStage == CLEARBUILDAREA) then -- clear build area
		--sb.logInfo("3.3 - CLEARBUILDAREA")
		-- should never happen
	elseif (self.miab.buildingStage == DOUBLETAPBLOCKS) then -- clear build area
		--sb.logInfo("3.4 - DOUBLETAPBLOCKS")
		-- should never happen
	elseif (self.miab.buildingStage == PLACEBLOCKS) then -- place scaffolding + blocks
		--sb.logInfo("3.5 - PLACEBLOCKS")
		printBlocks()
	elseif (self.miab.buildingStage == PLACETILEMODS) then -- place mods on tiles
		--sb.logInfo("3.6 - PLACETILEMODS")
		printTileMods()
	elseif (self.miab.buildingStage == REMOVESCAFFOLD) then -- remove scaffolding
		--sb.logInfo("3.7 - REMOVESCAFFOLD")
		clearScaffolding()
	elseif (self.miab.buildingStage == PLACEOBJECTS) then -- place objects
		--sb.logInfo("3.8 - PLACEOBJECTS")
		printObjects()
	elseif (self.miab.buildingStage == PLACELIQUIDS) then -- place liquids
		--sb.logInfo("3.9 - PLACELIQUIDS")
		printLiquids()
 	elseif (self.miab.buildingStage == PRINTOBSTRUCTED) then -- area was obstructed
		--sb.logInfo("3.10 - PRINTOBSTRUCTED")
		FloatObstructed()
	elseif (self.miab.buildingStage == PRINTUNANCHORED) then -- area was in a void, no blocks could be placed
		--sb.logInfo("3.11 - PRINTUNANCHORED")
		FloatUnanchored()
	elseif (self.miab.buildingStage == PRINTSUCCESS) then
		--sb.logInfo("3.12 - PRINTSUCCESS")
		return true
	end

	return false
end

-- this spawns a invalid shippods atm because i'm missing related to the _configTbl thing from Modules in a box
-- I Am not exacly sure why this doesn't work but i'm sure im just being dumb
function spawnShippodItem()
	local _configTbl = blueprint.toConfigTable()
	world.spawnItem("storedshipcontroller", self.miab.spawnPrinterPosition, self.miab.printerCount, _configTbl)
end

--- Function to check if the item is a valid pod
-- @param itm The item to check
-- @return true if the item is valid, false otherwise
function validatePod(itm)
	return root.itemHasTag(itm["name"], "shipcontroller")
end
