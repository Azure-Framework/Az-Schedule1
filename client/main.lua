

local RES = GetCurrentResourceName()

Config = Config or {}
local json = json


Config.Place = Config.Place or {}
Config.Place.RotateStep     = tonumber(Config.Place.RotateStep or 5.0) or 5.0
Config.Place.MaxDistance    = tonumber(Config.Place.MaxDistance or 3.0) or 3.0
Config.Place.RotateLeftKey  = Config.Place.RotateLeftKey  or 174
Config.Place.RotateRightKey = Config.Place.RotateRightKey or 175
Config.Place.CancelKey      = Config.Place.CancelKey      or 177
Config.Place.ConfirmKey     = Config.Place.ConfirmKey     or 38

Config.InteractKey       = Config.InteractKey or 38
Config.DrawDistance      = tonumber(Config.DrawDistance or 8.0) or 8.0
Config.InteractDistance  = tonumber(Config.InteractDistance or 2.0) or 2.0

Config.Props = Config.Props or {}


if Config.PlantModelsPotted == nil then
  Config.PlantModelsPotted = true
end


Config.ToolYawOffset = Config.ToolYawOffset or {}
if Config.ToolYawOffset.water == nil then Config.ToolYawOffset.water = -90.0 end
if Config.ToolYawOffset.fert  == nil then Config.ToolYawOffset.fert  = 0.0 end

Config.ToolYawFlip = Config.ToolYawFlip or {}
if Config.ToolYawFlip.water == nil then Config.ToolYawFlip.water = true end

Config.ToolTiltInvert = Config.ToolTiltInvert or {}
if Config.ToolTiltInvert.water == nil then Config.ToolTiltInvert.water = true end


local function clamp(v, mn, mx)
  v = tonumber(v) or 0.0
  mn = tonumber(mn) or 0.0
  mx = tonumber(mx) or 0.0
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end


_G.clamp = clamp

local function modelHash(model)
  return type(model) == "string" and GetHashKey(model) or model
end

local function ensureModel(model)
  local m = modelHash(model)
  if not IsModelInCdimage(m) then return false end
  RequestModel(m)
  local t = GetGameTimer() + 5000
  while not HasModelLoaded(m) and GetGameTimer() < t do Wait(0) end
  return HasModelLoaded(m)
end


local function ensureAnyModel(models)
  if models == nil then return nil end
  local t = type(models)
  if t == "string" or t == "number" then
    if ensureModel(models) then return models end
    return nil
  end
  if t ~= "table" then return nil end
  for _, m in ipairs(models) do
    if m ~= nil and m ~= "" and ensureModel(m) then
      return m
    end
  end
  return nil
end

local function deleteEntitySafe(ent)
  if ent and ent ~= 0 and DoesEntityExist(ent) then
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
  end
end

local function list_remove(t, val)
  if type(t) ~= "table" then return false end
  for i = #t, 1, -1 do
    if t[i] == val then
      table.remove(t, i)
      return true
    end
  end
  return false
end


local function modelBaseZ(mhash, baseZ)
  baseZ = tonumber(baseZ or 0.0) or 0.0
  local ok = IsModelInCdimage(mhash)
  if not ok then return baseZ end
  local minDim, maxDim = GetModelDimensions(mhash)
  if minDim then
    return baseZ - (minDim.z or 0.0)
  end
  return baseZ
end


local function stageFromGrowth(g)
  g = tonumber(g or 0) or 0
  if g < 34 then return 1 elseif g < 75 then return 2 else return 3 end
end

local function stageModelForPot(pot)
  if not pot or not pot.strain or pot.dead then return nil end
  local stage = stageFromGrowth(pot.growth)


  local pm = Config.PlantModels or {}
  local custom = (stage==1 and pm.stage1) or (stage==2 and pm.stage2) or (stage==3 and pm.stage3)


  local candidates = {}
  if custom then table.insert(candidates, custom) end

  if stage == 1 then
    table.insert(candidates, "bkr_prop_weed_01_small_01c")
    table.insert(candidates, "bkr_prop_weed_01_small_01a")
  elseif stage == 2 then

    table.insert(candidates, "sf_prop_sf_weed_med_01a")
    table.insert(candidates, "bkr_prop_weed_01_med_01b")
    table.insert(candidates, "bkr_prop_weed_01_med_01a")
  else

    table.insert(candidates, "bkr_prop_weed_lrg_01a")
    table.insert(candidates, "bkr_prop_weed_lrg_01b")
  end

  return candidates, stage
end


local WEED_STAGE_HASHES = {
  [GetHashKey("bkr_prop_weed_01_small_01c")] = true,
  [GetHashKey("bkr_prop_weed_01_small_01a")] = true,
  [GetHashKey("bkr_prop_weed_01_med_01b")]   = true,
  [GetHashKey("bkr_prop_weed_01_med_01a")]   = true,
  [GetHashKey("sf_prop_sf_weed_med_01a")]    = true,
  [GetHashKey("bkr_prop_weed_lrg_01a")]      = true,
  [GetHashKey("bkr_prop_weed_lrg_01b")]      = true,
}

local function isWeedStageModelHash(h)
  return WEED_STAGE_HASHES[h] == true
end


local function plantStageZOffset(stage)
  local o = Config and Config.PlantStageZOffset
  if type(o) == "table" then
    return tonumber(o[stage] or o.default or 0.0) or 0.0
  end
  return tonumber(o or 0.0) or 0.0
end


local World = { pots = {}, lamps = {}, tables = {} }
local PlayerData = nil


local Spawned = { pots = {}, potModel = {}, lamps = {}, tables = {}, dirt = {} }


local nuiOpen = false
local currentContext = nil
local currentPotId = nil
local currentTableId = nil


local placing = { active=false, kind=nil, ghost=nil, heading=0.0 }


local duiObj, duiHandle
local txdName, txnName
local mixTvEntity = nil
local mixRtId = nil


local bagCam = nil
local plantCam = nil

local bagScene = {
  tableEnt = nil,
  tableId = nil,
  buds = {},
  emptyBags = {},
  filledBags = {},
  outputBags = {},
  held = nil, heldType = nil, heldKey = nil,
  activeBag = nil,
  home = {},
  pickPos = {},
  slots = {},
  outputOccupied = {},
  dragDown = false,
  lastMouseEventAt = 0,
}

local mouse = { x=0, y=0, down=false }

local plantScene = {
  pot=nil,
  tools={},
  held=nil, heldType=nil, heldKey=nil,
  heldAxis=nil, heldRotZ=nil,
  tilt=0.0, pourMs=0, pouring=false, lastTick=0,
  ptfx=nil, ptfxType=nil,
  didUse=false
}


local potAction = { active=false, token=0 }


local destroyBagScene
local spawnPlantTool
local stopPourFx
local getToolPourOffset
local _bag_reset_items
local _bag_load_selection
local _bag_cfg
local _bag_spawn_on_plane


local function dbg(fmt, ...)
  if not Config.Debug then return end
  local ok, msg = pcall(string.format, fmt, ...)
  if ok then print(("[Az-Schedule1:CLIENT] %s"):format(msg)) end
end

local function notify(msg)
  BeginTextCommandThefeedPost("STRING")
  AddTextComponentSubstringPlayerName(tostring(msg))
  EndTextCommandThefeedPostTicker(false, false)
end
RegisterNetEvent("azs1:notify", function(msg) notify(msg) end)


local function getToolAxis(ttype)
  if Config and Config.ToolTiltAxis and Config.ToolTiltAxis[ttype] then
    return tostring(Config.ToolTiltAxis[ttype])
  end


  if ttype == "water" then
    return "y"
  end

  return "x"
end

local function headingTo(from, to)
  local dx = (to.x - from.x)
  local dy = (to.y - from.y)
  if math.abs(dx) < 0.0001 and math.abs(dy) < 0.0001 then return 0.0 end
  return GetHeadingFromVector_2d(dx, dy)
end

local function dist2D(a, b)
  local dx = (a.x - b.x)
  local dy = (a.y - b.y)
  return math.sqrt(dx*dx + dy*dy)
end


local function applyToolRotation(ent, axis, tilt, zRot, invertTilt)
  if not ent or not DoesEntityExist(ent) then return end
  axis = axis or "x"
  tilt = tonumber(tilt or 0.0) or 0.0
  zRot = tonumber(zRot or 0.0) or 0.0
  if invertTilt then tilt = -tilt end

  local rx, ry, rz = 0.0, 0.0, zRot
  if axis == "y" then
    ry = tilt
  elseif axis == "z" then
    rz = zRot + tilt
  else
    rx = tilt
  end
  SetEntityRotation(ent, rx, ry, rz, 2, true)
end

local function ensurePtfxAsset(asset)
  if HasNamedPtfxAssetLoaded(asset) then return true end
  RequestNamedPtfxAsset(asset)
  local t = GetGameTimer() + 2000
  while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(0) end
  return HasNamedPtfxAssetLoaded(asset)
end

getToolPourOffset = function(ttype)

  if Config and Config.ToolPourOffsets and Config.ToolPourOffsets[ttype] then
    return Config.ToolPourOffsets[ttype]
  end


  if ttype == "water" then return vector3(0.62, 0.02, 0.18) end
  if ttype == "fert"  then return vector3(0.22, 0.00, 0.14) end
  if ttype == "dirt"  then return vector3(0.30, 0.00, 0.18) end
  if ttype == "seed"  then return vector3(0.24, 0.00, 0.14) end
  return vector3(0.25, 0.0, 0.12)
end

local function startPourFx(ttype, ent)
  if not ent or not DoesEntityExist(ent) then return nil end
  local asset = "core"
  local fx = nil
  if ttype == "water" or ttype == "fert" then
    fx = "ent_sht_water"
  elseif ttype == "dirt" then
    fx = "ent_sht_dust"
  end
  if not fx then return nil end
  if not ensurePtfxAsset(asset) then return nil end
  local off = getToolPourOffset(ttype)
  UseParticleFxAssetNextCall(asset)
  local h = StartParticleFxLoopedOnEntity(fx, ent, off.x, off.y, off.z, 0.0, 0.0, 0.0, 0.7, false, false, false)
  return h ~= 0 and h or nil
end

stopPourFx = function(handle)
  if handle then
    StopParticleFxLooped(handle, 0)
  end
end


local function destroyAllCams()
  local did = false
  if bagCam and DoesCamExist(bagCam) then
    DestroyCam(bagCam, false)
    bagCam = nil
    did = true
  end
  if plantCam and DoesCamExist(plantCam) then
    DestroyCam(plantCam, false)
    plantCam = nil
    did = true
  end
  if plantScene and plantScene.ptfx then
    stopPourFx(plantScene.ptfx)
    plantScene.ptfx = nil
    plantScene.ptfxType = nil
  end
  if did then
    RenderScriptCams(false, true, 250, true, true)
  end
end

local function DrawText3D(x, y, z, text)
  local on, _x, _y = World3dToScreen2d(x, y, z)
  if not on then return end
  SetTextScale(0.35, 0.35)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(255,255,255,215)
  SetTextEntry("STRING")
  SetTextCentre(1)
  AddTextComponentString(text)
  DrawText(_x, _y)
end


local function drawText2D(x, y, text, scale, font, center, r, g, b, a)
  x = tonumber(x or 0.5) or 0.5
  y = tonumber(y or 0.5) or 0.5
  scale = tonumber(scale or 0.35) or 0.35
  font = tonumber(font or 4) or 4
  if center == nil then center = true end
  r = tonumber(r or 255) or 255
  g = tonumber(g or 255) or 255
  b = tonumber(b or 255) or 255
  a = tonumber(a or 215) or 215

  SetTextFont(font)
  SetTextProportional(1)
  SetTextScale(scale, scale)
  SetTextColour(r, g, b, a)
  SetTextDropshadow(0, 0, 0, 0, 255)
  SetTextEdge(2, 0, 0, 0, 150)
  SetTextDropShadow()
  SetTextOutline()
  SetTextCentre(center and 1 or 0)

  SetTextEntry("STRING")
  AddTextComponentSubstringPlayerName(tostring(text or ""))
  DrawText(x, y)
end


_G.drawText2D = drawText2D

local function rotStep(dir)
  placing.heading = (placing.heading + (Config.Place.RotateStep or 5.0) * dir) % 360.0
end


local function raycastFromCamera(dist, flags)
  local camCoord = GetGameplayCamCoord()
  local camRot = GetGameplayCamRot(2)
  local rx, rz = math.rad(camRot.x), math.rad(camRot.z)
  local dx = -math.sin(rz) * math.abs(math.cos(rx))
  local dy =  math.cos(rz) * math.abs(math.cos(rx))
  local dz =  math.sin(rx)
  local dest = camCoord + vector3(dx, dy, dz) * dist

  flags = tonumber(flags) or (1 + 8)
  local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, flags, PlayerPedId(), 0)
  local _, hit, endCoords, _, _ = GetShapeTestResult(ray)

  if hit == 1 then
    return true, endCoords, nil
  end

  local ped = PlayerPedId()
  local fwd = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
  local ok, gz = GetGroundZFor_3dCoord(fwd.x, fwd.y, fwd.z + 5.0, 0)
  if ok then
    return true, vector3(fwd.x, fwd.y, gz), nil
  end

  return false, dest, nil
end


local function potBasis(pot)
  local h = math.rad(pot.h or 0.0)
  local forward = vector3(-math.sin(h), math.cos(h), 0.0)
  local right = vector3(math.cos(h), math.sin(h), 0.0)
  return forward, right
end


local function plantInteractCfg()
  Config = Config or {}
  Config.PlantInteract = Config.PlantInteract or {}
  return Config.PlantInteract
end


local function getToolTiltRequired(ttype)
  local cfg = plantInteractCfg()
  local req = cfg.TiltRequired
  if type(req) == "table" and req[ttype] ~= nil then
    return tonumber(req[ttype]) or 55.0
  end
  if ttype == "water" then return 35.0 end
  return 55.0
end

local function getToolPourDistance(ttype)
  local cfg = plantInteractCfg()
  local d = cfg.PourDistance
  if type(d) == "table" and d[ttype] ~= nil then
    return tonumber(d[ttype]) or 0.23
  end
  if ttype == "water" then return 0.34 end
  return 0.23
end

