Config = {}


Config.Debug = false


Config.UseNui = true


Config.UseDuiForMixingStation = true
Config.DuiSize = { w = 1024, h = 768 }


Config.MoneySystem = 'none'


Config.Storage = "mysql"
Config.OxMySQL = "oxmysql"


Config.AzEcon = {
  ExportName = 'az-econ',
  RemoveMoneyFn = 'removeMoney',
  AddMoneyFn    = 'addMoney'
}


Config.Shop = {
  label = "Seed & Supply Shop",
  coords = vec3(222.68, -806.08, 30.61),
  heading = 0.0,
  blip = { enabled = true, sprite = 496, color = 2, scale = 0.8 }
}

Config.GrowRoom = {
  label = "Grow Room",


  spots = {
    { id=1, coords=vec3(214.10, -810.42, 30.73), heading=0.0 },
    { id=2, coords=vec3(215.10, -810.42, 30.73), heading=0.0 },
    { id=3, coords=vec3(216.10, -810.42, 30.73), heading=0.0 },
    { id=4, coords=vec3(214.10, -809.20, 30.73), heading=180.0 },
    { id=5, coords=vec3(215.10, -809.20, 30.73), heading=180.0 },
    { id=6, coords=vec3(216.10, -809.20, 30.73), heading=180.0 },
  }
}

Config.BaggingStation = {
  label = "Bagging Station",
  coords = vec3(219.06, -807.32, 30.73),
  heading = 90.0
}

Config.MixingStation = {
  label = "Mixing Station",
  coords = vec3(218.10, -806.10, 30.73),
  heading = 0.0,
  duiDraw = {
    enabled = true,
    offset = vec3(0.0, 0.0, 1.15),
    scale = 0.12
  }
}


Config.ShopItems = {

  ["pot"] = { label = "Plant Pot", desc = "Place a pot, add dirt, then plant seeds.", price = 40 },
  ["lamp"] = { label = "LED Grow Lamp", desc = "Place near pots to boost growth.", price = 150 },
  ["bag_table"] = { label = "Bagging Table", desc = "Place a table for 3D bagging.", price = 200 },
  ["trimmers"] = { label = "Trimmers", desc = "Required to trim plants (not consumed).", price = 80 },
  ["watering_can"] = { label = "Watering Can", desc = "Required to water plants (not consumed).", price = 60 },

  ["water_jug"]    = { label = "Water Jug", desc = "Consumable water source (1 use).", price = 8 },

  ["dirt"] = { label = "Bag of Dirt", desc = "Fill pots before planting.", price = 10 },
  ["fertilizer"] = { label = "Fertilizer", desc = "Fertilize plants (+25).", price = 35 },
  ["empty_bag"] = { label = "Empty Baggies (x10)", desc = "Used to bag buds.", price = 75, amount = 10 },


  ["seed:og_kush"]     = { label = "OG Kush Seeds",     desc = "Seed packet.", price = 50 },
  ["seed:blue_dream"]  = { label = "Blue Dream Seeds",  desc = "Seed packet.", price = 60 },
  ["seed:sour_diesel"] = { label = "Sour Diesel Seeds", desc = "Seed packet.", price = 65 },


  ["mixer:coke"]   = { label = "Coke Mixer",   desc = "Mixer ingredient.", price = 90 },
  ["mixer:energy"] = { label = "Energy Mixer", desc = "Mixer ingredient.", price = 90 },
  ["mixer:syrup"]  = { label = "Syrup Mixer",  desc = "Mixer ingredient.", price = 90 },
}


Config.SellPrices = {
  buds = {
    default = 55,
    og_kush = 60,
    blue_dream = 68,
    sour_diesel = 74,
  },
  bagged = {
    default = 135,
    og_kush = 145,
    blue_dream = 155,
    sour_diesel = 165,
  }
}


Config.Strains = {
  og_kush = {
    label = "OG Kush",
    baseYield = 6,
    growMinutes = 45,
    effects = {"Calming"}
  },
  blue_dream = {
    label = "Blue Dream",
    baseYield = 7,
    growMinutes = 55,
    effects = {"Refreshing"}
  },
  sour_diesel = {
    label = "Sour Diesel",
    baseYield = 8,
    growMinutes = 60,
    effects = {"Energizing"}
  }
}


Config.CareDrain = {
  water = 1.0,
  trim  = 0.4
}


Config.CareImpact = {
  minMultiplier = 0.25,
  yieldPenaltyAtZero = 0.45
}


Config.HarvestAt = 100.0


Config.PlantModels = {
  empty = `prop_pot_plant_02a`,
  stage1 = `bkr_prop_weed_01_small_01c`,
  stage2 = `bkr_prop_weed_01_med_01b`,
  stage3 = `bkr_prop_weed_lrg_01b`,
}


