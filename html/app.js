

function getResName(){
  try{
    if (window.GetParentResourceName) return GetParentResourceName();
  }catch(e){}
  return "az-schedule1";
}


function post(name, data){
  const RES = getResName();
  const url = `https://${RES}/${name}`;
  const payload = JSON.stringify(data || {});

  return new Promise((resolve) => {
    try{
      const xhr = new XMLHttpRequest();
      xhr.open("POST", url, true);
      xhr.setRequestHeader("Content-Type", "application/json; charset=UTF-8");
      xhr.onload = () => resolve(xhr);
      xhr.onerror = () => resolve(null);
      xhr.send(payload);
    }catch(e){
      console.warn("NUI post failed", name, e);
      resolve(null);
    }
  });
}


const elApp = document.getElementById("app");
const elPanel = document.getElementById("panel");
const elBackdrop = document.getElementById("backdrop");
const elTitle = document.getElementById("title");
const elBtnClose = document.getElementById("btnClose");

const tabShop = document.getElementById("tabShop");
const tabInv  = document.getElementById("tabInv");
const tabMarket = document.getElementById("tabMarket");

const views = {
  shop: document.getElementById("viewShop"),
  inventory: document.getElementById("viewInventory"),
  market: document.getElementById("viewMarket"),
  mix: document.getElementById("viewMix"),
  plant_sidebar: document.getElementById("viewPlantSidebar"),
  bag_scene: document.getElementById("viewBagScene"),
};

function hideAll(){
  Object.values(views).forEach(v => v && v.classList.add("hidden"));
}

function hardHide(){
  elApp?.classList.add("hidden");
  document.body.classList.remove("open","mode-shop","mode-inventory","mode-market","mode-plant","mode-bag");
  hideAll();
}

function hardShow(){
  elApp?.classList.remove("hidden");
  document.body.classList.add("open");
}

function setMode(ctx){
  document.body.classList.remove("mode-shop","mode-inventory","mode-market","mode-plant","mode-bag");
  const isModal = (ctx === "shop" || ctx === "inventory" || ctx === "market");

  if (ctx === "shop") document.body.classList.add("mode-shop");
  if (ctx === "inventory") document.body.classList.add("mode-inventory");
  if (ctx === "market") document.body.classList.add("mode-market");
  if (ctx === "plant_sidebar") document.body.classList.add("mode-plant");
  if (ctx === "bag_scene") document.body.classList.add("mode-bag");


  if (elPanel) elPanel.classList.toggle("hidden", !isModal);
  if (elBackdrop) elBackdrop.classList.toggle("hidden", !isModal);


  if (tabShop) tabShop.classList.toggle("active", ctx === "shop");
  if (tabInv)  tabInv.classList.toggle("active", ctx === "inventory");
  if (tabMarket) tabMarket.classList.toggle("active", ctx === "market");

  if (elTitle){
    const map = { shop: "Supply marketplace", inventory: "Stored stock & gear", market: "Broker listings & sell orders", plant_sidebar: "Plant care sidebar", bag_scene: "Bagging loadout" };
    elTitle.textContent = map[ctx] || "Supply marketplace";
  }
}

function show(ctx){
  hideAll();
  const v = views[ctx];
  if (v) v.classList.remove("hidden");
}


let state = {
  context: null,
  payload: {},
  player: null,
  bagSelection: { buds: {}, bags: 0 },
};

function pct(n){
  n = Number(n || 0);
  if (Number.isNaN(n)) n = 0;
  return Math.max(0, Math.min(100, n));
}


const shopGrid = document.getElementById("shopGrid");
const shopPlaceRow = document.getElementById("shopPlaceRow");

