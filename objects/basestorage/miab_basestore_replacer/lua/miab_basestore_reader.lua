-- how many iterations should a for loop go through before the coroutine yields?
YIELDPOINT = 100000

-- stages of reading
PREREADBUILDING = 0.5
READBUILDING = 1
PRECLEARAREA = 1.5
CLEARAREA = 1.6
SPITOUTPRINTER = 2
PREPRODUCEJSON = 2.4
PRODUCEJSON = 2.5
DISPLAYANIMATION = 3
READSUCCESS = 256

function readerBusy()
	if (self.miab) then
		return true
	end

	return false
end

function readStart(args)
	self.miab = {}
	-- store area to read
	self.miab.boundingBox = copyTable(args.areaToScan)
	
	-- store area to ignore
	self.miab.areaToIgnore = copyTable(args.areaToIgnore)
	
	-- store placement of printer
	self.miab.readerPosition = copyTable(args.readerPosition)
	
	-- position where the blueprint (or currently printer) will be dropped after successfull read
	self.miab.spawnPrinterPosition = copyTable(args.spawnPrinterPosition)
	
	-- do we remove the scanned structure?
	self.miab.clearArea = args.clearArea
	
	-- do we drop removed blocks and objects on the ground?
	self.miab.dropContents = args.dropContents
	
	-- do we give a printer? and if so, how many?
	self.miab.givePrinter = args.givePrinter
	self.miab.printerCount = args.printerCount
	
	-- do we give a replacer?
	self.miab.giveReplacer = args.giveReplacer
	
	-- what descriptions and icon do we give the printer?
	self.miab.printerShortDescription = args.printerName
	self.miab.printerDescription = args.printerDescription
	self.miab.printerInventoryIcon = args.printerIcon
	
	-- do we dump blueprint files to starbound.log?
	self.miab.saveBlueprint = args.saveBlueprint
	-- if we're dumping the blueprint, where should the recipe show up?
	self.miab.recipeGroup = args.recipeGroup
	
	self.miab.animationDuration = args.animationDuration -- in seconds
	
	-- reset the blueprint to blank (and store bounding box)
	local dist = world.distance({self.miab.boundingBox[3], self.miab.boundingBox[4]}, {self.miab.boundingBox[1], self.miab.boundingBox[2]})
	blueprint.Init({dist[1], dist[2]})

	-- make sure the area we're looking at is active
	if (not world.regionActive(self.miab.boundingBox)) then
		world.loadRegion(self.miab.boundingBox)
	end

	-- flag to start scanning
	self.miab.readingStage = PREREADBUILDING
	
	self.miab.animationStarted = false
	
	-- experimental coroutine stuff
	self.miab.cor = coroutine.create(function() end)
	assert(coroutine.resume(self.miab.cor))
end

function readModule()
	if (self.miab == nil) then return end -- not initialized
	
	if (self.miab.readingStage == PREREADBUILDING) then
		if (setDefaultAnimation) then setDefaultAnimation() end
		self.miab.cor = coroutine.create(scanBuilding)
		self.miab.readingStage = READBUILDING
	elseif (self.miab.readingStage == READBUILDING) then
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		else
			self.miab.readingStage = PRECLEARAREA
		end
	elseif (self.miab.readingStage == PRECLEARAREA) then
		if (self.miab == nil) then return end
		if (self.miab.clearArea) then
			self.miab.cor = coroutine.create(function ()
				dropLiquids()
				dropObjects()
				dropBlocks()
				coroutine.yield()
				cleanUpLooseEnds()
				dropBlocks() -- this has to happen twice, on seperate frames
			end)
			self.miab.readingStage = CLEARAREA
		else
			self.miab.readingStage = SPITOUTPRINTER
		end
	elseif (self.miab.readingStage == CLEARAREA) then
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		else
			self.miab.readingStage = SPITOUTPRINTER
		end
	elseif (self.miab.readingStage == SPITOUTPRINTER) then
		if (self.miab.givePrinter) then spawnPrinterItem() end
		if (self.miab.giveReplacer) then spawnReplacerItem() end
		self.miab.readingStage = PREPRODUCEJSON
	elseif (self.miab.readingStage == PREPRODUCEJSON) then
		if (self.miab.saveBlueprint) then
			self.miab.cor = coroutine.create(blueprint.DumpJSON)
			self.miab.readingStage = PRODUCEJSON
		else
			self.miab.readingStage = DISPLAYANIMATION
		end
	elseif (self.miab.readingStage == PRODUCEJSON) then
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor, self.miab.printerDescription, self.miab.printerShortDescription, self.miab.printerInventoryIcon, self.miab.recipeGroup))
		else
			self.miab.readingStage = DISPLAYANIMATION
		end
	elseif (self.miab.readingStage == DISPLAYANIMATION) then
		setScannerStatus("Scan completed successfully", "bell", "green")
		if (self.miab.animationDuration > 0) then
			displayBlueprintAnimation()
		else
			self.miab.readingStage = READSUCCESS
		end
	elseif (self.miab.readingStage == READSUCCESS) then
		endSuccessfully()
	end
