-- how many iterations should a for loop go through before the coroutine yields?
YIELDPOINT = 100000

-- stages of printing
PRINTINITIALISE = 1
BLUEPRINTINITIALISE = 1.1
PREVIEWBUILDAREA = 2
PRECLEARBUILDAREA = 2.9
CLEARBUILDAREA = 3
PRELOOSEENDS = 3.1
LOOSEENDS = 3.2
PREDOUBLETAPBLOCKS = 3.4
DOUBLETAPBLOCKS = 3.5
PLACEBLOCKS = 4
PREPLACETILEMODS = 4.9
PLACETILEMODS = 5
PREPAINTCOLOURS = 5.1
PAINTCOLOURS = 5.2
PREREMOVESCAFFOLD = 5.9
REMOVESCAFFOLD = 6
PREPLACEOBJECTS = 6.9
PLACEOBJECTS = 7
PREPLACELIQUIDS = 7.9
PLACELIQUIDS = 8
PRINTPROTECTED = 253
PRINTOBSTRUCTED = 254
PRINTUNANCHORED = 255
PRINTSUCCESS = 256

function printInit(args)
	self.miab = {}
	
	-- We build at the right of this object, which is 1 blocks right
	self.miab.pos = args.writerPosition
	
	if (args.areaToIgnore == nil) then else self.miab.areaToIgnore = args.areaToIgnore end
	
	-- this is where all items that have not been placed
	-- (for whatever reason i.e. door doesnt fit in new building location)
	-- are spawned after construction and before the blueprint is destroyed
	self.miab.pos_to_spit_out_unplaceables = args.spawnUnplaceablesPosition
	
	-- display bluegrid
	self.miab.buildingStage = PRINTINITIALISE
	-- next bluegrid execution is now
	self.miab.time_to = nil
	self.miab.particleDelay = os.time() - 1
	
	self.miab.ScaffoldmatName = "glass"
	
	-- experimental coroutine stuff
	self.miab.cor = coroutine.create(function() end)
	assert(coroutine.resume(self.miab.cor))
end

function printStart()
	-- flag to start printing
	if (self.miab.buildingStage == PREVIEWBUILDAREA) then
		self.miab.buildingStage = PRECLEARBUILDAREA
	end
end

