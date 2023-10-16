ESX = nil
local truck, trailer, currentJobPay, totalJobPay = nil, nil, nil, 0
local lastDropOffSpot, currentDropOffSpot = nil, nil
local lastPickupSpot, currentPickupSpot = nil, nil
local hasSpawnedTrailer = false
local missionblip = nil
local cancelMission = false
local playerLoaded = false
local doingARun = false
local deliveriesBeforeReturning, deliveryCount = 0, 0
local ownTruck = false
local truckType = nil
local missionStartTime = 0
local truckSpawnSpots = {
	vector4(-340.98, -2724.54, 5.0, 76.92),
	vector4(-342.01, -2730.19, 5.04, 85.18),
	vector4(-332.6, -2731.29, 5.03, 45.1),
	vector4(-323.92, -2740.04, 5.01, 46.12),
	vector4(-352.51, -2756.82, 5.04, 48.56),
}
local truckGroup = nil
local doingGroupJob = false
local something = 69691337

local Keys = {
    ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
    ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

--Script startup
------------------------------------------------------------------
Citizen.CreateThread(function()
	if Config.UseESX then
		while not ESX do
			TriggerEvent("esx:getSharedObject", function(library) 
				ESX = library 
			end)

			Citizen.Wait(0)
		end
		while ESX.GetPlayerData().job == nil do
			Citizen.Wait(10)
		end
		if not playerLoaded then
			playerLoaded = true
			CreateBlip()
		end
	else
		--This may need to be reworked to fit your framework or create your own event handler for when a player fully loads that way the blip is actually created properly
		CreateBlip()
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	if not playerLoaded then
		playerLoaded = true
		CreateBlip()
	end
end)
------------------------------------------------------------------

--Command
------------------------------------------------------------------
--[[RegisterCommand('testmarker', function(source, args, rawCommand)
	while true do
		DrawMarker(1, 1194.32, -3105.85, 6.03, 0.0, 0.0, 0.0, 90.0, 309.99 + 180.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
		Citizen.Wait(0)
	end
end)--]]
------------------------------------------------------------------
--Events
------------------------------------------------------------------

RegisterNetEvent("des-trucking-cl:finishTruckSpawn")
AddEventHandler("des-trucking-cl:finishTruckSpawn", function(netId, model, location)
    print("Waiting for net id to exist", netId)
    local startTime = GetGameTimer()
	while not NetworkDoesNetworkIdExist(netId) do
        if GetGameTimer() - startTime >= 1250 then
            TriggerServerEvent("des-garage-sv:spawnVehicle", model, location, true, "des-trucking-cl:finishTruckSpawn")
            return
        end
		Citizen.Wait(100)
	end
	print("Waiting for entity with net id to exist")
    startTime = GetGameTimer()
	while not NetworkDoesEntityExistWithNetworkId(netId) do
        if GetGameTimer() - startTime >= 1250 then
            TriggerServerEvent("des-garage-sv:spawnVehicle", model, location, true, "des-trucking-cl:finishTruckSpawn")
            return
        end
		Citizen.Wait(100)
	end
	local vehicle = NetworkGetEntityFromNetworkId(netId)
    local model = GetEntityModel(vehicle)
    while Entity(vehicle).state.VIN == nil do
        Citizen.Wait(100)
    end
	local startTime = GetGameTimer()
	local count = 0
	while not NetworkHasControlOfEntity(vehicle) and not NetworkHasControlOfNetworkId(netId) and (GetGameTimer() - startTime) <= 5000 do
		NetworkRequestControlOfEntity(vehicle)
		NetworkRequestControlOfNetworkId(netId)
		Citizen.Wait(100)
		if count > 20 then
			count = 0
			print("Still trying to take control of", netId, vehicle)
		else
			count = count + 1
		end
	end
    local plate = GetVehicleNumberPlateText(vehicle)
    exports["des-oGasStations"]:SetFuel(vehicle, 100)
    --print("towtruck with " .. plate .. "  spawned ")
    local vin = Entity(vehicle).state.VIN
    truck = vehicle
    TriggerServerEvent('garage:addKeys', vin)
    TriggerEvent('DoLongHudText', 'You received keys to the vehicle.', 1)
end)

AddEventHandler('des-trucking-cl:startSoloJobUnowned', function()
	if (GetNetworkTime() - missionStartTime) >= 150000 or GetNetworkTime() <= 300000 then
		trailer, currentJobPay, totalJobPay = nil, nil, 0
		lastDropOffSpot, currentDropOffSpot = nil, nil
		lastPickupSpot, currentPickupSpot = nil, nil
		hasSpawnedTrailer = false
		missionblip = nil
		cancelMission = false
		playerLoaded = false
		doingARun = false
		deliveriesBeforeReturning, deliveryCount = 0, 0
		ownTruck = false
		truckType = nil
		truckGroup = nil
		doingGroupJob = false
		local truckSpawnPos = truckSpawnSpots[1]
		while not ESX.Game.IsSpawnPointClear(truckSpawnPos, 4.5) do
			truckSpawnPos = truckSpawnSpots[math.random(1, #truckSpawnSpots)]
			Citizen.Wait(5)
		end
		local truckSpawnHeading = truckSpawnSpots.w
		--ClearAreaOfVehicles(truckSpawnPos, 4.5, false, false, false, false, false)
		Citizen.Wait(500)
		if truck == nil or not DoesEntityExist(truck) then
			local playerVehicle = GetVehiclePedIsIn(GetPlayerPed(-1), true)
			local model = GetEntityModel(playerVehicle)
			local playerVehicleModel = 'None'
			if playerVehicle ~= nil then
				playerVehicleModel = string.lower(GetDisplayNameFromVehicleModel(model))
			end
			if (playerVehicleModel ~= 'phantom' or (playerVehicleModel == 'phantom' and GetEntityHealth(playerVehicle) <= 0.0)) and (playerVehicleModel ~= 'w900' or (playerVehicleModel == 'w900' and GetEntityHealth(playerVehicle) <= 0.0)) and (playerVehicleModel ~= 'phantom3' or (playerVehicleModel == 'phantom3' and GetEntityHealth(playerVehicle) <= 0.0)) and (playerVehicleModel ~= 'hauler' or (playerVehicleModel == 'hauler' and GetEntityHealth(playerVehicle) <= 0.0)) then
				RequestModel(GetHashKey('phantom'))
				while not HasModelLoaded(GetHashKey('phantom')) do
					Citizen.Wait(0)
				end
				TriggerServerEvent("des-garage-sv:spawnVehicle", GetHashKey('phantom'), truckSpawnPos, true, "des-trucking-cl:finishTruckSpawn")
				--[[truck = CreateVehicle(GetHashKey('phantom'),truckSpawnPos, truckSpawnHeading,true,true)
				NetworkRegisterEntityAsNetworked(truck)
				local timer = GetGameTimer()
				while not NetworkGetEntityIsNetworked(truck) and (GetGameTimer() - timer) <= 2500 do
					NetworkRegisterEntityAsNetworked(truck)
					Citizen.Wait(100)
				end
				local plate = GetVehicleNumberPlateText(truck)
				local vin = nil
				if vin == nil then
					TriggerServerEvent("des-vehRegistration-sv:genVehVIN", NetworkGetNetworkIdFromEntity(truck), false)
					while vin == nil do
						vin = Entity(truck).state.VIN
						Citizen.Wait(10)
					end
				end
				TriggerServerEvent('garage:addKeys', vin)
				--Start new delivery--]]
				while truck == nil do
					Citizen.Wait(100)
				end
				doingARun = true
				Citizen.CreateThread(function()
					healthMonitor()
				end)
				deliveriesBeforeReturning = math.random(3, 6)
				--TriggerEvent("DoLongHudText","Looks like you didn't bring your own truck. Here use one of mine.",1, 15000)
				SendNotification("Looks like you didn't bring your own truck. Here use one of mine.")
				missionStartTime = GetNetworkTime()
				SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(truck), false)
				ownTruck = false
				newDelivery()
			else
				truck = playerVehicle
				doingARun = true
				Citizen.CreateThread(function()
					healthMonitor()
				end)
				ownTruck = true
				deliveriesBeforeReturning = math.random(3, 6)
				--TriggerEvent("DoLongHudText","I see you got money and brought your own truck. Cool.",1, 15000)
				SendNotification("I see you got money and brought your own truck. Cool.")
				missionStartTime = GetNetworkTime()
				SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(truck), false)
				newDelivery()
			end
		else
			doingARun = true
			Citizen.CreateThread(function()
				healthMonitor()
			end)
			deliveriesBeforeReturning = math.random(3, 6)
			newDelivery()
		end
	else
		--TriggerEvent("DoLongHudText","You must wait 5 minutes before you can start another delivery mission",2, 15000)
		SendNotification("You must wait 2.5 minutes before you can start another delivery mission")
	end
end)

AddEventHandler('des-trucking-cl:attemptToStartGroupJob', function()
	local group = exports["des-assets"]:getGroup()
	if group ~= nil then
		local members = group.members
		local player = GetPlayerPed(-1)
		--Make sure all the members are within 50 meters
		local memberTooFar = false
		for identifier, personData in pairs(members) do
			local currentMember = GetPlayerFromServerId(personData[2])
			if #(GetEntityCoords(player) - GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(personData[2])))) > 50.0 then
				memberTooFar = true
				break
			end
		end
		if not memberTooFar then
			if group.memberCount > 1 and group.memberCount < 5 then
				TriggerServerEvent("des-trucking-sv:startGroupJob", group)
			else

			end
		else
			--A member of the job group is too far to start the group job
		end
	else
		--Let the person know they can't start a group mission due to them not being in a group
	end
end)

RegisterNetEvent("des-trucking-cl:startGroupJob")
AddEventHandler("des-trucking-cl:startGroupJob", function(sentTruckGroup)
	truckGroup = sentTruckGroup
	doingGroupJob = true
	cancelMission = false
	local identifier = ESX.GetPlayerData().identifier
	print('Can spawn truck', truckGroup.personData[identifier].canSpawnTruck)
	print('Spawn pos', truckGroup.personData[identifier].trailerSpawn)
	print('Truck spawn pos', truckSpawnSpots[truckGroup.personData[identifier].trailerSpawn])
	while not truckGroup.personData[identifier].canSpawnTruck do
		print('Waiting to spawn truck')
		Citizen.Wait(10)
	end
	print('Spawning truck', truckSpawnSpots[truckGroup.personData[identifier].trailerSpawn])
	local truckSpawnPos = truckSpawnSpots[truckGroup.personData[identifier].trailerSpawn]
	while not ESX.Game.IsSpawnPointClear(truckSpawnPos, 4.5) do
		truckSpawnPos = truckSpawnSpots[math.random(1, #truckSpawnSpots)]
		Citizen.Wait(5)
	end
	local truckSpawnHeading = truckSpawnSpots.w
	Citizen.Wait(500)
	if truck == nil or not DoesEntityExist(truck) then
		local playerVehicle = GetVehiclePedIsIn(GetPlayerPed(-1), true)
		local model = GetEntityModel(playerVehicle)
		local playerVehicleModel = 'None'
		if playerVehicle ~= nil then
			playerVehicleModel = string.lower(GetDisplayNameFromVehicleModel(model))
		end
		RequestModel(GetHashKey('phantom'))
		while not HasModelLoaded(GetHashKey('phantom'))do
			Citizen.Wait(0)
		end
		if (playerVehicleModel ~= 'phantom' or (playerVehicleModel == 'phantom' and GetEntityHealth(playerVehicle) <= 0.0)) and (playerVehicleModel ~= 'phantom3' or (playerVehicleModel == 'phantom3' and GetEntityHealth(playerVehicle) <= 0.0)) then
			truck = CreateVehicle(GetHashKey('phantom'), truckSpawnPos, truckSpawnHeading, true, true)
			print("Check 1")
			NetworkRegisterEntityAsNetworked(truck)
			while not NetworkGetEntityIsNetworked(truck) do
				NetworkRegisterEntityAsNetworked(truck)
				Citizen.Wait(100)
			end
			print("Check 2")
			local plate = GetVehicleNumberPlateText(truck)
			local vin = nil
			print("Check 3")
			if vin == nil then
				print("Check 4")
				TriggerServerEvent("des-vehRegistration-sv:genVehVIN", NetworkGetNetworkIdFromEntity(truck), false)
				while vin == nil do
					vin = Entity(truck).state.VIN
					Citizen.Wait(10)
				end
				print("Check 5")
			end
			print("Check 6")
			TriggerServerEvent('garage:addKeys', vin)
			--Start new delivery
			doingARun = true
			Citizen.CreateThread(function()
				healthMonitor()
			end)
			deliveriesBeforeReturning = truckGroup.numberOfDropOffs
			--TriggerEvent("DoLongHudText","Looks like you didn't bring your own truck. Here use one of mine.",1, 15000)
			SendNotification("Looks like you didn't bring your own truck. Here use one of mine.")
			missionStartTime = GetNetworkTime()
			ownTruck = false
			TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "truckSpawn", {id = identifier})
			while truckGroup.stage == 0 and not cancelMission do
				Citizen.Wait(100)
			end
			if cancelMission then
				return
			end
			SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(truck), false)
			newGroupDelivery()
		else
			truck = playerVehicle
			doingARun = true
			Citizen.CreateThread(function()
				healthMonitor()
			end)
			ownTruck = true
			deliveriesBeforeReturning = truckGroup.numberOfDropOffs
			--TriggerEvent("DoLongHudText","I see you got money and brought your own truck. Cool.",1, 15000)
			SendNotification("I see you got money and brought your own truck. Cool.")
			TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "truckSpawn", {id = identifier})
			while truckGroup.stage == 0 and not cancelMission do
				Citizen.Wait(100)
			end
			if cancelMission then
				return
			end
			missionStartTime = GetNetworkTime()
			SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(truck), false)
			newGroupDelivery()
		end
	else
		doingARun = true
		Citizen.CreateThread(function()
			healthMonitor()
		end)
		deliveriesBeforeReturning = truckGroup.numberOfDropOffs
		TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "truckSpawn", {id = identifier})
		while truckGroup.stage == 0 and not cancelMission do
			Citizen.Wait(100)
		end
		if cancelMission then
			return
		end
		SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(truck), false)
		newGroupDelivery()
	end
