local QBCore = exports['qb-core']:GetCoreObject()
local Fines = {};

Citizen.CreateThread(function()
    QBCore.Functions.TriggerCallback('qb-mdt:getFines', function(fines)
        Fines = fines;
    end);

    Wait(3000);

    SendNUIMessage({
        type = 'getFines',
        fines = Fines
    });
end)

RegisterNUICallback('search', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:getSearchResults', function(results)
        Wait(350); cb(results);
    end, data.query);
end)

RegisterNUICallback('saveNotes', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:saveNotes', function(success)
        Wait(1000); cb(success);
    end, data.identifier, data.notes);
end)

RegisterNUICallback('newrecord', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:addRecord', function(success)
        cb(success);
    end, data);
end)

RegisterNUICallback('assets', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:getAssets', function(data)
        for _, v in pairs(data) do
            if v.type == 'vehicle' then
                v.name = GetLabelText(GetDisplayNameFromVehicleModel(v.model));
                if v.name == 'NULL' then v.name = 'Unknown'; end
            end
        end

        Wait(250); cb(data);
    end, data.identifier);
end)

RegisterNUICallback('saveProfilePicture', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:saveProfilePicture', function(success)
        Wait(250); cb(success);
    end, data.picture, data.identifier);
end)

RegisterNetEvent('qb-mdt:client:addCallout')
AddEventHandler('qb-mdt:client:addCallout', function(callout)
    SendNUIMessage({
        type = 'addCallout',
        callout = callout
    });
end)

RegisterNUICallback('getCalloutCoords', function(data, cb)
    if QBCore.Functions.GetPlayerData().PlayerData.job.name ~= 'police' then
        return cb(false);
    end

    SetNewWaypoint(data.coords.x, data.coords.y); cb(true);
end)

RegisterNUICallback('records', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:getRecords', function(results)
        Wait(350); cb(results);
    end, data.identifier);
end)

RegisterNUICallback('deleteWarrant', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:removeWarrant', function(success)
        Wait(350); cb(success);
    end, data.id);
end)

RegisterNUICallback('addWarrant', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:addWarrant', function(success)
        Wait(350); cb(success);
    end, data);
end)

RegisterNUICallback('getWarrants', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:getWarrants', function(warrants)
        Wait(350); cb(warrants);
    end);
end)

RegisterNUICallback('removeLicense', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:removeLicense', function(success)
        cb(success);
    end, data.license, data.identifier);
end)

RegisterNUICallback('profile', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-mdt:getProfile', function(profile)
        Wait(500); cb(profile);
    end, data.identifier);
end)

local animDict = "amb@world_human_seat_wall_tablet@female@base";
local tabletModel = GetHashKey('prop_cs_tablet');
local tabletObject = nil;


local Game = {};

Game.SpawnObject = function(model, coords, cb)
    local model = (type(model) == 'number' and model or GetHashKey(model))

    Citizen.CreateThread(function()
        RequestModel(model)
        local obj = CreateObject(model, coords.x, coords.y, coords.z, true, false, true)
        SetModelAsNoLongerNeeded(model)

        if cb then
            cb(obj)
        end
    end)
end

Game.DeleteObject = function(object)
    SetEntityAsMissionEntity(object, false, true)
    DeleteObject(object)
end

Game.RequestAnimDict = function(animDict, cb)
	if not HasAnimDictLoaded(animDict) then
		RequestAnimDict(animDict)

		while not HasAnimDictLoaded(animDict) do
			Wait(0)
		end
	end

	if cb ~= nil then
		cb()
	end
end


local function handleAnimation()
    Game.RequestAnimDict(animDict, function()
        local playerPed = PlayerPedId(); local playerCoords = GetEntityCoords(playerPed)

        Game.SpawnObject(tabletModel, playerCoords, function(_objectHandler)
            AttachEntityToEntity(_objectHandler, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.03, 0.0, 0.0, 0.0, 1, 1, 0, 1, 0, 1)

            tabletObject = _objectHandler;
    
            if not IsEntityPlayingAnim(playerPed, animDict, 'base', 3) then
                TaskPlayAnim(playerPed, animDict, 'base', 8.0, 1.0, -1, 49, 1.0, 0, 0, 0);
            end
        end, true)
    end)
end

RegisterNUICallback('closeUI', function(_, cb)
    if (tabletObject ~= nil and DoesEntityExist(tabletObject))  then
        Game.DeleteObject(tabletObject);
    end

    SetNuiFocus(false, false); ClearPedTasks(PlayerPedId()); cb('ok');
end)

RegisterNetEvent('qb-mdt:openUI')
AddEventHandler('qb-mdt:openUI', function(name)
    SetNuiFocus(true, true);
    SendNUIMessage({
        type = 'openUI',
        name = name,
        fines = Fines
    }); handleAnimation();
end)