function printModule()
	if (self.miab == nil) then return false end -- not initialized

	if (self.miab.buildingStage == PRINTINITIALISE) then
		self.miab.cor = coroutine.create(readBlueprint)
		self.miab.buildingStage = BLUEPRINTINITIALISE
	elseif (self.miab.buildingStage == BLUEPRINTINITIALISE) then -- read the Blueprint to be built
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PREVIEWBUILDAREA) then -- display the build area indicator
		-- display build area with blue line
		if (self.miab.time_to == nil) then self.miab.time_to = (os.time() - 1) end
		if (os.time() >= self.miab.time_to) then
			self.miab.time_to = os.time() + printPreview({self.miab.pos[1], self.miab.pos[2]})
		end
	elseif (self.miab.buildingStage == PRECLEARBUILDAREA) then
		self.miab.cor = coroutine.create(clearArea)
		self.miab.buildingStage = CLEARBUILDAREA
	elseif (self.miab.buildingStage == CLEARBUILDAREA) then -- clear build area
		-- make sure the area we're looking at is active
		if (not world.regionActive({self.miab.pos[1], self.miab.pos[2], self.miab.pos[1] + blueprint.boundingBoxSize[1], self.miab.pos[2] + blueprint.boundingBoxSize[2]})) then
			world.loadRegion({self.miab.pos[1], self.miab.pos[2], self.miab.pos[1] + blueprint.boundingBoxSize[1], self.miab.pos[2] + blueprint.boundingBoxSize[2]})
		end
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PRELOOSEENDS) then
		self.miab.cor = coroutine.create(cleanUpLooseEnds)
		self.miab.buildingStage = LOOSEENDS
	elseif (self.miab.buildingStage == LOOSEENDS) then -- clean up loose ends
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		else
			self.miab.buildingStage = PREDOUBLETAPBLOCKS
		end
	elseif (self.miab.buildingStage == PREDOUBLETAPBLOCKS) then
		self.miab.cor = coroutine.create(clearModdedBlocks)
		self.miab.buildingStage = DOUBLETAPBLOCKS
	elseif (self.miab.buildingStage == DOUBLETAPBLOCKS) then -- clear build area
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PLACEBLOCKS) then -- place scaffolding + blocks
		if (coroutine.status(self.miab.cor) == "dead") then
			self.miab.cor = coroutine.create(printBlocks)
		end
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PREPLACETILEMODS) then
		self.miab.cor = coroutine.create(printTileMods)
		self.miab.buildingStage = PLACETILEMODS
	elseif (self.miab.buildingStage == PLACETILEMODS) then -- place mods on tiles
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PREPAINTCOLOURS) then
		self.miab.cor = coroutine.create(paintTileColours)
		self.miab.buildingStage = PAINTCOLOURS
	elseif (self.miab.buildingStage == PAINTCOLOURS) then -- paint colours on tiles
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PREREMOVESCAFFOLD) then
		self.miab.cor = coroutine.create(clearScaffolding)
		self.miab.buildingStage = REMOVESCAFFOLD
	elseif (self.miab.buildingStage == REMOVESCAFFOLD) then -- remove scaffolding
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PREPLACEOBJECTS) then
		self.miab.cor = coroutine.create(printObjects)
		self.miab.buildingStage = PLACEOBJECTS
	elseif (self.miab.buildingStage == PLACEOBJECTS) then -- place objects
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PREPLACELIQUIDS) then
		self.miab.cor = coroutine.create(printLiquids)
		self.miab.buildingStage = PLACELIQUIDS
	elseif (self.miab.buildingStage == PLACELIQUIDS) then -- place liquids
		if (coroutine.status(self.miab.cor) == "suspended") then
			assert(coroutine.resume(self.miab.cor))
		end
	elseif (self.miab.buildingStage == PRINTOBSTRUCTED) then -- area was obstructed
		FloatObstructed()
	elseif (self.miab.buildingStage == PRINTUNANCHORED) then -- area was in a void, no blocks could be placed
		FloatUnanchored()
	elseif (self.miab.buildingStage == PRINTPROTECTED) then -- part or all of the area has tile protection in place
		FloatProtected()
	elseif (self.miab.buildingStage == PRINTSUCCESS) then
		return true
	end

	return false
end

function readBlueprint()
	blueprint.fromEntityConfig()
	self.miab.buildingStage = PREVIEWBUILDAREA
end

function printPreview(pos)
	if self.miab.printPreviewDirection == nil then
		self.miab.printPreviewDirection = -1
	end
	local timeToLive = 3
	local start
	if self.miab.printPreviewDirection == -1 then
		start = blueprint.boundingBoxSize[2]
	else
		start = 0
	end
	local x
	local ourSpeed = blueprint.boundingBoxSize[2] / timeToLive
	if self.miab.printPreviewDirection == -1 then
		world.spawnProjectile("miab_buildingcode_r", {pos[1] + 0.5, start + pos[2] + 0.5}, entity.id(), {0, self.miab.printPreviewDirection}, true, {speed = ourSpeed})
		world.spawnProjectile("miab_buildingcode_l", {blueprint.boundingBoxSize[1] + pos[1] + 0.5, start + pos[2] + 0.5}, entity.id(), {0, self.miab.printPreviewDirection}, true, {speed = ourSpeed})
	else
		world.spawnProjectile("miab_buildingcode_l", {pos[1] + 0.5, start + pos[2] + 0.5}, entity.id(), {0, self.miab.printPreviewDirection}, true, {speed = ourSpeed})
		world.spawnProjectile("miab_buildingcode_r", {blueprint.boundingBoxSize[1] + pos[1] + 0.5, start + pos[2] + 0.5}, entity.id(), {0, self.miab.printPreviewDirection}, true, {speed = ourSpeed})
	end
	for x = 1, blueprint.boundingBoxSize[1] - 1, 1 do
		world.spawnProjectile("miab_buildingcode", {x + pos[1] + 0.5, start + pos[2] + 0.5}, entity.id(), {0, self.miab.printPreviewDirection}, true, {speed = ourSpeed})
	end
	self.miab.printPreviewDirection = 0 - self.miab.printPreviewDirection
	return timeToLive