end)

RegisterNetEvent("des-trucking-cl:updateTruckGroup")
AddEventHandler("des-trucking-cl:updateTruckGroup", function(sentTruckGroup)
	truckGroup = sentTruckGroup
	if truckGroup == nil then
		cancelMission = true
		Citizen.Wait(1000)
		resetMission()
	end
end)

AddEventHandler('des-trucking-cl:returnTruck', function()
	if DoesEntityExist(truck) then
		if not ownTruck then
			local timeout = 0
			while not NetworkGetEntityIsNetworked(truck) do
				NetworkRegisterEntityAsNetworked(truck)
				Citizen.Wait(100)
			end
			while true do
				if timeout >= 3000 then break end
				timeout = timeout + 1

				NetworkRequestControlOfEntity(truck)

				local nTimeout = 0

				while nTimeout < 1000 and NetworkGetEntityOwner(truck) ~= PlayerId() do
					nTimeout = nTimeout + 1
					NetworkRequestControlOfEntity(truck)
					Citizen.Wait(0)
				end
			end
			local vin = Entity(truck).state.VIN
			if vin ~= nil and vin < 200000000 then
			  TriggerServerEvent("des-vehRegistration-sv:removeVIN", vin)
			end
			DeleteEntity(truck)
			if DoesEntityExist(trailer) then
				timeout = 0
				while not NetworkGetEntityIsNetworked(trailer) do
					NetworkRegisterEntityAsNetworked(trailer)
					Citizen.Wait(100)
				end
				while true do
					if timeout >= 3000 then break end
					timeout = timeout + 1
	
					NetworkRequestControlOfEntity(trailer)
	
					local nTimeout = 0
	
					while nTimeout < 1000 and NetworkGetEntityOwner(trailer) ~= PlayerId() do
						nTimeout = nTimeout + 1
						NetworkRequestControlOfEntity(trailer)
						Citizen.Wait(0)
					end
				end
				local vin = Entity(trailer).state.VIN
				if vin ~= nil and vin < 200000000 then
				  TriggerServerEvent("des-vehRegistration-sv:removeVIN", vin)
				end
				DeleteEntity(trailer)
				if not DoesEntityExist(trailer) then
					trailer = nil
				end
			end
			if not DoesEntityExist(truck) then
				truck = nil
				--TriggerEvent("DoLongHudText","Successfully returned the truck.",3, 15000)
				SendNotification("Successfully returned the truck.")
				TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "missionCancel", nil)
				resetMission()
			else
				--TriggerEvent("DoLongHudText","You were not able to return the truck. Make sure no one is in it.",2, 15000)
				SendNotification("You were not able to return the truck. Make sure no one is in it.")
			end
		else
			if DoesEntityExist(trailer) then
				timeout = 0
				while not NetworkGetEntityIsNetworked(trailer) do
					NetworkRegisterEntityAsNetworked(trailer)
					Citizen.Wait(100)
				end
				while true do
					if timeout >= 3000 then break end
					timeout = timeout + 1
	
					NetworkRequestControlOfEntity(trailer)
	
					local nTimeout = 0
	
					while nTimeout < 1000 and NetworkGetEntityOwner(trailer) ~= PlayerId() do
						nTimeout = nTimeout + 1
						NetworkRequestControlOfEntity(trailer)
						Citizen.Wait(0)
					end
				end
				local vin = Entity(trailer).state.VIN
				if vin ~= nil and vin < 200000000 then
				  TriggerServerEvent("des-vehRegistration-sv:removeVIN", vin)
				end
				DeleteEntity(trailer)
				if not DoesEntityExist(trailer) then
					trailer = nil
				end
			end
			--TriggerEvent("DoLongHudText","You stopped truckin' for the day", 1, 15000)
			SendNotification("You stopped truckin' for the day")
			TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "missionCancel", nil)
			resetMission()
		end
	else
		--TriggerEvent("DoLongHudText","It seems you don't have a truck to return",2, 10000)
		SendNotification("It seems you don't have a truck to return")
	end
