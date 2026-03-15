local RES = GetCurrentResourceName()

Config = Config or {}


Config.World = Config.World or { Pots = {}, BaggingStations = {}, Shops = {}, WaterSources = {}, TrimmingStations = {} }
Config.Shop  = Config.Shop  or { Items = {} }
Config.Plants = Config.Plants or {}

local function dbg(...)
  if Config.Debug then print('[az-schedule1]', ...) end
end

local json = json or require("json")


local function kvpKeyWorld() return "azs1:world:v1" end
local function kvpKeyPlayer(license) return ("azs1:player:v1:%s"):format(license) end


local function collectIds(src)
  local ids = { license=nil, license2=nil, fivem=nil, steam=nil }

  for _, id in ipairs(GetPlayerIdentifiers(src)) do
    if (not ids.license)  and id:sub(1,8) == "license:"  then ids.license  = id end
    if (not ids.license2) and id:sub(1,9) == "license2:" then ids.license2 = id end
    if (not ids.fivem)    and id:sub(1,6) == "fivem:"    then ids.fivem    = id end
    if (not ids.steam)    and id:sub(1,6) == "steam:"    then ids.steam    = id end
  end

  return ids
end


local function preferredId(ids, src)
  return (ids and (ids.license or ids.license2 or ids.fivem or ids.steam))
      or ("license:unknown:%d"):format(src or 0)
end


local function getLicense(src)
  return preferredId(collectIds(src), src)
end


local function kvpGetJson(key, fallback)
  local raw = GetResourceKvpString(key)
  if not raw or raw == "" then return fallback end
  local ok, data = pcall(json.decode, raw)
  if ok and data ~= nil then return data end
  return fallback
end

local function kvpSetJson(key, data)
  SetResourceKvp(key, json.encode(data))
end


local world = kvpGetJson(kvpKeyWorld(), { pots = {}, lamps = {}, tables = {} })


local players = {}

local function defaultPlayerData()
  return {
    buds = {},
    bagged = {},
    bags = 0,
    mixers = {},
    seeds = {},
    money = 0,


    pots = 0,
    lamps = 0,
    tables = 0,
    dirt = 0,
    fertilizer = 0,
    watering_can = 0,
    water_jug = 0,
    trimmers = 0,
  }
end

local function normalizePlayerData(d)
  if type(d) ~= "table" then d = {} end
  d.buds = type(d.buds)=="table" and d.buds or {}
  d.bagged = type(d.bagged)=="table" and d.bagged or {}
  d.mixers = type(d.mixers)=="table" and d.mixers or {}
  d.seeds = type(d.seeds)=="table" and d.seeds or {}
  d.money = tonumber(d.money or 0) or 0
  d.bags = tonumber(d.bags or 0) or 0
  d.pots = tonumber(d.pots or 0) or 0
  d.lamps = tonumber(d.lamps or 0) or 0
  d.tables = tonumber(d.tables or 0) or 0
  d.dirt = tonumber(d.dirt or 0) or 0
  d.fertilizer = tonumber(d.fertilizer or 0) or 0
  d.water_jug = tonumber(d.water_jug or 0) or 0
  d.watering_can = tonumber(d.watering_can or 0) or 0
  d.trimmers = tonumber(d.trimmers or 0) or 0
  return d
end


local function hasOx()
  return Config.Storage == "mysql" and (Config.OxMySQL or "") ~= "" and GetResourceState(Config.OxMySQL) == "started"
end

local function dbExec(query, params, cb)
  if not hasOx() then
    if cb then cb(nil) end
    return
  end
  exports[Config.OxMySQL]:execute(query, params or {}, cb or function() end)
end

local function dbScalar(query, params, cb)
  if not hasOx() then
    cb(nil); return
  end
  exports[Config.OxMySQL]:scalar(query, params or {}, cb)
end

local function dbSingle(query, params, cb)
  if not hasOx() then
    cb(nil); return
  end
  if exports[Config.OxMySQL].single then
    exports[Config.OxMySQL]:single(query, params or {}, cb)
  else
    exports[Config.OxMySQL]:query(query, params or {}, function(rows)
      cb((rows and rows[1]) or nil)
    end)
  end
end

local function await(cbfn)
  local done, result = false, nil
  cbfn(function(r)
    result = r
    done = true
  end)
  while not done do Wait(0) end
  return result
end

