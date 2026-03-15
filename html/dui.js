const prod = document.getElementById('prod');
const out = document.getElementById('out');
const prodInfo = document.getElementById('prodInfo');
const outInfo = document.getElementById('outInfo');
const time = document.getElementById('time');

setInterval(() => {
  const d = new Date();
  time.textContent = d.toLocaleTimeString();
}, 500);

let state = { player:null, plants:{} };

function setDefault(){
  prod.textContent = '—';
  prodInfo.textContent = 'Waiting…';
  out.textContent = 'Pick a recipe';
  outInfo.textContent = 'Open the station with [E] to mix.';
}
setDefault();

window.addEventListener('message', (e) => {
  let msg = e.data;
  try{
    if (typeof msg === 'string') msg = JSON.parse(msg);
  }catch(_){}

  if (!msg || !msg.action) return;

  if (msg.action === 'player'){
    state.player = msg.data;
  }
  if (msg.action === 'plants'){
    state.plants = msg.data;
  }

  if (state.player){
    const buds = state.player.buds || {};
    const mixers = state.player.mixers || {};
    const budKey = Object.keys(buds).find(k => !k.startsWith('bag_') && buds[k] > 0);
    const mixKey = Object.keys(mixers).find(k => mixers[k] > 0);
    if (budKey && mixKey){
      prod.textContent = `${budKey} + ${mixKey}`;
      prodInfo.textContent = 'Ready to mix (1 + 1).';
      out.textContent = '—';
      outInfo.textContent = 'Use the Mixing Station to craft a new strain.';
    } else {
      setDefault();
    }
  }
});
