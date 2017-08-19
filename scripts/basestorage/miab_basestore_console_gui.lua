miabScannerOptions = {}
printerIconIndex = -1
currentStatusText = ""

function init()
	miabScannerOptions = world.getObjectParameter(pane.sourceEntity(), "miabScannerOptions") or {}
	if (miabScannerOptions.clearArea == nil) then miabScannerOptions.clearArea = true end
	if (miabScannerOptions.dropContents == nil) then miabScannerOptions.dropContents = false end
	if (miabScannerOptions.givePrinter == nil) then miabScannerOptions.givePrinter = true end
	miabScannerOptions.printerCount = miabScannerOptions.printerCount or 1
	miabScannerOptions.printerName = miabScannerOptions.printerName or ""
	miabScannerOptions.printerDescription = miabScannerOptions.printerDescription or ""
	miabScannerOptions.printerIcon = miabScannerOptions.printerIcon or "/objects/basestorage/miab_basestore_printer/inventoryicons/_base.png"
	if (miabScannerOptions.saveBlueprint == nil) then miabScannerOptions.saveBlueprint = false end
	printerIconIndex = printerIndexFromIcon(miabScannerOptions.printerIcon)
	if (miabScannerOptions.lockdown == nil) then miabScannerOptions.lockdown = false end
	
	-- sanity checks
	if (miabScannerOptions.printerName == "Building Printer") then miabScannerOptions.printerName = "" end
	if (miabScannerOptions.printerDescription == "A device that will construct a building from its internal blueprint") then miabScannerOptions.printerDescription = "" end
	if (miabScannerOptions.printerCount < 1) then miabScannerOptions.printerCount = 1 end
	if (miabScannerOptions.printerCount > 1000) then miabScannerOptions.printerCount = 1000 end
	if (printerIconIndex < -1) then printerIconIndex = -1 end -- no, I have no idea why the icons are numbered
	if (printerIconIndex > 38) then printerIconIndex = 38 end -- from -1 to 38 instead of 1 to 40 either
	if (miabScannerOptions.lockdown) then
		miabScannerOptions.clearArea = true
		miabScannerOptions.dropContents = false
		miabScannerOptions.givePrinter = true
		miabScannerOptions.printerCount = 1
	end
	
	widget.setChecked("clearAreaCheckBox", miabScannerOptions.clearArea)
	widget.setChecked("dropContentsCheckBox", miabScannerOptions.dropContents)
	widget.setChecked("givePrinterCheckBox", miabScannerOptions.givePrinter)
	widget.setText("printerCountTextBox", miabScannerOptions.printerCount)
	widget.setText("printerNameTextBox", miabScannerOptions.printerName)
	widget.setText("printerDescriptionTextBox", miabScannerOptions.printerDescription)
	widget.setSelectedOption("printerIconRadioGroup", printerIconIndex)
	widget.setChecked("dumpJSONCheckBox", miabScannerOptions.saveBlueprint)
	
	checkRelationships()
	
	world.sendEntityMessage(pane.sourceEntity(), "setActiveAnimation")
end

function update(dt)
	checkRelationships()
end

function dismissed()
	saveOptions()
	world.sendEntityMessage(pane.sourceEntity(), "setInactiveAnimation")
end

function saveOptions()
	if (miabScannerOptions.printerName == "") then miabScannerOptions.printerName = "Building Printer" end
	if (miabScannerOptions.printerDescription == "") then miabScannerOptions.printerDescription = "A device that will construct a building from its internal blueprint" end
	world.sendEntityMessage(pane.sourceEntity(), "setScannerOptions", miabScannerOptions)
end

