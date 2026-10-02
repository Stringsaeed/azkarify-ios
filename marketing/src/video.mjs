// Renders the App Store app preview (and a 1080x1920 social cut) from real simulator footage.
// Usage: node video.mjs [--width 886] [--out name] [--skip-extract]
import { chromium } from 'playwright-core';
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readdirSync, rmSync, existsSync } from 'node:fs';
import path from 'node:path';
import { ROOT, C, asset, raw, sprig, baseCss } from './shared.mjs';

const args = Object.fromEntries(process.argv.slice(2).join(' ').split('--').filter(Boolean)
  .map((a) => { const [k, ...v] = a.trim().split(' '); return [k, v.join(' ') || true]; }));
const W = Number(args.width || 886), H = 1920, FPS = 30;
const OUT = args.out || `app-preview-${W}x${H}`;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const FOOT = path.join(ROOT, 'footage');
const WORK = path.join('/tmp', 'azkarify-video');
const FRAMES = path.join(WORK, `frames-${W}`);

// Source pieces are [start, end, speed] in seconds of the 30 fps footage.
const SEGMENTS = {
  home: ['clipA_cfr', [[7.55, 8.95, 1.0], [9.6, 10.7, 1.3]]],
  journeys: ['clipA_cfr', [[11.25, 12.5, 1.35], [13.05, 13.45, 1.35], [14.3, 15.45, 1.35]]],
  points: ['clipA_cfr', [[15.45, 17.95, 1.45], [24.5, 26.5, 1.0]]],
  reader: ['clipA_cfr', [[37.0, 37.65, 1.2], [38.6, 39.85, 1.3]]],
  counter: ['clipA_cfr', [[45.3, 46.0, 1.2], [46.75, 48.8, 1.15]]],
  arabic: ['clipB_cfr', [[6.3, 7.0, 1.2], [7.9, 8.75, 1.2], [10.1, 10.9, 1.4], [12.1, 12.85, 1.4]]],
};

function extract() {
  rmSync(path.join(WORK, 'seg'), { recursive: true, force: true });
  for (const [name, [clip, pieces]] of Object.entries(SEGMENTS)) {
    const dir = path.join(WORK, 'seg', name);
    mkdirSync(dir, { recursive: true });
    const filters = pieces.map(([s, e, sp], i) =>
      `[0:v]trim=${s}:${e},setpts=(PTS-STARTPTS)/${sp},fps=${FPS}[p${i}]`).join(';');
    const concat = pieces.map((_, i) => `[p${i}]`).join('') + `concat=n=${pieces.length}:v=1[v]`;
    execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-i', path.join(FOOT, clip + '.mp4'),
      '-filter_complex', `${filters};${concat}`, '-map', '[v]', '-q:v', '2', path.join(dir, '%04d.jpg')]);
  }
}
if (!args['skip-extract'] || !existsSync(path.join(WORK, 'seg'))) extract();
const count = (n) => readdirSync(path.join(WORK, 'seg', n)).length;
const segDur = (n) => count(n) / FPS;

// Map a source-clip time inside a segment to output seconds (for sound/overlay cues).
function cue(name, srcT) {
  const [, pieces] = SEGMENTS[name];
  let acc = 0;
  for (const [s, e, sp] of pieces) {
    if (srcT >= s && srcT <= e) return acc + (srcT - s) / sp;
    acc += (e - s) / sp;
  }
  return acc;
}

const SHOTS = ['en-home', 'en-home-teal', 'en-home-blue', 'en-home-saffron-dark', 'en-home-green-dark', 'en-home-dark'];
const THEME_BG = ['#F7EEE4', '#E9F2F0', '#EAF0F8', '#1E140C', '#0F1A13', '#17100C'];