local function ensureTables()
  if not hasOx() then return end
  dbExec([[
    CREATE TABLE IF NOT EXISTS azs1_players (
      identifier VARCHAR(64) NOT NULL PRIMARY KEY,
      data LONGTEXT NOT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  ]])
end

CreateThread(function()
  Wait(250)
  ensureTables()
end)

local function dbLoadPlayer(identifier, cb)
  dbExec("SELECT data FROM azs1_players WHERE identifier=? LIMIT 1", {identifier}, function(rows)
    if rows and rows[1] and rows[1].data then
      local ok, parsed = pcall(json.decode, rows[1].data)
      if ok and type(parsed) == "table" then cb(parsed); return end
    end
    cb(nil)
  end)
end

local function dbSavePlayer(identifier, data)
  dbExec("INSERT INTO azs1_players (identifier, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data=VALUES(data)", {identifier, json.encode(data)})
end

local function loadPlayer(src)
  local ids = collectIds(src)
  local lic = preferredId(ids, src)

  if hasOx() then
    local row = await(function(done)
      dbSingle("SELECT data FROM azs1_players WHERE identifier = ? LIMIT 1", { lic }, done)
    end)


    if (not row) or (not row.data) or row.data == "" then
      for _, alt in ipairs({ ids.license2, ids.license, ids.fivem, ids.steam }) do
        if alt and alt ~= lic then
          local row2 = await(function(done)
            dbSingle("SELECT data FROM azs1_players WHERE identifier = ? LIMIT 1", { alt }, done)
          end)
          if row2 and row2.data and row2.data ~= "" then
            dbExec("INSERT INTO azs1_players (identifier, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)", { lic, row2.data })
            row = row2
            break
          end
        end
      end
    end


    local pdata = nil
    if row and row.data and row.data ~= "" then
      local ok, decoded = pcall(json.decode, row.data)
      if ok and type(decoded) == "table" then pdata = decoded end
    end
    if not pdata then
      pdata = defaultPlayerData()
      dbExec("INSERT INTO azs1_players (identifier, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)", { lic, json.encode(pdata) })
    end

    pdata = normalizePlayerData(pdata)
    players[src] = { lic = lic, data = pdata }
    return players[src]
  end


  local pdata = kvpGetJson(kvpKeyPlayer(lic), nil)
  if not pdata then
    for _, alt in ipairs({ ids.license2, ids.license, ids.fivem, ids.steam }) do
      if alt and alt ~= lic then
        pdata = kvpGetJson(kvpKeyPlayer(alt), nil)
        if pdata then
          kvpSetJson(kvpKeyPlayer(lic), pdata)
          break
        end
      end
    end
  end
  pdata = normalizePlayerData(pdata or defaultPlayerData())
  players[src] = { lic = lic, data = pdata }
  return players[src]
end


local function savePlayer(src)
  local p = players[src]
  if not p then return end
  p.data = normalizePlayerData(p.data)

  if hasOx() then
    dbExec("INSERT INTO azs1_players (identifier, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)", { p.lic, json.encode(p.data) })
    return
  end

  kvpSetJson(kvpKeyPlayer(p.lic), p.data)
end


local function saveWorld()
  kvpSetJson(kvpKeyWorld(), world)
end

local function notify(src, msg)
  TriggerClientEvent("azs1:notify", src, msg)
end

local function broadcastWorld()
  TriggerClientEvent("azs1:world:sync", -1, world)
end

local function broadcastPlayer(src)
  local p = players[src]
  if not p then return end
  TriggerClientEvent("azs1:player:sync", src, p.data)
end


local function getPrice(itemKey)
  local it = Config.ShopItems and Config.ShopItems[itemKey]
  return it and (it.price or 0) or 0
end


local function getSellPrice(kind, strainKey)
  local prices = Config.SellPrices or {}
  local bucket = prices[kind] or {}
  local direct = tonumber(bucket[strainKey] or 0) or 0
  if direct > 0 then return direct end
  local fallback = tonumber(bucket.default or 0) or 0
  if fallback > 0 then return fallback end
  return kind == "bagged" and 125 or 50
end

local function addSaleMoney(src, amount, reason)
  amount = math.floor(tonumber(amount or 0) or 0)
  if amount <= 0 then return true end

  if Config.MoneySystem == "az-econ" then
    local exp = Config.AzEcon and Config.AzEcon.ExportName or "az-econ"
    local fn = Config.AzEcon and Config.AzEcon.AddMoneyFn or "addMoney"
    local ok = pcall(function()
      exports[exp][fn](src, amount, reason or "az-schedule1:sell")
    end)
    if ok then return true end
  end

  local p = players[src] or loadPlayer(src)
  p.data.money = math.max(0, math.floor(tonumber(p.data.money or 0) or 0) + amount)
  return true
end

local function canAfford(src, cost)
  if Config.MoneySystem == "none" then return true end
  local p = players[src]; if not p then return false end
  return (p.data.money or 0) >= cost
end

local function takeMoney(src, cost)
  if Config.MoneySystem == "none" then return true end
  local p = players[src]; if not p then return false end
  p.data.money = math.max(0, (p.data.money or 0) - cost)
  return true
end


RegisterNetEvent("azs1:shop:buy", function(itemKey)
  local src = source
  local p = players[src] or loadPlayer(src)
  if not p then return end
  p.data = normalizePlayerData(p.data)
  local price = getPrice(itemKey)
  if not canAfford(src, price) then return notify(src, "Not enough money") end
  takeMoney(src, price)

  if itemKey:find("^seed:") then
    local strain = itemKey:gsub("^seed:", "")
    p.data.seeds[strain] = (p.data.seeds[strain] or 0) + 1
    notify(src, ("Bought 1 seed (%s)"):format(strain))
  elseif itemKey == "empty_bag" then
    local it = (Config.ShopItems and Config.ShopItems[itemKey]) or {}
    local amt = tonumber(it.amount or 10) or 10
    p.data.bags = (p.data.bags or 0) + amt
    notify(src, ("Bought %d empty bags"):format(amt))
  elseif itemKey:find("^mixer:") then
    local mk = itemKey:gsub("^mixer:", "")
    p.data.mixers[mk] = (p.data.mixers[mk] or 0) + 1
    notify(src, ("Bought 1 mixer (%s)"):format(mk))
  elseif itemKey == "mixer:basic" then
    p.data.mixers["basic"] = (p.data.mixers["basic"] or 0) + 1
    notify(src, "Bought 1 mixer (basic)")
  elseif itemKey == "dirt" then
    p.data.dirt = (p.data.dirt or 0) + 1
    notify(src, "Bought 1 bag of dirt")
  elseif itemKey == "fertilizer" then
    p.data.fertilizer = (p.data.fertilizer or 0) + 1
    notify(src, "Bought 1 fertilizer")
  elseif itemKey == "pot" then
    p.data.pots = (p.data.pots or 0) + 1
    notify(src, "Bought 1 pot")
  elseif itemKey == "lamp" then
    p.data.lamps = (p.data.lamps or 0) + 1
    notify(src, "Bought 1 grow lamp")
  elseif itemKey == "bag_table" then
    p.data.tables = (p.data.tables or 0) + 1
    notify(src, "Bought 1 bagging table")
  elseif itemKey == "watering_can" then
    p.data.watering_can = (p.data.watering_can or 0) + 1
    notify(src, "Bought 1 watering can")
  elseif itemKey == "water_jug" then
    p.data.water_jug = (p.data.water_jug or 0) + 1
    notify(src, "Bought 1 water jug")
  elseif itemKey == "trimmers" then
    p.data.trimmers = (p.data.trimmers or 0) + 1
    notify(src, "Bought 1 trimmers")
  else
    notify(src, "Unknown item")
  end

  dbg("BUY src=%d item=%s pots=%d dirt=%d fert=%d lamps=%d tables=%d bags=%d", src, tostring(itemKey), tonumber(p.data.pots or 0), tonumber(p.data.dirt or 0), tonumber(p.data.fertilizer or 0), tonumber(p.data.lamps or 0), tonumber(p.data.tables or 0), tonumber(p.data.bags or 0))

  savePlayer(src)
  broadcastPlayer(src)
end)


local function countOwned(kind, license)
  local t = world[kind] or {}
  local c = 0
  for _, obj in pairs(t) do
    if obj.owner == license then c = c + 1 end
  end
  return c
end

local function newId(prefix)
  return ("%s_%d_%d"):format(prefix, os.time(), math.random(1000,9999))
end

RegisterNetEvent("azs1:world:place", function(kind, coords, heading)
  local src = source
  local p = players[src] or loadPlayer(src)
  kind = tostring(kind or "")
  if type(coords) ~= "table" then return end
  heading = tonumber(heading or 0.0) or 0.0

  if kind == "pots" then
    if (p.data.pots or 0) <= 0 then return notify(src, "You don't have a pot. Buy one at the shop.") end
    if countOwned("pots", p.lic) >= (Config.World.MaxPotsPerPlayer or 20) then return notify(src, "Pot limit reached.") end
    p.data.pots = (p.data.pots or 0) - 1

    local id = newId("pot")
    world.pots[id] = {
      id=id, owner=p.lic,
      x=coords.x, y=coords.y, z=coords.z,
      h=heading,
      strain=nil,
      growth=0.0,
      water=0.0,
      fert=0.0,
      stage=0,
      dead=false,
      hasDirt=false,
      dirtTicks=0,
      belowTicks=0
    }
    saveWorld(); savePlayer(src)
    broadcastWorld(); broadcastPlayer(src)
    notify(src, "Pot placed.")
    return
  end

  if kind == "lamps" then
    if (p.data.lamps or 0) <= 0 then return notify(src, "You don't have a lamp. Buy one at the shop.") end
    if countOwned("lamps", p.lic) >= (Config.World.MaxLampsPerPlayer or 10) then return notify(src, "Lamp limit reached.") end
    p.data.lamps = (p.data.lamps or 0) - 1

    local id = newId("lamp")
    world.lamps[id] = { id=id, owner=p.lic, x=coords.x, y=coords.y, z=coords.z, h=heading }
    saveWorld(); savePlayer(src)
    broadcastWorld(); broadcastPlayer(src)
    notify(src, "Lamp placed.")
    return
  end

  if kind == "tables" then
    if (p.data.tables or 0) <= 0 then return notify(src, "You don't have a table. Buy one at the shop.") end
    if countOwned("tables", p.lic) >= (Config.World.MaxBagTablesPerPlayer or 3) then return notify(src, "Table limit reached.") end
    p.data.tables = (p.data.tables or 0) - 1

    local id = newId("table")
    world.tables[id] = { id=id, owner=p.lic, x=coords.x, y=coords.y, z=coords.z, h=heading }
    saveWorld(); savePlayer(src)
    broadcastWorld(); broadcastPlayer(src)
    notify(src, "Bagging table placed.")
    return
  end
end)


RegisterNetEvent("azs1:pot:addDirt", function(potId)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if pot.strain then return notify(src, "Already planted.") end
  if pot.hasDirt then return notify(src, "Pot already has dirt.") end
  if (p.data.dirt or 0) <= 0 then return notify(src, "You need dirt. Buy it at the shop.") end

  p.data.dirt = (p.data.dirt or 0) - 1
  pot.hasDirt = true
  pot.water = 0.0
  pot.fert  = 0.0

  saveWorld(); savePlayer(src)
  broadcastWorld(); broadcastPlayer(src)
  notify(src, "Added dirt to pot.")
end)

RegisterNetEvent("azs1:pot:plant", function(potId, strainKey)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  strainKey = tostring(strainKey or "")

  local pot = world.pots[potId]
  if not pot then return end
  if pot.dead then return notify(src, "This plant is dead.") end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.strain ~= nil then return notify(src, "Already planted.") end
  if not pot.hasDirt then return notify(src, "This pot needs dirt first.") end

  if (p.data.seeds[strainKey] or 0) <= 0 then return notify(src, "You don't have that seed.") end
  p.data.seeds[strainKey] = (p.data.seeds[strainKey] or 0) - 1
  pot.strain = strainKey
  pot.growth = 0.0
  pot.water = 50.0
  pot.fert  = 50.0
  pot.belowTicks = 0
  pot.dead = false

  saveWorld(); savePlayer(src)
  broadcastWorld(); broadcastPlayer(src)
  notify(src, ("Planted %s."):format(strainKey))
end)

RegisterNetEvent("azs1:pot:water", function(potId)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if not pot.strain then return notify(src, "Nothing planted.") end
  if (p.data.watering_can or 0) <= 0 then
    if (p.data.water_jug or 0) <= 0 then
      return notify(src, "You need a watering can or a water jug. Buy it at the shop.")
    end
    p.data.water_jug = math.max(0, (p.data.water_jug or 0) - 1)
  end

  pot.water = math.min(100.0, (pot.water or 0) + 25.0)
  saveWorld()
  broadcastWorld()
  notify(src, "Watered (+25).")
end)


RegisterNetEvent("azs1:pot:waterPour", function(potId, delta)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if not pot.strain then return notify(src, "Nothing planted.") end
  if (p.data.watering_can or 0) <= 0 then return notify(src, "You need a watering can. Buy it at the shop.") end


  delta = tonumber(delta or 0) or 0
  if delta <= 0 then return end
  pot.water = math.min(100.0, (pot.water or 0) + delta)

  saveWorld()
  broadcastWorld()
end)


RegisterNetEvent("azs1:pot:fert", function(potId)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if not pot.strain then return notify(src, "Nothing planted.") end

  if (p.data.fertilizer or 0) <= 0 then return notify(src, "You need fertilizer. Buy it at the shop.") end
  p.data.fertilizer = (p.data.fertilizer or 0) - 1
  pot.fert = math.min(100.0, (pot.fert or 0) + 25.0)
  saveWorld()
  broadcastWorld()
  notify(src, "Fertilized (+25).")
end)


RegisterNetEvent("azs1:pot:fertPour", function(potId, delta)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if not pot.strain then return notify(src, "Nothing planted.") end

  delta = tonumber(delta or 0) or 0
  if delta <= 0 then return end

  if (p.data.fertilizer or 0) <= 0 then return notify(src, "You need fertilizer. Buy it at the shop.") end


  p.data.fertilizer = (p.data.fertilizer or 0) - 1
  pot.fert = math.min(100.0, (pot.fert or 0) + delta)

  saveWorld()
  savePlayer(src)
  broadcastWorld()
  broadcastPlayer(src)
end)


RegisterNetEvent("azs1:pot:trim", function(potId)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if not pot.strain then return notify(src, "Nothing planted.") end
  if (pot.growth or 0) < 35.0 then return notify(src, "Too early to trim.") end

  if (p.data.trimmers or 0) <= 0 then return notify(src, "You need trimmers. Buy them at the shop.") end


  pot.growth = math.min(100.0, (pot.growth or 0) + 3.0)
  saveWorld()
  broadcastWorld()
  notify(src, "Trimmed (+3% growth).")
end)

RegisterNetEvent("azs1:pot:harvest", function(potId)
  local src = source
  local p = players[src] or loadPlayer(src)
  potId = tostring(potId or "")
  local pot = world.pots[potId]
  if not pot then return end
  if pot.owner ~= p.lic then return notify(src, "Not your pot.") end
  if pot.dead then return notify(src, "Plant is dead.") end
  if not pot.strain then return notify(src, "Nothing planted.") end
  if (pot.growth or 0) < 100.0 then return notify(src, "Not ready.") end

  local yield = 6
  local strain = pot.strain
  p.data.buds[strain] = (p.data.buds[strain] or 0) + yield


  pot.strain = nil
  pot.growth = 0.0
  pot.water = 0.0
  pot.fert  = 0.0
  pot.hasDirt = true
  pot.belowTicks = 0
  pot.dead = false

  saveWorld(); savePlayer(src)
  broadcastWorld(); broadcastPlayer(src)
  notify(src, ("Harvested %d buds (%s)."):format(yield, strain))
end)


RegisterNetEvent("azs1:bag:one", function(strainKey)
  local src = source
  local p = players[src] or loadPlayer(src)
  strainKey = tostring(strainKey or "")
  if (p.data.buds[strainKey] or 0) <= 0 then return notify(src, "No buds.") end
  if (p.data.bags or 0) <= 0 then return notify(src, "No empty bags.") end

  p.data.buds[strainKey] = (p.data.buds[strainKey] or 0) - 1
  p.data.bags = (p.data.bags or 0) - 1
  p.data.bagged = p.data.bagged or {}
  p.data.bagged[strainKey] = (p.data.bagged[strainKey] or 0) + 1

  local strainLabel = strainKey
  if Config.Strains and Config.Strains[strainKey] and Config.Strains[strainKey].label then
    strainLabel = tostring(Config.Strains[strainKey].label)
  end

  savePlayer(src)
  broadcastPlayer(src)
  notify(src, ("Bagged 1 %s."):format(strainLabel))
end)


RegisterNetEvent("azs1:sell:product", function(itemType, strainKey, amountMode)
  local src = source
  local p = players[src] or loadPlayer(src)
  itemType = tostring(itemType or "")
  strainKey = tostring(strainKey or "")
  amountMode = tostring(amountMode or "one")

  if itemType ~= "buds" and itemType ~= "bagged" then
    return notify(src, "Invalid product type.")
  end

  local store = p.data[itemType]
  if type(store) ~= "table" then
    p.data[itemType] = {}
    store = p.data[itemType]
  end

  local owned = math.floor(tonumber(store[strainKey] or 0) or 0)
  if owned <= 0 then
    return notify(src, "You do not have any of that product.")
  end

  local amount = 1
  if amountMode == "all" then amount = owned end
  amount = math.max(1, math.min(owned, math.floor(tonumber(amount) or 1)))

  local each = getSellPrice(itemType, strainKey)
  local total = amount * each
  store[strainKey] = math.max(0, owned - amount)
  addSaleMoney(src, total, ("az-schedule1:sell:%s"):format(itemType))

  local strainLabel = strainKey
  if Config.Strains and Config.Strains[strainKey] and Config.Strains[strainKey].label then
    strainLabel = tostring(Config.Strains[strainKey].label)
  end

  savePlayer(src)
  broadcastPlayer(src)
  notify(src, ("Sold %dx %s for $%d."):format(amount, strainLabel, total))
end)


RegisterNetEvent("azs1:mix:do", function(inStrain, mixerKey)
  local src = source
  local p = players[src] or loadPlayer(src)
  inStrain = tostring(inStrain or "")
  mixerKey = tostring(mixerKey or "")
  if (p.data.buds[inStrain] or 0) <= 0 then return notify(src, "No buds.") end
  if (p.data.mixers[mixerKey] or 0) <= 0 then return notify(src, "No mixer.") end

  local recipe = Config.MixRecipes and Config.MixRecipes[inStrain] and Config.MixRecipes[inStrain][mixerKey]
  if not recipe then return notify(src, "No recipe.") end

  p.data.buds[inStrain] = (p.data.buds[inStrain] or 0) - 1
  p.data.mixers[mixerKey] = (p.data.mixers[mixerKey] or 0) - 1

  local out = recipe.outStrain
  local outBuds = recipe.outBuds or 2
  p.data.buds[out] = (p.data.buds[out] or 0) + outBuds
  if recipe.bonusSeeds then
    p.data.seeds[out] = (p.data.seeds[out] or 0) + (recipe.bonusSeeds or 0)
  end

  savePlayer(src)
  broadcastPlayer(src)
  notify(src, ("Mixed into %s (+%d buds)."):format(out, outBuds))
end)


RegisterNetEvent("azs1:player:requestSync", function()
  local src = source
  loadPlayer(src)
  TriggerClientEvent("azs1:world:sync", src, world)
  broadcastPlayer(src)
end)


RegisterNetEvent("azs1:player:request", function()
  local src = source
  loadPlayer(src)
  TriggerClientEvent("azs1:world:sync", src, world)
  broadcastPlayer(src)
end)


AddEventHandler("playerDropped", function()
  local src = source
  savePlayer(src)
  players[src] = nil
end)


local function lampNearPot(pot)
  local r = Config.World.LampRadius or 2.5
  for _, lamp in pairs(world.lamps) do
    local dx = (lamp.x - pot.x); local dy = (lamp.y - pot.y); local dz = (lamp.z - pot.z)
    local d = math.sqrt(dx*dx + dy*dy + dz*dz)
    if d <= r then return true end
  end
  return false
end

CreateThread(function()
  Wait(2000)
  while true do
    Wait((Config.World.TickSeconds or 10) * 1000)

    local changed = false
    for _, pot in pairs(world.pots) do
      if pot.strain and not pot.dead then
        pot.water = math.max(0.0, (pot.water or 0) - (Config.World.WaterDecayPerTick or 0.8))
        pot.fert  = math.max(0.0, (pot.fert or 0) - (Config.World.FertDecayPerTick  or 0.6))

        local waterFactor = math.min(1.0, (pot.water or 0) / 50.0)
        local fertFactor  = math.min(1.0, (pot.fert  or 0) / 50.0)
        local mult = (0.15 + 0.85 * ((waterFactor + fertFactor) / 2.0))

        if lampNearPot(pot) then
          mult = mult * (Config.World.LampGrowthMultiplier or 1.35)
        end

        pot.growth = math.min(100.0, (pot.growth or 0) + (Config.World.BaseGrowthPerTick or 1.2) * mult)


        if (pot.water or 0) < (Config.World.DieIfWaterBelow or 2.0) then
          pot.belowTicks = (pot.belowTicks or 0) + 1
          if pot.belowTicks >= (Config.World.DieGraceTicks or 30) then
            pot.dead = true
          end
        else
          pot.belowTicks = 0
        end

        changed = true
      end
    end

    if changed then
      saveWorld()
      broadcastWorld()
    end
  end
end)


RegisterNetEvent("azs1:inventory:request", function()
  local src = source
  local p = players[src] or loadPlayer(src)
  broadcastPlayer(src)
end)


