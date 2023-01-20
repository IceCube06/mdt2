local QBCore = exports['qb-core']:GetCoreObject()

local function getWarrants()
    local Warrants = {};

    local result = MySQL.Sync.fetchAll('SELECT * FROM `mdt_warrants`;', {});
    if type(result) == 'table' then
        for i=1, #result, 1 do
            local warrant = result[i];
            table.insert(Warrants, {
                id = warrant.id,
                label = warrant.label,
                description = warrant.description,
                name = warrant.name,
                date = warrant.date_added,
                expire = warrant.date_expires,
                author = warrant.author,
            })
        end
    end

    return Warrants;
end

QBCore.Functions.CreateCallback('qb-mdt:getFines', function(playerId, cb)
    cb(Fines);
end)

Citizen.CreateThread(function()
    Wait(2000)

    MySQL.query('SELECT `charinfo`, `citizenid` FROM `players` WHERE `phone_number` IS NULL;', {

    }, function(results)
        for i=1, #results, 1 do
            local identifier = results[i].citizenid; local phone = json.decode(results[i].charinfo).phone;
            local rowsChanged = MySQL.update.await('UPDATE `players` SET `phone_number`=? WHERE `citizenid`=?', {phone, identifier});
        end
    end)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    MySQL.Sync.execute('UPDATE `players` SET `firstname`=@firstname, `lastname`=@lastname WHERE citizenid=@identifier;', {
        ['@firstname'] = Player.PlayerData.charinfo.firstname,
        ['@lastname'] = Player.PlayerData.charinfo.lastname,
        ['@identifier'] = Player.PlayerData.citizenid
    });
end)

QBCore.Functions.CreateCallback('qb-mdt:getSearchResults', function(playerId, cb, query)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end


    if type(query) ~= 'string' then
        return false;
    end

    local results = {};

    local players = MySQL.query.await('SELECT `citizenid`, `charinfo`, `picture`, `job` FROM `players` WHERE CONCAT(LOWER(`firstname`), " ", LOWER(`lastname`)) LIKE @search OR `phone_number` LIKE @search;', {
        ['@search'] = '%' .. query .. '%'
    });

    if type(players) == 'table' then
        for _, v in pairs(players) do
            local charinfo = json.decode(v.charinfo);
            local job = json.decode(v.job);

            local metadata = MySQL.Sync.fetchScalar('SELECT `metadata` FROM `players` WHERE `citizenid` = ?;', {
                v.citizenid
            }); 

            metadata = json.decode(metadata);
            local licenses = metadata.licences;

            table.insert(results, {
                name = charinfo.firstname .. ' ' .. charinfo.lastname,
                type = 'citizen',
                identifier = v.citizenid,
                veh_license = licenses['driver'],
                gun_license = licenses['weapon'],
                sex = tonumber(charinfo.gender) == 0 and 'man' or 'woman',
                job = job.label,
                job_grade = job.grade.name,
                img = v.picture or ''
            });
        end
    end

    local vehicles = MySQL.Sync.fetchAll('SELECT `plate`, `citizenid`, `mods` FROM `player_vehicles` WHERE LOWER(`plate`) LIKE ?;', {
        '%' .. query .. '%' 
    });

    if type(vehicles) == 'table' then
        for _, v in pairs(vehicles) do
            local charInfo = MySQL.Sync.fetchScalar('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?;', {
                v.citizenid
            })

            charInfo = json.decode(charInfo)

            local vehicleProperties = json.decode(v.mods) or {};
            ownerName = charInfo.firstname .. ' ' .. charInfo.lastname;

            table.insert(results, {
                plate = v.plate,
                identifier = v.citizenid,
                owner = ownerName,
                sex = 'vehicle',
                color1 = VehicleColors[tonumber(vehicleProperties.color1)] or 'Teadmata',
                color2 = VehicleColors[tonumber(vehicleProperties.color2)],
                type = 'vehicle'
            });
        end
    end

    cb(results);
end)


QBCore.Functions.CreateCallback('qb-mdt:saveProfilePicture', function(playerId, cb, picture, identifier)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end
    
    if type(picture) ~= 'string' then
        return false;
    end

    local rowsChanged = MySQL.Sync.execute('UPDATE `players` SET `picture` = ? WHERE `citizenid` = ?;', {picture, identifier});

    cb(rowsChanged > 0);
end)