function renderShop(payload){
  if (!shopGrid) return;
  const items = payload.items || {};
  shopGrid.innerHTML = "";

  Object.entries(items).forEach(([k, v]) => {
    const el = document.createElement("div");
    el.className = "item";

    const priceTxt = (v.price && payload.moneySystem !== "none") ? ` ($${v.price})` : "";
    el.innerHTML = `
      <div class="itemInner">
        <div class="name">${v.label || k}</div>
        <div class="desc">${v.desc || ""}</div>
        <div class="priceLine"><div class="price">${priceTxt || "Stocked"}</div><button class="btn primary">Buy${priceTxt}</button></div>
      </div>
    `;

    el.querySelector("button").onclick = () => post("shop_buy", { item: k });
    shopGrid.appendChild(el);
  });

  if (payload.canPlace) shopPlaceRow?.classList.remove("hidden");
  else shopPlaceRow?.classList.add("hidden");
}

document.getElementById("btnPlacePot")?.addEventListener("click", () => post("place_start", { kind: "pots" }));
document.getElementById("btnPlaceLamp")?.addEventListener("click", () => post("place_start", { kind: "lamps" }));
document.getElementById("btnPlaceTable")?.addEventListener("click", () => post("place_start", { kind: "tables" }));


function setText(id, val){
  const el = document.getElementById(id);
  if (el) el.textContent = String(val ?? 0);
}

function pill(label, count, actionsHtml = ""){
  const d = document.createElement("div");
  d.className = "pill";
  d.innerHTML = `<span>${label}</span><span class="chipAction"><span class="mini">x${count}</span>${actionsHtml}</span>`;
  return d;
}

function resolveSellPrice(type, strainKey){
  const prices = (state.payload && state.payload.sellPrices) || {};
  const bucket = prices[type] || {};
  return Number(bucket[strainKey] ?? bucket.default ?? (type === "bagged" ? 125 : 50) ?? 0) || 0;
}

function sellButtons(type, strainKey, count){
  if (!count || Number(count) <= 0) return "";
  return `<button class="btn primary" data-sell="one" data-type="${type}" data-strain="${strainKey}">Sell 1</button><button class="btn good" data-sell="all" data-type="${type}" data-strain="${strainKey}">Sell All</button>`;
}

function bindSellButtons(root){
  if (!root) return;
  root.querySelectorAll('[data-sell]').forEach((btn) => {
    btn.onclick = () => {
      post('sell_item', {
        itemType: btn.dataset.type,
        strainKey: btn.dataset.strain,
        amount: btn.dataset.sell,
      });
    };
  });
}

function renderInventory(payload){
  const p = (payload && payload.player) ? payload.player : (state.player || {});
  const strains = (payload && payload.strains) ? payload.strains : ((state.payload && state.payload.strains) || {});

  setText("invPots", p.pots || 0);
  setText("invLamps", p.lamps || 0);
  setText("invTables", p.tables || 0);
  setText("invDirt", p.dirt || 0);
  setText("invFert", p.fertilizer || 0);
  setText("invWateringCan", p.watering_can || 0);
  setText("invTrimmers", p.trimmers || 0);
  setText("invBags", p.bags || 0);

  const seedWrap = document.getElementById("invSeeds");
  if (seedWrap){
    seedWrap.innerHTML = "";
    const seeds = p.seeds || {};
    Object.entries(seeds).forEach(([k, c]) => {
      const n = Number(c || 0);
      if (n <= 0) return;
      seedWrap.appendChild(pill(`Seed: ${(strains[k] && strains[k].label) || k}`, n));
    });
    if (!seedWrap.children.length) seedWrap.innerHTML = '<div class="mini">No seeds stocked.</div>';
  }

  const budWrap = document.getElementById("invBuds");
  if (budWrap){
    budWrap.innerHTML = "";
    const buds = p.buds || {};
    Object.entries(buds).forEach(([k, c]) => {
      const n = Number(c || 0);
      if (n <= 0) return;
      budWrap.appendChild(pill(`Buds: ${(strains[k] && strains[k].label) || k}`, n, sellButtons('buds', k, n)));
    });
    if (!budWrap.children.length) budWrap.innerHTML = '<div class="mini">No loose buds stocked.</div>';
    bindSellButtons(budWrap);
  }

  const baggedWrap = document.getElementById("invBagged");
  if (baggedWrap){
    baggedWrap.innerHTML = "";
    const bagged = p.bagged || {};
    Object.entries(bagged).forEach(([k, c]) => {
      const n = Number(c || 0);
      if (n <= 0) return;
      baggedWrap.appendChild(pill(`Bagged: ${(strains[k] && strains[k].label) || k}`, n, sellButtons('bagged', k, n)));
    });
    if (!baggedWrap.children.length) baggedWrap.innerHTML = '<div class="mini">No packaged product stocked.</div>';
    bindSellButtons(baggedWrap);
  }

  const usePot = document.getElementById("usePot");
  const useLamp = document.getElementById("useLamp");
  const useTable = document.getElementById("useTable");

  if (usePot){
    usePot.onclick = () => { if ((p.pots||0) > 0) post("place_start", { kind: "pots" }); };
  }
  if (useLamp){
    useLamp.onclick = () => { if ((p.lamps||0) > 0) post("place_start", { kind: "lamps" }); };
  }
  if (useTable){
    useTable.onclick = () => { if ((p.tables||0) > 0) post("place_start", { kind: "tables" }); };
  }
}

