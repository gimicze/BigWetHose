local dict = "core"
local streamParticles = "water_cannon_jet"
local splashParticles = "water_cannon_spray"
local ped = nil

local x, y, z = nil
local xx, yy, zz = nil

local ActiveEffects = {}
local pressed = false

local hoseNozzle = nil

local hasExtinguisher = false
local extinguisherAmmo = 0
local weaponHash = GetHashKey("WEAPON_FIREEXTINGUISHER")

function switchNozzle()
    local playerPed = GetPlayerPed(-1)
    if not hoseNozzle then
        if HasPedGotWeapon(playerPed, weaponHash, false) then
            SetCurrentPedWeapon(playerPed, weaponHash, true)
            hasExtinguisher = true
            extinguisherAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)
        else
            GiveWeaponToPed(playerPed, weaponHash, 2000, true, true)
        end
        SetPedCurrentWeaponVisible(playerPed, false, false, false, false)
        hoseNozzle = CreateObject(GetHashKey('prop_hose_nozzle'), 0, 0, 0, true, true, true)
        AttachEntityToEntity(hoseNozzle, playerPed, GetPedBoneIndex(playerPed, 57005), 0.15, 0.14, -0.03, 30.0, 260.0, 170.0, true, false, false, true, 1, true)
    else
        DeleteEntity(hoseNozzle)
        hoseNozzle = nil
        SetPedCurrentWeaponVisible(playerPed, true, false, false, false)
        SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
        if hasExtinguisher then
            hasExtinguisher = false
            SetPedAmmo(playerPed, weaponHash, extinguisherAmmo)
            extinguisherAmmo = 0
        else
            RemoveWeaponFromPed(playerPed, weaponHash)
        end
    end
end

RegisterCommand(
    "hose",
    function(source, args, raw) --change command here
        switchNozzle()
    end,
    false
)

RegisterNetEvent('baseevents:onPlayerDied')
AddEventHandler(
    'baseevents:onPlayerDied',
    function()
        if hoseNozzle ~= nil then
            switchNozzle()
        end
    end
)

RegisterNetEvent('onResourceStop')
AddEventHandler(
    'onResourceStop',
    function(resourceName)
        if resourceName == GetCurrentResourceName() and hoseNozzle ~= nil then
            switchNozzle()
        end
    end
)

Citizen.CreateThread(
    function()
        RequestNamedPtfxAsset(dict)

        while not HasNamedPtfxAssetLoaded(dict) do
            Citizen.Wait(0)
        end
        
        while true do
            Citizen.Wait(1)
            if hoseNozzle then
                if pressed then
                    Citizen.Wait(100)

                    SetParticleFxShootoutBoat(true)

                    local entity = GetCurrentPedWeaponEntityIndex(ped)
                    local multiplier = GetGameplayCamRelativePitch(ped) - GetEntityPitch(entity)
                    local distance = 10

                    if multiplier < 0 then
                        distance = distance + (-9 * (multiplier / -52.0))
                    elseif multiplier >= 0 and multiplier < 15 then
                        distance = distance + (10 * multiplier / 15)
                    else
                        distance = distance + (-9 * (multiplier - 15) / 45)
                    end

                    local off = GetOffsetFromEntityInWorldCoords(
                        entity,
                        distance,
                        -0.5,
                        0.0
                    )

                    local x = off.x
                    local y = off.y
                    local offZ = off.z

                    if offZ > GetEntityCoords(entity).z then
                        offZ = off.z - 2.0
                    end

                    local _, z = GetGroundZFor_3dCoord(x, y, offZ)

                    Citizen.Wait(distance * 10)

                    PlayEffect(dict, splashParticles, x, y, z)
                else
                    Citizen.Wait(0)
                end
            end
        end
    end
)

Citizen.CreateThread(
    function()
        local particleEffect = 0

        while true do
            Citizen.Wait(1)
            if hoseNozzle then
                if ped == nil then
                    ped = GetPlayerPed(-1)
                end
                local selectedWeapon = GetSelectedPedWeapon(ped)
                if selectedWeapon == weaponHash and (IsControlJustPressed(0, 24) or IsDisabledControlPressed(0, 24)) and not pressed then
                    ped = GetPlayerPed(-1)
                    pressed = true
                    UseParticleFxAssetNextCall(dict)
                    particleEffect = StartParticleFxLoopedOnEntity(
                        streamParticles,
                        GetCurrentPedWeaponEntityIndex(ped),
                        0.35,
                        0.0,
                        -0.15,
                        0.0,
                        0.0,
                        -90.0,
                        1.0,
                        false,
                        false,
                        false
                    )
                    TriggerServerEvent('hose:startParticleEffect')
                end
                if selectedWeapon == weaponHash then
                    DisablePlayerFiring(PlayerId(), true)
                    DisableControlAction(0, 24, true)
                    if pressed then
                        SetParticleFxLoopedOffsets(
                            particleEffect,
                            0.35,
                            0.0,
                            -0.15,
                            -25.0,
                            0.0,
                            -90.0
                        )
                    end
                end
                if (IsControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 24)) and pressed then
                    StopParticleFxLooped(particleEffect, 0)
                    pressed = false
                    TriggerServerEvent('hose:stopParticleEffect')
                end
                if selectedWeapon ~= weaponHash and hoseNozzle then
                    switchNozzle(ped)
                end
            end
        end
    end
)

RegisterNetEvent('hose:stopParticleEffect')
AddEventHandler(
    'hose:stopParticleEffect',
    function(playerId)
        local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
        if playerPed ~= GetPlayerPed(-1) then
            if ActiveEffects[playerPed] then
                StopParticleFxLooped(ActiveEffects[playerPed], 0)
            end
        end
    end
)

RegisterNetEvent('hose:startParticleEffect')
AddEventHandler(
    'hose:startParticleEffect',
    function(playerId)
        local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
        if playerPed ~= GetPlayerPed(-1) and playerPed ~= 0 then
            UseParticleFxAssetNextCall(dict)
            ActiveEffects[playerPed] = StartParticleFxLoopedOnEntity(
                streamParticles,
                GetCurrentPedWeaponEntityIndex(playerPed),
                0.35,
                0.0,
                -0.15,
                -25.0,
                0.0,
                -90.0,
                1.0,
                false,
                false,
                false
            )
        end
    end
)

Citizen.CreateThread(
    function()
        Citizen.Wait(1)
        for k, v in pairs(ActiveEffects) do
            UseParticleFxAssetNextCall(dict)
            ActiveEffects[k] = StartParticleFxLoopedOnEntity(
                streamParticles,
                GetCurrentPedWeaponEntityIndex(k),
                0.0,
                0.0,
                0.0,
                0.1,
                0.0,
                0.0,
                1.0,
                false,
                false,
                false
            )
        end
    end
)

function PlayEffect(pdict, pname, posx, posy, posz, ped)
    Citizen.CreateThread(
        function()
            local ped = ped or PlayerPedId()
            UseParticleFxAssetNextCall(pdict)
            local pfx = StartParticleFxLoopedAtCoord(
                pname,
                posx,
                posy,
                posz,
                0.0,
                0.0,
                GetEntityHeading(ped),
                1.0,
                false,
                false,
                false,
                false
            )
            Citizen.Wait(100)
            StopParticleFxLooped(pfx, 0)
        end
    )
end