// Timeline. `dur` for footage scenes comes from the extracted frames.
const scenes = [
  { id: 'intro', type: 'intro', dur: 1.7 },
  { id: 'words', type: 'words', dur: 1.25, words: ['Read.', 'Reflect.', 'Remember.'] },
  { id: 'home', type: 'footage', seg: 'home', cap: ['Every zikr,', 'in one place.'] },
  { id: 'journeys', type: 'footage', seg: 'journeys', cap: ['Daily journeys,', 'morning to night.'] },
  { id: 'points', type: 'footage', seg: 'points', cap: ['Every step', 'earns points.'], hold: 0.3,
    chips: [{ t: cue('points', 16.23), text: '+10' }, { t: cue('points', 25.33), text: '+35' }] },
  { id: 'reader', type: 'footage', seg: 'reader', cap: ['Read with', 'full focus.'] },
  { id: 'counter', type: 'footage', seg: 'counter', cap: ['Count with', 'a single tap.'], hold: 0.2 },
  { id: 'arabic', type: 'footage', seg: 'arabic', cap: ['English &', 'العربية'] },
  { id: 'themes', type: 'themes', dur: 1.75, cap: ['Make it', 'yours.'] },
  { id: 'outro', type: 'outro', dur: 2.4 },
];
let t0 = 0;
for (const s of scenes) {
  if (s.type === 'footage') { s.frames = count(s.seg); s.dur = s.frames / FPS + (s.hold || 0); }
  s.start = t0; t0 += s.dur;
}
const TOTAL = t0;
const NFRAMES = Math.round(TOTAL * FPS);

// Sound cues for audio.py (seconds, sample name, gain).
const sfx = [];
const at = (sceneId, dt, name, gain = 1) => sfx.push({ t: scenes.find((s) => s.id === sceneId).start + dt, name, gain });
at('intro', 0.18, 'boom', 0.9); at('intro', 0.22, 'routine-complete', 0.8);
at('intro', 1.5, 'whoosh', 0.9);
scenes[1].words.forEach((_, i) => at('words', i * (1.25 / 3), 'tick', 1));
for (const s of scenes.slice(2)) at(s.id, -0.06, 'whoosh', 0.7);
for (const c of scenes.find((s) => s.id === 'points').chips) at('points', c.t, c.text === '+35' ? 'collectible-unlock' : 'routine-complete', 0.9);
[46.83, 47.62, 48.23].forEach((src) => at('counter', cue('counter', src), 'tick', 0.8));
SHOTS.forEach((_, i) => at('themes', i * 0.26, 'tick', 0.5));
at('outro', 0.25, 'level-up', 0.8);
writeFileSync(path.join(WORK, 'cues.json'), JSON.stringify({ total: TOTAL, sfx }, null, 1));

// ---------- page ----------
const card = { w: Math.round(W * 0.74) };
card.h = Math.round(card.w * 2868 / 1320);
card.top = H - card.h - Math.round(H * 0.028);
const capTop = Math.round(H * 0.058);

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
${baseCss}
body { width:${W}px; height:${H}px; overflow:hidden; position:relative; background:${C.cream}; }
#bg { position:absolute; inset:0; background: radial-gradient(120% 70% at 50% 20%, #FCF7F1, ${C.cream} 55%, ${C.creamDeep}); }
.sprig { position:absolute; transform-origin: 50% 100%; }
.sprig svg { width:100%; height:100%; }
.layer { position:absolute; inset:0; display:none; }
#card { position:absolute; left:${(W - card.w) / 2}px; top:${card.top}px; width:${card.w}px; height:${card.h}px;
  border-radius:${Math.round(card.w * 0.12)}px; overflow:hidden; background:#fff;
  box-shadow: 0 0 0 ${Math.round(W * 0.012)}px #1a1512, 0 40px 90px -20px rgba(70,30,10,.5); }
#card img { width:100%; height:100%; display:block; }
#cap { position:absolute; top:${capTop}px; left:0; right:0; text-align:center; font-weight:800;
  font-size:${Math.round(W * 0.088)}px; line-height:1.05; letter-spacing:-.02em; color:${C.ink}; }
#cap .ln { display:block; overflow:hidden; padding:.04em 0 .12em; }
#cap .ln span { display:inline-block; }
#cap [lang=ar] { letter-spacing:0; }
.chip { position:absolute; display:flex; align-items:center; gap:${W * 0.02}px; padding:${W * 0.018}px ${W * 0.04}px ${W * 0.018}px ${W * 0.022}px;
  background:#FFFBF6; border-radius:999px; border:2px solid rgba(133,64,36,.2); font-weight:800; color:${C.accent};
  font-size:${W * 0.075}px; box-shadow:0 20px 40px -12px rgba(80,40,15,.45); }
