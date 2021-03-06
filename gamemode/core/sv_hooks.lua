util.AddNetworkString("nut_ShowMenu")
util.AddNetworkString("nut_CurTime")

function GM:ShowHelp(client)
	if (!client.character) then
		return
	end
	
	net.Start("nut_ShowMenu")
	net.Send(client)
end

function GM:GetDefaultInv(inventory, client, data)
end

function GM:GetDefaultMoney(client, data)
	return nut.config.startingAmount
end

function GM:PlayerInitialSpawn(client)
	if (IsValid(client)) then
		client:KillSilent()
	end
	
	timer.Simple(5, function()
		if (!IsValid(client)) then
			return
		end

		net.Start("nut_CurTime")
			net.WriteUInt(nut.util.GetTime(), 32)
		net.Send(client)

		client:KillSilent()
		client:StripWeapons()
		client:InitializeData()

		local fraction = client:Ping() / 100

		for k, v in ipairs(nut.char.GetAll()) do
			timer.Simple(k * fraction, function()
				if (IsValid(client)) then
					v:Send(nil, client, true)
				end
			end)
		end

		player_manager.SetPlayerClass(client, "player_nut")
		player_manager.RunClass(client, "Spawn")

		nut.char.Load(client, function()
			net.Start("nut_CharMenu")
				net.WriteBit(false)
			net.Send(client)

			local uniqueID = "nut_SaveChar"..client:SteamID()

			timer.Create(uniqueID, nut.config.saveInterval, 0, function()
				if (!IsValid(client)) then
					timer.Remove(uniqueID)

					return
				end

				nut.char.Save(client)
			end)
		end)
	end)
end

function GM:PlayerLoadedChar(client)
	local faction = client.character:GetVar("faction", 9001)
	client:SetTeam(faction)
	client:SetSkin(client.character:GetData("skin", 0))

	if (!client:GetNutVar("sawCredits")) then
		client:SetNutVar("sawCredits", true)

		nut.util.SendIntroFade(client)

		timer.Simple(15, function()
			if (!IsValid(client)) then
				return
			end
			
			nut.scroll.Send("NutScript: "..nut.lang.Get("schema_author", "Chessnut"), client, function()
				if (IsValid(client)) then
					nut.scroll.Send(SCHEMA.name..": "..nut.lang.Get("schema_author", SCHEMA.author), client)
				end
			end)
		end)
	end
end

function GM:PlayerSpawn(client)
	client:SetMainBar()

	if (!client.character) then
		return
	end

	client:StripWeapons()
	client:SetModel(client.character.model)

	client:Give("nut_fists")

	player_manager.SetPlayerClass(client, "player_nut")
	player_manager.RunClass(client, "Spawn")

	client:SetWalkSpeed(nut.config.walkSpeed)
	client:SetRunSpeed(nut.config.runSpeed)
	client:SetWepRaised(false)

	nut.flag.OnSpawn(client)
	nut.attribs.OnSpawn(client)
end

function GM:PlayerDisconnected(client)
	nut.char.Save(client)

	timer.Remove("nut_SaveChar"..client:SteamID())
end

function GM:PlayerShouldTakeDamage()
	return true
end

function GM:CanArmDupe()
	print("Duping?")

	return false
end

function GM:GetGameDescription()
	return "NutScript - "..(SCHEMA and SCHEMA.name or "Unknown")
end

function GM:GetFallDamage(client, speed)
	speed = speed - 580

	return speed * nut.config.fallDamageScale
end

function GM:ShutDown()
	for k, v in pairs(player.GetAll()) do
		nut.char.Save(v)
	end

	self:SaveTime()
	nut.schema.Call("SaveData")
end

function GM:PlayerSay(client, text, public)
	local result = nut.chat.Process(client, text)

	if (result) then
		return result
	end
	
	return text
end

function GM:CanPlayerSuicide(client)
	return nut.config.canSuicide
end

function GM:PlayerGiveSWEP(client, class, weapon)
	return client:IsAdmin()
end

function GM:PlayerSpawnSWEP(client, class, weapon)
	return client:IsAdmin()
end

function GM:PlayerSpawnEffect(client, model)
	return client:HasFlag("e")
end

function GM:PlayerSpawnNPC(client, npc, weapon)
	return client:HasFlag("n")
end

function GM:PlayerSpawnObject(client)
	return client:HasFlag("e") or client:HasFlag("r")
end

function GM:PlayerSpawnProp(client, model)
	return client:HasFlag("e")
end

function GM:PlayerSpawnRagdoll(client, model, entity)
	return client:HasFlag("r")
end

function GM:PlayerSpawnSENT(client)
	return client:IsAdmin()
end

function GM:PlayerSpawnVehicle(client, model, name, vehicle)
	return client:HasFlag("c")
end

function GM:PlayerSwitchFlashlight(client, state)
	return nut.config.flashlight
end

function GM:InitPostEntity()
	nut.schema.Call("LoadData")
end

function GM:PlayerDeath(victim, weapon, attacker)
	local time = CurTime() + nut.config.deathTime
	time = nut.schema.Call("PlayerGetDeathTime", client, time) or time

	victim:SetNutVar("deathTime", time)

	timer.Simple(0, function()
		victim:SetMainBar("You are now respawning.", nut.config.deathTime)
	end)
end

function GM:PlayerDeathThink(client)
	if (client.character and client:GetNutVar("deathTime", 0) < CurTime()) then
		client:Spawn()

		return true
	end
	
	return false
end

function GM:PlayerCanHearPlayersVoice(speaker, listener)
	return nut.config.allowVoice, nut.config.voice3D
end

function GM:PlayerGetFistDamage(client, damage)
	return damage + client:GetAttrib(ATTRIB_STR, 0)
end

function GM:PlayerThrowPunch(client, attempted)
	local value = 0.001

	if (attempted) then
		value = 0.005
	end

	client:UpdateAttrib(ATTRIB_STR, value)
end

function GM:OnPlayerHitGround(client, inWater, onFloater, fallSpeed)
	if (!inWater and !onFloater) then
		client:UpdateAttrib(ATTRIB_ACR, 0.01)
	end
end

function GM:Initialize()
	local date = nut.util.ReadTable("date", true)
	local time = os.time({
		month = nut.config.dateStartMonth,
		day = nut.config.dateStartDay,
		year = nut.config.dateStartYear
	})

	if (#date < 1) then
		time = time * (nut.config.dateMinuteLength / 60)

		nut.util.WriteTable("date", time, true)
		nut.curTime = time
	else
		nut.curTime = date[1] or time
	end
end

function GM:SaveTime()
	nut.util.WriteTable("date", tostring(nut.util.GetTime()), true)
end