function checkRelationships()
	local statusText = world.getObjectParameter(pane.sourceEntity(), "scannerStatus") or ""
	if (statusText ~= currentStatusText) then
		local sound = world.getObjectParameter(pane.sourceEntity(), "scannerStatusSound") or nil
		if (sound) then
			pane.playSound(sound)
			world.sendEntityMessage(pane.sourceEntity(), "soundPlayed")
		end
		if (string.sub(statusText, 1, 5) == "^red;") then
			widget.setImage("statusImage", "/objects/basestorage/miab_basestore_console/interface/titlebar.png:red")
		else
			widget.setImage("statusImage", "/objects/basestorage/miab_basestore_console/interface/titlebar.png:green")
		end
		currentStatusText = statusText
		widget.setText("statusLabel", statusText)
	end
	local cornerCount = world.getObjectParameter(pane.sourceEntity(), "miabCornerCount") or 0
	if (cornerCount == 0) then
		widget.setButtonEnabled("clearAreaCheckBox", false)
		widget.setButtonEnabled("dropContentsCheckBox", false)
		widget.setButtonEnabled("givePrinterCheckBox", false)
		widget.setButtonEnabled("printerCountMinus", false)
		widget.setButtonEnabled("printerCountPlus", false)
		widget.setVisible("printerCountTextBox", false)
		widget.setVisible("printerNameTextBox", false)
		widget.setVisible("printerDescriptionTextBox", false)
		for i = -1, 38 do
			widget.setOptionEnabled("printerIconRadioGroup", i, false)
		end
		widget.setButtonEnabled("dumpJSONCheckBox", false)
		widget.setButtonEnabled("activateButton", false)
	else
		widget.setButtonEnabled("clearAreaCheckBox", true)
		widget.setButtonEnabled("dropContentsCheckBox", miabScannerOptions.clearArea)
		widget.setButtonEnabled("givePrinterCheckBox", true)
		widget.setButtonEnabled("printerCountMinus", miabScannerOptions.givePrinter)
		widget.setButtonEnabled("printerCountPlus", miabScannerOptions.givePrinter)
		widget.setVisible("printerCountTextBox", miabScannerOptions.givePrinter)
		widget.setVisible("printerNameTextBox", miabScannerOptions.givePrinter or miabScannerOptions.saveBlueprint)
		widget.setVisible("printerDescriptionTextBox", miabScannerOptions.givePrinter or miabScannerOptions.saveBlueprint)
		for i = -1, 38 do
			widget.setOptionEnabled("printerIconRadioGroup", i, miabScannerOptions.givePrinter or miabScannerOptions.saveBlueprint)
		end
		widget.setButtonEnabled("dumpJSONCheckBox", true)
		widget.setButtonEnabled("activateButton", true)
	end
	if (miabScannerOptions.lockdown) then
		widget.setButtonEnabled("clearAreaCheckBox", false)
		widget.setButtonEnabled("dropContentsCheckBox", false)
		widget.setButtonEnabled("givePrinterCheckBox", false)
		widget.setButtonEnabled("printerCountMinus", false)
		widget.setButtonEnabled("printerCountPlus", false)
		widget.setVisible("printerCountTextBox", false)
	end
	if 	(miabScannerOptions.clearArea == false) and
		(miabScannerOptions.givePrinter == false) and
		(miabScannerOptions.saveBlueprint == false) then
		widget.setButtonEnabled("activateButton", false)
	end
end

function printerCountSanityCheck()
	if (miabScannerOptions.printerCount) then
		if (miabScannerOptions.printerCount < 1) then miabScannerOptions.printerCount = 1 end
		if (miabScannerOptions.printerCount > 1000) then miabScannerOptions.printerCount = 1000 end
		widget.setText("printerCountTextBox", miabScannerOptions.printerCount)
	end
end

function printerIndexFromIcon(iconPath)
	for i = -1, 38 do
		if (iconPathList[i] == iconPath) then return i end
	end
	return -1
end

function printerIconFromIndex(index)
	return iconPathList[index] or iconPathList[-1]
end