local function getToolPlaneZ()
  local cfg = plantInteractCfg()
  return tonumber(cfg.ToolPlaneZ or 0.85) or 0.85
end

local function getPotPourZ()
  local cfg = plantInteractCfg()
  return tonumber(cfg.PotPourZ or 0.67) or 0.67
end

local function getPotFrame(potId)
  local pot = World.pots[potId]
  if not pot then return nil end

  local ent = Spawned.pots and Spawned.pots[potId] or nil
  local c = vector3(pot.x, pot.y, pot.z)
  local h = pot.h or 0.0
  if ent and ent ~= 0 and DoesEntityExist(ent) then
    c = GetEntityCoords(ent)
    h = GetEntityHeading(ent)
  end

  local rad = math.rad(h)
  local fwd = vector3(-math.sin(rad), math.cos(rad), 0.0)
  local rgt = vector3(math.cos(rad), math.sin(rad), 0.0)
  return pot, c, fwd, rgt
end

local function playAutoPropPour(potId, propModel, durationMs, fireAtPct, onFire)
  local pot, c, fwd, rgt = getPotFrame(potId)
  if not pot then return false end
  if not propModel or not ensureModel(propModel) then return false end

  local cfg = plantInteractCfg()
  local off = cfg.AutoPropOffset or { x=0.08, y=-0.22, z=0.58 }
  local base = c + (rgt * (tonumber(off.x) or 0.08)) + (fwd * (tonumber(off.y) or -0.22)) + vector3(0.0, 0.0, (tonumber(off.z) or 0.58))

  local prop = CreateObject(modelHash(propModel), base.x, base.y, base.z, false, false, false)
  if not prop or prop == 0 then return false end
  SetEntityCollision(prop, false, false)
  SetEntityInvincible(prop, true)
  SetEntityAsMissionEntity(prop, true, true)

  local start = GetGameTimer()
  local fired = false
  local firePct = tonumber(fireAtPct or 0.6) or 0.6
  durationMs = tonumber(durationMs or 1200) or 1200
  local yaw = (pot.h or 0.0) + 90.0

  while true do
    Wait(0)

    if not nuiOpen or currentContext ~= "plant_sidebar" or currentPotId ~= potId then
      break
    end

    local now = GetGameTimer()
    local t = (now - start) / durationMs
    if t >= 1.0 then break end

    local bob = math.sin(t * math.pi) * 0.02
    local slide = t * 0.10
    local p = base + (fwd * slide) + vector3(0.0, 0.0, bob)
    SetEntityCoordsNoOffset(prop, p.x, p.y, p.z, false, false, false)

    local pitch = -85.0 * math.min(1.0, t * 1.15)
    SetEntityRotation(prop, pitch, 0.0, yaw, 2, true)

    if (not fired) and t >= firePct then
      fired = true
      if onFire then pcall(onFire) end
    end
  end

  deleteEntitySafe(prop)
  return true
end

local function startPotAutoAction(potId, action, extra)
  local cfg = plantInteractCfg()
  if cfg.AutoActions == false then return false end
  if potAction.active then return false end

  potId = tostring(potId or "")
  if potId == "" or not World.pots[potId] then return false end

  potAction.active = true
  potAction.token = potAction.token + 1
  local myToken = potAction.token

  CreateThread(function()
    local duration = (cfg.DurationMs and cfg.DurationMs[action]) or 1200

    local function finish()
      if potAction.token == myToken then
        potAction.active = false
      end
    end

    local function resync()
      TriggerServerEvent("azs1:player:request")
    end

    if action == "dirt" then
      local model = (Config.Props and Config.Props.dirt) or "prop_cs_sack_01"
      playAutoPropPour(potId, model, duration, 0.62, function()
        TriggerServerEvent("azs1:pot:addDirt", potId)
        resync()
      end)

    elseif action == "seed" then
      local strainKey = extra and tostring(extra.strainKey or "") or ""
      local model = (Config.Props and Config.Props.seedBag) or "prop_weed_bottle"
      playAutoPropPour(potId, model, duration, 0.58, function()
        if strainKey ~= "" then
          TriggerServerEvent("azs1:pot:plant", potId, strainKey)
          resync()
        end
      end)

    elseif action == "water" then
      local model = (Config.Props and Config.Props.waterBottle) or "prop_wateringcan"
      local delta = (cfg.AutoDelta and tonumber(cfg.AutoDelta.water or 25.0)) or 25.0
      playAutoPropPour(potId, model, duration, 0.52, function()
        TriggerServerEvent("azs1:pot:waterPour", potId, delta)
        resync()
      end)

    elseif action == "fert" then
      local model = (Config.Props and Config.Props.fertBottle) or "prop_ld_flow_bottle"
      local delta = (cfg.AutoDelta and tonumber(cfg.AutoDelta.fert or 25.0)) or 25.0
      playAutoPropPour(potId, model, duration, 0.52, function()
        TriggerServerEvent("azs1:pot:fertPour", potId, delta)
        resync()
      end)

    elseif action == "trim" then
      local model = (Config.Props and Config.Props.secateurs) or "prop_secateurs_01"
      playAutoPropPour(potId, model, duration, 0.55, function()
        TriggerServerEvent("azs1:pot:trim", potId)
        resync()
      end)

    elseif action == "harvest" then
      local model = (Config.Props and Config.Props.secateurs) or "prop_secateurs_01"
      playAutoPropPour(potId, model, duration, 0.60, function()
        TriggerServerEvent("azs1:pot:harvest", potId)
        resync()
      end)
    end

    finish()
  end)

  return true
end


local function destroyPlantScene()
  if plantScene and plantScene.tools then
    for _, t in ipairs(plantScene.tools) do
      if t.ent then deleteEntitySafe(t.ent) end
    end
  end
  plantScene = {
    pot=nil,
    tools={},
    held=nil, heldType=nil, heldKey=nil,
    heldAxis=nil, heldRotZ=nil,
    tilt=0.0, pourMs=0, pouring=false, lastTick=0,
    ptfx=nil, ptfxType=nil,
    didUse=false
  }
end


local function nuiSend(action, data)
  SendNUIMessage({ action = action, data = data })
end

local function openNui(ctx, payload)
  nuiOpen = true
  currentContext = ctx

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(true)
  SetPlayerControl(PlayerId(), false, 0)
  FreezeEntityPosition(PlayerPedId(), true)

  TriggerServerEvent("azs1:player:request")

  local p = payload or {}
  CreateThread(function()
    for _, w in ipairs({0, 50, 250, 750}) do
      Wait(w)
      if nuiOpen and currentContext == ctx then
        nuiSend("open", { context = ctx, payload = p })
      end
    end
  end)
end

local function closeNui()
  if currentContext == "bag_scene" then
    if destroyBagScene then destroyBagScene() end
  elseif currentContext == "plant_sidebar" then
    destroyPlantScene()
  end

  destroyAllCams()

  nuiOpen = false
  currentContext = nil
  currentPotId = nil
  currentTableId = nil

  SendNUIMessage({ action = "close" })
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)

  SetPlayerControl(PlayerId(), true, 0)
  FreezeEntityPosition(PlayerPedId(), false)
end


local function registerNui(name, handler)
  RegisterNUICallback(name, function(data, cb)
    data = data or {}
    local responded = false
    local function reply(payload)
      if responded then return end
      responded = true
      cb(payload or { ok = true })
    end

    local ok, err = pcall(handler, data, reply)
    if not ok then
      print(("[Az-Schedule1:CLIENT] NUI cb '%s' error: %s"):format(name, tostring(err)))
      reply({ ok = false, error = tostring(err) })
      return
    end

    if not responded then
      reply({ ok = true })
    end
  end)
end

registerNui("close", function(_, reply)
  closeNui()
  reply({ ok = true })
end)


registerNui("shop_buy", function(data, reply)
  TriggerServerEvent("azs1:shop:buy", data.item)
  reply({ ok = true })
end)


registerNui("place_start", function(data, reply)
  local kind = tostring(data.kind or "")
  if kind == "pots" or kind == "lamps" or kind == "tables" then
    placing.active = true
    placing.kind = kind
    placing.heading = GetEntityHeading(PlayerPedId())
    reply({ ok = true })
  else
    reply({ ok = false })
  end
end)


registerNui("pot_add_dirt", function(data, reply)
  spawnPlantTool(data.potId or currentPotId, "dirt", nil)
  reply({ ok = true })
end)

registerNui("pot_plant", function(data, reply)
  local key = tostring(data.strainKey or "")
  if key ~= "" then
    spawnPlantTool(data.potId or currentPotId, "seed", key)
  end
  reply({ ok = true })
end)

registerNui("pot_water", function(data, reply)
  spawnPlantTool(data.potId or currentPotId, "water", nil)
  reply({ ok = true })
end)

registerNui("pot_fert", function(data, reply)
  spawnPlantTool(data.potId or currentPotId, "fert", nil)
  reply({ ok = true })
end)

registerNui("pot_trim", function(data, reply)
  spawnPlantTool(data.potId or currentPotId, "trim", nil)
  reply({ ok = true })
end)

registerNui("pot_harvest", function(data, reply)
  spawnPlantTool(data.potId or currentPotId, "harvest", nil)
  reply({ ok = true })
end)


registerNui("bag_one", function(data, reply)
  TriggerServerEvent("azs1:bag:one", data.strainKey)
  reply({ ok = true })
end)


