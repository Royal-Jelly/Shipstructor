function init(args)
	object.setInteractive(true)
end

function onInteraction(args)
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

function update(dt)
	if (self.miab == nil) then return end -- not initialized
	
	if (self.miab.readingStage) then -- only accessed during read
		-- this needs to be polled until done
		readModule()
		
		-- if reader compleeted in the current update(dt)
		if (self.miab == nil) then
			if (config.getParameter("miabScannerOptions.JustScan", nil)) then
				-- cancel without printing. This is the items users will use to dump theire designs in the correct format
				object.smash()
			end
		
			-- Configure writing process
			local writerOptions = {}
			local area_to_scan_bounding_box = config.getParameter("miabScannerOptions.areaToScan", nil)
			writerOptions.areaToIgnore = config.getParameter("miabScannerOptions.areaToIgnore", nil)
			writerOptions.writerPosition = ({area_to_scan_bounding_box[1],area_to_scan_bounding_box[2]})
			writerOptions.spawnUnplacablesPosition = object.toAbsolutePosition({ 0, 4 })
			
			printInit(writerOptions)
			donePrinting = false -- flag to end polling
		end
	end

	if (self.miab.buildingStage) then -- only accessed during write
		printStart()
		if (not donePrinting) then
			-- needs to be polled
			--donePrinting = printModule_modified_copy_from_miab_basestore_printer()
			donePrinting = printModule()
			
		else
			object.smash()
		end
	end
end

function setScannerStatus(status, sound, colour)
end