end

function clearArea()
	self.miab.obstructionTable = {}
	self.miab.anythingPrinted = false
	
    local bl = { self.miab.pos[1], self.miab.pos[2]}
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
				if(world.entityName(entID) ~= "teleporter" and world.entityName(entID) ~= "avianteleporter" and world.entityName(entID) ~= "floranteleporter" and world.entityName(entID) ~= "glitchteleporter" and world.entityName(entID) ~= "humanteleporter" and world.entityName(entID) ~= "hylotlteleporter" and world.entityName(entID) ~= "novakidteleporter" and world.entityName(entID) ~= "apexshiptether" and world.entityName(entID) ~= "avianshiptether" and world.entityName(entID) ~= "floranshiptether" and world.entityName(entID) ~= "glitchshiptether" and world.entityName(entID) ~= "humanshiptether" and world.entityName(entID) ~= "hylotlshiptether" and world.entityName(entID) ~= "novakidshiptether" and world.entityName(entID) ~= "fu_byosteleporter") then -- Blacklist.
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

function clearModdedBlocks()
    local bl = { self.miab.pos[1], self.miab.pos[2]}
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

function printBlocks()
	local done = true
	local anythingPrinted = false
	local matName = nil
	local wpos = {}
	
	-- background blocks
	local iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableBackground) do
		for _x, _id in pairs(_tbl) do
			if (_id > 0) then
				matName = blueprint.materialFromId(_id)
			else
				matName = blueprint.materialFromId(0 - _id)
			end
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (matName ~= nil) then
				if (matName ~= "miab_scaffold") then
					if (world.material(wpos, "background") ~= matName) then
						-- world block is not equal blueprint block
						-- try to place
						if (world.placeMaterial(wpos, "background", matName)) then
							anythingPrinted = true
						else
							-- couldn`t place
							if (_id > 0) then
								done = false
							end
						end
					end
				else
					-- place scaffold
					if (world.material(wpos, "background") ~= self.miab.ScaffoldmatName) then
						if (world.placeMaterial(wpos, "background", self.miab.ScaffoldmatName)) then
							anythingPrinted = true
						else
							-- couldn`t place
							if (_id > 0) then
								done = false
							end
						end
					end
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- foreground blocks
	iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableForeground) do
		for _x, _id in pairs(_tbl) do
			if (_id > 0) then
				matName = blueprint.materialFromId(_id)
			else
				matName = blueprint.materialFromId(0 - _id)
			end
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (matName) ~= nil then
				if (matName ~= "miab_scaffold") then
					if (world.material(wpos, "foreground") ~= matName) then
						-- world block is not equal blueprint block
						-- try to place
						if (world.placeMaterial(wpos, "foreground", matName)) then
							anythingPrinted = true
						else
							-- couldn`t place
							if (_id > 0) then
								done = false
							end
						end
					end
				else
					-- place scaffold
					if (world.material(wpos, "foreground") ~= self.miab.ScaffoldmatName) then
						if (world.placeMaterial(wpos, "foreground", self.miab.ScaffoldmatName)) then
							anythingPrinted = true
						else
							-- couldn`t place
							if (_id > 0) then
								done = false
							end
						end
					end
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- what to do next?
	if (done) then
		self.miab.buildingStage = PREPLACETILEMODS
	elseif (not anythingPrinted) then
		self.miab.buildingStage = PRINTUNANCHORED
	end