Config.MixRecipes = {


  { inStrain='og_kush', mixer='coke', outKey='californian_cookies', outLabel='Californian Cookies', effects={"Refreshing","Energizing"}, yield=1 },


  { inStrain='blue_dream', mixer='energy', outKey='neon_breeze', outLabel='Neon Breeze', effects={"Refreshing","Energizing"}, yield=1 },


  { inStrain='sour_diesel', mixer='syrup', outKey='purple_drift', outLabel='Purple Drift', effects={"Calming","Refreshing"}, yield=1 },
}


Config.MixedStrainsPlantable = true
Config.MixedSeedYield = 1


Config.InteractKey = 38
Config.DrawDistance = 18.0
Config.InteractDistance = 1.8


Config.Text = {
  shop = "[E] Open Shop",
  plant = "[E] Plant / Care",
  bag = "[E] Bag Product",
  mix = "[E] Mix Strains",
}


Config.UseWorldPlacement = false

Config.World = {


  MaxPotsPerPlayer = 20,
  MaxLampsPerPlayer = 10,
  MaxBagTablesPerPlayer = 10,


  TickSeconds = 10,


  WaterDecayPerTick = 0.8,
  FertDecayPerTick  = 0.6,


  BaseGrowthPerTick = 1.2,


  LampRadius = 2.5,
  LampGrowthMultiplier = 1.35,


  DieIfWaterBelow = 2.0,
  DieGraceTicks   = 30,
}

Config.Props = {
  pot = "prop_bucket_02a",
  dirt = "prop_cs_sack_01",
  seedBag = "prop_weed_bottle",
  fertBottle = "prop_feed_sack_01",
  waterBottle = "prop_wateringcan",
  secateurs = "prop_cs_scissors",
  growLamp = "bzzz_world_of_lamps_purple",
  bagTable = "prop_table_03",
  weedBud = "bkr_prop_weed_bud_01b",
  weedBag = "m25_1_prop_m51_bag_weed_01a",
}


Config.Place = {
  ConfirmKey = 38,
  CancelKey  = 194,
  RotateLeftKey  = 174,
  RotateRightKey = 175,
  RotateStep = 5.0,
  MaxDistance = 3.0,
}


Config.PlantUI = {
  UseSidebar = true
}


Config.Cameras = {
  Plant = {
    Side = 0.42,
    Back = 0.98,
    Up   = 0.62,
    Fov  = 90.0,
    LookZ = 0.24,
  },
  Bagging = {
  Back = 1.00,
  Up = 0.90,
  Side = 0.00,
  LookFwd = 0.12,
  LookZ = 0.02,
  Fov = 62.0,
  }
}

Config.Bagging = {
  PickDist = 0.13,
  ActiveDropDist = 0.15,
  HoldLift = 0.08,
  OutputMax = 6,
  PlaneZAdd = 0.02,


  ActiveBagLift = 0.055,
  ActiveBagPitch = 89.0,
  ActiveBagRoll = 0.0,

  LocalPickRadius = 0.11,
  BudLocalPickRadius = 0.125,
  BagLocalPickRadius = 0.085,
  ActiveBagLocalPickRadius = 0.08,

  ScreenPickRadius = 0.08,
  BudScreenPickRadius = 0.14,
  BagScreenPickRadius = 0.07,
  ActiveBagScreenPickRadius = 0.065,
  ScreenPickBudBias = -0.020,

  LockActiveBag = true,


  CombineDist = 0.115,
  ActiveBagHeadingOffset = 90.0,
  ActiveBagInsertLift = 0.08,
  ActiveBagInsertForward = 0.01,
  InsertAnimMs = 180,


  EmptyBagPitch = 0.0,
  EmptyBagRoll = 0.0,
  FilledBagPitch = 0.0,
  FilledBagRoll = 0.0,
  BudPitch = 0.0,
  BudRoll = 0.0,
}


Config.PlantInteract = {


  DragAndDropTools = tryResolveHouseDoorCoords_DB_ONLY,


  AutoActions = true,


  DurationMs = {
    dirt   = 1400,
    seed   = 1100,
    water  = 1200,
    fert   = 1200,
    trim   = 900,
    harvest= 1100,
  },


  AutoDelta = {
    water = 25.0,
    fert  = 25.0,
  },


  AutoPropOffset = { x = 0.08, y = -0.22, z = 0.58 },
}


Config.Keys = {
  OpenInventory = 47,
}

Config.Text = Config.Text or {}
Config.Text.inventory = "Open Inventory"


Config.Storage = "mysql"


Config.OxMySQL = "oxmysql"


Config.Debug = false


Config.ToolTiltAxis = {
  dirt = "x",
  seed = "x",
  water = "y",
  fert = "x",
  trim = "x"
}


Config.ToolPourOffsets = {
  dirt = vector3(0.22, 0.00, 0.18),
  seed = vector3(0.18, 0.00, 0.10),
  water = vector3(0.33, 0.00, 0.12),
  fert = vector3(0.12, 0.00, 0.10),
  trim = vector3(0.10, 0.00, 0.05)
}


Config.ToolYawOffset = {
  water = 0.0,
  fert  = 0.0
}