.chip img { width:${W * 0.085}px; }
#word { position:absolute; inset:0; display:flex; align-items:center; justify-content:center; font-weight:900;
  font-size:${W * 0.2}px; letter-spacing:-.04em; }
.center { position:absolute; left:0; right:0; text-align:center; }
#icon { width:${W * 0.34}px; border-radius:${W * 0.078}px; box-shadow:0 30px 60px -18px rgba(80,40,15,.45); }
.wm { font-weight:800; font-size:${W * 0.13}px; color:${C.ink}; letter-spacing:-.03em; }
.eyebrow { display:inline-block; font-weight:700; font-size:${W * 0.036}px; letter-spacing:.16em; text-transform:uppercase;
  color:${C.accent}; padding:${W * 0.012}px ${W * 0.035}px; border-radius:999px; background:rgba(133,64,36,.08); border:2px solid rgba(133,64,36,.16); }
.tag { font-weight:800; font-size:${W * 0.074}px; line-height:1.08; color:${C.ink}; letter-spacing:-.02em; }
.small { font-size:${W * 0.04}px; color:${C.inkSoft}; font-weight:500; }
.float { position:absolute; filter: drop-shadow(0 24px 30px rgba(70,35,10,.3)); }
</style></head><body>
<div id="bg"></div>
<div id="sprigs"></div>
<div class="layer" id="L-intro">
  <div class="center" id="i-icon" style="top:${H * 0.31}px"><img id="icon" src="${asset('icon.png')}"></div>
  <div class="center wm" id="i-wm" style="top:${H * 0.5}px">Azkarify</div>
  <div class="center" id="i-eb" style="top:${H * 0.6}px"><span class="eyebrow">Hisn al-Muslim</span></div>
</div>
<div class="layer" id="L-words"><div id="word"></div></div>
<div class="layer" id="L-foot">
  <div id="cap"></div>
  <div id="card"><img id="frame"></div>
  <div class="chip" id="chip" style="display:none"><img src="${asset('mosaic.svg')}"><b></b></div>
</div>
<div class="layer" id="L-outro">
  <img class="float" id="o-cres" src="${asset('crescent.svg')}" style="width:${W * 0.34}px;left:${W * 0.6}px;top:${H * 0.12}px">
  <img class="float" id="o-mos" src="${asset('mosaic.svg')}" style="width:${W * 0.17}px;left:${W * 0.1}px;top:${H * 0.74}px">
  <div class="center" id="o-icon" style="top:${H * 0.26}px"><img id="icon2" src="${asset('icon.png')}" style="width:${W * 0.3}px;border-radius:${W * 0.07}px;box-shadow:0 30px 60px -18px rgba(80,40,15,.45)"></div>
  <div class="center wm" id="o-wm" style="top:${H * 0.43}px">Azkarify</div>
  <div class="center tag" id="o-tag" style="top:${H * 0.53}px">Your daily azkar,<br>beautifully kept.</div>
  <div class="center small" id="o-sm" style="top:${H * 0.67}px">English · العربية · Offline</div>
</div>
<script>
const W=${W}, H=${H}, FPS=${FPS};
const scenes=${JSON.stringify(scenes)};
const SHOTS=${JSON.stringify(SHOTS.map((s) => raw(s)))};
const THEME_BG=${JSON.stringify(THEME_BG)};
const SEG='file://${WORK}/seg/';
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
const lerp=(a,b,t)=>a+(b-a)*t;
const p=(t,a,b)=>clamp((t-a)/(b-a));
const outCubic=t=>1-Math.pow(1-t,3), outExpo=t=>t>=1?1:1-Math.pow(2,-10*t), inCubic=t=>t*t*t;
const outBack=t=>{const c=1.70158,c3=c+1;return 1+c3*Math.pow(t-1,3)+c*Math.pow(t-1,2);};
const $=id=>document.getElementById(id);