const marketBagged = document.getElementById("marketBagged");
const marketBuds = document.getElementById("marketBuds");
const marketBalance = document.getElementById("marketBalance");

function marketCard(type, strainKey, count, label){
  const each = resolveSellPrice(type, strainKey);
  const total = each * Number(count || 0);
  const el = document.createElement('div');
  el.className = 'marketCard';
  el.innerHTML = `
    <div class="marketInner">
      <div class="name">${label}</div>
      <div class="marketMeta">${type === 'bagged' ? 'Packaged product ready for premium sale.' : 'Loose buds ready for quick sale.'}</div>
      <div class="priceLine"><div class="price">Each $${each}</div><div class="mini">Owned x${count}</div></div>
      <div class="row" style="margin-top:14px; justify-content:space-between; align-items:center;">
        <div class="mini">Sell all value $${total}</div>
        <div class="row" style="justify-content:flex-end;">
          <button class="btn primary" data-sell="one" data-type="${type}" data-strain="${strainKey}">Sell 1</button>
          <button class="btn good" data-sell="all" data-type="${type}" data-strain="${strainKey}">Sell All</button>
        </div>
      </div>
    </div>`;
  return el;
}

function renderMarket(payload){
  const p = (payload && payload.player) ? payload.player : (state.player || {});
  const strains = (payload && payload.strains) ? payload.strains : ((state.payload && state.payload.strains) || {});
  if (marketBalance){
    const balance = Number(p.money || 0) || 0;
    marketBalance.textContent = `Ledger balance $${balance}`;
  }

  const fill = (wrap, entries, type) => {
    if (!wrap) return;
    wrap.innerHTML = '';
    const rows = Object.entries(entries || {}).filter(([, c]) => Number(c || 0) > 0);
    if (!rows.length){
      wrap.innerHTML = `<div class="marketEmpty">No ${type === 'bagged' ? 'packaged product' : 'loose buds'} ready to sell.</div>`;
      return;
    }
    rows.forEach(([k, c]) => {
      wrap.appendChild(marketCard(type, k, Number(c || 0), (strains[k] && strains[k].label) || k));
    });
    bindSellButtons(wrap);
  };

  fill(marketBagged, p.bagged || {}, 'bagged');
  fill(marketBuds, p.buds || {}, 'buds');
}


const waterFill = document.getElementById("waterFill");
const fertFill  = document.getElementById("fertFill");
const growthFill= document.getElementById("growthFill");
const waterPct  = document.getElementById("waterPct");
const fertPct   = document.getElementById("fertPct");
const growthStage = document.getElementById("growthStage");
const seedSelect = document.getElementById("seedSelect");
const plantSeedBox = document.getElementById("plantSeedBox");