local function spawnPot(pot)
  local id = pot.id


  local basePotModel = (Config.Props and Config.Props.pot) or "prop_pot_plant_05a"
  local wantCandidates = basePotModel
  local isPottedStage = false
  local stageNum = nil

  if Config.PlantModelsPotted and pot.strain and not pot.dead then
    local stageCandidates, st = stageModelForPot(pot)
    if stageCandidates then
      wantCandidates = stageCandidates
      isPottedStage = true
      stageNum = st
    end
  end


  local chosenModel = ensureAnyModel(wantCandidates)
  if not chosenModel then return end

  local wantHash = modelHash(chosenModel)

  local ent = Spawned.pots[id]
  if ent and ent ~= 0 and DoesEntityExist(ent) then
    if Spawned.potModel[id] ~= wantHash then

      deleteEntitySafe(ent)
      Spawned.pots[id] = nil
      Spawned.potModel[id] = nil
      ent = nil
    end
  end

  if not (ent and ent ~= 0 and DoesEntityExist(ent)) then
    local z = pot.z


    if isPottedStage and isWeedStageModelHash(wantHash) then
      z = (pot.z or 0.0) + plantStageZOffset(stageNum or 3)
    else
      z = modelBaseZ(wantHash, pot.z)
    end

    ent = CreateObject(wantHash, pot.x, pot.y, z, false, false, false)
    if ent and ent ~= 0 then
      SetEntityAsMissionEntity(ent, true, true)
      SetEntityInvincible(ent, true)
      FreezeEntityPosition(ent, true)
      Spawned.pots[id] = ent
      Spawned.potModel[id] = wantHash
    end
  end

  if not (ent and ent ~= 0 and DoesEntityExist(ent)) then return end


  local zNow = pot.z
  if isPottedStage and isWeedStageModelHash(wantHash) then
    zNow = (pot.z or 0.0) + plantStageZOffset(stageNum or 3)
  else
    zNow = modelBaseZ(wantHash, pot.z)
  end

  SetEntityCoordsNoOffset(ent, pot.x, pot.y, zNow, false, false, false)
  SetEntityHeading(ent, pot.h or 0.0)


  if isPottedStage then
    if Spawned.dirt[id] then
      deleteEntitySafe(Spawned.dirt[id])
      Spawned.dirt[id] = nil
    end
    return
  end

  if pot.hasDirt then
    local d = Spawned.dirt[id]
    if not (d and d ~= 0 and DoesEntityExist(d)) then
      local soilList = nil
      if Config and Config.Props then
        soilList = Config.Props.potSoil or Config.Props.soil
      end


      local soilModel = ensureAnyModel(soilList or {
        "bkr_prop_weed_dirt_01a",
        "bkr_prop_weed_dirt_01b",
        "bkr_prop_weed_soil_01a",
      })

      if soilModel then
        local ec = GetEntityCoords(ent)
        d = CreateObject(modelHash(soilModel), ec.x, ec.y, ec.z + 0.02, false, false, false)
        SetEntityAsMissionEntity(d, true, true)
        SetEntityInvincible(d, true)
        SetEntityCollision(d, false, false)
        FreezeEntityPosition(d, true)

        local off = (Config and Config.Props and Config.Props.potSoilOffset) or vector3(0.0, 0.0, 0.02)
        AttachEntityToEntity(d, ent, 0, off.x, off.y, off.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

        if SetEntityScale then
          local s = tonumber((Config and Config.Props and Config.Props.potSoilScale) or 0.65) or 0.65
          SetEntityScale(d, s, s, s)
        end

        Spawned.dirt[id] = d
      end
    end
  else
    if Spawned.dirt[id] then
      deleteEntitySafe(Spawned.dirt[id])
      Spawned.dirt[id] = nil
    end
  end
end

local function despawnMissing(kind, map)
  for id, ent in pairs(map) do
    if not World[kind][id] then
      deleteEntitySafe(ent)
      map[id] = nil

      if kind == "pots" then
        if Spawned.dirt[id] then
          deleteEntitySafe(Spawned.dirt[id])
          Spawned.dirt[id] = nil
        end

        local pk = "plant_"..id
        if Spawned[pk] then
          deleteEntitySafe(Spawned[pk])
          Spawned[pk] = nil
        end
      end
    end
  end
end


local function refreshPlantsOnPots()
  if Config.PlantModelsPotted then
    for id, _ in pairs(World.pots) do
      local k = "plant_"..id
      if Spawned[k] and DoesEntityExist(Spawned[k]) then
        deleteEntitySafe(Spawned[k])
        Spawned[k] = nil
      end
    end
    return
  end

  for id, pot in pairs(World.pots) do
    local entPot = Spawned.pots[id]
    if entPot and DoesEntityExist(entPot) then
      if Spawned["plant_"..id] and DoesEntityExist(Spawned["plant_"..id]) then
        deleteEntitySafe(Spawned["plant_"..id])
        Spawned["plant_"..id] = nil
      end

      if pot.strain and not pot.dead then
        local growth = tonumber(pot.growth or 0) or 0
        local stage = stageFromGrowth(growth)

        local model = (Config.PlantModels and (stage==1 and Config.PlantModels.stage1 or stage==2 and Config.PlantModels.stage2 or Config.PlantModels.stage3))
          or "bkr_prop_weed_01_small_01c"

        if ensureModel(model) then
          local zOff = 0.42
          if type(Config.PlantOffsetZ) == "table" then
            zOff = tonumber(Config.PlantOffsetZ[stage]) or tonumber(Config.PlantOffsetZ.default) or zOff
          elseif type(Config.PlantOffsetZ) == "number" then
            zOff = tonumber(Config.PlantOffsetZ) or zOff
          end

          local plant = CreateObject(modelHash(model), pot.x, pot.y, pot.z + zOff, false, false, false)
          SetEntityHeading(plant, pot.h or 0.0)
          FreezeEntityPosition(plant, true)
          SetEntityInvincible(plant, true)
          SetEntityAsMissionEntity(plant, true, true)
          Spawned["plant_"..id] = plant
        end
      end
    end
  end
end

local function spawnLamp(lamp)
  local id = lamp.id
  if Spawned.lamps[id] and DoesEntityExist(Spawned.lamps[id]) then return end
  local model = (Config.Props and Config.Props.growLamp) or "prop_worklight_03b"
  if ensureModel(model) then
    local mh = modelHash(model)
    local z = modelBaseZ(mh, lamp.z)
    local ent = CreateObject(mh, lamp.x, lamp.y, z, false, false, false)
    SetEntityHeading(ent, lamp.h or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityInvincible(ent, true)
    SetEntityAsMissionEntity(ent, true, true)
    Spawned.lamps[id] = ent
  end
end

local function spawnTable(t)
  local id = t.id
  if Spawned.tables[id] and DoesEntityExist(Spawned.tables[id]) then return end
  local model = (Config.Props and Config.Props.bagTable) or "prop_table_03"
  if ensureModel(model) then
    local mh = modelHash(model)
    local z = modelBaseZ(mh, t.z)
    local ent = CreateObject(mh, t.x, t.y, z, false, false, false)
    SetEntityHeading(ent, t.h or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityInvincible(ent, true)
    SetEntityAsMissionEntity(ent, true, true)
    Spawned.tables[id] = ent
  end
end

RegisterNetEvent("azs1:world:sync", function(w)
  World = w or { pots = {}, lamps = {}, tables = {} }

  for _, pot in pairs(World.pots) do spawnPot(pot) end
  for _, lamp in pairs(World.lamps) do spawnLamp(lamp) end
  for _, t in pairs(World.tables) do spawnTable(t) end

  despawnMissing("pots", Spawned.pots)
  despawnMissing("lamps", Spawned.lamps)
  despawnMissing("tables", Spawned.tables)

  refreshPlantsOnPots()

  if nuiOpen and currentContext == "plant_sidebar" and currentPotId then
    nuiSend("pot_update", World.pots[currentPotId])
  end
end)

RegisterNetEvent("azs1:player:sync", function(pdata)
  PlayerData = pdata
  if nuiOpen then nuiSend("player", PlayerData) end

  if nuiOpen and currentContext == "inventory" then
    nuiSend("open", { context = "inventory", payload = { player = PlayerData, strains = Config.Strains, sellPrices = Config.SellPrices, moneySystem = Config.MoneySystem } })
  end
end)


CreateThread(function()
  while true do
    if nuiOpen then
      DisableAllControlActions(0)
      DisablePlayerFiring(PlayerId(), true)
      SetPlayerControl(PlayerId(), false, 0)


      EnableControlAction(0, 322, true)
      EnableControlAction(0, 200, true)
      EnableControlAction(0, 245, true)
      EnableControlAction(0, 249, true)


      EnableControlAction(0, 241, true)
      EnableControlAction(0, 242, true)
      EnableControlAction(0, 174, true)
      EnableControlAction(0, 175, true)


      DisablePlayerFiring(PlayerId(), true)

      Wait(0)
    else
      Wait(250)
    end
  end
end)


local function getScreenRes()
  if GetActiveScreenResolution then
    return GetActiveScreenResolution()
  end
  if GetScreenActiveResolution then
    return GetScreenActiveResolution()
  end
  return 1920, 1080
end

local function pollCursor()
  if not nuiOpen then return end
  if GetNuiCursorPosition then
    local ok, cx, cy = pcall(GetNuiCursorPosition)
    if ok and cx and cy then
      local sx, sy = getScreenRes()
      if sx and sy and sx > 0 and sy > 0 then
        mouse.x = (cx / sx)
        mouse.y = (cy / sy)
      end
    end
  end
end

local function pollButtons()
  if not nuiOpen then return end
  mouse.down = (IsDisabledControlPressed(0, 24) or IsControlPressed(0, 24))
end


local function clearPlantTools()
  if plantScene and plantScene.tools then
    for _, t in ipairs(plantScene.tools) do
      if t.ent then deleteEntitySafe(t.ent) end
    end
  end
  plantScene.tools = {}
  plantScene.held = nil
  plantScene.heldType = nil
  plantScene.heldKey = nil
  plantScene.heldAxis = nil
  plantScene.heldRotZ = nil
  plantScene.tilt = 0.0
  plantScene.pourMs = 0
  plantScene.pouring = false
  plantScene.didUse = false
end

local function dragRequiredMs(ttype)
  local cfg = plantInteractCfg()
  local v = cfg.DragPourMs
  if type(v) == "table" then
    return tonumber(v[ttype] or v.default or 900) or 900
  end
  return tonumber(v or 900) or 900
end

local function dragDelta(ttype)
  local cfg = plantInteractCfg()
  local d = cfg.DragDelta
  if type(d) ~= "table" then
    return 25.0
  end
  return tonumber(d[ttype] or 25.0) or 25.0
end

local function performHeldToolAction(potId)
  if not plantScene or plantScene.didUse then return end
  plantScene.didUse = true

  local ttype = plantScene.heldType
  local key   = plantScene.heldKey
  local delta = dragDelta(ttype)

  if ttype == "dirt" then
    TriggerServerEvent("azs1:pot:addDirt", potId)

  elseif ttype == "seed" then
    key = tostring(key or "")
    if key ~= "" then
      TriggerServerEvent("azs1:pot:plant", potId, key)
    else
      notify("Missing strain key.")
    end

  elseif ttype == "water" then
    TriggerServerEvent("azs1:pot:waterPour", potId, delta)

  elseif ttype == "fert" then
    TriggerServerEvent("azs1:pot:fertPour", potId, delta)

  elseif ttype == "trim" then
    TriggerServerEvent("azs1:pot:trim", potId)

  elseif ttype == "harvest" then
    TriggerServerEvent("azs1:pot:harvest", potId)
  end

  TriggerServerEvent("azs1:player:request")


  clearPlantTools()
end

local function createPlantScene(potId)
  destroyPlantScene()
  local pot = World.pots[potId]
  if not pot then return end

  plantScene.pot = potId
  plantScene.tools = {}
  plantScene.didUse = false

  plantScene.sceneToken = (plantScene.sceneToken or 0) + 1
  local myToken = plantScene.sceneToken

  CreateThread(function()
    plantScene.lastTick = GetGameTimer()

    while nuiOpen and currentContext == "plant_sidebar" and plantScene.pot == potId and plantScene.sceneToken == myToken do
      Wait(50)

      if plantScene.held and DoesEntityExist(plantScene.held) and not plantScene.didUse then
        local now = GetGameTimer()
        local dt = now - (plantScene.lastTick or now)
        plantScene.lastTick = now

        local potNow = World.pots[potId]
        if potNow then
          local center = vector3(potNow.x, potNow.y, (potNow.z or 0.0) + getPotPourZ())
          local heldType = plantScene.heldType
          local off = getToolPourOffset(heldType)
          local pourPt = GetOffsetFromEntityInWorldCoords(plantScene.held, off.x, off.y, off.z)
          local heldPos = GetEntityCoords(plantScene.held)
          local dist = math.min(dist2D(pourPt, center), dist2D(heldPos, center))

          local tilt = tonumber(plantScene.tilt or 0.0) or 0.0

          local needsTilt = (heldType == "water" or heldType == "fert" or heldType == "dirt" or heldType == "seed")
          local tiltOk = (not needsTilt) or (math.abs(tilt) >= getToolTiltRequired(heldType))

          local cfgLocal = plantInteractCfg()
          local requireClick = (cfgLocal.PourRequiresClick == true)

          if heldType == "trim" or heldType == "harvest" then requireClick = true end
          local clickOk = (not requireClick) or mouse.down

          local canUse = (dist < getToolPourDistance(heldType)) and tiltOk and clickOk

          if canUse then
            plantScene.pourMs = (plantScene.pourMs or 0) + dt
            plantScene.pouring = true

            if (heldType == "water" or heldType == "fert" or heldType == "dirt") and not plantScene.ptfx then
              plantScene.ptfx = startPourFx(heldType, plantScene.held)
              plantScene.ptfxType = heldType
            end

            if (plantScene.pourMs or 0) >= dragRequiredMs(heldType) then
              if plantScene.ptfx then
                stopPourFx(plantScene.ptfx)
                plantScene.ptfx = nil
                plantScene.ptfxType = nil
              end
              performHeldToolAction(potId)
            end
          else
            plantScene.pouring = false
            plantScene.pourMs = 0
            if plantScene.ptfx then
              stopPourFx(plantScene.ptfx)
              plantScene.ptfx = nil
              plantScene.ptfxType = nil
            end
          end
        end
      end
    end
  end)
end


local function mouseToPotPoint(potId, mx, my)
  local pot = World.pots[potId]
  if not pot then return nil end

  mx = tonumber(mx or 0.5) or 0.5
  my = tonumber(my or 0.5) or 0.5

  local cfg = plantInteractCfg()
  local areaW = tonumber(cfg.ToolAreaW or 0.95) or 0.95
  local areaH = tonumber(cfg.ToolAreaH or 0.62) or 0.62
  local maxR  = tonumber(cfg.ToolAreaR or 0.85) or 0.85
  if areaW < 0.3 then areaW = 0.3 end
  if areaH < 0.2 then areaH = 0.2 end
  if maxR  < 0.3 then maxR  = 0.3 end

  local forward, right = potBasis(pot)


  local centerZ = (pot.z or 0.0) + getToolPlaneZ()
  local ent = Spawned.pots and Spawned.pots[potId] or nil
  if ent and DoesEntityExist(ent) then
    local ec = GetEntityCoords(ent)
    centerZ = ec.z + getToolPlaneZ()
  end

  local center = vector3(pot.x, pot.y, centerZ)


  local dx = (mx - 0.5) * areaW
  local dy = (0.5 - my) * areaH

  local p = center + (right * dx) + (forward * dy)


  local off = p - center
  local flat = vector3(off.x, off.y, 0.0)
  local dist = #(flat)
  if dist > maxR and dist > 0.0001 then
    local s = maxR / dist
    p = center + vector3(flat.x * s, flat.y * s, 0.0)
  end

  p = vector3(p.x, p.y, center.z)
  return p
end


local function raycastFromPlantCam(mx, my, dist)
  if not plantCam or not DoesCamExist(plantCam) then return nil end
  dist = dist or 6.0

  local camCoord = GetCamCoord(plantCam)
  local camRot = GetCamRot(plantCam, 2)
  local fov = GetCamFov(plantCam)
  local rz = math.rad(camRot.z)

  local nx = (mx - 0.5) * 2.0
  local ny = (my - 0.5) * 2.0
  local fx = nx * math.tan(math.rad(fov) / 2.0)
  local fy = -ny * math.tan(math.rad(fov) / 2.0)

  local function rotToDir(r)
    local z = math.rad(r.z); local x = math.rad(r.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
  end

  local forward = rotToDir(camRot)
  local right = vector3(math.cos(rz), math.sin(rz), 0.0)
  local up = vector3(0.0, 0.0, 1.0)
  local dir = forward + right * fx + up * fy
  local to = camCoord + dir * dist

  local flags = 1 + 8
  local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, to.x, to.y, to.z, flags, PlayerPedId(), 0)
  local _, hit, endCoords, _, ent = GetShapeTestResult(ray)
  if hit == 1 and ent and ent ~= 0 then
    return ent, endCoords
  end
  return nil
end


local function toolHomeScreen(ttype)
  local cfg = plantInteractCfg()
  if cfg and type(cfg.ToolHomeScreen) == "table" and type(cfg.ToolHomeScreen[ttype]) == "table" then
    local v = cfg.ToolHomeScreen[ttype]
    return tonumber(v[1] or v.x or 0.5) or 0.5, tonumber(v[2] or v.y or 0.6) or 0.6
  end
  local d = {
    dirt    = { 0.25, 0.62 },
    seed    = { 0.38, 0.62 },
    water   = { 0.55, 0.62 },
    fert    = { 0.68, 0.62 },
    trim    = { 0.70, 0.52 },
    harvest = { 0.70, 0.52 },
  }
  local v = d[ttype] or { 0.55, 0.62 }
  return v[1], v[2]
end


spawnPlantTool = function(potId, ttype, key)
  local cfg = plantInteractCfg()
  if cfg.DragAndDropTools == false then
    if ttype == "seed" then
      return startPotAutoAction(potId, "seed", { strainKey = key })
    else
      return startPotAutoAction(potId, ttype, { })
    end
  end

  potId = tostring(potId or currentPotId or (plantScene and plantScene.pot) or "")
  if potId == "" then
    notify("Invalid pot selection (UI missing potId).")
    return false
  end

  local pot = World.pots[potId]
  if not pot then
    notify("Pot not synced yet. Try again in a moment.")
    return false
  end

  if not nuiOpen or currentContext ~= "plant_sidebar" then
    notify("Plant panel not open.")
    return false
  end

  if plantScene.pot ~= potId then
    createPlantScene(potId)
  end


  clearPlantTools()

  local pdata = PlayerData or {}
  local model = nil


  if ttype == "dirt" then
    if pot.hasDirt then notify("This pot already has dirt.") return false end
    if (pdata.dirt or 0) <= 0 then notify("You don't have dirt.") return false end
    model = (Config.Props and Config.Props.dirt) or "prop_cs_sack_01"

  elseif ttype == "seed" then
    key = tostring(key or "")
    if not pot.hasDirt then notify("Add dirt first.") return false end
    if pot.strain and pot.strain ~= "" then notify("This pot already has a seed planted.") return false end
    if key == "" or not (pdata.seeds and (pdata.seeds[key] or 0) > 0) then notify("You don't have that seed.") return false end
    model = (Config.Props and Config.Props.seedBag) or "prop_weed_bottle"

  elseif ttype == "water" then
    if not pot.strain or pot.strain == "" then notify("Plant a seed first.") return false end
    if (pdata.watering_can or 0) <= 0 then notify("You don't have a watering can.") return false end
    model = { (Config.Props and Config.Props.waterBottle) or "prop_wateringcan", "prop_wateringcan", "prop_jerrycan_01a", "prop_ld_flow_bottle" }

  elseif ttype == "fert" then
    if not pot.strain or pot.strain == "" then notify("Plant a seed first.") return false end
    if (pdata.fertilizer or 0) <= 0 then notify("You don't have fertilizer.") return false end
    model = { (Config.Props and Config.Props.fertBottle) or "prop_ld_flow_bottle", "prop_ld_flow_bottle", "prop_paint_spray01a", "prop_jerrycan_01a", "prop_bottle_richard" }

  elseif ttype == "trim" or ttype == "harvest" then
    if not pot.strain or pot.strain == "" then notify("Nothing to "..ttype.." yet.") return false end
    if (pdata.trimmers or 0) <= 0 then notify("You don't have trimmers.") return false end
    model = (Config.Props and Config.Props.secateurs) or "prop_secateurs_01"

  else
    notify("Unknown plant action: "..tostring(ttype))
    return false
  end

  local chosen = ensureAnyModel(model)
  if not chosen then
    notify("Tool prop model missing. Check Config.Props for tool models.")
    return false
  end


  local hx, hy = toolHomeScreen(ttype)
  local pos = mouseToPotPoint(potId, hx, hy)
  if not pos then
    local fwd, right = potBasis(pot)
    pos = vector3(pot.x, pot.y, pot.z) + (right * -0.25) + (fwd * -0.35) + vector3(0.0, 0.0, 0.70)
  end

  local zAdd = tonumber((cfg.ToolSpawnZAdd or 0.02)) or 0.02
  pos = pos + vector3(0.0, 0.0, zAdd)

  local mh = modelHash(chosen)
  local minDim, maxDim = GetModelDimensions(mh)
  local zLift = 0.0
  if minDim then
    zLift = - (minDim.z or 0.0)
  end

  local ent = CreateObject(mh, pos.x, pos.y, pos.z + zLift, false, false, false)
  if not ent or ent == 0 then
    notify("Failed to spawn tool prop.")
    return false
  end

  SetEntityAsMissionEntity(ent, true, true)
  SetEntityInvincible(ent, true)
  FreezeEntityPosition(ent, true)
  SetEntityCollision(ent, true, true)


  local potCenter = vector3(pot.x, pot.y, (pot.z or 0.0) + getPotPourZ())
  local baseHeading = (pot.h or 0.0) + 90.0
  local heading = baseHeading

  if ttype == "water" or ttype == "fert" then
    local yawOff = tonumber((Config.ToolYawOffset and Config.ToolYawOffset[ttype]) or 0.0) or 0.0
    if Config.ToolYawFlip and Config.ToolYawFlip[ttype] == true then
      yawOff = yawOff + 180.0
    end
    heading = headingTo(pos, potCenter) + yawOff
  end

  SetEntityHeading(ent, heading)

  local axis = getToolAxis(ttype)
  local invertTilt = (Config.ToolTiltInvert and Config.ToolTiltInvert[ttype] == true) or false
  applyToolRotation(ent, axis, 0.0, heading, invertTilt)

  table.insert(plantScene.tools, {
    ent = ent,
    type = ttype,
    key = key,
    home = pos + vector3(0.0, 0.0, zLift),
    homeRotZ = heading,
    axis = axis,
    zLift = zLift
  })

  notify("Grab the prop, drag it over the pot, and scroll to tilt/pour.")
  return true
end


local function findPlantToolByEnt(ent)
  if not plantScene or not plantScene.tools then return nil end
  for _, t in ipairs(plantScene.tools) do
    if t.ent == ent then return t end
  end
  return nil
end

local function plantGrabTry(mx, my)
  if not (nuiOpen and currentContext == "plant_sidebar") then return end
  if not (plantScene and plantScene.tools and #plantScene.tools > 0) then return end

  mx = tonumber(mx or 0.5) or 0.5
  my = tonumber(my or 0.5) or 0.5

  local function beginHold(t)
    if not t or not t.ent or not DoesEntityExist(t.ent) then return end
    plantScene.held     = t.ent
    plantScene.heldType = t.type
    plantScene.heldKey  = t.key
    plantScene.heldAxis = t.axis or getToolAxis(t.type)
    plantScene.heldRotZ = t.homeRotZ or GetEntityHeading(t.ent)
    plantScene.tilt     = plantScene.tilt or 0.0
    plantScene.pourMs   = 0
    plantScene.pouring  = false
    plantScene.didUse   = false
    plantScene.dragLastX = nil

    FreezeEntityPosition(t.ent, true)
    SetEntityCollision(t.ent, false, false)
  end


  if plantCam and DoesCamExist(plantCam) then
    local hitEnt, _ = raycastFromPlantCam(mx, my, 6.0)
    if hitEnt and hitEnt ~= 0 then
      local t = findPlantToolByEnt(hitEnt)
      if t then
        beginHold(t)
        return
      end
    end
  end

  local cfg = plantInteractCfg()


  local potId = plantScene.pot
  local p = potId and mouseToPotPoint(potId, mx, my) or nil
  if p then
    local thresh = tonumber(cfg.PickWorldDistance or 0.55) or 0.55
    if thresh < 0.12 then thresh = 0.12 end

    local best, bestD = nil, 1e9
    for _, t in ipairs(plantScene.tools) do
      if t and t.ent and DoesEntityExist(t.ent) then
        local c = GetEntityCoords(t.ent)
        local d = #(c - p)
        if d < bestD then
          bestD = d
          best = t
        end
      end
    end

    if best and bestD <= thresh then
      beginHold(best)
      return
    end
  end


  local pickRadius = tonumber(cfg.PickRadius or 0.16) or 0.16
  if pickRadius < 0.04 then pickRadius = 0.04 end
  local thresh2 = pickRadius * pickRadius

  local best, bestD2 = nil, 1e9
  for _, t in ipairs(plantScene.tools) do
    if t and t.ent and DoesEntityExist(t.ent) then
      local c = GetEntityCoords(t.ent)
      local on, sx, sy = World3dToScreen2d(c.x, c.y, c.z + 0.02)
      if on then
        local dx = (sx - mx)
        local dy = (sy - my)
        local d2 = dx*dx + dy*dy
        if d2 <= thresh2 and d2 < bestD2 then
          bestD2 = d2
          best = t
        end
      end
    end
  end

  if best then
    beginHold(best)
  end
end

local function plantRelease()
  if plantScene and plantScene.held and DoesEntityExist(plantScene.held) then
    SetEntityCollision(plantScene.held, true, true)
  end

  if plantScene and plantScene.ptfx then
    stopPourFx(plantScene.ptfx)
    plantScene.ptfx = nil
    plantScene.ptfxType = nil
  end

  if plantScene then
    plantScene.held = nil
    plantScene.heldType = nil
    plantScene.heldKey = nil
    plantScene.heldAxis = nil
    plantScene.heldRotZ = nil
    plantScene.pouring = false
    plantScene.pourMs = 0
  end
end


local function openPlantSidebar(potId)
  currentPotId = potId

  destroyAllCams()

  local ent = Spawned.pots and Spawned.pots[potId] or nil
  if ent and ent ~= 0 and DoesEntityExist(ent) then
    local c = GetEntityCoords(ent)
    local forward = GetEntityForwardVector(ent)
    local right = nil
    if GetEntityRightVector then
      right = GetEntityRightVector(ent)
    else
      right = vector3(-forward.y, forward.x, 0.0)
    end

    local ccfg = (Config.Cameras and Config.Cameras.Plant) or {}
    local side = tonumber(ccfg.Side or 0.65) or 0.65
    local back = tonumber(ccfg.Back or 1.55) or 1.55
    local up   = tonumber(ccfg.Up or 1.05) or 1.05
    local fov  = tonumber(ccfg.Fov or 60.0) or 60.0
    local lookZ= tonumber(ccfg.LookZ or 0.45) or 0.45

    local camPos = c + (right * side) - (forward * back) + vector3(0.0, 0.0, up)
    plantCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, fov, false, 0)
    PointCamAtEntity(plantCam, ent, 0.0, 0.0, lookZ, true)
    SetCamActive(plantCam, true)
    RenderScriptCams(true, true, 250, true, true)
  end

  createPlantScene(potId)

  openNui("plant_sidebar", {
    potId = potId,
    pot = World.pots[potId],
    player = PlayerData or {},
    strains = Config.Strains,
    seeds = (PlayerData and PlayerData.seeds) or {}
  })
end


local function tableToWorld(t, dx, dy, dz)
  local h = math.rad(t.h or 0.0)
  local forward = vector3(-math.sin(h), math.cos(h), 0.0)
  local right   = vector3(math.cos(h),  math.sin(h), 0.0)
  dx = tonumber(dx or 0.0) or 0.0
  dy = tonumber(dy or 0.0) or 0.0
  dz = tonumber(dz or 0.0) or 0.0
  return vector3(t.x, t.y, t.z) + (right * dx) + (forward * dy) + vector3(0.0, 0.0, dz)
end


destroyBagScene = function()
  if bagScene then
    for _, ent in ipairs(bagScene.buds or {}) do deleteEntitySafe(ent) end
    for _, ent in ipairs(bagScene.emptyBags or {}) do deleteEntitySafe(ent) end
    for _, ent in ipairs(bagScene.filledBags or {}) do deleteEntitySafe(ent) end
    for _, ent in ipairs(bagScene.outputBags or {}) do deleteEntitySafe(ent) end
    if bagScene.activeBag then deleteEntitySafe(bagScene.activeBag) end


    if bagScene.tableEnt and bagScene.tableOwned then
      deleteEntitySafe(bagScene.tableEnt)
    end
  end
  bagScene = {
    tableEnt = nil,
    tableOwned = false,
    tableId = nil,
    planeZ = nil,
    base = nil,
    forward = nil,
    right = nil,

    buds = {},
    emptyBags = {},
    filledBags = {},
    outputBags = {},


    budQueue = {},
    bagRemaining = 0,


    slots = {},
    home = {},
    pickPos = {},
    budStrain = {},
    budSlotIdx = {},
    emptyBySlot = {},

    held = nil, heldKey = nil, heldType = nil,
    activeBag = nil,
    lastDown = false,
    dragDown = false,
    lastMouseEventAt = 0,
  }
  currentTableId = nil
  destroyAllCams()
end

local _bag_pose_entity

_bag_reset_items = function(clearOutput)
  if not bagScene then return end

  for _, ent in ipairs(bagScene.buds or {}) do deleteEntitySafe(ent) end
  for _, ent in ipairs(bagScene.emptyBags or {}) do deleteEntitySafe(ent) end
  if clearOutput ~= false then
    for _, ent in ipairs(bagScene.outputBags or {}) do deleteEntitySafe(ent) end
    for _, ent in ipairs(bagScene.filledBags or {}) do deleteEntitySafe(ent) end
  end
  if bagScene.activeBag then deleteEntitySafe(bagScene.activeBag) end

  bagScene.buds = {}
  bagScene.emptyBags = {}
  if clearOutput ~= false then
    bagScene.filledBags = {}
    bagScene.outputBags = {}
  end
  bagScene.budQueue = {}
  bagScene.bagRemaining = 0
  bagScene.home = {}
  bagScene.pickPos = {}
  bagScene.budStrain = {}
  bagScene.budSlotIdx = {}
  bagScene.emptyBySlot = {}
  bagScene.activeBag = nil
  bagScene.held = nil
  bagScene.heldType = nil
  bagScene.heldKey = nil
  bagScene.dragDown = false
  mouse.down = false
end

_bag_load_selection = function(data)
  if not bagScene or not bagScene.tableEnt then return false, "Bagging scene not ready." end

  local availableBuds = (PlayerData and PlayerData.buds) or {}
  local availableBags = tonumber((PlayerData and PlayerData.bags) or 0) or 0
  local selectedBuds = (data and data.buds) or {}
  local selectedBagCount = math.floor(tonumber((data and data.bags) or 0) or 0)
  local ordered = {}

  for strain, count in pairs(selectedBuds) do
    local have = math.floor(tonumber(availableBuds[strain] or 0) or 0)
    local want = math.floor(tonumber(count or 0) or 0)
    want = math.max(0, math.min(have, want))
    for _=1,want do table.insert(ordered, tostring(strain)) end
  end

  selectedBagCount = math.max(0, math.min(availableBags, selectedBagCount))

  if #ordered <= 0 then return false, "Select at least 1 bud to place on the table." end
  if selectedBagCount <= 0 then return false, "Select at least 1 empty bag to place on the table." end

  _bag_reset_items(true)

  local cfg = _bag_cfg()
  local tableHeading = GetEntityHeading(bagScene.tableEnt or PlayerPedId())

  local budModel = ensureAnyModel(cfg.BudModel)
  if not budModel then return false, "Bud prop missing (Config.Props.weedBud)." end

  local emptyBagModel = ensureAnyModel(cfg.EmptyModel)
  if not emptyBagModel then return false, "Empty bag prop missing (Config.Props.weedBagEmpty / weedBag)." end

  bagScene.budQueue = ordered

  local maxBuds = math.min(#bagScene.budQueue, #(bagScene.slots and bagScene.slots.buds or {}))
  for i=1,maxBuds do
    local slotPos = bagScene.slots.buds[i]
    local strain = table.remove(bagScene.budQueue, 1)
    local ent = _bag_spawn_on_plane(budModel, slotPos, tableHeading + 90.0)
    if ent then
      _bag_pose_entity(ent, "bud", slotPos)
      table.insert(bagScene.buds, ent)
      bagScene.home[ent] = slotPos
      bagScene.pickPos[ent] = slotPos
      bagScene.budStrain[ent] = strain
      bagScene.budSlotIdx[ent] = i
    end
  end

  local spawnBags = math.min(selectedBagCount, #(bagScene.slots and bagScene.slots.empty or {}))
  bagScene.bagRemaining = math.max(0, selectedBagCount - spawnBags)
  for i=1,spawnBags do
    local slotPos = bagScene.slots.empty[i]
    local ent = _bag_spawn_on_plane(emptyBagModel, slotPos, tableHeading)
    if ent then
      _bag_pose_entity(ent, "bag", slotPos)
      table.insert(bagScene.emptyBags, ent)
      bagScene.home[ent] = slotPos
      bagScene.pickPos[ent] = slotPos
      bagScene.emptyBySlot[i] = ent
    end
  end

  return true
end

local function createBagScene(tableId)
  if not World.tables[tableId] then return end
  destroyBagScene()

  local t = World.tables[tableId]


  local tableEnt = (Spawned.tables and Spawned.tables[tableId]) or nil
  local owned = false

  if not (tableEnt and tableEnt ~= 0 and DoesEntityExist(tableEnt)) then

    local model = ensureAnyModel((Config.Props and Config.Props.bagTable) or "prop_table_03")
    if not model then
      notify("Bagging table prop missing (Config.Props.bagTable).")
      return
    end
    local mh = modelHash(model)
    local z = modelBaseZ(mh, t.z)
    tableEnt = CreateObject(mh, t.x, t.y, z, false, false, false)
    if not tableEnt or tableEnt == 0 then
      notify("Failed to spawn bagging table.")
      return
    end
    SetEntityHeading(tableEnt, t.h or 0.0)
    FreezeEntityPosition(tableEnt, true)
    SetEntityInvincible(tableEnt, true)
    SetEntityAsMissionEntity(tableEnt, true, true)
    owned = true
  end

  bagScene.tableEnt = tableEnt
  bagScene.tableOwned = owned
  bagScene.tableId = tableId

  local base = GetEntityCoords(tableEnt)
  local h = GetEntityHeading(tableEnt)

  local forward = GetEntityForwardVector(tableEnt)
  local right = nil
  if GetEntityRightVector then
    right = GetEntityRightVector(tableEnt)
  else
    right = vector3(-forward.y, forward.x, 0.0)
  end

  bagScene.base = base
  bagScene.forward = forward
  bagScene.right = right


  local mh = GetEntityModel(tableEnt)
  local minDim, maxDim = GetModelDimensions(mh)
  local topZ = base.z + (maxDim and maxDim.z or 0.75)
  local zAdd = tonumber((Config.Bagging and Config.Bagging.PlaneZAdd) or 0.02) or 0.02
  bagScene.planeZ = topZ + zAdd

  local planeRel = bagScene.planeZ - base.z

  local function place(dx, dy)
    dx = tonumber(dx or 0.0) or 0.0
    dy = tonumber(dy or 0.0) or 0.0
    return base + (right * dx) + (forward * dy) + vector3(0.0, 0.0, planeRel)
  end


  destroyAllCams()

  local camCfg = (Config.Cameras and Config.Cameras.Bagging) or {}

  local depth  = (maxDim and minDim) and ((maxDim.y or 0.6) - (minDim.y or -0.6)) or 1.2
  local height = (maxDim and minDim) and ((maxDim.z or 0.45) - (minDim.z or 0.0)) or 0.85
  if depth < 0.6 then depth = 0.6 end
  if height < 0.5 then height = 0.5 end

  local up      = tonumber(camCfg.Up)      or (height * 0.90)
  local back    = tonumber(camCfg.Back)    or (depth  * 1.25)
  local side    = tonumber(camCfg.Side)    or 0.00
  local lookZ   = tonumber(camCfg.LookZ)   or -0.02
  local lookFwd = tonumber(camCfg.LookFwd) or 0.12
  local fov     = tonumber(camCfg.Fov)     or 45.0

  up   = clamp(up,   height * 0.55, height * 1.25)
  back = clamp(back, depth  * 0.75, depth  * 1.70)
  side = clamp(side, -depth * 0.50, depth  * 0.50)
  fov  = clamp(fov,  35.0, 70.0)

  bagCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
  local camPos = base + (right * side) - (forward * back) + vector3(0.0, 0.0, up)
  SetCamCoord(bagCam, camPos.x, camPos.y, camPos.z)

  local aim = base + (forward * lookFwd) + vector3(0.0, 0.0, (planeRel or 0.80) + lookZ)
  PointCamAtCoord(bagCam, aim.x, aim.y, aim.z)

  SetCamFov(bagCam, fov)
  SetCamActive(bagCam, true)
  RenderScriptCams(true, true, 250, true, true)


  bagScene.slots = {}
  bagScene.home = {}
  bagScene.pickPos = {}
  bagScene.budStrain = {}
  bagScene.budSlotIdx = {}
  bagScene.emptyBySlot = {}
  bagScene.outputBags = {}
  bagScene.activeBag = nil
  bagScene.held = nil
  bagScene.heldType = nil
  bagScene.heldKey = nil
  bagScene.lastDown = false
  bagScene.dragDown = false
  bagScene.lastMouseEventAt = 0

  local budSlots = {}
  local budStartX, budStartY = -0.40, 0.22
  local budCols, budRows = 3, 2
  local budSX, budSY = 0.16, 0.16
  for r=1,budRows do
    for c=1,budCols do
      local dx = budStartX + (c-1)*budSX
      local dy = budStartY - (r-1)*budSY
      table.insert(budSlots, place(dx, dy))
    end
  end
  bagScene.slots.buds = budSlots

  local bagSlots = {}
  local bagStartX, bagStartY = 0.10, 0.22
  local bagCols, bagRows = 3, 2
  local bagSX, bagSY = 0.14, 0.16
  for r=1,bagRows do
    for c=1,bagCols do
      local dx = bagStartX + (c-1)*bagSX
      local dy = bagStartY - (r-1)*bagSY
      table.insert(bagSlots, place(dx, dy))
    end
  end
  bagScene.slots.empty = bagSlots

  bagScene.slots.active = place(0.02, 0.05)

  local outSlots = {}
  local outStartX, outStartY = -0.14, -0.04
  local outCols, outRows = 3, 2
  local outSX, outSY = 0.14, 0.16
  for r=1,outRows do
    for c=1,outCols do
      local dx = outStartX + (c-1)*outSX
      local dy = outStartY - (r-1)*outSY
      table.insert(outSlots, place(dx, dy))
    end
  end
  bagScene.slots.output = outSlots

  currentTableId = tableId
  openNui("bag_scene", {
    tableId = tableId,
    strains = Config.Strains,
    availableBuds = (PlayerData and PlayerData.buds) or {},
    availableBags = (PlayerData and PlayerData.bags) or 0,
    maxBudSlots = #budSlots,
    maxBagSlots = #bagSlots,
    debugEnabled = (Config.Debug or (Config.Bagging and Config.Bagging.DebugVisuals)) and true or false,
  })
end


local function mouseToTablePoint(tableId, mx, my)
  if not bagScene or bagScene.tableId ~= tableId then return nil end
  if not bagCam or not DoesCamExist(bagCam) then return nil end
  if not bagScene.planeZ then return nil end

  mx = tonumber(mx or 0.5) or 0.5
  my = tonumber(my or 0.5) or 0.5

  local camCoord = GetCamCoord(bagCam)
  local camRot = GetCamRot(bagCam, 2)
  local fov = GetCamFov(bagCam)
  local rz = math.rad(camRot.z)

  local nx = (mx - 0.5) * 2.0
  local ny = (my - 0.5) * 2.0
  local fx = nx * math.tan(math.rad(fov) / 2.0)
  local fy = -ny * math.tan(math.rad(fov) / 2.0)

  local function rotToDir(r)
    local z = math.rad(r.z); local x = math.rad(r.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
  end

  local forward = rotToDir(camRot)
  local right = vector3(math.cos(rz), math.sin(rz), 0.0)
  local up = vector3(0.0, 0.0, 1.0)

  local dir = forward + right * fx + up * fy
  local from = camCoord
  local to = from + dir * 10.0

  local planeZ = bagScene.planeZ
  local denom = (to.z - from.z)
  if math.abs(denom) < 0.0001 then return nil end
  local tt = (planeZ - from.z) / denom
  if tt < 0 then return nil end

  local p = from + (to - from) * tt
  return p
end

local function raycastFromBagCam(mx, my, dist)
  if not bagCam or not DoesCamExist(bagCam) then return nil, nil end
  dist = tonumber(dist or 6.5) or 6.5

  mx = tonumber(mx or 0.5) or 0.5
  my = tonumber(my or 0.5) or 0.5

  local camCoord = GetCamCoord(bagCam)
  local camRot = GetCamRot(bagCam, 2)
  local fov = GetCamFov(bagCam)
  local rz = math.rad(camRot.z)

  local nx = (mx - 0.5) * 2.0
  local ny = (my - 0.5) * 2.0
  local fx = nx * math.tan(math.rad(fov) / 2.0)
  local fy = -ny * math.tan(math.rad(fov) / 2.0)

  local function rotToDir(r)
    local z = math.rad(r.z)
    local x = math.rad(r.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
  end

  local forward = rotToDir(camRot)
  local right = vector3(math.cos(rz), math.sin(rz), 0.0)
  local up = vector3(0.0, 0.0, 1.0)
  local dir = forward + right * fx + up * fy
  local to = camCoord + dir * dist

  local flags = 1 + 8
  local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, to.x, to.y, to.z, flags, PlayerPedId(), 0)
  local _, hit, endCoords, _, ent = GetShapeTestResult(ray)
  if hit == 1 and ent and ent ~= 0 then
    return ent, endCoords
  end
  return nil, nil
end


_bag_cfg = function()
  Config.Bagging = Config.Bagging or {}
  local c = Config.Bagging
  c.PickDist = tonumber(c.PickDist or 0.12) or 0.12
  c.ActiveDropDist = tonumber(c.ActiveDropDist or 0.15) or 0.15
  c.HoldLift = tonumber(c.HoldLift or 0.07) or 0.07
  c.OutputMax = tonumber(c.OutputMax or 4) or 4
  c.PlaneZAdd = tonumber(c.PlaneZAdd or 0.02) or 0.02
  c.FilledModel = c.FilledModel or "bkr_prop_weed_bag_01a"
  c.EmptyModel = c.EmptyModel or ((Config.Props and (Config.Props.weedBagEmpty or Config.Props.weedBag)) or "bkr_prop_weed_bag_01a")
  c.BudModel = c.BudModel or ((Config.Props and Config.Props.weedBud) or "bkr_prop_weed_dry_01a")
  c.ActiveBagLift = tonumber(c.ActiveBagLift or 0.05) or 0.05
  c.ActiveBagPitch = tonumber(c.ActiveBagPitch or 86.0) or 86.0
  c.ActiveBagRoll = tonumber(c.ActiveBagRoll or 0.0) or 0.0
  c.ActiveBagHeadingOffset = tonumber(c.ActiveBagHeadingOffset or 90.0) or 90.0
  c.ActiveBagInsertLift = tonumber(c.ActiveBagInsertLift or 0.08) or 0.08
  c.ActiveBagInsertForward = tonumber(c.ActiveBagInsertForward or 0.01) or 0.01
  c.InsertAnimMs = tonumber(c.InsertAnimMs or 180) or 180
  c.ScreenPickRadius = tonumber(c.ScreenPickRadius or 0.075) or 0.075
  c.ScreenPickBudBias = tonumber(c.ScreenPickBudBias or -0.010) or -0.010
  c.LockActiveBag = (c.LockActiveBag ~= false)
  c.EmptyBagPitch = tonumber(c.EmptyBagPitch or 0.0) or 0.0
  c.EmptyBagRoll = tonumber(c.EmptyBagRoll or 0.0) or 0.0
  c.FilledBagPitch = tonumber(c.FilledBagPitch or 0.0) or 0.0
  c.FilledBagRoll = tonumber(c.FilledBagRoll or 0.0) or 0.0
  c.BudPitch = tonumber(c.BudPitch or 0.0) or 0.0
  c.BudRoll = tonumber(c.BudRoll or 0.0) or 0.0
  if c.DebugVisuals == nil then c.DebugVisuals = true end
  if c.StrictClickPick == nil then c.StrictClickPick = true end
  if c.AllowPlaneFallback == nil then c.AllowPlaneFallback = false end
  return c
end

local function _bag_nearest_slot(pos, slots, occupiedFn, allowEnt)
  local bestI, bestD = nil, 999999.0
  for i, sp in ipairs(slots) do
    if not occupiedFn or occupiedFn(i, allowEnt) then
      local d = #(pos - sp)
      if d < bestD then bestD = d; bestI = i end
    end
  end
  return bestI, bestD
end

_bag_spawn_on_plane = function(model, pos, heading)
  local mh = modelHash(model)
  local z = modelBaseZ(mh, pos.z)
  local ent = CreateObject(mh, pos.x, pos.y, z, false, false, false)
  if ent and ent ~= 0 then
    SetEntityHeading(ent, heading or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityInvincible(ent, true)
    SetEntityAsMissionEntity(ent, true, true)
    return ent
  end
  return nil
end

local function _bag_entity_heading(kind)
  local cfg = _bag_cfg()
  local baseHeading = GetEntityHeading((bagScene and bagScene.tableEnt) or PlayerPedId())
  if kind == "bud" then
    return baseHeading + 90.0
  elseif kind == "active_bag" then
    return baseHeading + (tonumber(cfg.ActiveBagHeadingOffset or 90.0) or 90.0)
  end
  return baseHeading
end

function _bag_pose_entity(ent, kind, pos)
  if not ent or ent == 0 or not DoesEntityExist(ent) or not pos then return end
  local cfg = _bag_cfg()
  local mh = GetEntityModel(ent)
  local heading = _bag_entity_heading(kind)
  local x, y, z = pos.x, pos.y, pos.z
  local rx, ry = 0.0, 0.0

  if kind == "active_bag" then
    z = z + (tonumber(cfg.ActiveBagLift or 0.05) or 0.05)
    rx = tonumber(cfg.ActiveBagPitch or 86.0) or 86.0
    ry = tonumber(cfg.ActiveBagRoll or 0.0) or 0.0
  elseif kind == "bag" then
    z = modelBaseZ(mh, z)
    rx = tonumber(cfg.EmptyBagPitch or 0.0) or 0.0
    ry = tonumber(cfg.EmptyBagRoll or 0.0) or 0.0
  elseif kind == "filled_bag" then
    z = modelBaseZ(mh, z)
    rx = tonumber(cfg.FilledBagPitch or 0.0) or 0.0
    ry = tonumber(cfg.FilledBagRoll or 0.0) or 0.0
  elseif kind == "bud" then
    z = modelBaseZ(mh, z)
    rx = tonumber(cfg.BudPitch or 0.0) or 0.0
    ry = tonumber(cfg.BudRoll or 0.0) or 0.0
  else
    z = modelBaseZ(mh, z)
  end

  SetEntityCoordsNoOffset(ent, x, y, z, false, false, false)
  SetEntityRotation(ent, rx, ry, heading % 360.0, 2, true)
end

local function _bag_insert_anim(budEnt, bagEnt)
  if not budEnt or budEnt == 0 or not DoesEntityExist(budEnt) then return end
  if not bagEnt or bagEnt == 0 or not DoesEntityExist(bagEnt) then return end

  local cfg = _bag_cfg()
  local duration = tonumber(cfg.InsertAnimMs or 180) or 180
  if duration <= 0 then return end

  local startPos = GetEntityCoords(budEnt)
  local bagPos = GetEntityCoords(bagEnt)
  local bagForward = GetEntityForwardVector(bagEnt)
  local target = bagPos + (bagForward * (tonumber(cfg.ActiveBagInsertForward or 0.01) or 0.01)) + vector3(0.0, 0.0, (tonumber(cfg.ActiveBagInsertLift or 0.08) or 0.08))

  local startTime = GetGameTimer()
  while true do
    local elapsed = GetGameTimer() - startTime
    local t = elapsed / duration
    if t >= 1.0 then break end
    local p = startPos + (target - startPos) * t
    SetEntityCoordsNoOffset(budEnt, p.x, p.y, p.z, false, false, false)
    SetEntityRotation(budEnt, 0.0, 0.0, _bag_entity_heading("bud") % 360.0, 2, true)
    Wait(0)
  end

  SetEntityCoordsNoOffset(budEnt, target.x, target.y, target.z, false, false, false)
end

local function _bag_refill_one_empty()
  local cfg = _bag_cfg()
  if not bagScene or bagScene.bagRemaining <= 0 then return end
  local slots = bagScene.slots and bagScene.slots.empty or {}
  for i=1,#slots do
    if not bagScene.emptyBySlot[i] then
      local ent = _bag_spawn_on_plane(cfg.EmptyModel, slots[i], GetEntityHeading(bagScene.tableEnt or PlayerPedId()))
      if ent then
        _bag_pose_entity(ent, "bag", slots[i])
        table.insert(bagScene.emptyBags, ent)
        bagScene.home[ent] = slots[i]
        bagScene.pickPos[ent] = slots[i]
        bagScene.emptyBySlot[i] = ent
        bagScene.bagRemaining = math.max(0, (bagScene.bagRemaining or 0) - 1)
      end
      return
    end
  end
end

local function _bag_spawn_next_bud(slotIdx)
  if not bagScene or not bagScene.budQueue or #bagScene.budQueue <= 0 then return end
  local cfg = _bag_cfg()
  local slots = bagScene.slots and bagScene.slots.buds or {}
  local slotPos = slots[slotIdx]
  if not slotPos then return end
  local strain = table.remove(bagScene.budQueue, 1)
  local ent = _bag_spawn_on_plane(cfg.BudModel, slotPos, (GetEntityHeading(bagScene.tableEnt or PlayerPedId()) + 90.0))
  if ent then
    _bag_pose_entity(ent, "bud", slotPos)
    table.insert(bagScene.buds, ent)
    bagScene.home[ent] = slotPos
    bagScene.pickPos[ent] = slotPos
    bagScene.budStrain[ent] = strain
    bagScene.budSlotIdx[ent] = slotIdx
  end
end

local function _bag_spawn_filled_visual(strainKey)
  local cfg = _bag_cfg()
  if not bagScene or not bagScene.slots or not bagScene.slots.output then return end
  if #bagScene.outputBags >= math.min(cfg.OutputMax, #bagScene.slots.output) then return end

  local idx = #bagScene.outputBags + 1
  local pos = bagScene.slots.output[idx]
  if not pos then return end

  local ent = _bag_spawn_on_plane(cfg.FilledModel, pos, GetEntityHeading(bagScene.tableEnt or PlayerPedId()))
  if ent then
    _bag_pose_entity(ent, "filled_bag", pos)
    bagScene.pickPos[ent] = pos
    table.insert(bagScene.outputBags, ent)
    table.insert(bagScene.filledBags, ent)
  end
end

local function _bag_screen_pick_points(ent, typ)
  if not ent or ent == 0 or not DoesEntityExist(ent) then return {} end

  local minDim, maxDim = GetModelDimensions(GetEntityModel(ent))
  local cx = (minDim.x + maxDim.x) * 0.5
  local cy = (minDim.y + maxDim.y) * 0.5
  local cz = (minDim.z + maxDim.z) * 0.5
  local sx = math.max(0.01, (maxDim.x - minDim.x) * 0.5)
  local sy = math.max(0.01, (maxDim.y - minDim.y) * 0.5)
  local sz = math.max(0.01, (maxDim.z - minDim.z))

  if typ == "bud" then
    return {
      vector3(cx, cy, minDim.z + (sz * 0.92)),
      vector3(cx, cy, minDim.z + (sz * 0.72)),
      vector3(cx, cy, minDim.z + (sz * 0.52)),
      vector3(cx + (sx * 0.30), cy, minDim.z + (sz * 0.78)),
      vector3(cx - (sx * 0.30), cy, minDim.z + (sz * 0.78)),
      vector3(cx, cy + (sy * 0.20), minDim.z + (sz * 0.66)),
      vector3(cx, cy - (sy * 0.20), minDim.z + (sz * 0.66)),
      vector3(cx, cy, minDim.z + (sz * 0.30)),
    }
  end

  return {
    vector3(cx, cy, cz),
    vector3(cx, cy, minDim.z + (sz * 0.72)),
    vector3(cx, cy, minDim.z + (sz * 0.30)),
    vector3(cx + (sx * 0.45), cy, cz),
    vector3(cx - (sx * 0.45), cy, cz),
    vector3(cx, cy + (sy * 0.35), cz),
    vector3(cx, cy - (sy * 0.35), cz),
  }
end

local function _bag_screen_pick_distance(ent, typ, mx, my)
  local best = nil
  for _, pt in ipairs(_bag_screen_pick_points(ent, typ)) do
    local wp = GetOffsetFromEntityInWorldCoords(ent, pt.x, pt.y, pt.z)
    local ok, sx, sy = GetScreenCoordFromWorldCoord(wp.x, wp.y, wp.z)
    if ok then
      local dx = sx - mx
      local dy = sy - my
      local dist = math.sqrt((dx * dx) + (dy * dy))
      if (not best) or (dist < best) then
        best = dist
      end
    end
  end
  return best
end

local function _bag_entity_pick_pos(ent)
  if bagScene and bagScene.pickPos and bagScene.pickPos[ent] then
    return bagScene.pickPos[ent]
  end
  if bagScene and bagScene.home and bagScene.home[ent] then
    return bagScene.home[ent]
  end
  if ent and ent ~= 0 and DoesEntityExist(ent) then
    return GetEntityCoords(ent)
  end
  return nil
end

local function _bag_table_local(pos)
  if not bagScene or not pos or not bagScene.base or not bagScene.right or not bagScene.forward then return nil, nil end
  local rel = pos - bagScene.base
  local lx = (rel.x * bagScene.right.x) + (rel.y * bagScene.right.y) + (rel.z * bagScene.right.z)
  local ly = (rel.x * bagScene.forward.x) + (rel.y * bagScene.forward.y) + (rel.z * bagScene.forward.z)
  return lx, ly
end

local function _bag_plane_dist(a, b)
  if (not a) or (not b) then return nil end
  local ax, ay = _bag_table_local(a)
  local bx, by = _bag_table_local(b)
  if (not ax) or (not ay) or (not bx) or (not by) then return nil end
  local dx = ax - bx
  local dy = ay - by
  return math.sqrt((dx * dx) + (dy * dy))
end

local function _bag_pick_world_point(ent, typ)
  local pos = _bag_entity_pick_pos(ent)
  if not pos then return nil end

  local z = pos.z
  if typ == "bud" then
    z = z + 0.09
  elseif typ == "bag" then
    z = z + 0.03
  else
    z = z + 0.05
  end

  return vector3(pos.x, pos.y, z)
end

local function _bag_find_item_by_ent(ent, mode)
  if not ent or ent == 0 then return nil, nil, nil end
  local allowBuds = (mode ~= "bag_only")
  local allowBags = (mode ~= "bud_only")

  if allowBuds then
    for _, b in ipairs(bagScene.buds or {}) do
      if b == ent then
        return b, "bud", bagScene.budStrain[b]
      end
    end
  end

  if allowBags then
    if bagScene.activeBag and ent == bagScene.activeBag and (not (_bag_cfg().LockActiveBag)) then
      return bagScene.activeBag, "bag", "active"
    end
    for _, b in ipairs(bagScene.emptyBags or {}) do
      if b == ent then
        return b, "bag", "empty"
      end
    end
  end

  return nil, nil, nil
end

local function _bag_tracked_screen_pick(mx, my, mode)
  if not bagScene then return nil, nil, nil end

  local cfg = _bag_cfg()
  local baseRadius = tonumber(cfg.TrackedScreenPickRadius or 0.080) or 0.080
  local budRadius = tonumber(cfg.BudTrackedScreenPickRadius or math.max(baseRadius * 1.55, 0.12)) or math.max(baseRadius * 1.55, 0.12)
  local bagRadius = tonumber(cfg.BagTrackedScreenPickRadius or math.max(baseRadius * 0.80, 0.055)) or math.max(baseRadius * 0.80, 0.055)
  local budBias = tonumber(cfg.TrackedScreenBudBias or -0.015) or -0.015
  local allowBuds = (mode ~= "bag_only")
  local allowBags = (mode ~= "bud_only")
  local bestEnt, bestType, bestKey, bestScore = nil, nil, nil, nil

  local function consider(ent, typ, key, radius, bias)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local world = _bag_pick_world_point(ent, typ)
    if not world then return end
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
    if not onScreen then return end
    local dx, dy = (sx - mx), (sy - my)
    local dist = math.sqrt((dx * dx) + (dy * dy))
    if dist > radius then return end
    local score = dist + (bias or 0.0)
    if (not bestScore) or (score < bestScore) then
      bestEnt, bestType, bestKey, bestScore = ent, typ, key, score
    end
  end

  if allowBuds then
    for _, ent in ipairs(bagScene.buds or {}) do
      consider(ent, "bud", bagScene.budStrain[ent], budRadius, budBias)
    end
    if bestEnt and bestType == "bud" then
      return bestEnt, bestType, bestKey
    end
  end

  if allowBags then
    for _, ent in ipairs(bagScene.emptyBags or {}) do
      consider(ent, "bag", "empty", bagRadius, 0.010)
    end
  end

  return bestEnt, bestType, bestKey
end

local function _bag_pick_from_plane(p, mode)
  if not bagScene or not p then return nil, nil, nil end

  local cfg = _bag_cfg()
  local baseRadius = tonumber(cfg.LocalPickRadius or cfg.PickDist or 0.12) or 0.12
  local budRadius = tonumber(cfg.BudLocalPickRadius or math.max(baseRadius * 1.05, 0.10)) or math.max(baseRadius * 1.05, 0.10)
  local bagRadius = tonumber(cfg.BagLocalPickRadius or math.max(baseRadius * 0.90, 0.085)) or math.max(baseRadius * 0.90, 0.085)
  local bestEnt, bestType, bestKey, bestDist = nil, nil, nil, nil
  local allowBuds = (mode ~= "bag_only")
  local allowBags = (mode ~= "bud_only")

  local function consider(ent, typ, key, radius)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local epos = _bag_entity_pick_pos(ent)
    local dist = _bag_plane_dist(p, epos)
    if not dist or dist > radius then return end
    if (not bestDist) or (dist < bestDist) then
      bestEnt, bestType, bestKey, bestDist = ent, typ, key, dist
    end
  end

  if allowBuds then
    for _, ent in ipairs(bagScene.buds or {}) do
      consider(ent, "bud", bagScene.budStrain[ent], budRadius)
    end
    if bestEnt and bestType == "bud" then
      return bestEnt, bestType, bestKey
    end
  end

  if allowBags then
    if (not cfg.LockActiveBag) and bagScene.activeBag and DoesEntityExist(bagScene.activeBag) then
      consider(bagScene.activeBag, "bag", "active", tonumber(cfg.ActiveBagLocalPickRadius or math.max(bagRadius * 0.9, 0.08)) or math.max(bagRadius * 0.9, 0.08))
    end

    for _, ent in ipairs(bagScene.emptyBags or {}) do
      if (not cfg.LockActiveBag) or ent ~= bagScene.activeBag then
        consider(ent, "bag", "empty", bagRadius)
      end
    end
  end

  return bestEnt, bestType, bestKey
end

local function _bag_pick_from_screen(mx, my, mode)
  if not bagScene then return nil, nil, nil end

  local cfg = _bag_cfg()
  local baseRadius = tonumber(cfg.ScreenPickRadius or 0.090) or 0.090
  local budRadius = tonumber(cfg.BudScreenPickRadius or math.max(baseRadius * 2.0, 0.14)) or math.max(baseRadius * 2.0, 0.14)
  local bagRadius = tonumber(cfg.BagScreenPickRadius or math.max(baseRadius, 0.085)) or math.max(baseRadius, 0.085)
  local activeRadius = tonumber(cfg.ActiveBagScreenPickRadius or math.max(baseRadius * 0.9, 0.075)) or math.max(baseRadius * 0.9, 0.075)
  local budBias = tonumber(cfg.ScreenPickBudBias or -0.020) or -0.020
  local bestEnt, bestType, bestKey, bestScore = nil, nil, nil, nil
  local allowBuds = (mode ~= "bag_only")
  local allowBags = (mode ~= "bud_only")

  local function consider(ent, typ, key, radius, bias)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local dist = _bag_screen_pick_distance(ent, typ, mx, my)
    if not dist or dist > radius then return end

    local score = dist + (bias or 0.0)
    if (not bestScore) or (score < bestScore) then
      bestEnt, bestType, bestKey, bestScore = ent, typ, key, score
    end
  end

  if allowBuds then
    for _, ent in ipairs(bagScene.buds or {}) do
      consider(ent, "bud", bagScene.budStrain[ent], budRadius, budBias)
    end
    if bestEnt and bestType == "bud" then
      return bestEnt, bestType, bestKey
    end
  end

  if allowBags then
    if (not cfg.LockActiveBag) and bagScene.activeBag and DoesEntityExist(bagScene.activeBag) then
      consider(bagScene.activeBag, "bag", "active", activeRadius, 0.010)
    end

    for _, ent in ipairs(bagScene.emptyBags or {}) do
      if (not cfg.LockActiveBag) or ent ~= bagScene.activeBag then
        consider(ent, "bag", "empty", bagRadius, 0.015)
      end
    end
  end

  return bestEnt, bestType, bestKey
end

local function _bag_remove_empty_slot_ref(ent)
  for i, e in pairs(bagScene.emptyBySlot or {}) do
    if e == ent then
      bagScene.emptyBySlot[i] = nil
      break
    end
  end
end

local function _bag_find_overlap_bud(p, ignoreEnt)
  local cfg = _bag_cfg()
  local radius = tonumber(cfg.CombineDist or 0.115) or 0.115
  local bestEnt, bestDist = nil, nil
  for _, ent in ipairs(bagScene.buds or {}) do
    if ent ~= ignoreEnt and DoesEntityExist(ent) then
      local dist = _bag_plane_dist(p, _bag_entity_pick_pos(ent))
      if dist and dist <= radius and ((not bestDist) or (dist < bestDist)) then
        bestEnt, bestDist = ent, dist
      end
    end
  end
  return bestEnt
end

local function _bag_find_overlap_bag(p, ignoreEnt)
  local cfg = _bag_cfg()
  local radius = tonumber(cfg.CombineDist or 0.115) or 0.115
  local bestEnt, bestDist = nil, nil

  if bagScene.activeBag and bagScene.activeBag ~= ignoreEnt and DoesEntityExist(bagScene.activeBag) then
    local dist = _bag_plane_dist(p, _bag_entity_pick_pos(bagScene.activeBag))
    if dist and dist <= radius then
      bestEnt, bestDist = bagScene.activeBag, dist
    end
  end

  for _, ent in ipairs(bagScene.emptyBags or {}) do
    if ent ~= ignoreEnt and DoesEntityExist(ent) then
      local dist = _bag_plane_dist(p, _bag_entity_pick_pos(ent))
      if dist and dist <= radius and ((not bestDist) or (dist < bestDist)) then
        bestEnt, bestDist = ent, dist
      end
    end
  end

  return bestEnt
end

local function _bag_finish_pair(budEnt, bagEnt, strain)
  if not bagScene then return false end
  if not budEnt or budEnt == 0 or not DoesEntityExist(budEnt) then return false end
  if not bagEnt or bagEnt == 0 or not DoesEntityExist(bagEnt) then return false end

  local slotIdx = bagScene.budSlotIdx[budEnt]

  _bag_insert_anim(budEnt, bagEnt)
  TriggerServerEvent("azs1:bag:one", tostring(strain or ""))

  deleteEntitySafe(budEnt)
  list_remove(bagScene.buds, budEnt)
  bagScene.home[budEnt] = nil
  bagScene.pickPos[budEnt] = nil
  bagScene.budStrain[budEnt] = nil
  bagScene.budSlotIdx[budEnt] = nil

  deleteEntitySafe(bagEnt)
  list_remove(bagScene.emptyBags, bagEnt)
  if bagScene.activeBag == bagEnt then bagScene.activeBag = nil end
  _bag_remove_empty_slot_ref(bagEnt)
  bagScene.home[bagEnt] = nil
  bagScene.pickPos[bagEnt] = nil

  _bag_spawn_filled_visual(tostring(strain or ""))
  _bag_refill_one_empty()
  if slotIdx then _bag_spawn_next_bud(slotIdx) end

  SetTimeout(350, function()
    if bagScene and bagScene.tableId then
      TriggerServerEvent("azs1:table:sync_request", bagScene.tableId)
    end
  end)

  return true
end

local function _bag_draw_point(pos, r, g, b, scale)
  if not pos then return end
  scale = tonumber(scale or 0.035) or 0.035
  DrawMarker(1, pos.x, pos.y, pos.z + 0.003, 0.0,0.0,0.0, 0.0,0.0,0.0, scale, scale, 0.012, r or 255, g or 255, b or 255, 140, false, false, 2, false, nil, nil, false)
end

local function _bag_draw_box(pos, sx, sy, sz, r, g, b, a)
  if not pos then return end
  DrawMarker(43, pos.x, pos.y, pos.z + ((sz or 0.02) * 0.5), 0.0,0.0,0.0, 0.0,0.0,0.0, sx or 0.045, sy or 0.045, sz or 0.02, r or 255, g or 255, b or 255, a or 120, false, false, 2, false, nil, nil, false)
end

local function _bag_debug_visuals(mx, my)
  if not bagScene then return end
  if not (Config.Debug or (Config.Bagging and Config.Bagging.DebugVisuals)) then return end

  local function drawSlotSet(slots, r, g, b)
    for _, pos in ipairs(slots or {}) do
      _bag_draw_box(pos, 0.055, 0.055, 0.015, r, g, b, 110)
    end
  end

  drawSlotSet(bagScene.slots and bagScene.slots.buds,   255, 140, 0)
  drawSlotSet(bagScene.slots and bagScene.slots.empty,  0, 180, 255)
  drawSlotSet(bagScene.slots and bagScene.slots.output, 255, 0, 180)
  if bagScene.slots and bagScene.slots.active then
    _bag_draw_box(bagScene.slots.active, 0.070, 0.070, 0.018, 160, 160, 160, 90)
  end

  local function drawEntitySet(list, typ, r, g, b)
    for _, ent in ipairs(list or {}) do
      if ent and ent ~= 0 and DoesEntityExist(ent) then
        local c = GetEntityCoords(ent)
        local p = _bag_entity_pick_pos(ent)
        local h = bagScene.home and bagScene.home[ent] or nil
        if p then
          DrawLine(c.x, c.y, c.z + 0.02, p.x, p.y, p.z + 0.02, r, g, b, 255)
          _bag_draw_point(p, r, g, b, 0.032)
        end
        if h then
          DrawLine(p.x, p.y, p.z + 0.01, h.x, h.y, h.z + 0.01, r, g, b, 120)
          _bag_draw_box(h, 0.035, 0.035, 0.012, r, g, b, 70)
        end
        local minDim, maxDim = GetModelDimensions(GetEntityModel(ent))
        local sx = math.max(0.04, ((maxDim.x or 0.04) - (minDim.x or -0.04)) * 0.7)
        local sy = math.max(0.04, ((maxDim.y or 0.04) - (minDim.y or -0.04)) * 0.7)
        local sz = math.max(0.04, ((maxDim.z or 0.04) - (minDim.z or 0.0)) * 0.55)
        _bag_draw_box(c, sx, sy, sz, r, g, b, 35)
      end
    end
  end

  drawEntitySet(bagScene.buds, 'bud', 255, 140, 0)
  drawEntitySet(bagScene.emptyBags, 'bag', 0, 180, 255)
  drawEntitySet(bagScene.outputBags, 'filled', 255, 0, 180)

  local cursorPoint = mouseToTablePoint(bagScene.tableId, mx, my)
  if cursorPoint then
    _bag_draw_point(cursorPoint, 0, 255, 80, 0.045)
    _bag_draw_box(cursorPoint, 0.070, 0.070, 0.018, 0, 255, 80, 110)
  end

  local hitEnt, hitPos = raycastFromBagCam(mx, my, 6.5)
  local hitItem, hitType = _bag_find_item_by_ent(hitEnt, 'any')
  if hitItem then
    local hp = hitPos or GetEntityCoords(hitItem)
    if hp then
      _bag_draw_point(hp, 255, 60, 60, 0.050)
      local pp = _bag_entity_pick_pos(hitItem)
      if pp then DrawLine(hp.x, hp.y, hp.z + 0.01, pp.x, pp.y, pp.z + 0.01, 255, 60, 60, 255) end
    end
  end
end

local function bagGrabTry(mx, my)
  if not bagScene or not bagScene.tableId then return end
  if bagScene.held and DoesEntityExist(bagScene.held) then return end

  local cfg = _bag_cfg()
  local pickMode = "any"
  local bestEnt, bestType, bestKey = nil, nil, nil
  local p = mouseToTablePoint(bagScene.tableId, mx, my)

  local hitEnt = nil
  hitEnt = select(1, raycastFromBagCam(mx, my, 6.5))
  if hitEnt then
    bestEnt, bestType, bestKey = _bag_find_item_by_ent(hitEnt, pickMode)
  end

  if not bestEnt then
    bestEnt, bestType, bestKey = _bag_pick_from_screen(mx, my, pickMode)
  end

  if (not bestEnt) and (cfg.StrictClickPick ~= true) then
    bestEnt, bestType, bestKey = _bag_tracked_screen_pick(mx, my, pickMode)
  end

  if (not bestEnt) and p and (cfg.AllowPlaneFallback == true) then
    bestEnt, bestType, bestKey = _bag_pick_from_plane(p, pickMode)
  end

  if not bestEnt then return end

  bagScene.held = bestEnt
  bagScene.heldType = bestType
  bagScene.heldKey = bestKey
  bagScene.pickPos[bestEnt] = _bag_entity_pick_pos(bestEnt) or GetEntityCoords(bestEnt)

  _bag_remove_empty_slot_ref(bestEnt)

  FreezeEntityPosition(bestEnt, false)
  SetEntityCollision(bestEnt, false, false)
end

local function bagRelease(mx, my)
  if not bagScene or not bagScene.tableId then return end
  bagScene.pickPos = bagScene.pickPos or {}
  if not bagScene.held or not DoesEntityExist(bagScene.held) then
    bagScene.held, bagScene.heldType, bagScene.heldKey = nil, nil, nil
    return
  end

  local ent = bagScene.held
  local typ = bagScene.heldType
  local key = bagScene.heldKey

  local p = mouseToTablePoint(bagScene.tableId, mx, my)
  if not p then

    local home = bagScene.home[ent]
    if home then
      bagScene.pickPos[ent] = home
      if typ == "bag" then
        _bag_pose_entity(ent, "bag", home)
      else
        _bag_pose_entity(ent, "bud", home)
      end
    end
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, true, true)
    bagScene.held, bagScene.heldType, bagScene.heldKey = nil, nil, nil
    return
  end

  local cfg = _bag_cfg()
  local activePos = bagScene.slots and bagScene.slots.active
  local activeDist = activePos and #(p - activePos) or 999.0

  if typ == "bag" then
    local overlapBud = _bag_find_overlap_bud(p, nil)
    if overlapBud then
      _bag_finish_pair(overlapBud, ent, bagScene.budStrain[overlapBud])
    else


      local dropPos = vector3(p.x, p.y, p.z)
      _bag_pose_entity(ent, "bag", dropPos)
      bagScene.home[ent] = dropPos
      bagScene.pickPos[ent] = dropPos
      if bagScene.activeBag == ent then bagScene.activeBag = nil end
      FreezeEntityPosition(ent, true)
      SetEntityCollision(ent, true, true)
    end
  elseif typ == "bud" then
    local overlapBag = _bag_find_overlap_bag(p, nil)
    if overlapBag then
      _bag_finish_pair(ent, overlapBag, tostring(key or ""))
    elseif activePos and bagScene.activeBag and DoesEntityExist(bagScene.activeBag) and activeDist <= cfg.ActiveDropDist then
      _bag_finish_pair(ent, bagScene.activeBag, tostring(key or ""))
    else
      local home = bagScene.home[ent]
      if home then
        bagScene.pickPos[ent] = home
        _bag_pose_entity(ent, "bud", home)
      end
      FreezeEntityPosition(ent, true)
      SetEntityCollision(ent, true, true)
    end
  end

  bagScene.held, bagScene.heldType, bagScene.heldKey = nil, nil, nil
  bagScene.dragDown = false
  mouse.down = false
end

local function bagUpdateHeld(mx, my)
  if not bagScene or not bagScene.held or not DoesEntityExist(bagScene.held) then return end
  local p = mouseToTablePoint(bagScene.tableId, mx, my)
  if not p then return end
  local cfg = _bag_cfg()
  local z = p.z + cfg.HoldLift
  local ent = bagScene.held
  bagScene.pickPos[ent] = vector3(p.x, p.y, p.z)
  SetEntityCoordsNoOffset(ent, p.x, p.y, z, false, false, false)

  if bagScene.heldType == "bag" then
    SetEntityRotation(ent, 28.0, 0.0, _bag_entity_heading("active_bag") % 360.0, 2, true)
  else
    SetEntityRotation(ent, 0.0, 0.0, _bag_entity_heading("bud") % 360.0, 2, true)
  end
end


local function startGhost(kind)
  if placing.ghost then deleteEntitySafe(placing.ghost) placing.ghost=nil end
  local model = (kind=="pots" and (Config.Props and Config.Props.pot))
    or (kind=="lamps" and (Config.Props and Config.Props.growLamp))
    or (kind=="tables" and (Config.Props and Config.Props.bagTable))
  if not model then return end
  if ensureModel(model) then
    placing.ghost = CreateObject(modelHash(model), 0.0,0.0,0.0, false, false, false)
    SetEntityCollision(placing.ghost, false, false)
    SetEntityAlpha(placing.ghost, 160, false)
    SetEntityInvincible(placing.ghost, true)
    FreezeEntityPosition(placing.ghost, true)
  end
end

local function stopGhost()
  if placing.ghost then deleteEntitySafe(placing.ghost) end
  placing = { active=false, kind=nil, ghost=nil, heading=0.0 }
end


CreateThread(function()
  Wait(1200)
  TriggerServerEvent("azs1:player:requestSync")
end)

RegisterCommand("weedinv", function()
  TriggerServerEvent("azs1:inventory:request")
  openNui("inventory", { player = PlayerData or {}, strains = Config.Strains })
end, false)


CreateThread(function()
  while true do
    Wait(0)

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local closestPot, closestDist
    local closestTable, td

    if placing.active then
      if not placing.ghost then startGhost(placing.kind) end


      local hit, endCoords = raycastFromCamera(Config.Place.MaxDistance or 3.0, 1)
      if hit and placing.ghost then
        SetEntityCoordsNoOffset(placing.ghost, endCoords.x, endCoords.y, endCoords.z, false, false, false)
        SetEntityHeading(placing.ghost, placing.heading)

        DrawText3D(endCoords.x, endCoords.y, endCoords.z + 0.35, "[E] Place  [←/→] Rotate  [Backspace] Cancel")
        DrawMarker(0, endCoords.x, endCoords.y, endCoords.z + 0.03, 0,0,0, 0,0,0, 0.35,0.35,0.35, 0,255,0,120, false,true,2,false,nil,nil,false)

        if IsControlJustPressed(0, Config.Place.RotateLeftKey) then rotStep(-1) end
        if IsControlJustPressed(0, Config.Place.RotateRightKey) then rotStep(1) end

        if IsControlJustPressed(0, Config.Place.CancelKey) then
          stopGhost()
        end

        if IsControlJustPressed(0, Config.Place.ConfirmKey) then
          TriggerServerEvent("azs1:world:place", placing.kind, { x=endCoords.x, y=endCoords.y, z=endCoords.z }, placing.heading)
          stopGhost()


          CreateThread(function()
            Wait(150)
            TriggerServerEvent("azs1:player:requestSync")
            TriggerServerEvent("azs1:player:request")
          end)
        end
      end
      goto continue
    end


    if nuiOpen and currentContext == "bag_scene" then
      DisableControlAction(0, 1, true)
      DisableControlAction(0, 2, true)
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 257, true)
      DisableControlAction(0, 263, true)
      DisableControlAction(0, 106, true)

      pollCursor()

      if bagScene then


        if bagScene.dragDown and bagScene.held then
          bagUpdateHeld(mouse.x, mouse.y)
        end


        if bagScene.dragDown and (not (IsDisabledControlPressed(0, 24) or IsControlPressed(0, 24))) and bagScene.held then
          bagScene.dragDown = false
          mouse.down = false
          bagRelease(mouse.x, mouse.y)
        end

        _bag_debug_visuals(mouse.x, mouse.y)
        drawText2D(0.50, 0.965, "Bagging: load only the buds/bags you want, click the exact prop to drag it, then drop bud onto bag (or bag onto bud) | DEBUG ON | [BACKSPACE] Exit", 0.35)
      end

      if IsControlJustPressed(0, 177) then closeNui() end
      goto continue
    end


    if nuiOpen and currentContext == "plant_sidebar" then
      DisableControlAction(0, 1, true)
      DisableControlAction(0, 2, true)
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 200, true)

      pollCursor()
      pollButtons()

      if plantScene then
        if mouse.down and (not plantScene.held) then
          plantGrabTry(mouse.x, mouse.y)
        elseif (not mouse.down) and plantScene.held then
          plantRelease()
        end
      end


      if plantScene and plantScene.held and DoesEntityExist(plantScene.held) then
        local step = tonumber((Config and Config.ToolTiltStep) or 9.0) or 9.0
        if IsDisabledControlJustPressed(0, 241) or IsControlJustPressed(0, 241) then
          plantScene.tilt = (plantScene.tilt or 0.0) - step
          plantScene.lastWheelAt = GetGameTimer()
        elseif IsDisabledControlJustPressed(0, 242) or IsControlJustPressed(0, 242) then
          plantScene.tilt = (plantScene.tilt or 0.0) + step
          plantScene.lastWheelAt = GetGameTimer()
        end
        plantScene.tilt = math.max(-170.0, math.min(30.0, plantScene.tilt))
      end


      if plantScene and plantScene.held and DoesEntityExist(plantScene.held) then
        local step = 6.0
        local cfg2 = plantInteractCfg()
        if cfg2 and cfg2.ZRotStep then
          step = tonumber(cfg2.ZRotStep) or step
        end
        if IsDisabledControlJustPressed(0, 174) or IsControlJustPressed(0, 174) then
          plantScene.heldRotZ = (plantScene.heldRotZ or GetEntityHeading(plantScene.held)) - step
        elseif IsDisabledControlJustPressed(0, 175) or IsControlJustPressed(0, 175) then
          plantScene.heldRotZ = (plantScene.heldRotZ or GetEntityHeading(plantScene.held)) + step
        end
      end

      if plantScene and plantScene.held and plantScene.pot then
        if mouse.down then
          local shift = IsDisabledControlPressed(0, 21) or IsControlPressed(0, 21)
          if shift then
            local lastX = plantScene.dragLastX or mouse.x
            local dx = (mouse.x - lastX)
            plantScene.dragLastX = mouse.x

            local speed = 220.0
            plantScene.heldRotZ = (plantScene.heldRotZ or GetEntityHeading(plantScene.held)) + (dx * speed)

            local axis = plantScene.heldAxis or getToolAxis(plantScene.heldType)
            local invertTilt = (Config.ToolTiltInvert and Config.ToolTiltInvert[plantScene.heldType] == true) or false
            applyToolRotation(plantScene.held, axis, plantScene.tilt or 0.0, plantScene.heldRotZ, invertTilt)
          else
            plantScene.dragLastX = mouse.x
            local p = mouseToPotPoint(plantScene.pot, mouse.x, mouse.y)
            if p then
              local t = findPlantToolByEnt(plantScene.held)
              local zLift = (t and tonumber(t.zLift or 0.0)) or 0.0
              SetEntityCoordsNoOffset(plantScene.held, p.x, p.y, p.z + zLift, false, false, false)

              local axis = plantScene.heldAxis or getToolAxis(plantScene.heldType)
              local zRot = plantScene.heldRotZ or GetEntityHeading(plantScene.held)
              local invertTilt = (Config.ToolTiltInvert and Config.ToolTiltInvert[plantScene.heldType] == true) or false
              applyToolRotation(plantScene.held, axis, plantScene.tilt or 0.0, zRot, invertTilt)
            end
          end
        else
          plantScene.dragLastX = nil
        end
      end

      goto continue
    end

    if Config.Shop and Config.Shop.coords and #(pos - Config.Shop.coords) < (Config.DrawDistance or 8.0) then
      DrawMarker(2, Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z+0.1, 0,0,0, 0,0,0, 0.25,0.25,0.25, 0,200,120, 180, false,true,2,false,nil,nil,false)
      DrawText3D(Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z+0.35, (Config.Text and Config.Text.shop or "[E] Shop") .. " (Buy seeds/pots/lamps/tables)")
      if #(pos - Config.Shop.coords) < (Config.InteractDistance or 2.0) and IsControlJustPressed(0, Config.InteractKey) then
        openNui("shop", { items = Config.ShopItems, moneySystem = Config.MoneySystem, canPlace = true, player = PlayerData or {}, strains = Config.Strains, sellPrices = Config.SellPrices })
      end
    end

    for id, pot in pairs(World.pots) do
      local d = #(pos - vector3(pot.x, pot.y, pot.z))
      if d < (closestDist or 999.0) then
        closestDist = d
        closestPot = id
      end
    end

    if closestPot and closestDist and closestDist < 2.0 then
      local pot = World.pots[closestPot]
      local label = "[E] Plant"
      if pot.dead then
        label = "Dead Plant"
      elseif pot.strain then
        label = ("[E] Plant (%s)"):format(pot.strain)
      end
      DrawText3D(pot.x, pot.y, pot.z + 0.55, label)
      if IsControlJustPressed(0, Config.InteractKey) then
        openPlantSidebar(closestPot)
      end
    end

    for id, t in pairs(World.tables) do
      local d = #(pos - vector3(t.x, t.y, t.z))
      if d < (td or 999.0) then td = d; closestTable = id end
    end

    if closestTable and td and td < 2.0 then
      local t = World.tables[closestTable]
      DrawText3D(t.x, t.y, t.z + 0.95, "[E] Bagging Table")
      if IsControlJustPressed(0, Config.InteractKey) then
        createBagScene(closestTable)
      end
    end

    ::continue::
  end
end)


registerNui("mouse", function(data, reply)
    local wasDown = mouse.down
    mouse.x = clamp(tonumber(data.x) or 0.5, 0.0, 1.0)
    mouse.y = clamp(tonumber(data.y) or 0.5, 0.0, 1.0)
    mouse.down = (data.down == true)

    if nuiOpen and currentContext == "plant_sidebar" then
        local act = tostring(data.action or "")
        if act == "pick" then
            plantGrabTry(mouse.x, mouse.y)
        elseif act == "drop" then
            if plantScene and plantScene.held then plantRelease() end
        end

        if mouse.down and not wasDown then
            plantGrabTry(mouse.x, mouse.y)
        elseif (not mouse.down) and wasDown then
            if plantScene and plantScene.held then plantRelease() end
        end
    end

    if nuiOpen and currentContext == "bag_scene" then
      if bagScene then
        bagScene.lastMouseEventAt = GetGameTimer()
        local wasDownBag = (bagScene.dragDown == true)
        bagScene.dragDown = (data.down == true)

        if bagScene.dragDown and (not wasDownBag) then
          if bagScene.held and not DoesEntityExist(bagScene.held) then
            bagScene.held, bagScene.heldType, bagScene.heldKey = nil, nil, nil
          end
          if not bagScene.held then
            bagGrabTry(mouse.x, mouse.y)
          end
        elseif (not bagScene.dragDown) and wasDownBag then
          if bagScene.held then
            bagRelease(mouse.x, mouse.y)
          end
        end
      end
    end

    reply({ ok = true })
end)

registerNui("wheel", function(data, reply)
  if currentContext == "plant_sidebar" and plantScene and plantScene.held and DoesEntityExist(plantScene.held) then
    if plantScene.lastWheelAt and (GetGameTimer() - plantScene.lastWheelAt) < 80 then
      reply({ ok = true })
      return
    end
    local step = tonumber((Config and Config.ToolTiltStep) or 9.0) or 9.0

    local delta = tonumber(data.delta or 0) or 0
    if delta > 0 then
      plantScene.tilt = (plantScene.tilt or 0.0) - step
    elseif delta < 0 then
      plantScene.tilt = (plantScene.tilt or 0.0) + step
    end
    plantScene.tilt = math.max(-170.0, math.min(30.0, plantScene.tilt))

    local invert = (Config.ToolTiltInvert and Config.ToolTiltInvert[plantScene.heldType] == true) or false

    local axis = plantScene.heldAxis or getToolAxis(plantScene.heldType)
    local zRot = plantScene.heldRotZ or GetEntityHeading(plantScene.held)
    applyToolRotation(plantScene.held, axis, plantScene.tilt or 0.0, zRot, invert)
  end

  reply({ ok = true })
end)

registerNui("bag_load_selection", function(data, reply)
  local ok, err = _bag_load_selection(data or {})
  if not ok and err then notify(err) end
  reply({ ok = ok, error = err })
end)

registerNui("bag_close", function(_, reply)
  if destroyBagScene then destroyBagScene() end
  closeNui()
  reply({ ok = true })
end)

registerNui("use_item", function(data, reply)
  local item = tostring(data.item or "")

  if item == "pot" then
    if (PlayerData and (PlayerData.pots or 0) > 0) then
      placing.active = true
      placing.kind = "pots"
      placing.heading = GetEntityHeading(PlayerPedId())
      notify("Placement: Pot")
      reply({ ok = true }); return
    end
    notify("You don't have a pot.")
    reply({ ok = false }); return
  end

  if item == "lamp" then
    if (PlayerData and (PlayerData.lamps or 0) > 0) then
      placing.active = true
      placing.kind = "lamps"
      placing.heading = GetEntityHeading(PlayerPedId())
      notify("Placement: Lamp")
      reply({ ok = true }); return
    end
    notify("You don't have a lamp.")
    reply({ ok = false }); return
  end

  if item == "bag_table" then
    if (PlayerData and (PlayerData.tables or 0) > 0) then
      placing.active = true
      placing.kind = "tables"
      placing.heading = GetEntityHeading(PlayerPedId())
      notify("Placement: Bagging Table")
      reply({ ok = true }); return
    end
    notify("You don't have a bagging table.")
    reply({ ok = false }); return
  end

  reply({ ok = false })
end)

registerNui("open_inventory", function(_, reply)
  TriggerServerEvent("azs1:inventory:request")
  openNui("inventory", { player = PlayerData or {}, strains = Config.Strains, sellPrices = Config.SellPrices, moneySystem = Config.MoneySystem })
  reply({ ok = true })
end)

registerNui("sell_item", function(data, reply)
  local itemType = tostring(data.itemType or "")
  local strainKey = tostring(data.strainKey or "")
  local amount = tostring(data.amount or "one")
  TriggerServerEvent("azs1:sell:product", itemType, strainKey, amount)
  reply({ ok = true })
end)

registerNui("nui_ready", function(_, reply)
  if nuiOpen and currentContext then
    nuiSend("open", { context = currentContext, payload = {} })
  end
  reply({ ok = true })
end)


AddEventHandler("onResourceStop", function(res)
  if res ~= RES then return end
  closeNui()
  if destroyBagScene then destroyBagScene() end
  stopGhost()
  for _, ent in pairs(Spawned.pots) do deleteEntitySafe(ent) end
  for _, ent in pairs(Spawned.dirt) do deleteEntitySafe(ent) end
  for _, ent in pairs(Spawned.lamps) do deleteEntitySafe(ent) end
  for _, ent in pairs(Spawned.tables) do deleteEntitySafe(ent) end
  for k, ent in pairs(Spawned) do
    if type(k) == "string" and k:sub(1,6) == "plant_" then
      deleteEntitySafe(ent)
    end
  end
end)

CreateThread(function()
  while true do
    Wait(250)
    if (not nuiOpen) and (bagCam or plantCam) then
      destroyAllCams()
    end
  end
end)


