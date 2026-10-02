// Renders App Store screenshots (6.9" iPhone, 1320 x 2868) for English and Arabic.
// One wide panorama per language is rendered so decoration can cross slide edges,
// then each slide is clipped out.  Usage: node screenshots.mjs
import { chromium } from 'playwright-core';
import { mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { ROOT, C, asset, raw, sprig, phone, baseCss } from './shared.mjs';

const W = 1320, H = 2868;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const COPY = {
  en: {
    dir: 'ltr', name: 'Azkarify',
    slides: [
      { kind: 'hero', eyebrow: 'Hisn al-Muslim', title: 'Your daily azkar,<br>beautifully kept.',
        sub: 'Every zikr, a gentle counter and daily journeys, in English and العربية.', shot: 'en-home' },
      { kind: 'single', eyebrow: 'Daily journeys', title: 'Small steps,<br>morning to night.',
        sub: 'Follow a journey from waking to sleep, at your own pace.', shot: 'en-journeys', deco: 'crescent' },
      { kind: 'single', eyebrow: 'Points', title: 'Every step<br>counts.',
        sub: '10 points per step, plus 25 for each journey you complete.', shot: 'en-journey-detail', deco: 'coin',
        coin: '+25' },
      { kind: 'single', dark: true, eyebrow: 'Prayer journeys', title: 'Prayer journeys,<br>right on time.',
        sub: 'Prayer times for your city, calculated on your phone.', shot: 'en-journeys-dark' },
      { kind: 'duo', eyebrow: 'Read', title: 'Read with<br>full focus.',
        sub: 'The full collection in English and Arabic. Works offline from the first launch.',
        shots: ['en-reader', 'ar-slideshow'] },
      { kind: 'single', eyebrow: 'Counter', title: 'Count with<br>a single tap.',
        sub: 'A built-in counter for every repeated zikr.', shot: 'en-counter', deco: 'beads' },
      { kind: 'trio', eyebrow: 'Themes', title: 'Make it<br>yours.',
        sub: 'Five accent colors, in light and dark.', shots: ['en-home-teal', 'en-home-saffron-dark', 'en-home-green-dark'] },
      { kind: 'duo', eyebrow: 'Private by design', title: 'English &amp;<br><span lang="ar">العربية</span>',
        sub: 'Full right-to-left support. No account needed. Your progress stays on your phone.',
        shots: ['ar-home', 'en-home'] },
    ],
  },
  ar: {
    dir: 'rtl', name: 'حصن المسلم',
    slides: [
      { kind: 'hero', eyebrow: 'رفيقك كل يوم', title: 'أذكارك اليومية<br>بأجمل حُلّة',
        sub: 'الأذكار كاملة، مع عدّاد للتسبيح ورحلات يومية، بالعربية والإنجليزية.', shot: 'ar-home' },
      { kind: 'single', eyebrow: 'رحلاتك اليومية', title: 'خطوات صغيرة<br>من الصباح للمساء',
        sub: 'رحلات ترافقك من الاستيقاظ حتى النوم، على مهل.', shot: 'ar-journeys', deco: 'crescent' },
      { kind: 'single', eyebrow: 'النقاط', title: 'كل خطوة<br>تُحتسب',
        sub: '10 نقاط لكل خطوة، و25 نقطة لكل رحلة تُكملها.', shot: 'ar-journey-detail', deco: 'coin', coin: '+25' },
      { kind: 'single', dark: true, eyebrow: 'رحلات الصلاة', title: 'رحلات الصلاة<br>في وقتها',
        sub: 'مواقيت الصلاة لمدينتك، تُحسب على هاتفك.', shot: 'ar-journeys-dark' },
      { kind: 'duo', eyebrow: 'القراءة', title: 'اقرأ بتركيز<br>وطمأنينة',
        sub: 'نصوص الأذكار كاملة بالعربية والإنجليزية، وتعمل دون إنترنت من أول تشغيل.',
        shots: ['ar-reader', 'ar-slideshow'] },
      { kind: 'single', eyebrow: 'العدّاد', title: 'سبّح بلمسة<br>واحدة',
        sub: 'عدّاد مدمج لكل ذكر يتكرر.', shot: 'ar-counter', deco: 'beads' },
      { kind: 'trio', eyebrow: 'المظهر', title: 'اجعله<br>على ذوقك',
        sub: 'خمسة ألوان، في الوضع الفاتح والداكن.', shots: ['ar-home-teal', 'ar-home-saffron-dark', 'ar-home-green-dark'] },
      { kind: 'duo', eyebrow: 'خصوصيتك أولًا', title: 'العربية<br><span lang="en" dir="ltr">&amp; English</span>',
        sub: 'دعم كامل للعربية. بلا حساب، وتقدّمك يبقى على هاتفك.', shots: ['en-home', 'ar-home'] },
    ],
  },
};

function textBlock(s, lang) {
  return `<div class="text">
    <div class="eyebrow">${s.eyebrow}</div>
    <h1>${s.title}</h1>
    <p>${s.sub}</p></div>`;
}

function slide(s, i, lang) {
  const x = i * W;
  const rtl = COPY[lang].dir === 'rtl';
  let body = '';
  if (s.kind === 'hero') {
    body = `
      <div class="brand"><img src="${asset('icon.png')}"/><span>${COPY[lang].name}</span></div>
      ${textBlock(s, lang)}
      <div class="ph" style="top:1230px">${phone(raw(s.shot), 900)}</div>
      <img class="float crescent" src="${asset('crescent.svg')}" style="width:270px;top:1020px;${rtl ? 'left' : 'right'}:6px;transform:rotate(${rtl ? -8 : 8}deg)"/>
      <img class="float" src="${asset('mosaic.svg')}" style="width:170px;top:2120px;${rtl ? 'right' : 'left'}:52px;transform:rotate(-12deg)"/>`;
  } else if (s.kind === 'single') {
    let deco = '';
    if (s.deco === 'crescent') deco = `<img class="float crescent" src="${asset('crescent.svg')}" style="width:300px;top:2160px;${rtl ? 'right' : 'left'}:20px;transform:rotate(${rtl ? 10 : -10}deg)"/>`;
    if (s.deco === 'coin') deco = `<div class="chip" style="top:1150px;${rtl ? 'left' : 'right'}:56px"><img src="${asset('mosaic.svg')}"/><b dir="ltr">${s.coin}</b></div>
      <img class="float" src="${asset('mosaic.svg')}" style="width:150px;top:2300px;${rtl ? 'right' : 'left'}:40px;transform:rotate(14deg)"/>`;
    if (s.deco === 'beads') deco = `<img class="float" src="${asset('mosaic.svg')}" style="width:130px;top:1000px;${rtl ? 'left' : 'right'}:60px;transform:rotate(18deg)"/>`;
    const full = s.deco === 'beads';  // counter ring sits low on screen, so show the whole phone
    body = `${textBlock(s, lang)}<div class="ph" style="top:${full ? 880 : s.dark ? 960 : 980}px">${phone(raw(s.shot), full ? 880 : 1000, { dark: s.dark })}</div>${deco}`;
  } else if (s.kind === 'duo') {
    const [back, front] = s.shots;
    body = `${textBlock(s, lang)}
      <div class="ph abs" style="top:1080px;${rtl ? 'right' : 'left'}:-60px;transform:rotate(${rtl ? 6 : -6}deg);opacity:.98">${phone(raw(back), 820)}</div>
      <div class="ph abs" style="top:1220px;${rtl ? 'left' : 'right'}:-30px;transform:rotate(${rtl ? -3 : 3}deg)">${phone(raw(front), 860)}</div>`;
  } else if (s.kind === 'trio') {
    const [a, b, c] = s.shots;
    body = `${textBlock(s, lang)}
      <div class="ph abs" style="top:1330px;left:-40px;transform:rotate(-8deg)">${phone(raw(a), 600)}</div>
      <div class="ph abs" style="top:1330px;right:-40px;transform:rotate(8deg)">${phone(raw(c), 600, { dark: true })}</div>
      <div class="ph abs" style="top:1020px;left:50%;transform:translateX(-50%);z-index:3">${phone(raw(b), 740, { dark: true })}</div>`;
  }
  return `<section dir="${COPY[lang].dir}" class="slide ${s.dark ? 'dark' : ''} ${s.kind}" style="left:${x}px">${body}</section>`;
}

// Sprigs straddling slide seams make the set read as one continuous strip in the store.
function seams(n, slides) {
  let out = '';
  for (let k = 0; k <= n; k++) {
    const dark = slides[Math.min(k, n - 1)]?.dark || slides[k - 1]?.dark;
    const color = dark ? C.accentDark : C.accent;
    const y = [620, 1700, 900, 2300, 760, 1900, 1100, 2200, 1500][k % 9];
    const size = 320 + (k % 3) * 40;
    const rot = k % 2 ? 24 : -18;
    out += `<div class="sprig" style="left:${k * W - size / 2}px;top:${y}px;width:${size}px;height:${size * 1.8}px;transform:rotate(${rot}deg);opacity:${dark ? .22 : .16}">${sprig(color)}</div>`;
    out += `<div class="sprig" style="left:${k * W - size / 2 + 40}px;top:${y + 700}px;width:${size * .8}px;height:${size * 1.44}px;transform:scaleX(-1) rotate(${-rot}deg);opacity:${dark ? .16 : .1}">${sprig(color)}</div>`;
  }
  return out;
}

function page(lang) {
  const { dir, slides } = COPY[lang];
  const n = slides.length;
  const backgrounds = slides.map((s, i) => `<div class="bg ${s.dark ? 'dark' : ''}" style="left:${i * W}px"></div>`).join('');
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><style>
${baseCss}
body { width:${W * n}px; height:${H}px; position:relative; overflow:hidden; }
.bg { position:absolute; top:0; width:${W}px; height:${H}px;
  background: radial-gradient(120% 60% at 50% 18%, #FCF7F1 0%, ${C.cream} 55%, ${C.creamDeep} 100%); }
.bg.dark { background: radial-gradient(120% 60% at 50% 18%, #2E1F17 0%, ${C.night} 60%, #0E0907 100%); }
.slide { position:absolute; top:0; width:${W}px; height:${H}px; overflow:hidden; z-index:2; }
.sprig { position:absolute; z-index:1; }
.sprig svg { width:100%; height:100%; }
.text { position:absolute; top:200px; left:90px; right:90px; text-align:center; color:${C.ink}; }
.hero .text { top:470px; }
.dark .text { color:#F6E9DC; }
.eyebrow { display:inline-block; font-weight:700; font-size:38px; letter-spacing:.16em; text-transform:uppercase;
  color:${C.accent}; padding:14px 34px; border-radius:999px; background:rgba(133,64,36,.08);
  border:2px solid rgba(133,64,36,.16); }
.dark .eyebrow { color:${C.accentDark}; background:rgba(232,158,110,.10); border-color:rgba(232,158,110,.22); }
h1 { font-weight:800; font-size:136px; line-height:1.0; letter-spacing:-.025em; margin-top:46px; }
.hero h1 { font-size:124px; }
p { font-weight:400; font-size:46px; line-height:1.35; color:${C.inkSoft}; margin:40px auto 0; max-width:1060px; }
.dark p { color:#CDB7A6; }
[dir=rtl] .eyebrow { letter-spacing:0; text-transform:none; font-size:44px; }
[dir=rtl] h1 { letter-spacing:0; line-height:1.28; font-size:116px; }
[dir=rtl] .text { left:50px; right:50px; }
[dir=rtl] p { font-size:48px; line-height:1.5; }
h1 [lang=ar] { font-size:.92em; }
.brand { position:absolute; top:150px; left:0; right:0; display:flex; align-items:center; justify-content:center; gap:30px; }
.brand img { width:190px; height:190px; border-radius:44px; box-shadow:0 24px 50px -16px rgba(80,40,15,.4); }
.brand span { font-weight:800; font-size:84px; color:${C.ink}; letter-spacing:-.02em; }
.ph { position:absolute; left:50%; transform:translateX(-50%); }
.ph.abs { left:auto; }
.float { position:absolute; filter: drop-shadow(0 30px 40px rgba(70,35,10,.30)); z-index:5; }
.chip { position:absolute; z-index:6; display:flex; align-items:center; gap:22px; padding:26px 46px 26px 30px;
  background:rgba(255,251,246,.92); border-radius:999px; border:2px solid rgba(133,64,36,.18);
  box-shadow:0 30px 60px -20px rgba(80,40,15,.45); font-size:78px; font-weight:800; color:${C.accent}; }
.chip img { width:96px; height:96px; }
</style></head><body>${backgrounds}${seams(n, slides)}${slides.map((s, i) => slide(s, i, lang)).join('')}</body></html>`;
}

const browser = await chromium.launch({ executablePath: CHROME });
const ctx = await browser.newContext({ deviceScaleFactor: 1 });
for (const lang of ['en', 'ar']) {
  const n = COPY[lang].slides.length;
  const outDir = path.join(ROOT, 'app-store', 'screenshots', lang);
  mkdirSync(outDir, { recursive: true });
  const htmlPath = path.join(ROOT, 'src', `.screens-${lang}.html`);
  writeFileSync(htmlPath, page(lang));
  const p = await ctx.newPage();
  await p.setViewportSize({ width: W * n, height: H });
  await p.goto('file://' + htmlPath);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(400);
  for (let i = 0; i < n; i++) {
    const file = path.join(outDir, `${String(i + 1).padStart(2, '0')}.png`);
    await p.screenshot({ path: file, clip: { x: i * W, y: 0, width: W, height: H } });
    // App Store Connect rejects screenshots with an alpha channel.
    execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-i', file, '-pix_fmt', 'rgb24', file + '.tmp.png']);
    renameSync(file + '.tmp.png', file);
  }
  console.log(lang, 'done');
  await p.close();
}
await browser.close();
