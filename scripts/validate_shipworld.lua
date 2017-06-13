function is_shipworld()
	if (world.threatLevel() == 0) and (world.type() == "unknown") then
	--if (world.type() == "unknown") then
		sb.logInfo(world.type())
		return true;
	else
		sb.logInfo(world.type())
		return false;
	end
end

--[[
-- use position of teleporter of initial ship, which is locked down in place at 1025,1025
function is_shipworld()	
	local teleporter_position_in_our_shipworld = {1025,1025};
	local Teleporter_found = false;
	local TeleporterIds = world.entityQuery (teleporter_position_in_our_shipworld, 1);-- (position, radius)
	-- loop over one object, brilliant!
	for _, TeleporterId in pairs(TeleporterIds) do
		-- world.logInfo("Name of Entity.TeleporterID" .. world.entityName(TeleporterId));
		if  (world.entityName(TeleporterId) == "madtulip_apex_teleporter") or
			(world.entityName(TeleporterId) == "madtulip_avian_teleporter") or
			(world.entityName(TeleporterId) == "madtulip_floran_teleporter") or
			(world.entityName(TeleporterId) == "madtulip_glitch_teleporter") or
			(world.entityName(TeleporterId) == "madtulip_human_teleporter") or
			(world.entityName(TeleporterId) == "madtulip_hylotl_teleporter") or
			(world.entityName(TeleporterId) == "madtulip_novakid_teleporter")
		then
			-- world.logInfo("Teleporter found!")
			Teleporter_found = true;
		end
	end
	if Teleporter_found then
		-- world.logInfo("is_shipworld = true")
		return true;
	end
	
	-- world.logInfo("is_shipworld = false")
	return false;
end
--]]	


--[[
-- players are by default only invincible on shipworld? so we can use that property.
function is_shipworld()
	if (world.getProperty("invinciblePlayers")) then
		-- shipworld
		return true
	else
		-- planet
		return false
	end
end
--]]