const btnAddDirt = document.getElementById("btnAddDirt");
const btnWater = document.getElementById("btnWater");
const btnFert  = document.getElementById("btnFert");
const btnTrim  = document.getElementById("btnTrim");
const btnHarvest = document.getElementById("btnHarvest");
const btnPlantSeed = document.getElementById("btnPlantSeed");
const btnClosePlant = document.getElementById("btnClosePlant");

function renderPlantSidebar(payload){
  const pot = payload.pot || {};
  const potId = payload.potId;

  const w = pct(pot.water);
  const f = pct(pot.fert);
  const g = pct(pot.growth);

  if (waterFill) waterFill.style.width = `${w}%`;
  if (fertFill)  fertFill.style.width  = `${f}%`;
  if (growthFill)growthFill.style.width= `${g}%`;

  if (waterPct) waterPct.textContent = `${w.toFixed(1)}%`;
  if (fertPct)  fertPct.textContent  = `${f.toFixed(1)}%`;
  if (growthStage) growthStage.textContent = `${g.toFixed(0)}%`;

  if (btnAddDirt) btnAddDirt.onclick = () => post("pot_add_dirt", { potId });
  if (btnWater)   btnWater.onclick   = () => post("pot_water", { potId });
  if (btnFert)    btnFert.onclick    = () => post("pot_fert", { potId });
  if (btnTrim)    btnTrim.onclick    = () => post("pot_trim", { potId });
  if (btnHarvest) btnHarvest.onclick = () => post("pot_harvest", { potId });
  if (btnClosePlant) btnClosePlant.onclick = () => post("close", {});


  if (!pot.hasDirt){
    btnAddDirt?.classList.remove("hidden");
    plantSeedBox?.classList.add("hidden");
    return;
  }
  btnAddDirt?.classList.add("hidden");


  const seeds = payload.seeds || {};
  const strains = payload.strains || {};
  if (!pot.strain && !pot.dead){
    plantSeedBox?.classList.remove("hidden");
    if (seedSelect){
      seedSelect.innerHTML = "";
      Object.entries(seeds).forEach(([k, c]) => {
        if (Number(c) <= 0) return;
        const opt = document.createElement("option");
        opt.value = k;
        opt.textContent = `${(strains[k] && strains[k].label) || k} (x${c})`;
        seedSelect.appendChild(opt);
      });
    }
    if (btnPlantSeed){
      btnPlantSeed.onclick = () => {
        const strainKey = seedSelect?.value;
        if (!strainKey) return;
        post("pot_plant", { potId, strainKey });
      };
    }
  } else {
    plantSeedBox?.classList.add("hidden");
  }
}


const btnBagClose = document.getElementById("btnBagClose");
const bagBudList = document.getElementById("bagBudList");
const bagAvailableBags = document.getElementById("bagAvailableBags");
const bagSelectedBags = document.getElementById("bagSelectedBags");
const bagMaxBudSlots = document.getElementById("bagMaxBudSlots");
const bagMaxBagSlots = document.getElementById("bagMaxBagSlots");
const btnBagLoadSelection = document.getElementById("btnBagLoadSelection");
const btnBagResetSelection = document.getElementById("btnBagResetSelection");
const btnBagMinus = document.getElementById("bagMinus");
const btnBagPlus = document.getElementById("bagPlus");
btnBagClose?.addEventListener("click", () => post("bag_close", {}));

function clampInt(n, mn, mx){
  n = Math.floor(Number(n || 0));
  if (Number.isNaN(n)) n = 0;
  return Math.max(mn, Math.min(mx, n));
}

function selectedBudTotal(){
  return Object.values(state.bagSelection?.buds || {}).reduce((a, b) => a + Number(b || 0), 0);
}