QBCore.Functions.CreateCallback('qb-mdt:getRecords', function(playerId, cb, identifier)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    local records = {};
    local data = MySQL.Sync.fetchAll('SELECT `description`, `date_added`, `author`, `fine_amount`, `fine_prison`, `fines` FROM `mdt_records` WHERE `identifier` = ?;', {
        identifier
    });

    if type(data) == 'table' then
        for _, v in pairs(data) do
            records[#records + 1] = {
                desc = v.description,
                time = v.date_added,
                amount = v.fine_amount,
                prison = v.fine_prison,
                author = v.author,
                extra_content = false,
                fines = json.decode(v.fines)
            };
        end
    end

    cb(records);
end)

QBCore.Functions.CreateCallback('qb-mdt:removeLicense', function(playerId, cb, license, identifier)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    --TODO Get player
--[[     local licenseTable = Player.PlayerData.metadata['licences'];
    licenseTable[license] = false;

    xPlayer.Functions.SetMetaData(licences, licenseTable); ]]

    cb(true);
end)

QBCore.Functions.CreateCallback('qb-mdt:getProfile', function(playerId, cb, identifier)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    if type(identifier) ~= 'string' then
        return false;
    end

    local profile = {};

    local user = MySQL.Sync.fetchAll('SELECT `charinfo`, `job`, `firstname`, `lastname`, `picture` FROM `players` WHERE `citizenid` = ?;', {
        identifier
    });

    if type(user) == 'table' then
        user = user[1];

        local charinfo = json.decode(user.charinfo); local job = json.decode(user.job);

        profile.name = user.firstname .. ' ' .. user.lastname;
        profile.dob = charinfo.birthdate;
        profile.phone = charinfo.phone;
        profile.job = job.label;
        profile.job_grade = job.grade.name;
        profile.img = user.picture;
    end

    local hasWarrant = MySQL.Sync.fetchScalar('SELECT `id` FROM `mdt_warrants` WHERE `identifier` = ?;', {
        identifier
    });

    profile.warrant = type(hasWarrant) == 'number';

    local metadata = MySQL.Sync.fetchScalar('SELECT `metadata` FROM `players` WHERE `citizenid` = ?;', {
        identifier
    }); 
    
    metadata = json.decode(metadata);

    local licenses = metadata.licences;
    profile.gun_license = licenses['weapon'];
    profile.veh_license = licenses['driver'];
   

    profile.identifier = identifier;

    local notes = MySQL.Sync.fetchScalar('SELECT `label` FROM `mdt_notes` WHERE `identifier` = ?;', {
        identifier
    })


    profile.warrants = getWarrants();
    
    profile.notes = tostring(notes or '');
    cb(profile)
end)

QBCore.Functions.CreateCallback('qb-mdt:getWarrants', function(playerId, cb, identifier, notes)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    cb(getWarrants())
end)

QBCore.Functions.CreateCallback('qb-mdt:saveNotes', function(playerId, cb, identifier, notes)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    local rowsChanged = MySQL.Sync.execute('INSERT INTO `mdt_notes` (`identifier`, `label`) VALUES (@owner, @label) ON DUPLICATE KEY UPDATE `label` = @label;', {
        ['@owner'] = identifier,
        ['@label'] = tostring(notes)
    });

    cb(rowsChanged > 0)
end)

local Houses = {};
Citizen.CreateThread(function()
    local houses = MySQL.Sync.fetchAll('SELECT `name`, `label` FROM `houselocations`;', {});
    if type(houses) == 'table' then
        for _, v in pairs(houses) do
            Houses[v.name] = v.label;
        end
    end
end)

QBCore.Functions.CreateCallback('qb-mdt:getAssets', function(playerId, cb, identifier, notes)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    local assets = {};
    local houses = MySQL.Sync.fetchAll('SELECT `house` FROM `player_houses` WHERE `identifier` = ?;', {
        identifier
    });

    if type(houses) == 'table' then
        for _, v in pairs(houses) do
            assets[#assets + 1] = {
                name = Houses[v.house] or 'Teadmata',
                type = 'property',
                rented = false --v.rented == 1
            };
        end
    end

    local vehicles = MySQL.Sync.fetchAll('SELECT `plate`, `hash`, `mods` FROM `player_vehicles` WHERE `citizenid` = ?;', {
        identifier 
    });

    if type(vehicles) == 'table' then
        for _, v in pairs(vehicles) do
            local vehicleProperties = json.decode(v.mods) or {};
            
            assets[#assets + 1] = {
                plate = v.plate,
                type = 'vehicle',
                color1 = VehicleColors[tonumber(vehicleProperties.color1)] or 'Teadmata',
                color2 = VehicleColors[tonumber(vehicleProperties.color2)],
                model = tonumber(vehicleProperties.model) or v.hash
            };
        end
    end

    cb(assets)
end)