---------------------------------------------------------
-- printer icon/index table
---------------------------------------------------------
iconPathList = {}
iconPathList[-1] = "/objects/basestorage/miab_basestore_printer/inventoryicons/_base.png"
iconPathList[0] = "/objects/basestorage/miab_basestore_printer/inventoryicons/A.png"
iconPathList[1] = "/objects/basestorage/miab_basestore_printer/inventoryicons/B.png"
iconPathList[2] = "/objects/basestorage/miab_basestore_printer/inventoryicons/C.png"
iconPathList[3] = "/objects/basestorage/miab_basestore_printer/inventoryicons/D.png"
iconPathList[4] = "/objects/basestorage/miab_basestore_printer/inventoryicons/E.png"
iconPathList[5] = "/objects/basestorage/miab_basestore_printer/inventoryicons/F.png"
iconPathList[6] = "/objects/basestorage/miab_basestore_printer/inventoryicons/G.png"
iconPathList[7] = "/objects/basestorage/miab_basestore_printer/inventoryicons/H.png"
iconPathList[8] = "/objects/basestorage/miab_basestore_printer/inventoryicons/I.png"
iconPathList[9] = "/objects/basestorage/miab_basestore_printer/inventoryicons/J.png"
iconPathList[10] = "/objects/basestorage/miab_basestore_printer/inventoryicons/K.png"
iconPathList[11] = "/objects/basestorage/miab_basestore_printer/inventoryicons/L.png"
iconPathList[12] = "/objects/basestorage/miab_basestore_printer/inventoryicons/M.png"
iconPathList[13] = "/objects/basestorage/miab_basestore_printer/inventoryicons/N.png"
iconPathList[14] = "/objects/basestorage/miab_basestore_printer/inventoryicons/O.png"
iconPathList[15] = "/objects/basestorage/miab_basestore_printer/inventoryicons/P.png"
iconPathList[16] = "/objects/basestorage/miab_basestore_printer/inventoryicons/Q.png"
iconPathList[17] = "/objects/basestorage/miab_basestore_printer/inventoryicons/R.png"
iconPathList[18] = "/objects/basestorage/miab_basestore_printer/inventoryicons/S.png"
iconPathList[19] = "/objects/basestorage/miab_basestore_printer/inventoryicons/T.png"
iconPathList[20] = "/objects/basestorage/miab_basestore_printer/inventoryicons/U.png"
iconPathList[21] = "/objects/basestorage/miab_basestore_printer/inventoryicons/V.png"
iconPathList[22] = "/objects/basestorage/miab_basestore_printer/inventoryicons/W.png"
iconPathList[23] = "/objects/basestorage/miab_basestore_printer/inventoryicons/X.png"
iconPathList[24] = "/objects/basestorage/miab_basestore_printer/inventoryicons/Y.png"
iconPathList[25] = "/objects/basestorage/miab_basestore_printer/inventoryicons/Z.png"
iconPathList[26] = "/objects/basestorage/miab_basestore_printer/inventoryicons/_at.png"
iconPathList[27] = "/objects/basestorage/miab_basestore_printer/inventoryicons/_hash.png"
iconPathList[28] = "/objects/basestorage/miab_basestore_printer/inventoryicons/_slash.png"
iconPathList[29] = "/objects/basestorage/miab_basestore_printer/inventoryicons/0.png"
iconPathList[30] = "/objects/basestorage/miab_basestore_printer/inventoryicons/1.png"
iconPathList[31] = "/objects/basestorage/miab_basestore_printer/inventoryicons/2.png"
iconPathList[32] = "/objects/basestorage/miab_basestore_printer/inventoryicons/3.png"
iconPathList[33] = "/objects/basestorage/miab_basestore_printer/inventoryicons/4.png"
iconPathList[34] = "/objects/basestorage/miab_basestore_printer/inventoryicons/5.png"
iconPathList[35] = "/objects/basestorage/miab_basestore_printer/inventoryicons/6.png"
iconPathList[36] = "/objects/basestorage/miab_basestore_printer/inventoryicons/7.png"
iconPathList[37] = "/objects/basestorage/miab_basestore_printer/inventoryicons/8.png"
iconPathList[38] = "/objects/basestorage/miab_basestore_printer/inventoryicons/9.png"

---------------------------------------------------------
-- widget callbacks
---------------------------------------------------------
function quitButton()
	pane.dismiss()
end

function clearAreaCheckBox()
	miabScannerOptions.clearArea = widget.getChecked("clearAreaCheckBox")
	checkRelationships()
end

function dropContentsCheckBox()
	miabScannerOptions.dropContents = widget.getChecked("dropContentsCheckBox")
end

function givePrinterCheckBox()
	miabScannerOptions.givePrinter = widget.getChecked("givePrinterCheckBox")
	checkRelationships()
end

function printerCountTextBox()
	miabScannerOptions.printerCount = tonumber(widget.getText("printerCountTextBox"))
	printerCountSanityCheck()
end

function printerCountMinus()
	if (miabScannerOptions.printerCount) then miabScannerOptions.printerCount = miabScannerOptions.printerCount - 1 end
	printerCountSanityCheck()
end

function printerCountPlus()
	if (miabScannerOptions.printerCount) then miabScannerOptions.printerCount = miabScannerOptions.printerCount + 1 end
	printerCountSanityCheck()
end

function printerNameTextBox()
	miabScannerOptions.printerName = widget.getText("printerNameTextBox")
end

function printerDescriptionTextBox()
	miabScannerOptions.printerDescription = widget.getText("printerDescriptionTextBox")
end

function printerIconRadioGroup()
	printerIconIndex = widget.getSelectedOption("printerIconRadioGroup")
	miabScannerOptions.printerIcon = printerIconFromIndex(printerIconIndex)
end

function dumpJSONCheckBox()
	miabScannerOptions.saveBlueprint = widget.getChecked("dumpJSONCheckBox")
	checkRelationships()
end

function activateButton()
	saveOptions()
	world.sendEntityMessage(pane.sourceEntity(), "activate")
end