function bagSetCount(strainKey, next){
  const available = Number((state.payload?.availableBuds || {})[strainKey] || 0);
  const maxSlots = Number(state.payload?.maxBudSlots || 0);
  const otherTotal = selectedBudTotal() - Number(state.bagSelection.buds?.[strainKey] || 0);
  const maxForThis = Math.max(0, Math.min(available, maxSlots - otherTotal));
  if (!state.bagSelection.buds) state.bagSelection.buds = {};
  state.bagSelection.buds[strainKey] = clampInt(next, 0, maxForThis);
  renderBagScene(state.payload || {});
}

function bagSetBags(next){
  const available = Number(state.payload?.availableBags || 0);
  const maxSlots = Number(state.payload?.maxBagSlots || 0);
  state.bagSelection.bags = clampInt(next, 0, Math.min(available, maxSlots));
  renderBagScene(state.payload || {});
}

function resetBagSelection(payload){
  const buds = payload?.availableBuds || {};
  state.bagSelection = { buds: {}, bags: 0 };
  Object.keys(buds).forEach((k) => { state.bagSelection.buds[k] = 0; });
}

function renderBagScene(payload){
  const player = state.player || {};
  const buds = (payload && Object.keys(payload.availableBuds || {}).length > 0) ? (payload.availableBuds || {}) : (player.buds || {});
  const strains = payload.strains || {};
  const maxBudSlots = Number(payload.maxBudSlots || 0);
  const maxBagSlots = Number(payload.maxBagSlots || 0);
  payload.availableBuds = buds;
  payload.availableBags = Number((payload.availableBags ?? player.bags ?? 0) || 0);
  if (!state.bagSelection || !state.bagSelection.buds || Object.keys(state.bagSelection.buds).length === 0) {
    resetBagSelection(payload);
  }

  if (bagAvailableBags) bagAvailableBags.textContent = String(payload.availableBags || 0);
  if (bagSelectedBags) bagSelectedBags.textContent = String(state.bagSelection.bags || 0);
  if (bagMaxBudSlots) bagMaxBudSlots.textContent = String(maxBudSlots || 0);
  if (bagMaxBagSlots) bagMaxBagSlots.textContent = String(maxBagSlots || 0);

  if (bagBudList) {
    bagBudList.innerHTML = "";
    Object.entries(buds).forEach(([k, c]) => {
      const available = Number(c || 0);
      if (available <= 0) return;
      const selected = Number(state.bagSelection.buds?.[k] || 0);
      const row = document.createElement("div");
      row.className = "row";
      row.style.justifyContent = "space-between";
      row.style.alignItems = "center";
      row.style.padding = "8px 10px";
      row.style.border = "1px solid rgba(255,255,255,.10)";
      row.style.borderRadius = "12px";
      row.style.background = "rgba(255,255,255,.04)";
      row.innerHTML = `
        <div>
          <div style="font-weight:900;">${(strains[k] && strains[k].label) || k}</div>
          <div class="mini">Available: ${available}</div>
        </div>
        <div class="row" style="gap:6px;">
          <button class="btn" data-act="minus" data-strain="${k}" style="padding:8px 10px;">-</button>
          <div class="pill"><span>Use</span><span class="mini">${selected}</span></div>
          <button class="btn primary" data-act="plus" data-strain="${k}" style="padding:8px 10px;">+</button>
        </div>
      `;
      row.querySelector('[data-act="minus"]').onclick = () => bagSetCount(k, selected - 1);
      row.querySelector('[data-act="plus"]').onclick = () => bagSetCount(k, selected + 1);
      bagBudList.appendChild(row);
    });
  }

  btnBagMinus && (btnBagMinus.onclick = () => bagSetBags((state.bagSelection.bags || 0) - 1));
  btnBagPlus && (btnBagPlus.onclick = () => bagSetBags((state.bagSelection.bags || 0) + 1));
  btnBagResetSelection && (btnBagResetSelection.onclick = () => { resetBagSelection(payload); renderBagScene(payload); });
  btnBagLoadSelection && (btnBagLoadSelection.onclick = async () => {
    await post("bag_load_selection", state.bagSelection);
  });
}


