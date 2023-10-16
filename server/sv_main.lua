ESX = nil
local payslips = {}
local truckGroups = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(500)
	end
end)

RegisterServerEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(source, xPlayer)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	if payslips[xPlayer.identifier] ~= nil then
		TriggerClientEvent('des-trucking-cl:setTotalPay', _source, payslips[xPlayer.identifier])
	end
end)

RegisterNetEvent("des-trucking-sv:startGroupJob")
AddEventHandler("des-trucking-sv:startGroupJob", function(group)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local newTruckGroup = {
		personData = {},
		numberOfDropOffs = math.random(4, 6),
		completedDropOffs = 0,
		missionType = math.random(1, #Config.GroupPickupLocations),
		deliveryLocation = -1,
		lastDeliveryLocation = -1,
		stage = 0,
		distance = 0,
		allDocked = false,
		currentDeliveryFinished = false,
		allTrucksReturned = false,
		numberOfMembers = group.memberCount,
		allReceivedPay = false,
		perMeterPay = math.random(Config.PayPerMeter[1], Config.PayPerMeter[2]) / 100
	}
	local spawnSpot = 1
	for id, data in pairs(group.members) do
		newTruckGroup.personData[id] = {
			source			= data[2],
			canSpawnTruck	= false,
			canSpawnTrailer	= false,
			trailerSpawn	= spawnSpot,
			trailerAttached	= false,
			docked			= false,
			hasDelivered	= false,
			truckReturned	= false,
			receivedPay		= false,
			readyToComplete = false
		}
		spawnSpot = spawnSpot + 1
	end
	newTruckGroup.personData[xPlayer.identifier].canSpawnTruck = true
	truckGroups[group.name] = newTruckGroup
	for id, data in pairs(group.members) do
		TriggerClientEvent("des-trucking-cl:startGroupJob", data[2], truckGroups[group.name])
	end
end)

RegisterNetEvent("des-trucking-sv:updateTruckGroup")
AddEventHandler("des-trucking-sv:updateTruckGroup", function(group, updateType, sentData)
	if group ~= nil then
		local targetTruckGroup = truckGroups[group.name]
		if targetTruckGroup ~= nil then
			if updateType == "truckSpawn" then
				targetTruckGroup.personData[sentData.id].truckStatus = 1
				local allTrucksSpawned = true
				for id, data in pairs(targetTruckGroup.personData) do
					if not data.canSpawnTruck then
						data.canSpawnTruck = true
						allTrucksSpawned = false
						break
					end
				end
				if allTrucksSpawned then
					targetTruckGroup.stage = 1
				end
			elseif updateType == "trailerAttached" then
				targetTruckGroup.personData[sentData.id].trailerAttached = true
				local allTrailersAttached = true
				for id, data in pairs(targetTruckGroup.personData) do
					if not data.trailerAttached then
						allTrailersAttached = false
						break
					end
				end
				if allTrailersAttached then
					--TODO Get delivery location
					local newDropOffSpot = math.random(1, #Config.GroupDeliveryLocations[targetTruckGroup.missionType])
					while newDropOffSpot == targetTruckGroup.lastDeliveryLocation do
						Citizen.Wait(10)
						newDropOffSpot = math.random(1, #Config.GroupDeliveryLocations[targetTruckGroup.missionType])
					end
					print(newDropOffSpot, targetTruckGroup.missionType)
					targetTruckGroup.deliveryLocation = Config.GroupDeliveryLocations[targetTruckGroup.missionType][newDropOffSpot]
					targetTruckGroup.lastDeliveryLocation = newDropOffSpot
					targetTruckGroup.stage = 2
				end
			elseif updateType == "distance" then
				print("Distance updated to", sentData.dist)
				targetTruckGroup.distance = sentData.dist
			elseif updateType == "docked" then
				targetTruckGroup.personData[sentData.id].docked = true
				local allDocked = true
				for id, data in pairs(targetTruckGroup.personData) do
					if not data.docked then
						allDocked = false
						break
					end
				end
				if allDocked then
					targetTruckGroup.allDocked = true
				end
			elseif updateType == "deliveryMade" then
				targetTruckGroup.personData[sentData.id].hasDelivered = true
				local allCurrentDeliveriesMade = true
				for id, data in pairs(targetTruckGroup.personData) do
					print(id, data.hasDelivered)
					if not data.hasDelivered then
						allCurrentDeliveriesMade = false
						break
					end
				end
				if allCurrentDeliveriesMade then
					--If so, get new delivery location if still has deliveries to make
					--Otherwise, progress the mission to the return truck phase
					targetTruckGroup.currentDeliveryFinished = true
					targetTruckGroup.completedDropOffs = targetTruckGroup.completedDropOffs + 1
					targetTruckGroup.lastDeliveryLocation = targetTruckGroup.deliveryLocation
					if targetTruckGroup.completedDropOffs < targetTruckGroup.numberOfDropOffs then
						local newDropOffSpot = math.random(1, #Config.GroupDeliveryLocations[targetTruckGroup.missionType])
						while newDropOffSpot == targetTruckGroup.lastDeliveryLocation do
							Citizen.Wait(10)
							newDropOffSpot = math.random(1, #Config.GroupDeliveryLocations[targetTruckGroup.missionType])
						end
						targetTruckGroup.deliveryLocation = Config.GroupDeliveryLocations[targetTruckGroup.missionType][newDropOffSpot]
					else
						targetTruckGroup.stage = 3
					end
				end
			elseif updateType == "receivedPay" then
				targetTruckGroup.personData[sentData.id].receivedPay = true
				local allGotPaid = true
				for id, data in pairs(targetTruckGroup.personData) do
					if not data.receivedPay then
						allGotPaid = false
						break
					end
				end
				if allGotPaid then
					targetTruckGroup.allReceivedPay = true
				end
			elseif updateType == "resetDeliveriesMade" then
				local allReset = true
				targetTruckGroup.personData[sentData.id].hasDelivered = false
				targetTruckGroup.personData[sentData.id].docked = false
				targetTruckGroup.personData[sentData.id].receivedPay = false
				for id, data in pairs(targetTruckGroup.personData) do
					if data.hasDelivered then
						allReset = false
					end
				end
				if allReset and targetTruckGroup.currentDeliveryFinished then
					targetTruckGroup.currentDeliveryFinished = false
					targetTruckGroup.allReceivedPay = false
					targetTruckGroup.allDocked = false
				end
			elseif updateType == "returnTruck" then
				targetTruckGroup.personData[sentData.id].truckReturned = true
				local allTrucksReturned = true
				for id, data in pairs(targetTruckGroup.personData) do
					if not data.truckReturned then
						allTrucksReturned = false
						break
					end
				end
				if allTrucksReturned then
					targetTruckGroup.allTrucksReturned = true
				end
			elseif updateType == "missionCancel" then
				for id, data in pairs(targetTruckGroup.personData) do
					TriggerClientEvent("des-trucking-cl:updateTruckGroup", data.source, nil)
				end
				targetTruckGroup = nil
			elseif updateType == "readyToComplete" then
				targetTruckGroup.personData[sentData.id].readyToComplete = true
				local allComplete = true
				for id, data in pairs(targetTruckGroup.personData) do
					if not data.readyToComplete then
						allComplete = false
						break
					end
				end
				if allComplete then
					for id, data in pairs(targetTruckGroup.personData) do
						TriggerClientEvent("des-trucking-cl:updateTruckGroup", data.source, nil)
					end
					targetTruckGroup = nil
				end
			end
			if targetTruckGroup ~= nil then
				for id, data in pairs(targetTruckGroup.personData) do
					TriggerClientEvent("des-trucking-cl:updateTruckGroup", data.source, targetTruckGroup)
				end
			end
		end
	end
end)

local someCheck = {}

RegisterServerEvent('des-trucking-sv:abc')
AddEventHandler('des-trucking-sv:abc', function(thing)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	someCheck[xPlayer.identifier] = vector3(thing[1], thing[2], thing[3])
end)

RegisterServerEvent('des-trucking-sv:pay')
AddEventHandler('des-trucking-sv:pay', function(identifier)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	if payslips[identifier] ~= nil then
		if payslips[identifier] > 0 then
			xPlayer.addMoney(payslips[identifier], "Job Payment", 'Trucking Job',  "trucking.")
			payslips[identifier] = 0
			TriggerClientEvent('des-trucking-cl:resetTotalPay', _source)
		else
			TriggerClientEvent("DoLongHudText", _source, "You do not have a payment to collect", 2, 15000)
		end
	else
		TriggerClientEvent("DoLongHudText", _source, "You do not have a payment to collect", 2, 15000)
	end
end)

RegisterServerEvent('des-trucking-sv:addToPayslip')
AddEventHandler('des-trucking-sv:addToPayslip', function(identifier, amount, groupCount)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
    local ped = GetPlayerPed(_source)
    local pedLocation = GetEntityCoords(ped)
	if #(someCheck[xPlayer.identifier] - pedLocation) <= 20.0 then
		someCheck[xPlayer.identifier] = nil
		if groupCount == nil then
			groupCount = 0
		end
		local groupBonus = (0.075 * (groupCount - 1))
		amount = math.floor((amount * (1 + groupBonus)) + 0.5)
		if payslips[identifier] == nil then
			payslips[identifier] = amount
		else
			payslips[identifier] = payslips[identifier] + amount
		end
		
		TriggerClientEvent("DoLongHudText", _source, "$" .. amount .. " was added to you pending payment totaling $" .. payslips[identifier] .. ". You will receive your payment once you finish all your deliveries, return the trailer and collect it from the starting location",1, 15000)	
	else
        TriggerEvent('logger:log', 'Possible Hack Attempt', xPlayer.getLegalName() .. ' attempted to receive money from the trucking job. Wrong Location', _source, 'Hack', 'Hack', 1, 'Trucking Job')
	end
end)	

RegisterServerEvent('des-trucking-sv:setPayslip')
AddEventHandler('des-trucking-sv:setPayslip', function(nameAndId, amount)
	payslips[nameAndId] = amount
end)