end

----- Reading State machine -----

-- workers
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
	local iterations = 0
	for y = 0, yMax, 1 do
		for x = 0, xMax, 1 do
			pos = {self.miab.boundingBox[1] + x, self.miab.boundingBox[2] + y}
			if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- ignore pixels in areaToIgnore if it is defined
				liquid = world.liquidAt(pos)
				if (liquid) then
					blueprint.setLiquid(x, y, liquid)
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end
	
	-- scan blocks + mods + colours
	local matNameBack = nil
	local matNameFore = nil
	local modNameBack = nil
	local modNameFore = nil
	local colourBack = nil
	local colourFore = nil
	iterations = 0
	for y = 0, yMax, 1 do
		for x = 0, xMax, 1 do
			pos = {self.miab.boundingBox[1] + x, self.miab.boundingBox[2] + y}
			if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- ignore pixels in areaToIgnore if it is defined
				matNameBack = world.material(pos, "background")
				matNameFore = world.material(pos, "foreground")
				modNameBack = world.mod(pos, "background")
				modNameFore = world.mod(pos, "foreground")
				colourBack = world.materialColor(pos, "background")
				colourFore = world.materialColor(pos, "foreground")
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
				
				if (colourBack > 0) then
					-- store in blueprint
					blueprint.setColour(x, y, colourBack, "background")
				end
				
				if (colourFore > 0) then
					-- store in blueprint
					blueprint.setColour(x, y, colourFore, "foreground")
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- scan objects
	-- local objectIds = fixedObjectQuery({self.miab.boundingBox[1], self.miab.boundingBox[2]}, {self.miab.boundingBox[3], self.miab.boundingBox[4]}) -- the in game objectquery should be world wrap safe now
	local objectIds = world.objectQuery({self.miab.boundingBox[1], self.miab.boundingBox[2]}, {self.miab.boundingBox[3], self.miab.boundingBox[4]})
	if (objectIds) then
		iterations = 0
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
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	if (not anythingScanned) then
		endUnsuccessfully("Scan area is empty")
	end
end

function spawnPrinterItem()
	-- spawn printer item
	local _configTbl = blueprint.toConfigTable()
	_configTbl.description = self.miab.printerDescription
	_configTbl.shortdescription = self.miab.printerShortDescription
	_configTbl.inventoryIcon = self.miab.printerInventoryIcon
	world.spawnItem("miab_basestore_printer", self.miab.spawnPrinterPosition, self.miab.printerCount, _configTbl)
end

function spawnReplacerItem()
	-- spawn printer item
	local _configTbl = blueprint.toConfigTable()
	_configTbl.description = self.miab.printerDescription
	_configTbl.shortdescription = self.miab.printerShortDescription
	_configTbl.inventoryIcon = self.miab.printerInventoryIcon
	world.spawnItem("miab_basestore_replacer", self.miab.spawnPrinterPosition, self.miab.printerCount, _configTbl)
end

function displayBlueprintAnimation()
	if (self.miab.animationStarted) then
		-- timer is already running
		if(os.time() >= self.miab.animationStartTime + self.miab.animationDuration) then
			-- timer ran out
			if (setDefaultAnimation) then setDefaultAnimation() end
			self.miab.animationStarted = false
			self.miab.readingStage = READSUCCESS
		end
	else
		if (setBlueprintAnimation) then
			-- start animation
			setBlueprintAnimation()
			-- start timer
			self.miab.animationStartTime = os.time()
			self.miab.animationStarted = true
		end
	end
end