let mouseDown = false;
let lastMoveAt = 0;

function normMouse(e){
  return {
    x: e.clientX / window.innerWidth,
    y: e.clientY / window.innerHeight
  };
}

function in3DMode(){
  return (state.context === "bag_scene" || state.context === "plant_sidebar");
}

function sendMouse(e, down){
  const m = normMouse(e);
  return post("mouse", { ...m, down: !!down });
}

document.addEventListener("mousedown", (e) => {
  if (!in3DMode()) return;
  mouseDown = true;
  sendMouse(e, true);
}, true);

document.addEventListener("mouseup", (e) => {
  if (!in3DMode()) return;
  mouseDown = false;
  sendMouse(e, false);
}, true);


document.addEventListener("mousemove", (e) => {
  if (!in3DMode()) return;
  const now = performance.now();
  if (now - lastMoveAt < 16) return;
  lastMoveAt = now;
  const m = normMouse(e);
  post("mouse", { ...m, down: mouseDown });
}, true);

document.addEventListener("wheel", (e) => {
  if (state.context !== "plant_sidebar") return;
  e.preventDefault();
  const m = normMouse(e);
  post("wheel", { ...m, delta: e.deltaY });
}, { passive: false, capture: true });


elBtnClose?.addEventListener("click", () => post("close", {}));
document.addEventListener("keydown", (e)=> {
  if (e.key === "Escape"){
    post("close", {});
  }
});


tabShop?.addEventListener("click", ()=> {
  if (state.context === "inventory" || state.context === "shop"){
    state.context = "shop";
    setMode("shop");
    show("shop");
    renderShop(state.payload || {});
  }
});

tabInv?.addEventListener("click", ()=> {
  post("open_inventory", {});
});

tabMarket?.addEventListener("click", ()=> {
  state.context = "market";
  setMode("market");
  show("market");
  renderMarket({ ...(state.payload || {}), player: state.player || ((state.payload || {}).player || {}) });
});


window.addEventListener("message", (e) => {
  const msg = e.data || {};
  const action = msg.action;
  const data = msg.data || {};

  if (action === "open"){
    state.context = data.context;
    state.payload = data.payload || {};
    state.player = (state.payload && state.payload.player) || state.player;

    hardShow();
    setMode(state.context);
    show(state.context);

    if (state.context === "shop"){
      renderShop(state.payload);
    }
    if (state.context === "inventory"){
      renderInventory(state.payload);
    }
    if (state.context === "market"){
      renderMarket(state.payload);
    }
    if (state.context === "plant_sidebar"){
      renderPlantSidebar(state.payload);
    }
    if (state.context === "bag_scene"){
      resetBagSelection(state.payload);
      renderBagScene(state.payload);
    }
    return;
  }

  if (action === "close"){
    state.context = null;
    state.payload = {};
    hardHide();
    return;
  }

  if (action === "player"){
    state.player = data;
    if (state.context === "inventory"){
      renderInventory({ player: state.player, strains: (state.payload && state.payload.strains) || {}, sellPrices: (state.payload && state.payload.sellPrices) || {} });
    }
    if (state.context === "market"){
      renderMarket({ ...(state.payload || {}), player: state.player, strains: (state.payload && state.payload.strains) || {}, sellPrices: (state.payload && state.payload.sellPrices) || {} });
    }
    if (state.context === "bag_scene"){
      state.payload = state.payload || {};
      state.payload.availableBuds = (state.player && state.player.buds) || {};
      state.payload.availableBags = Number((state.player && state.player.bags) || 0);
      renderBagScene(state.payload);
    }
  }

  if (action === "pot_update"){
    if (state.context === "plant_sidebar"){
      state.payload.pot = data;
      renderPlantSidebar(state.payload);
    }
  }
});


hardHide();