// Botanical sprigs along both edges, as in BotanicalBackground.swift.
const sp=[]; const box=$('sprigs');
for(let i=0;i<6;i++){ const left=i%2===0; const s=W*(0.36+((i*37)%10)/40);
  const d=document.createElement('div'); d.className='sprig'; d.innerHTML=${JSON.stringify(sprig(C.accent))};
  Object.assign(d.style,{width:s+'px',height:s*1.8+'px',top:(H*(0.04+Math.floor(i/2)*0.33+((i*13)%7)/80))+'px',
    [left?'left':'right']:(-s*0.45)+'px'}); box.appendChild(d); sp.push({d,left,rot:(left?1:-1)*(12+((i*29)%10)*1.8)}); }

function sprigs(t, grow, color){ sp.forEach((o,i)=>{ const g=outCubic(p(grow,i*0.06,0.5+i*0.06));
  o.d.style.opacity=(0.14*g).toFixed(3);
  o.d.style.transform=(o.left?'':'scaleX(-1) ')+'rotate('+(o.rot+Math.sin(t*1.3+i)*2.5)+'deg) scaleY('+(0.4+0.6*g)+')'; }); }

let lastCap='';
function setCap(lines, t){
  const key=lines.join('|');
  if(key!==lastCap){ $('cap').innerHTML=lines.map(l=>'<span class="ln">'+l.split(' ').map(w=>'<span'+(/[\\u0600-\\u06FF]/.test(w)?' lang="ar"':'')+'>'+w+'&nbsp;</span>').join('')+'</span>').join(''); lastCap=key; }
  let k=0; $('cap').querySelectorAll('.ln span').forEach(s=>{ const e=outExpo(p(t,0.04+k*0.035,0.34+k*0.035)); k++;
    s.style.transform='translateY('+((1-e)*110)+'%)'; s.style.opacity=e; });
}

async function setImg(src){ const im=$('frame'); if(im.dataset.src===src) return; im.dataset.src=src; im.src=src; await im.decode().catch(()=>{}); }