end

function printTileMods()
	local done = true
	local anythingPrinted = false
	local modName = nil
	local wpos = {}
	
	-- background mods
	local iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableBackgroundMods) do
		for _x, _id in pairs(_tbl) do
			modName = blueprint.materialFromId(_id)
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (modName ~= nil) then
				if (world.mod(wpos, "background") ~= modName) then
					-- world mod is not equal blueprint mod
					-- try to place
					if (world.placeMod(wpos, "background", modName)) then
						anythingPrinted = true
					else
						-- couldn`t place
						done = false
					end
				end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
			end
		end
	end

	-- foreground mods
	iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableForegroundMods) do
		for _x, _id in pairs(_tbl) do
			modName = blueprint.materialFromId(_id)
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (modName ~= nil) then
				if (world.mod(wpos, "foreground") ~= modName) then
					-- world mod is not equal blueprint mod
					-- try to place
					if (world.placeMod(wpos, "foreground", modName)) then
						anythingPrinted = true
					else
						-- couldn`t place
						done = false
					end
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- what to do next?
	if (done) then
		self.miab.buildingStage = PREPAINTCOLOURS
	elseif (not anythingPrinted) then
		sb.logWarn("Modules in a Box: Possibly failed to print all tilemods")
		self.miab.buildingStage = PREPAINTCOLOURS
	end
end

function paintTileColours()
	local wpos = {}
	
	-- background colours
	local iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableBackgroundColours) do
		for _x, _colour in pairs(_tbl) do
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (_colour) then
				world.setMaterialColor(wpos, "background", _colour)
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- foreground colours
	iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableForegroundColours) do
		for _x, _colour in pairs(_tbl) do
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (_colour)then
				world.setMaterialColor(wpos, "foreground", _colour)
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- what to do next?
	self.miab.buildingStage = PREREMOVESCAFFOLD
end

function clearScaffolding()
	local matName = nil
	local wpos = {}
	
	-- background blocks
	local iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableBackground) do
		for _x, _id in pairs(_tbl) do
			if (_id > 0) then
				matName = blueprint.materialFromId(_id)
			else
				matName = blueprint.materialFromId(0 - _id)
			end
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (matName == "miab_scaffold") then
				if world.material(wpos, "background") == self.miab.ScaffoldmatName then
					blueprint.clearBlock(wpos, "background")
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- foreground blocks
	iterations = 0
	for _y, _tbl in pairs(blueprint.layoutTableForeground) do
		for _x, _id in pairs(_tbl) do
			if (_id > 0) then
				matName = blueprint.materialFromId(_id)
			else
				matName = blueprint.materialFromId(0 - _id)
			end
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			if (matName == "miab_scaffold") then
				if world.material(wpos, "foreground") == self.miab.ScaffoldmatName then
					blueprint.clearBlock(wpos, "foreground")
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	self.miab.buildingStage = PREPLACEOBJECTS
end

function printObjects()
	local done = true
	local anythingPrinted = false
	local matName = nil
	local wpos = {}
	
	local iterations = 0
	for _y, _tbl in pairs(blueprint.objectTable) do
		for _x, objectParameterTable in pairs(_tbl) do
			wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
			matName = objectParameterTable.name
			if (matName ~= nil) then
				-- place
				if (world.placeObject(matName, wpos, objectParameterTable.facing, objectParameterTable.jsonParameters)) then
					local _objects = world.objectQuery(wpos, 0)
					local _objID
					for _, _objID in pairs(_objects) do
						if (world.entityName(_objID) == matName) and (world.entityPosition(_objID)[1] == wpos[1]) and (world.entityPosition(_objID)[2] == wpos[2]) then
							if (objectParameterTable.contents) then
								for _, _v in pairs(objectParameterTable.contents) do
									world.containerAddItems(_objID, _v)
								end
							end
							if (objectParameterTable.nodes) then
								-- wiring would go here but is currently impossible
							end
						end
					end
					anythingPrinted = true
				else
					done = false
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	if (done) then
		self.miab.buildingStage = PREPLACELIQUIDS
	elseif (not anythingPrinted) then
		sb.logWarn("Modules in a Box: Possibly failed to print all objects")
		self.miab.buildingStage = PREPLACELIQUIDS
	end
