

const invPots   = document.getElementById('invPots');
const invLamps  = document.getElementById('invLamps');
const invTables = document.getElementById('invTables');
const invDirt   = document.getElementById('invDirt');
const invFert   = document.getElementById('invFert');
const invBags   = document.getElementById('invBags');
const invSeeds  = document.getElementById('invSeeds');
const invBuds   = document.getElementById('invBuds');


document.getElementById('usePot')?.addEventListener('click', () => post('place_start', { kind: 'pots' }));
document.getElementById('useLamp')?.addEventListener('click', () => post('place_start', { kind: 'lamps' }));
document.getElementById('useTable')?.addEventListener('click', () => post('place_start', { kind: 'tables' }));

function _pill(label, value){
  const el = document.createElement('div');
  el.className = 'pill';
  el.innerHTML = `<span>${label}</span><span class="amt">x${value}</span>`;
  return el;
}

function renderInventory(payload){
  const p = payload.player || {};
  const strains = payload.strains || {};

  if (invPots) invPots.textContent = (p.pots ?? 0);
  if (invLamps) invLamps.textContent = (p.lamps ?? 0);
  if (invTables) invTables.textContent = (p.tables ?? 0);

  if (invDirt) invDirt.textContent = (p.dirt ?? 0);
  if (invFert) invFert.textContent = (p.fertilizer ?? 0);
  if (invBags) invBags.textContent = (p.bags ?? 0);

  if (invSeeds){
    invSeeds.innerHTML = '';
    const seeds = p.seeds || {};
    let any = false;
    Object.entries(seeds).forEach(([k, c]) => {
      c = Number(c || 0);
      if (c <= 0) return;
      any = true;
      const label = (strains[k] && strains[k].label) || k;
      invSeeds.appendChild(_pill(label, c));
    });
    if (!any) invSeeds.innerHTML = '<div class="muted">No seeds</div>';
  }

  if (invBuds){
    invBuds.innerHTML = '';
    const buds = p.buds || {};
    let any = false;
    Object.entries(buds).forEach(([k, c]) => {
      c = Number(c || 0);
      if (c <= 0) return;
      any = true;
      const label = (strains[k] && strains[k].label) || k;
      invBuds.appendChild(_pill(label, c));
    });
    if (!any) invBuds.innerHTML = '<div class="muted">No buds</div>';
  }
}


const tabShop = document.getElementById("tabShop");
const tabInv  = document.getElementById("tabInv");
function setTab(name){
  state.context = name;
  tabShop?.classList.toggle("active", name==="shop");
  tabInv?.classList.toggle("active", name==="inventory");
  show(name);
  if (name === "inventory"){

    post("open_inventory", {});
    renderInventory({ player: state.player || {}, strains: (state.payload && state.payload.strains) || {} });
  }
  if (name === "shop"){
    renderShop(state.payload || {});
  }
}

tabShop?.addEventListener("click", ()=> setTab("shop"));
tabInv?.addEventListener("click", ()=> setTab("inventory"));