function dropObjects()
	if (self.miab == nil) then return end -- failed during read stage
	
	-- local objectIds = fixedObjectQuery({self.miab.boundingBox[1], self.miab.boundingBox[2]}, {self.miab.boundingBox[3], self.miab.boundingBox[4]}) -- world.objectQuery should work across the world wrap nowadays
	local objectIds = world.objectQuery({self.miab.boundingBox[1], self.miab.boundingBox[2]}, {self.miab.boundingBox[3], self.miab.boundingBox[4]})
	self.miab.looseEnds = {} -- this is for cleaning up rogue item drops (from stuff that drops itself in die(), where we can't get at it)
	if (objectIds) then
		local iterations = 0
		for _, objectId in pairs(objectIds) do
			local pos = world.entityPosition(objectId)
			local dist = world.distance(pos, {self.miab.boundingBox[1], self.miab.boundingBox[2]})
			if (not world.isTileProtected(pos)) then -- skip if tile protection is in place
				-- this if is needed as objects that overlap the BB but are not placed
				-- "at a block inside the BB" dont need to be copied			
				if (blueprint.isInsideBoundingBox(pos, self.miab.boundingBox)) then -- drop it, in a manner that suggests its temperature is high
					if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- ignore objects in areaToIgnore if it is defined
						if (not self.miab.dropContents) then
							if (world.containerSize(objectId)) then
								world.containerTakeAll(objectId) -- dropContents is false and the object has an inventory so we delete that inventory rather than drop it
							end
							-- "what's today, my fine fellow?" "today? why, it's kludgemas day"
							-- here's where we compile our list of loose end item drops
							local objectBreakDrop = world.getObjectParameter(objectId, "breakDropOptions")
							if (objectBreakDrop) then self.miab.looseEnds[pos] = world.entityName(objectId) end
							--
						end
						world.breakObject(objectId, not self.miab.dropContents) -- only drop if dropContents is true, so we can delete areas
					end
				end
			end
		end
		iterations = iterations + 1
		if (iterations % YIELDPOINT == 0) then coroutine.yield() end
	end
end

function dropBlocks()
	if (self.miab == nil) then return end -- failed during read stage
	
	local dist = world.distance({self.miab.boundingBox[3], self.miab.boundingBox[4]}, {self.miab.boundingBox[1], self.miab.boundingBox[2]})
	local xMax = dist[1]
	local yMax = dist[2]
	local pos = {}
	local harvestLevel = 0

	if (self.miab.dropContents) then -- are we dropping blocks today?
		harvestLevel = 1000
	end
	local iterations = 0
	for y = yMax, 0, -1 do
		for x = 0, xMax, 1 do
			pos = {self.miab.boundingBox[1] + x, self.miab.boundingBox[2] + y}
			if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- dont destroy what we ignored while scanning
				if (not world.isTileProtected(pos)) then -- skip if tile protection is in place
					world.damageTiles({pos}, "background", pos, "blockish", 10000, harvestLevel)
					world.damageTiles({pos}, "foreground", pos, "blockish", 10000, harvestLevel)
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end
end

function dropLiquids()
	if (self.miab == nil) then return end -- failed during read stage
	
	local dist = world.distance({self.miab.boundingBox[3], self.miab.boundingBox[4]}, {self.miab.boundingBox[1], self.miab.boundingBox[2]})
	local xMax = dist[1]
	local yMax = dist[2]
	local pos = {}
	local liquid = nil
	local json = nil

	local iterations = 0
	for y = yMax, 0, -1 do
		for x = 0, xMax, 1 do
			pos = {self.miab.boundingBox[1] + x, self.miab.boundingBox[2] + y}
			if (not self.miab.areaToIgnore) or (self.miab.areaToIgnore and not blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then -- dont destroy what we ignored while scanning
				if (not world.isTileProtected(pos)) then -- skip if tile protection is in place
					if (self.miab.dropContents) then
						liquid = world.liquidAt(pos)
						if (liquid) then
							json = root.liquidConfig(liquid[1])
							if (json) then
								world.spawnItem(json.config.itemDrop, pos, math.ceil(liquid[2]), {})
							end
						end
					end
					world.destroyLiquid(pos)
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end
end

function cleanUpLooseEnds()
	if (self.miab == nil) then return end -- failed during read stage
	
	if (self.miab.looseEnds) and (not self.miab.dropContents) then
		local pos, objectName, iDrop
		local iterations = 0
		for pos, objectName in pairs(self.miab.looseEnds) do
			local dropIds = world.itemDropQuery(pos, 5.0)
			for _, iDrop in pairs(dropIds) do
				if (world.entityName(iDrop) == objectName) then
					world.takeItemDrop(iDrop)
					objectName = nil
				end
				iterations = iterations + 1
				if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
	end
end

function endUnsuccessfully(reason)
	setScannerStatus(reason, "error", "red")
	blueprint.Init({0, 0}) -- reset blueprint
	self.miab = nil -- reset state
end

function endSuccessfully()
	blueprint.Init({0, 0}) -- reset blueprint
	self.miab = nil -- reset state
end