RegisterCommand('mdt', function(source)
    local xPlayer = QBCore.Functions.GetPlayer(source);

    if xPlayer.PlayerData.job.name ~= 'police' then
        return
    end
    local name = xPlayer.PlayerData.charinfo.firstname.. ' ' .. xPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('qb-mdt:openUI', source, name)
end)


local Callouts = {};
RegisterNetEvent('qb-mdt:server:addCallout')
AddEventHandler('qb-mdt:server:addCallout', function(label, location)
    local callout = {
        label = label,
        date = os.date('%d.%m.%Y %H:%M:%S'),
        location = location,
        id = #Callouts + 1
    }

    table.insert(Callouts, callout);
    TriggerClientEvent('qb-mdt:client:addCallout', -1, callout);
end)

QBCore.Functions.CreateCallback('qb-mdt:addWarrant', function(playerId, cb, data)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())

    local rowsChanged = MySQL.Sync.execute('INSERT INTO `mdt_warrants` (`identifier`, `description`, `name`, `date_added`, `date_expires`, `author`) VALUES (@identifier, @description, @name, @date_added, @date_expires, @author);', {
        ['identifier'] = data.identifier,
        ['@description'] = data.description,
        ['@name'] = data.name,
        ['@date_added'] = data.date,
        ['@date_expires'] = data.expire,
        ['@author'] = xPlayer.PlayerData.charinfo.firstname.. ' ' .. xPlayer.PlayerData.charinfo.lastname
    });

    local warrantId = MySQL.Sync.fetchScalar('SELECT `id` FROM `mdt_warrants` WHERE `identifier` = ? ORDER BY `id` DESC LIMIT 1;', {
        data.identifier
    });

    cb({
        success = rowsChanged > 0,
        id = warrantId,
        author = xPlayer.PlayerData.charinfo.firstname.. ' ' .. xPlayer.PlayerData.charinfo.lastname
    })
end)


QBCore.Functions.CreateCallback('qb-mdt:removeWarrant', function(playerId, cb, warrantId)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    local rowsChanged = MySQL.Sync.execute('DELETE FROM `mdt_warrants` WHERE `id` = ?;', {
        tonumber(warrantId)
    });

    cb(rowsChanged > 0)
end)

QBCore.Functions.CreateCallback('qb-mdt:addRecord', function(playerId, cb, data)
    local xPlayer = QBCore.Functions.GetPlayer(playerId);
    if xPlayer.PlayerData.job.name ~= 'police' then return; end

    local dateString = os.date('%m-%d-%Y %H:%M:%S', os.time());

    local fineLabel = '';
    for _, v in pairs(data.fines) do
        fineLabel = v.label;
        break;
    end

    local fineAmount = tonumber(data.fine) or 0;
    local prisonTime = tonumber(data.prison) or 0;

    local rowsChanged = MySQL.Sync.execute('INSERT INTO `mdt_records` (`identifier`, `fines`, `description`, `fine_prison`, `fine_amount`, `date_added`, `author`) VALUES (?, ?, ?, ?, ?, ?, ?);', {
        data.identifier,
        json.encode(data.fines),
        tostring(data.desc),
        prisonTime,
        fineAmount,
        dateString,
        xPlayer.PlayerData.charinfo.firstname.. ' ' .. xPlayer.PlayerData.charinfo.lastname
    });

    local tPlayer = QBCore.Functions.GetPlayerByCitizenId(data.identifier);
    local xTarget = QBCore.Functions.GetPlayer(tPlayer.PlayerData.source);
    
     if xTarget and fineAmount >= 0 then
        MySQL.Sync.execute(
            'INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)',
            {xTarget.PlayerData.citizenid, fineAmount, xPlayer.PlayerData.job.name,
            xPlayer.PlayerData.charinfo.firstname, xPlayer.PlayerData.citizenid})
            TriggerClientEvent('qb-phone:RefreshPhone', xTarget.PlayerData.source)
            TriggerClientEvent('QBCore:Notify', xPlayer.PlayerData.source, 'Arve edukalt saadetud', 'success')
            TriggerClientEvent('QBCore:Notify', xTarget.PlayerData.source, 'Sul on telefonis uus arve!')
        if prisonTime > 0 then
	        xTarget.Functions.SetMetaData("injail", prisonTime)
            TriggerClientEvent("police:client:SendToJail", xTarget.PlayerData.source, prisonTime)
        end
    end 

    cb(rowsChanged > 0)
end)