window.renderAt = async function(T){
  const s=scenes.find(s=>T>=s.start && T<s.start+s.dur) || scenes[scenes.length-1];
  const t=T-s.start;
  for(const id of ['L-intro','L-words','L-foot','L-outro']) $(id).style.display='none';
  document.body.style.background='${C.cream}'; $('bg').style.opacity=1; $('sprigs').style.display='block';
  $('cap').style.color='${C.ink}';
  sprigs(T, 1, '${C.accent}');

  if(s.type==='intro'){
    $('L-intro').style.display='block'; sprigs(T, t*1.2);
    const ic=outBack(p(t,0.15,0.6)); $('i-icon').style.transform='scale('+ic+')'; $('i-icon').style.opacity=clamp(ic*3);
    const wm=outExpo(p(t,0.4,0.85)); $('i-wm').style.transform='translateY('+(1-wm)*60+'px)'; $('i-wm').style.opacity=wm;
    const eb=outExpo(p(t,0.62,1.0)); $('i-eb').style.transform='translateY('+(1-eb)*40+'px)'; $('i-eb').style.opacity=eb;
    const z=inCubic(p(t,1.42,s.dur)); $('L-intro').style.transform='scale('+(1+z*1.8)+')'; $('L-intro').style.opacity=1-z;
    $('L-intro').style.filter='blur('+(z*14)+'px)';
  } else if(s.type==='words'){
    $('L-words').style.display='block'; $('sprigs').style.display='none'; $('bg').style.opacity=0;
    const n=s.words.length, seg=s.dur/n, i=Math.min(n-1,Math.floor(t/seg)), lt=t-i*seg;
    const pal=[['${C.cream}','${C.ink}'],['${C.accent}','#FBEFE3'],['${C.night}','${C.accentDark}']][i];
    document.body.style.background=pal[0]; $('word').style.color=pal[1]; $('word').textContent=s.words[i];
    const e=outExpo(p(lt,0,0.16)); $('word').style.transform='scale('+lerp(1.35,1,e)+')'; $('word').style.opacity=e;
    $('word').style.filter='blur('+((1-e)*8)+'px)';
  } else if(s.type==='footage' || s.type==='themes'){
    $('L-foot').style.display='block';
    setCap(s.cap, t);
    let x=0, rot=0, blur=0;
    const inE=outCubic(p(t,0,0.24)); x=(1-inE)*W*1.05; rot=(1-inE)*6; blur=(1-inE)*10;
    const outE=inCubic(p(t,s.dur-0.14,s.dur)); x-=outE*W*1.05; rot-=outE*6; blur+=outE*10;
    const zoom=1+0.04*p(t,0,s.dur);
    $('card').style.transform='translateX('+x+'px) rotate('+rot+'deg) scale('+zoom+')'; $('card').style.filter='blur('+blur+'px)';
    $('cap').style.transform='translateX('+(-outE*W*0.4)+'px)'; $('cap').style.opacity=1-outE;
    if(s.type==='footage'){
      const f=Math.min(s.frames, Math.floor(t*FPS)+1);
      await setImg(SEG+s.seg+'/'+String(f).padStart(4,'0')+'.jpg');
      const ch=$('chip'); ch.style.display='none';
      for(const c of (s.chips||[])){ const lt=t-c.t; if(lt>=0 && lt<0.9){
        ch.style.display='flex'; ch.querySelector('b').textContent=c.text;
        const e=outBack(p(lt,0,0.28)), fade=1-p(lt,0.65,0.9);
        ch.style.left=(W*0.5)+'px'; ch.style.top=(${card.top}+${card.h}*0.03-lt*40)+'px';
        ch.style.transform='scale('+e+')'; ch.style.opacity=fade; } }
    } else {
      $('chip').style.display='none';
      const i=Math.min(SHOTS.length-1, Math.floor(t/0.26));
      await setImg(SHOTS[i]);
      const dark=i>=3; document.body.style.background=THEME_BG[i]; $('bg').style.opacity=0;
      $('cap').style.color=dark?'#F6E9DC':'${C.ink}';
    }
  } else if(s.type==='outro'){
    $('L-outro').style.display='block';
    const cr=outBack(p(t,0,0.5)); $('o-cres').style.transform='translateY('+(1-cr)*-300+'px) rotate('+(1-cr)*-40+'deg)'; $('o-cres').style.opacity=clamp(cr*2);
    const mo=outBack(p(t,0.25,0.75)); $('o-mos').style.transform='scale('+mo+') rotate('+(-20+t*8)+'deg)';
    const ic=outBack(p(t,0.02,0.4)); $('o-icon').style.transform='scale('+ic+')';
    [['o-wm',0.15],['o-tag',0.3],['o-sm',0.55]].forEach(([id,d])=>{ const e=outExpo(p(t,d,d+0.45));
      $(id).style.transform='translateY('+(1-e)*50+'px)'; $(id).style.opacity=e; });
  }
};
</script></body></html>`;

mkdirSync(WORK, { recursive: true });
const htmlPath = path.join(WORK, `video-${W}.html`);
writeFileSync(htmlPath, html);
rmSync(FRAMES, { recursive: true, force: true }); mkdirSync(FRAMES, { recursive: true });

const browser = await chromium.launch({ executablePath: CHROME, args: ['--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: W, height: H } });
await page.goto('file://' + htmlPath);
await page.evaluate(() => document.fonts.ready);
const every = Number(args.every || 1);
for (let i = 0; i < NFRAMES; i++) {
  if (i % every) continue;
  await page.evaluate((T) => window.renderAt(T), i / FPS);
  await page.screenshot({ path: path.join(FRAMES, `${String(i).padStart(5, '0')}.jpg`), type: 'jpeg', quality: 95 });
  if (i % 60 === 0) process.stdout.write(`\rframe ${i}/${NFRAMES}`);
}
await browser.close();
console.log(`\nrendered ${NFRAMES} frames, ${TOTAL.toFixed(2)}s -> ${FRAMES}`);
writeFileSync(path.join(WORK, `meta-${W}.json`), JSON.stringify({ W, H, FPS, NFRAMES, TOTAL, OUT }));