end

function printLiquids()
	local wpos = {}

	local iterations = 0
	for _y, _tbl in pairs(blueprint.liquidTable) do
		for _x, _liquid in pairs(_tbl) do
			if (_liquid) then
				wpos = { self.miab.pos[1] + _x, self.miab.pos[2] + _y }
				if (_liquid[1] and _liquid[2]) then
					world.spawnLiquid(wpos, _liquid[1], _liquid[2])
				else
					world.spawnLiquid(wpos, _liquid["1"], _liquid["2"])
				end
			end
			iterations = iterations + 1
			if (iterations % YIELDPOINT == 0) then coroutine.yield() end
		end
	end

	-- what to do next?
	self.miab.buildingStage = PRINTSUCCESS
end

function FloatObstructed()
	local dist
	if (self.miab.obstructionTable) then
		animator.playSound("error")
		if (os.time() > self.miab.particleDelay) then
			for _id, _val in pairs(self.miab.obstructionTable) do
				dist = world.distance(world.entityPosition(_id), self.miab.pos)
				world.spawnProjectile("miab_obstruction", {world.entityPosition(_id)[1], world.entityPosition(_id)[2]}, entity.id(), {0, 0}, true)
			end
			animator.burstParticleEmitter("obstructed")
			self.miab.particleDelay = os.time() + 3
		end
	end
	self.miab.obstructionTable = nil
	self.miab.buildingStage = PREVIEWBUILDAREA
end

function FloatUnanchored()
	animator.playSound("error")
	if (os.time() > self.miab.particleDelay) then
		animator.burstParticleEmitter("unanchored")
		self.miab.particleDelay = os.time() + 3
	end
	self.miab.buildingStage = PREVIEWBUILDAREA
end

function FloatProtected()
	animator.playSound("error")
	if (os.time() > self.miab.particleDelay) then
		animator.burstParticleEmitter("protected")
		self.miab.particleDelay = os.time() + 3
	end
	self.miab.buildingStage = PREVIEWBUILDAREA
end

-- UTILITY FUNCTIONS
function breakBlock(pos, layer)
	world.damageTiles({pos}, layer, pos, "blockish", 10000, 0)
end

function entityInOurBox(entId, bl, tr)
	local box = { bl[1], bl[2], tr[1], tr[2] }
	local pos = world.entityPosition(entId)
	local box2 = { pos[1], pos[2], pos[1], pos[2] }
	local entType = world.entityType(entId) -- "player", "monster", "object", "itemdrop", "projectile", "plant", "plantdrop", "effect", "npc"

	if (self.miab.areaToIgnore and blueprint.isInsideBoundingBox(pos, self.miab.areaToIgnore)) then return false end
	
	if (entType == "object") then
		box2 = world.callScriptedEntity(entId, "object.boundBox")
		box2 = {box2[1] + 1, box2[2] + 1, box2[3] - 1, box2[4] - 1}
	end

	if (box2[3] <= box[1]) then
		return false
	elseif (box2[1] > box[3]) then
		return false
	elseif (box2[4] <= box[2]) then
		return false
	elseif (box2[2] > box[4]) then
		return false
	end

	return true
end

function cleanUpLooseEnds()
	if (self.miab == nil) then return end -- failed during read stage
	
	if (self.miab.looseEnds) then
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