end)

AddEventHandler('des-trucking-cl:collectPay', function()
	TriggerServerEvent('des-trucking-sv:pay', ESX.GetPlayerData().identifier)
end)

RegisterNetEvent('des-trucking-cl:resetTotalPay')
AddEventHandler('des-trucking-cl:resetTotalPay', function()
	totalJobPay = 0
end)

RegisterNetEvent('des-trucking-cl:setTotalPay')
AddEventHandler('des-trucking-cl:setTotalPay', function(totalPay)
	totalJobPay = totalPay
	if totalJobPay > 0 then
		--TriggerEvent("DoLongHudText","You have $" .. totalJobPay .. " waiting to be collected at the trucking location", 1, 15000)
		SendNotification("You have $" .. totalJobPay .. " waiting to be collected at the trucking location")
	end
end)
------------------------------------------------------------------

--Functions
------------------------------------------------------------------
--Start new delivery function
function newDelivery()
	if trailer == nil then
		local newPickupSpot = math.random(1, #Config.PickupLocations)
		while newPickupSpot == lastPickupSpot do
			Citizen.Wait(10)
			newPickupSpot = math.random(1, #Config.PickupLocations)
		end
		lastPickupSpot = newPickupSpot
		currentPickupSpot = Config.PickupLocations[newPickupSpot]
		truckType = newPickupSpot
		SetJobBlip(currentPickupSpot[1], 'Pickup Location')
		--TriggerEvent("DoLongHudText","A trailer is ready for pickup and has been marked on your map",4, 10000)
		SendNotification("A trailer is ready for pickup and has been marked on your map")
		local count = 0
		while #(GetEntityCoords(GetPlayerPed(-1)) - currentPickupSpot[1]) > 100.0 and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				--TriggerEvent("DoLongHudText","You need to go to the marked location on your map to pickup your trailer",4, 10000)
				SendNotification("You need to go to the marked location on your map to pickup your trailer")
				count = 0
			else
				count = count + 1
			end
		end
		if cancelMission then
			return
		end
		local trailerModel = "trailers4"
		if truckType > 1 and truckType < 5 then
			trailerModel = "trailers2"
		elseif truckType == 5 then
			trailerModel = "tanker"
		elseif truckType == 6 then
			trailerModel = "TR4"
		elseif truckType == 7 then
			trailerModel = "TrailerLogs"
		end
		ESX.Game.SpawnVehicle(trailerModel, currentPickupSpot[1], currentPickupSpot[2], function(tempTrailer)
			trailer = tempTrailer
			hasSpawnedTrailer = true
			Citizen.Wait(0)
			SetVehicleOnGroundProperly(trailer)
			local plate = GetVehicleNumberPlateText(tempTruck)
			if truckType > 1 and truckType < 5 then
				SetVehicleLivery(trailer, truckType)
			else
				SetVehicleExtra(trailer,1,true)
				SetVehicleExtra(trailer,2,true)
				SetVehicleExtra(trailer,3,true)
				SetVehicleExtra(trailer,4,true)
				SetVehicleExtra(trailer,5,true)
				SetVehicleExtra(trailer,6,true)
				SetVehicleExtra(trailer,7,true)
				SetVehicleExtra(trailer,8,true)
				SetVehicleExtra(trailer,9,true)
				SetVehicleExtra(trailer,2,false)
			end
			NetworkRegisterEntityAsNetworked(trailer)
			while not NetworkGetEntityIsNetworked(trailer) do
				NetworkRegisterEntityAsNetworked(trailer)
				Citizen.Wait(100)
			end
			local id = NetworkGetNetworkIdFromEntity(trailer)
			SetVehicleHasBeenOwnedByPlayer(trailer, true)
			SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(trailer), false)
			local vin = nil
			if vin == nil then
				TriggerServerEvent("des-vehRegistration-sv:genVehVIN", NetworkGetNetworkIdFromEntity(trailer), false)
				while vin == nil do
					vin = Entity(trailer).state.VIN
					Citizen.Wait(10)
				end
			end
			TriggerServerEvent('garage:addKeys', vin)
		end)
		--TriggerEvent("DoLongHudText","Attach to the trailer with the marker above it",4, 10000)
		SendNotification("Attach to the trailer with the marker above it")
		count = 0
		local attached = false
		Citizen.CreateThread(function()
			while not attached and not cancelMission do 
				local trailerPos = GetEntityCoords(trailer)
				Citizen.Wait(0)
				DrawMarker(0, trailerPos.x, trailerPos.y, trailerPos.z+2.1, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 135, 31, 35, 150, 1, 0, 0, 0)
			end
		end)
		while (not IsEntityAttached(trailer) and GetEntityAttachedTo(trailer) ~= truck) and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				--TriggerEvent("DoLongHudText","You need to attach the marked trailer to your truck",4, 10000)
				SendNotification("You need to attach the marked trailer to your truck")
				count = 0
			else
				count = count + 1
			end
		end
		if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
		if cancelMission then
			return
		end
		attached = true
		local newDropOffSpot = math.random(1, #Config.DeliveryLocations[lastPickupSpot])
		while newDropOffSpot == lastDropOffSpot and not cancelMission do
			Citizen.Wait(10)
			newDropOffSpot = math.random(1, #Config.DeliveryLocations[lastPickupSpot])
		end
		if cancelMission then
			return
		end
		lastDropOffSpot = newDropOffSpot
		currentDropOffSpot = Config.DeliveryLocations[lastPickupSpot][newDropOffSpot]
		TriggerServerEvent("des-trucking-sv:abc", currentDropOffSpot[1])
		SetJobBlip(currentDropOffSpot[1], 'Delivery Location')
		local distance = math.floor(CalculateTravelDistanceBetweenPoints(GetEntityCoords(trailer), currentDropOffSpot[1]))
		--TriggerEvent("DoLongHudText","Deliver the contents of the trailer to the marked location on your map",4, 15000)
		SendNotification("Deliver the contents of the trailer to the marked location on your map")
		count = 0
		while #(GetEntityCoords(trailer) - currentDropOffSpot[1]) > 65.0 and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				--TriggerEvent("DoLongHudText","You need to go to the marked location on your map to make a drop off",4, 15000)
				SendNotification("You need to go to the marked location on your map to make a drop off")
				count = 0
			else
				count = count + 1
			end
		end
		if cancelMission then
			return
		end
		TriggerEvent("DoLongHudText","Back the back of the trailer up to the marker to make the drop off",4, 15000)
		SendNotification("Back the back of the trailer up to the marker to make the drop off")
		local vehDims = GetModelDimensions(GetEntityModel(trailer))
		local vehLength = vehDims[2]
		local vehWidth = vehDims[1]
		local zOffset = -0.50
		if truckType == 6 then
			zOffset = 1.0
		end
		local rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
		local inPosition = false
		Citizen.CreateThread(function()
			while not inPosition and not cancelMission do 
				local tempCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
				local tempHeading = GetEntityHeading(trailer)
				Citizen.Wait(0)
				DrawMarker(1, currentDropOffSpot[1], 0.0, 0.0, 0.0, 90.0, currentDropOffSpot[2] + 180.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				DrawMarker(1, tempCoords, 0.0, 0.0, 0.0, 90.0, tempHeading, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
			end
		end)
		count = 0
		while (#(rearCoords - currentDropOffSpot[1]) > 1.0 or math.abs(((GetEntityHeading(trailer) - currentDropOffSpot[2])  + 180) % 360 - 180) > 35) and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				TriggerEvent("DoLongHudText","You need to go to the marked location on your map to make a drop off",4, 10000)
				count = 0
			else
				count = count + 1
			end
			rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
		end
		if cancelMission then
			return
		end
		inPosition = true
		if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
		TriggerEvent("DoLongHudText","Get out of the truck and go to the rear to help unload the contents",4, 15000)
		zOffset = -2.75
		if truckType == 6 then
			zOffset = -1.20
		end
		local rearCoordsRight = GetOffsetFromEntityInWorldCoords(trailer,1.35,vehLength,zOffset)
		local rearCoordsLeft = GetOffsetFromEntityInWorldCoords(trailer,-1.35,vehLength,zOffset)
		Citizen.Wait(500)
		inPosition = false
		Citizen.CreateThread(function()
			while not inPosition and not cancelMission do
				DrawMarker(1, rearCoordsRight, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				DrawMarker(1, rearCoordsLeft, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				Citizen.Wait(0)
			end
		end)
		while (#(GetEntityCoords(GetPlayerPed(-1)) - rearCoordsRight) > 1.5 and #(GetEntityCoords(GetPlayerPed(-1)) - rearCoordsLeft) > 1.5) and not cancelMission do
			Citizen.Wait(500)
			rearCoordsRight = GetOffsetFromEntityInWorldCoords(trailer,1.35,vehLength,zOffset)
			rearCoordsLeft = GetOffsetFromEntityInWorldCoords(trailer,-1.35,vehLength,zOffset)
		end
		if cancelMission then
			return
		end
		inPosition = true
		rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,0.0)
		UnloadTruck(rearCoords)
		currentJobPay = 0
		local perMeterPay = math.random(Config.PayPerMeter[1], Config.PayPerMeter[2]) / 100
		currentJobPay = math.ceil(distance * perMeterPay)
		if currentJobPay > 750 then
			currentJobPay = 750
		end
		if exports["des-assets"]:getTruckingBoost() - GetGameTimer() > 0 then
			local extra = 0
			extra = math.floor((currentJobPay * 0.20) + 0.5)
			TriggerEvent('DoLongHudText', 'You received extra $' .. extra .. ' due to using something that gives you a boost', 109)
			TriggerEvent('DoLongHudText', 'You have ' .. math.floor((exports["des-assets"]:getTruckingBoost()- GetGameTimer()) / 1000 + 0.5) .. "s left to your boost", 423122)
			currentJobPay = currentJobPay + extra
		end
		local craftBeerAmount = math.random(1, 2)
		if math.random(1, 100) <= 45 then
			TriggerEvent('player:receiveItem', "craftbeer", craftBeerAmount)
			TriggerEvent('okokNotify:Alert', "Trucking Job", "You received " .. craftBeerAmount .. " craft beer from the delivery crew as a tip.", 4000, 'info')
		end
		totalJobPay = totalJobPay + currentJobPay	
		TriggerServerEvent('des-dailies-server:handleDailyEvent', 'truckdelivery', 1, GetEntityCoords(GetPlayerPed(-1), false), 10069)
		local charSteam = ESX.GetPlayerData().identifier
		TriggerServerEvent('des-trucking-sv:addToPayslip', charSteam, currentJobPay)
		if deliveriesBeforeReturning ~= deliveryCount and not cancelMission then
			newDelivery()
		else
			TriggerEvent("DoLongHudText","Return the trailer to where you got it from. A marker has been placed on your map",4, 15000)
			TriggerServerEvent("des-trucking-abc", currentPickupSpot[1])
			SetJobBlip(currentPickupSpot[1], 'Return Location')
			count = 0
			while #(GetEntityCoords(trailer) - currentPickupSpot[1]) > 50.0 and not cancelMission do
				Citizen.Wait(500)
				if count >= 600 then
					TriggerEvent("DoLongHudText","You need to go to the marked location on your map to return the trailer",4, 15000)
					count = 0
				else
					count = count + 1
				end
			end
			if cancelMission then
				return
			end
			TriggerEvent("DoLongHudText","Put the trailer in the spot to complete the run.",4, 15000)
			inPosition = false
			Citizen.CreateThread(function()
				while not inPosition and not cancelMission do 
					local tempCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,0.0)
					local tempHeading = GetEntityHeading(trailer)
					Citizen.Wait(0)
					DrawMarker(1, currentPickupSpot[1], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				end
			end)
			while #(GetEntityCoords(trailer) - currentPickupSpot[1]) > 4.0 and not cancelMission do
				Citizen.Wait(500)
			end
			inPosition = true
			local vin = Entity(trailer).state.VIN
			if vin ~= nil and vin < 200000000 then
			  TriggerServerEvent("des-vehRegistration-sv:removeVIN", vin)
			end
			DeleteEntity(trailer)
			trailer = nil
			TriggerEvent("DoLongHudText","Successfully did a full run. Extra cash was added to your total payment. Go get it from the starting area",3, 15000)
			TriggerEvent("DoLongHudText","Either return the truck or start another mission",4, 15000)
			TriggerServerEvent('des-trucking-sv:addToPayslip', ESX.GetPlayerData().identifier, math.random(125, 250))
			resetMission()
		end
	else
		local newDropOffSpot = math.random(1, #Config.DeliveryLocations[lastPickupSpot])
		while newDropOffSpot == lastDropOffSpot and not cancelMission do
			Citizen.Wait(10)
			newDropOffSpot = math.random(1, #Config.DeliveryLocations[lastPickupSpot])
		end
		if cancelMission then
			return
		end
		lastDropOffSpot = newDropOffSpot
		currentDropOffSpot = Config.DeliveryLocations[lastPickupSpot][newDropOffSpot]
		TriggerServerEvent("des-trucking-sv:abc", currentDropOffSpot[1])
		SetJobBlip(currentDropOffSpot[1], 'Delivery Location')
		TriggerEvent("DoLongHudText","Deliver the contents of the trailer to the marked location on your map",4, 15000)
		local distance = math.floor(CalculateTravelDistanceBetweenPoints(GetEntityCoords(trailer), currentDropOffSpot[1]))
		local count = 0
		while #(GetEntityCoords(trailer) - currentDropOffSpot[1]) > 50.0 and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				TriggerEvent("DoLongHudText","You need to go to the marked location on your map to make a drop off",4, 15000)
				count = 0
			else
				count = count + 1
			end
		end
		if cancelMission then
			return
		end
		TriggerEvent("DoLongHudText","Back the back of the trailer up to the marker to make the drop off",4, 15000)
		local vehDims = GetModelDimensions(GetEntityModel(trailer))
		local vehLength = vehDims[2]
		local vehWidth = vehDims[1]
		local zOffset = -0.50
		if truckType == 6 then
			zOffset = 1.0
		end
		local rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
		local inPosition = false
		Citizen.CreateThread(function()
			while not inPosition and not cancelMission do 
				local tempCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
				local tempHeading = GetEntityHeading(trailer)
				Citizen.Wait(0)
				DrawMarker(1, currentDropOffSpot[1], 0.0, 0.0, 0.0, 90.0, currentDropOffSpot[2] + 180.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				DrawMarker(1, tempCoords, 0.0, 0.0, 0.0, 90.0, tempHeading, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
			end
		end)
		while (#(rearCoords - currentDropOffSpot[1]) > 1.0 or math.abs(((GetEntityHeading(trailer) - currentDropOffSpot[2])  + 180) % 360 - 180) > 35) and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				TriggerEvent("DoLongHudText","You need to go to the marked location on your map to make a drop off",4, 10000)
				count = 0
			else
				count = count + 1
			end
			rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
		end
		if cancelMission then
			return
		end
		inPosition = true
		if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
		TriggerEvent("DoLongHudText","Get out of the truck and go to the rear to help unload the contents",4, 15000)
		zOffset = -2.75
		if truckType == 6 then
			zOffset = -1.20
		end
		local rearCoordsRight = GetOffsetFromEntityInWorldCoords(trailer,1.35,vehLength,zOffset)
		local rearCoordsLeft = GetOffsetFromEntityInWorldCoords(trailer,-1.35,vehLength,zOffset)
		Citizen.Wait(500)
		inPosition = false
		Citizen.CreateThread(function()
			while not inPosition and not cancelMission do
				DrawMarker(1, rearCoordsRight, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				DrawMarker(1, rearCoordsLeft, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				Citizen.Wait(0)
			end
		end)
		while (#(GetEntityCoords(GetPlayerPed(-1)) - rearCoordsRight) > 1.5 and #(GetEntityCoords(GetPlayerPed(-1)) - rearCoordsLeft) > 1.5) and not cancelMission do
			Citizen.Wait(500)
			rearCoordsRight = GetOffsetFromEntityInWorldCoords(trailer,1.35,vehLength,zOffset)
			rearCoordsLeft = GetOffsetFromEntityInWorldCoords(trailer,-1.35,vehLength,zOffset)
		end
		if cancelMission then
			return
		end
		inPosition = true
		rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,0.0)
		UnloadTruck(rearCoords)
		currentJobPay = 0
		local perMeterPay = math.random(Config.PayPerMeter[1], Config.PayPerMeter[2]) / 100
		currentJobPay = math.ceil(distance * perMeterPay)
		if currentJobPay > 750 then
			currentJobPay = 750
		end
		if exports["des-assets"]:getTruckingBoost() - GetGameTimer() > 0 then
			local extra = 0
			extra = math.floor((currentJobPay * 0.20) + 0.5)
			TriggerEvent('DoLongHudText', 'You received extra $' .. extra .. ' due to using something that gives you a boost', 109)
			TriggerEvent('DoLongHudText', 'You have ' .. math.floor((exports["des-assets"]:getTruckingBoost()- GetGameTimer()) / 1000 + 0.5) .. "s left to your boost", 423122)
			currentJobPay = currentJobPay + extra
		end
		local craftBeerAmount = math.random(1, 2)
		if math.random(1, 100) <= 45 then
			TriggerEvent('player:receiveItem', "craftbeer", craftBeerAmount)
			TriggerEvent('okokNotify:Alert', "Trucking Job", "You received " .. craftBeerAmount .. " craft beer from the delivery crew as a tip.", 4000, 'info')
		end
		totalJobPay = totalJobPay + currentJobPay
		TriggerServerEvent('des-dailies-server:handleDailyEvent', 'truckdelivery', 1, GetEntityCoords(GetPlayerPed(-1), false), 10069)
		TriggerServerEvent('des-trucking-sv:addToPayslip', ESX.GetPlayerData().identifier, currentJobPay)
		if deliveriesBeforeReturning ~= deliveryCount and not cancelMission then
			newDelivery()
		else
			TriggerEvent("DoLongHudText","Return the trailer to where you got it from. A marker has been placed on your map",4, 15000)
			TriggerServerEvent("des-trucking-abc", currentPickupSpot[1])
			SetJobBlip(currentPickupSpot[1], 'Return Location')
			count = 0
			while #(GetEntityCoords(trailer) - currentPickupSpot[1]) > 50.0 and not cancelMission do
				Citizen.Wait(500)
				if count >= 600 then
					TriggerEvent("DoLongHudText","You need to go to the marked location on your map to return the trailer",4, 15000)
					count = 0
				else
					count = count + 1
				end
			end
			if cancelMission then
				return
			end
			TriggerEvent("DoLongHudText","Put the trailer in the spot to complete the run.",4, 15000)
			inPosition = false
			Citizen.CreateThread(function()
				while not inPosition and not cancelMission do 
					local tempCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,0.0)
					local tempHeading = GetEntityHeading(trailer)
					Citizen.Wait(0)
					DrawMarker(1, currentPickupSpot[1], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
				end
			end)
			while #(GetEntityCoords(trailer) - currentPickupSpot[1]) > 4.0 and not cancelMission do
				Citizen.Wait(500)
			end
			inPosition = true
			local vin = Entity(trailer).state.VIN
			if vin ~= nil and vin < 200000000 then
			  TriggerServerEvent("des-vehRegistration-sv:removeVIN", vin)
			end
			DeleteEntity(trailer)
			trailer = nil
			TriggerEvent("DoLongHudText","Successfully did a full run. Extra cash was added to your total payment. Go get it from the starting area",3, 15000)
			TriggerEvent("DoLongHudText","Either return the truck or start another mission",4, 15000)
			TriggerServerEvent('des-trucking-sv:addToPayslip', ESX.GetPlayerData().identifier, math.random(125, 250))
			resetMission()
		end
	end
end

function handleTrailerSpawn()
	local playerId = ESX.GetPlayerData().identifier
	currentPickupSpot = Config.GroupPickupLocations[truckGroup.missionType][truckGroup.personData[playerId].trailerSpawn]
	truckType = truckGroup.missionType
	SetJobBlip(currentPickupSpot[1], 'Pickup Location')
	--TriggerEvent("DoLongHudText","A trailer is ready for pickup and has been marked on your map",4, 10000)
	SendNotification("A trailer is ready for pickup and has been marked on your map")
	local count = 0
	while #(GetEntityCoords(GetPlayerPed(-1)) - currentPickupSpot[1]) > 100.0 and not cancelMission do
		Citizen.Wait(500)
		if count >= 600 then
			--TriggerEvent("DoLongHudText","You need to go to the marked location on your map to pickup your trailer",4, 10000)
			SendNotification("You need to go to the marked location on your map to pickup your trailer")
			count = 0
		else
			count = count + 1
		end
	end
	if cancelMission then
		return
	end
	local trailerModel = "trailers4"
	if truckType > 1 and truckType < 5 then
		trailerModel = "trailers2"
	elseif truckType == 5 then
		trailerModel = "tanker"
	elseif truckType == 6 then
		trailerModel = "TR4"
	elseif truckType == 7 then
		trailerModel = "TrailerLogs"
	end
	ESX.Game.SpawnVehicle(trailerModel, currentPickupSpot[1], currentPickupSpot[2], function(tempTrailer)
		trailer = tempTrailer
		NetworkRegisterEntityAsNetworked(trailer)
		while not NetworkGetEntityIsNetworked(trailer) do
			NetworkRegisterEntityAsNetworked(trailer)
			Citizen.Wait(100)
		end
		hasSpawnedTrailer = true
		Citizen.Wait(0)
		SetVehicleOnGroundProperly(trailer)
		local plate = GetVehicleNumberPlateText(tempTruck)
		if truckType > 1 and truckType < 5 then
			SetVehicleLivery(trailer, truckType)
		else
			SetVehicleExtra(trailer,1,true)
			SetVehicleExtra(trailer,2,true)
			SetVehicleExtra(trailer,3,true)
			SetVehicleExtra(trailer,4,true)
			SetVehicleExtra(trailer,5,true)
			SetVehicleExtra(trailer,6,true)
			SetVehicleExtra(trailer,7,true)
			SetVehicleExtra(trailer,8,true)
			SetVehicleExtra(trailer,9,true)
			SetVehicleExtra(trailer,2,false)
		end
		NetworkRegisterEntityAsNetworked(trailer)
		while not NetworkGetEntityIsNetworked(trailer) do
			NetworkRegisterEntityAsNetworked(trailer)
			Citizen.Wait(100)
		end
		local id = NetworkGetNetworkIdFromEntity(trailer)
		SetVehicleHasBeenOwnedByPlayer(trailer, true)
		SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(trailer), false)
		local vin = nil
		if vin == nil then
			TriggerServerEvent("des-vehRegistration-sv:genVehVIN", NetworkGetNetworkIdFromEntity(trailer), false)
			while vin == nil do
				vin = Entity(trailer).state.VIN
				Citizen.Wait(10)
			end
		end
		TriggerServerEvent('garage:addKeys', vin)
	end)
	--TriggerEvent("DoLongHudText","Attach to the trailer with the marker above it",4, 10000)
	SendNotification("Attach to the trailer with the marker above it")
	count = 0
	local attached = false
	Citizen.CreateThread(function()
		while not attached and not cancelMission do 
			local trailerPos = GetEntityCoords(trailer)
			Citizen.Wait(0)
			DrawMarker(0, trailerPos.x, trailerPos.y, trailerPos.z+2.1, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 135, 31, 35, 150, 1, 0, 0, 0)
		end
	end)
	while (not IsEntityAttached(trailer) and GetEntityAttachedTo(trailer) ~= truck) and not cancelMission do
		Citizen.Wait(500)
		if count >= 600 then
			--TriggerEvent("DoLongHudText","You need to attach the marked trailer to your truck",4, 10000)
			SendNotification("You need to attach the marked trailer to your truck")
			count = 0
		else
			count = count + 1
		end
	end
	if cancelMission then
		return
	end
	if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
	attached = true
	--Send update to server side saying the trailer has been attached
	TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "trailerAttached", {id = playerId})
	--Wait for all members of the group to attach their trailers then continue
	while truckGroup.stage == 1 and not cancelMission do
		Citizen.Wait(100)
	end
	if cancelMission then
		return
	end
end

--Start new group delivery function
function newGroupDelivery()
	local playerId = ESX.GetPlayerData().identifier
	local startSpot = Config.GroupPickupLocations[truckGroup.missionType][truckGroup.personData[playerId].trailerSpawn][1]
	if trailer == nil then
		handleTrailerSpawn()
	else
		startSpot = truckGroup.lastDeliveryLocation[truckGroup.personData[playerId].trailerSpawn][1]
	end
	--TODO Move drop of spot selection to server side
	currentDropOffSpot = truckGroup.deliveryLocation
	TriggerServerEvent("des-trucking-sv:abc", currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1])
	SetJobBlip(currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1], 'Delivery Location')
	local distance = math.floor(CalculateTravelDistanceBetweenPoints(startSpot, currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1]))
	print(startSpot, distance, playerId, exports["des-assets"]:getGroup().creator, currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1])
	if playerId == exports["des-assets"]:getGroup().creator then
		TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "distance", {dist = distance})
	end
	--TriggerEvent("DoLongHudText","Deliver the contents of the trailer to the marked location on your map",4, 15000)
	SendNotification("Deliver the contents of the trailer to the marked location on your map")
	local count = 0
	while #(GetEntityCoords(trailer) - currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1]) > 65.0 and not cancelMission do
		Citizen.Wait(500)
		if count >= 600 then
			--TriggerEvent("DoLongHudText","You need to go to the marked location on your map to make a drop off",4, 15000)
			SendNotification("You need to go to the marked location on your map to make a drop off")
			count = 0
		else
			count = count + 1
		end
	end
	if cancelMission then
		return
	end
	--TriggerEvent("DoLongHudText","Back the back of the trailer up to the marker to make the drop off",4, 15000)
	SendNotification("Back the back of the trailer up to the marker to make the drop off")
	local vehDims = GetModelDimensions(GetEntityModel(trailer))
	local vehLength = vehDims[2]
	local vehWidth = vehDims[1]
	local zOffset = -0.50
	if truckType == 6 then
		zOffset = 1.0
	end
	local rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
	local inPosition = false
	Citizen.CreateThread(function()
		while not inPosition and not cancelMission do 
			local tempCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
			local tempHeading = GetEntityHeading(trailer)
			Citizen.Wait(0)
			DrawMarker(1, currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1], 0.0, 0.0, 0.0, 90.0, currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][2] + 180.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
			DrawMarker(1, tempCoords, 0.0, 0.0, 0.0, 90.0, tempHeading, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
		end
	end)
	count = 0
	while (#(rearCoords - currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][1]) > 1.0 or math.abs(((GetEntityHeading(trailer) - currentDropOffSpot[truckGroup.personData[playerId].trailerSpawn][2])  + 180) % 360 - 180) > 35) and not cancelMission do
		Citizen.Wait(500)
		if count >= 600 then
			--TriggerEvent("DoLongHudText","You need to go to the marked location on your map to make a drop off",4, 10000)
			SendNotification("You need to go to the marked location on your map to make a drop off")
			count = 0
		else
			count = count + 1
		end
		rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,zOffset)
	end
	if cancelMission then
		return
	end
	inPosition = true
	TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "docked", {id = playerId})
	SendNotification("Waiting for all the others to dock their trailers")
	while not truckGroup.allDocked and not cancelMission do
		Citizen.Wait(100)
	end
	if cancelMission then
		return
	end
	if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
	--TriggerEvent("DoLongHudText","Get out of the truck and go to the rear to help unload the contents",4, 15000)
	SendNotification("Get out of the truck and go to the rear to help unload the contents")
	zOffset = -2.75
	if truckType == 6 then
		zOffset = -1.20
	end
	local rearCoordsRight = GetOffsetFromEntityInWorldCoords(trailer,1.35,vehLength,zOffset)
	local rearCoordsLeft = GetOffsetFromEntityInWorldCoords(trailer,-1.35,vehLength,zOffset)
	Citizen.Wait(500)
	inPosition = false
	Citizen.CreateThread(function()
		while not inPosition and not cancelMission do
			DrawMarker(1, rearCoordsRight, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
			DrawMarker(1, rearCoordsLeft, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
			Citizen.Wait(0)
		end
	end)
	while (#(GetEntityCoords(GetPlayerPed(-1)) - rearCoordsRight) > 1.5 and #(GetEntityCoords(GetPlayerPed(-1)) - rearCoordsLeft) > 1.5) and not cancelMission do
		Citizen.Wait(500)
		rearCoordsRight = GetOffsetFromEntityInWorldCoords(trailer,1.35,vehLength,zOffset)
		rearCoordsLeft = GetOffsetFromEntityInWorldCoords(trailer,-1.35,vehLength,zOffset)
	end
	if cancelMission then
		return
	end
	inPosition = true
	rearCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,0.0)
	UnloadTruck(rearCoords)
	TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "deliveryMade", {id = playerId})
	SendNotification("Waiting for all the others to make help unload")
	while not truckGroup.currentDeliveryFinished and not cancelMission do
		Citizen.Wait(100)
	end
	if cancelMission then
		return
	end
	currentJobPay = 0
	print(truckGroup.distance, truckGroup.perMeterPay)
	currentJobPay = math.ceil(truckGroup.distance * truckGroup.perMeterPay)
	if currentJobPay > 750 then
		currentJobPay = 750
	end
	if exports["des-assets"]:getTruckingBoost() - GetGameTimer() > 0 then
		local extra = 0
		extra = math.floor((currentJobPay * 0.20) + 0.5)
		TriggerEvent('DoLongHudText', 'You received extra $' .. extra .. ' due to using something that gives you a boost', 109)
		TriggerEvent('DoLongHudText', 'You have ' .. math.floor((exports["des-assets"]:getTruckingBoost()- GetGameTimer()) / 1000 + 0.5) .. "s left to your boost", 423122)
		currentJobPay = currentJobPay + extra
	end
	local craftBeerAmount = math.random(1, 2)
	if math.random(1, 100) <= 45 then
		TriggerEvent('player:receiveItem', "craftbeer", craftBeerAmount)
		TriggerEvent('okokNotify:Alert', "Trucking Job", "You received " .. craftBeerAmount .. " craft beer from the delivery crew as a tip.", 4000, 'info')
	end
	totalJobPay = totalJobPay + currentJobPay
	TriggerServerEvent('des-dailies-server:handleDailyEvent', 'truckdelivery', 1, GetEntityCoords(GetPlayerPed(-1), false), 10069)
	TriggerServerEvent('des-trucking-sv:addToPayslip', playerId, currentJobPay, truckGroup.numberOfMembers)
	TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "receivedPay", {id = playerId})
	while not truckGroup.allReceivedPay and not cancelMission do
		Citizen.Wait(100)
	end
	if cancelMission then
		return
	end
	if truckGroup.stage == 2 then
		TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "resetDeliveriesMade", {id = playerId})
		newGroupDelivery()
	else
		TriggerEvent("DoLongHudText","Return the trailer to where you got it from. A marker has been placed on your map",4, 15000)
		local currentPickupSpot = Config.GroupPickupLocations[truckGroup.missionType][truckGroup.personData[playerId].trailerSpawn]
		SetJobBlip(currentPickupSpot[1], 'Return Location')
		TriggerServerEvent("des-trucking-abc", currentPickupSpot[1])
		count = 0
		while #(GetEntityCoords(trailer) - currentPickupSpot[1]) > 50.0 and not cancelMission do
			Citizen.Wait(500)
			if count >= 600 then
				TriggerEvent("DoLongHudText","You need to go to the marked location on your map to return the trailer",4, 15000)
				count = 0
			else
				count = count + 1
			end
		end
		if cancelMission then
			return
		end
		--TriggerEvent("DoLongHudText","Put the trailer in the spot to complete the run.",4, 15000)
		exports['okokNotify']:Alert("Info", "Put the trailer in the spot to complete the run.", 2000, 'info')
		inPosition = false
		Citizen.CreateThread(function()
			while not inPosition and not cancelMission do 
				local tempCoords = GetOffsetFromEntityInWorldCoords(trailer,0.0,vehLength,0.0)
				local tempHeading = GetEntityHeading(trailer)
				Citizen.Wait(0)
				DrawMarker(1, currentPickupSpot[1], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,1.7,1.7,1.7,135,31,35,150,0,0,0,0)
			end
		end)
		while #(GetEntityCoords(trailer) - currentPickupSpot[1]) > 4.0 and not cancelMission do
			Citizen.Wait(500)
		end
		if cancelMission then
			return
		end
		--TriggerEvent("DoLongHudText","Waiting for the rest of your group to go to their locations",1, 15000)
		exports['okokNotify']:Alert("Info", "Waiting for the rest of your group to go to their locations", 2000, 'info')
		inPosition = true
		doingARun = false
		local vin = Entity(trailer).state.VIN
		if vin ~= nil and vin < 200000000 then
		  TriggerServerEvent("des-vehRegistration-sv:removeVIN", vin)
		end
		DeleteEntity(trailer)
		trailer = nil
		TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "returnTruck", {id = playerId})
		Citizen.Wait(1000)
		while not truckGroup.allTrucksReturned and not cancelMission do
			Citizen.Wait(100)
		end
		if cancelMission then
			return
		end
		TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "readyToComplete", {id = playerId})
		--TriggerEvent("DoLongHudText","Successfully did a full run. Extra cash was added to your total payment. Go get it from the starting area",3, 15000)
		exports['okokNotify']:Alert("Info", "Successfully did a full run. Extra cash was added to your total payment. Go get it from the starting area", 2000, 'success')
		--TriggerEvent("DoLongHudText","Either return the truck or start another mission",4, 15000)
		exports['okokNotify']:Alert("Info", "Either return the truck or start another mission", 2000, 'info')
		TriggerServerEvent('des-trucking-sv:addToPayslip', playerId, math.random(200, 375), truckGroup.numberOfMembers)
		resetMission()
	end
end

function SetJobBlip(coords, text)
	if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
	missionblip = AddBlipForCoord(coords)
	SetBlipSprite(missionblip, 164)
	SetBlipColour(missionblip, 53)
	SetBlipRoute(missionblip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(text)
	EndTextCommandSetBlipName(missionblip)
end

function UnloadTruck(coord)
    ClearPedTasks(PlayerPedId())
	TaskTurnPedToFaceCoord(PlayerPedId(), coord, 1.0)
    Citizen.Wait(1000)
	FreezeEntityPosition(PlayerPedId(), true)
    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
	local finished = exports["des-taskbar"]:taskBar(math.random(10000,15000), "UNLOADING TRAILER")
	while finished ~= 100 do
		finished = exports["des-taskbar"]:taskBar(math.random(10000,15000), "UNLOADING TRAILER")
		Citizen.Wait(100)
	end
	TriggerServerEvent("des-monewashmanager-sv:abc", something)
    ClearPedTasks(PlayerPedId())
	FreezeEntityPosition(PlayerPedId(), false)
	deliveryCount = deliveryCount + 1
	local washedMoney = exports["des-moneywashmanager"]:washMoney({2000, 5}, true)
	if washedMoney > 0 then
		--TriggerEvent("DoLongHudText","Thanks for the extra sauce!",5, 5000)
		exports['okokNotify']:Alert("Info", "Thanks for the extra sauce!", 2000, 'success')
		TriggerServerEvent("des-monewashmanager:pay", washedMoney, 'Trucking')
	end
end

function healthMonitor()
	while not cancelMission and doingARun do
		--if GetEntityHealth(truck) <= 0.0 or not DoesEntityExist(truck) or exports["des-ambulancejob"]:GetDeath() then
		if GetEntityHealth(truck) <= 0.0 or not DoesEntityExist(truck) then
			cancelMission = true
			Citizen.Wait(1000)
			resetMission()
			if doingGroupJob then
				TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "missionCancel", {})
			end
		end
		if (GetEntityHealth(trailer) <= 0.0 or not DoesEntityExist(trailer)) and hasSpawnedTrailer then
			cancelMission = true
			Citizen.Wait(1000)
			resetMission()
			if doingGroupJob then
				TriggerServerEvent("des-trucking-sv:updateTruckGroup", exports["des-assets"]:getGroup(), "missionCancel", {})
			end
		end
		local timeout = GetGameTimer()
		while (GetGameTimer() - timeout) < 1000 and NetworkGetEntityOwner(trailer) ~= PlayerId()  do
			NetworkRequestControlOfEntity(trailer)
			Citizen.Wait(0)
		end
		Citizen.Wait(500)
	end
end

function CreateBlip()
	local dist1 = AddBlipForCoord(-333.07, -2713.35, 6.0)
	SetBlipSprite(dist1, 477)
	SetBlipColour(dist1, 56)
	SetBlipScale(dist1, 0.6)
	SetBlipAsShortRange(dist1, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString('Trucking')
	EndTextCommandSetBlipName(dist1)
end

function resetMission()
	cancelMission = true
	print('Reseting mission')
	if DoesBlipExist(missionblip) then RemoveBlip(missionblip) end
	truck, trailer, currentJobPay, totalJobPay = nil, nil, nil, 0
	lastDropOffSpot, currentDropOffSpot = nil, nil
	lastPickupSpot, currentPickupSpot = nil, nil
	hasSpawnedTrailer = false
	missionblip = nil
	playerLoaded = false
	doingARun = false
	deliveriesBeforeReturning, deliveryCount = 0, 0
	ownTruck = false
	truckType = nil
	truckGroup = nil
	doingGroupJob = false
end

function SendNotification(msg)
	local texture = 'DIA_OJBB1_TRUCKER'
	RequestStreamedTextureDict(texture)
    while not HasStreamedTextureDictLoaded(texture) do
        Citizen.Wait(0)
    end

    -- Add the notification text
	ThefeedSetNextPostBackgroundColor(90)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(msg)

    -- Set the notification icon, title and subtitle.
    local title = '~r~Trucking Job'
    local subtitle = "Job Info"
    local iconType = 0
    local flash = false -- Flash doesn't seem to work no matter what.
    EndTextCommandThefeedPostMessagetext(texture, texture, flash, iconType, title, subtitle)
	--EXAMPLE USED IN VIDEO
	--exports['mythic_notify']:SendAlert('inform', msg)
end
------------------------------------------------------------------