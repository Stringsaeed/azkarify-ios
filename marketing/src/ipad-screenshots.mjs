// Renders App Store screenshots for the 13" iPad (2064 x 2752) in English and Arabic,
// using the same panorama approach as screenshots.mjs.  Usage: node ipad-screenshots.mjs
import { chromium } from 'playwright-core';
import { mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { ROOT, C, asset, fileUrl, RAW, sprig, baseCss } from './shared.mjs';

const W = 2064, H = 2752;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const shot = (name) => fileUrl(path.join(RAW, 'ipad', name + '.png'));

// iPad frame around a real 2064 x 2752 simulator capture.
function ipad(src, width, { dark = false } = {}) {
  const bezel = Math.round(width * 0.026);
  const radius = Math.round(width * 0.04);
  return `<div class="tablet${dark ? ' dark' : ''}" style="width:${width + bezel * 2}px;padding:${bezel}px;border-radius:${radius + bezel}px">
    <img src="${src}" style="width:${width}px;border-radius:${radius}px;display:block"/></div>`;
}

const COPY = {
  en: {
    dir: 'ltr', name: 'Azkarify',
    slides: [
      { kind: 'hero', eyebrow: 'Hisn al-Muslim', title: 'Your daily azkar, beautifully kept.',
        sub: 'The full collection, daily journeys and a gentle counter, in English and العربية.', shot: 'en-reader' },
      { kind: 'single', eyebrow: 'Daily journeys', title: 'Small steps,<br>morning to night.',
        sub: 'From waking to sleep, with prayer times for your city.', shot: 'en-journeys', deco: 'crescent' },
      { kind: 'single', eyebrow: 'Points', title: 'Every step counts.',
        sub: '10 points per step, plus 25 for each journey you complete.', shot: 'en-journey-detail', deco: 'coin' },
      { kind: 'single', dark: true, eyebrow: 'Prayer journeys', title: 'Prayer journeys,<br>right on time.',
        sub: 'Prayer times calculated on your iPad. Your location never leaves it.', shot: 'en-journeys-dark' },
      { kind: 'single', eyebrow: 'Counter', title: 'Count with a single tap.',
        sub: 'A built-in counter for every repeated zikr.', shot: 'en-counter', deco: 'mosaic' },
      { kind: 'trio', eyebrow: 'Themes', title: 'Make it yours.',
        sub: 'Five accent colors, in light and dark.', shots: ['en-reader-teal', 'en-reader-saffron-dark', 'en-journeys-green-dark'] },
      { kind: 'duo', eyebrow: 'Private by design', title: 'English &amp; <span lang="ar">العربية</span>',
        sub: 'Full right-to-left support. No account needed. Works offline.', shots: ['ar-reader', 'en-reader'] },
    ],
  },
  ar: {
    dir: 'rtl', name: 'حصن المسلم',
    slides: [
      { kind: 'hero', eyebrow: 'رفيقك كل يوم', title: 'أذكارك اليومية بأجمل حُلّة',
        sub: 'الأذكار كاملة، مع رحلات يومية وعدّاد للتسبيح، بالعربية والإنجليزية.', shot: 'ar-reader' },
      { kind: 'single', eyebrow: 'رحلاتك اليومية', title: 'خطوات صغيرة من الصباح للمساء',
        sub: 'رحلات ترافقك من الاستيقاظ حتى النوم، مع مواقيت الصلاة لمدينتك.', shot: 'ar-journeys', deco: 'crescent' },
      { kind: 'single', eyebrow: 'النقاط', title: 'كل خطوة تُحتسب',
        sub: '10 نقاط لكل خطوة، و25 نقطة لكل رحلة تُكملها.', shot: 'ar-journey-detail', deco: 'coin' },
      { kind: 'single', dark: true, eyebrow: 'رحلات الصلاة', title: 'رحلات الصلاة في وقتها',
        sub: 'مواقيت الصلاة تُحسب على جهازك، وموقعك لا يغادره.', shot: 'ar-journeys-dark' },
      { kind: 'single', eyebrow: 'العدّاد', title: 'سبّح بلمسة واحدة',
        sub: 'عدّاد مدمج لكل ذكر يتكرر.', shot: 'ar-counter', deco: 'mosaic' },
      { kind: 'trio', eyebrow: 'المظهر', title: 'اجعله على ذوقك',
        sub: 'خمسة ألوان، في الوضع الفاتح والداكن.', shots: ['ar-reader-teal', 'ar-reader-saffron-dark', 'ar-journeys-green-dark'] },
      { kind: 'duo', eyebrow: 'خصوصيتك أولًا', title: 'العربية <span lang="en" dir="ltr">&amp; English</span>',
        sub: 'دعم كامل للعربية. بلا حساب، ويعمل دون إنترنت.', shots: ['en-reader', 'ar-reader'] },
    ],
  },
};

const textBlock = (s) => `<div class="text"><div class="eyebrow">${s.eyebrow}</div><h1>${s.title}</h1><p>${s.sub}</p></div>`;

function slide(s, i, lang) {
  const rtl = COPY[lang].dir === 'rtl';
  const near = rtl ? 'right' : 'left', far = rtl ? 'left' : 'right';
  let body = '';
  if (s.kind === 'hero') {
    body = `<div class="brand"><img src="${asset('icon.png')}"/><span>${COPY[lang].name}</span></div>${textBlock(s)}
      <div class="dev" style="top:1010px">${ipad(shot(s.shot), 1640)}</div>
      <img class="float" src="${asset('crescent.svg')}" style="width:330px;top:850px;${far}:70px;transform:rotate(${rtl ? -8 : 8}deg)"/>
      <img class="float" src="${asset('mosaic.svg')}" style="width:190px;top:2320px;${near}:60px;transform:rotate(-12deg)"/>`;
  } else if (s.kind === 'single') {
    let deco = '';
    if (s.deco === 'crescent') deco = `<img class="float" src="${asset('crescent.svg')}" style="width:300px;top:2280px;${near}:50px;transform:rotate(${rtl ? 10 : -10}deg)"/>`;
    if (s.deco === 'coin') deco = `<div class="chip" style="top:760px;${far}:150px"><img src="${asset('mosaic.svg')}"/><b dir="ltr">+25</b></div>`;
    if (s.deco === 'mosaic') deco = `<img class="float" src="${asset('mosaic.svg')}" style="width:200px;top:700px;${far}:150px;transform:rotate(18deg)"/>`;
    const full = s.deco === 'mosaic';  // the counter ring sits at the bottom of the screen, so show the whole iPad
    const two = /<br>/.test(s.title);
    body = `${textBlock(s)}<div class="dev" style="top:${full ? 800 : two ? 1010 : 900}px">${ipad(shot(s.shot), full ? 1360 : 1700, { dark: s.dark })}</div>${deco}`;
  } else if (s.kind === 'duo') {
    const [back, front] = s.shots;
    body = `${textBlock(s)}
      <div class="dev abs" style="top:900px;${near}:-260px;transform:rotate(${rtl ? 5 : -5}deg)">${ipad(shot(back), 1300)}</div>
      <div class="dev abs" style="top:1080px;${far}:-120px;transform:rotate(${rtl ? -3 : 3}deg)">${ipad(shot(front), 1400)}</div>`;
  } else if (s.kind === 'trio') {
    const [a, b, c] = s.shots;
    body = `${textBlock(s)}
      <div class="dev abs" style="top:1140px;left:-260px;transform:rotate(-7deg)">${ipad(shot(a), 1050)}</div>
      <div class="dev abs" style="top:1140px;right:-260px;transform:rotate(7deg)">${ipad(shot(c), 1050, { dark: true })}</div>
      <div class="dev abs" style="top:940px;left:50%;transform:translateX(-50%);z-index:3">${ipad(shot(b), 1260, { dark: true })}</div>`;
  }
  return `<section dir="${COPY[lang].dir}" class="slide ${s.dark ? 'dark' : ''} ${s.kind}" style="left:${i * W}px">${body}</section>`;
}

function seams(slides) {
  let out = '';
  for (let k = 0; k <= slides.length; k++) {
    const dark = slides[Math.min(k, slides.length - 1)]?.dark || slides[k - 1]?.dark;
    const color = dark ? C.accentDark : C.accent;
    const y = [500, 1500, 800, 1900, 650, 1700, 1000, 1400][k % 8];
    const size = 380 + (k % 3) * 50, rot = k % 2 ? 24 : -18;
    out += `<div class="sprig" style="left:${k * W - size / 2}px;top:${y}px;width:${size}px;height:${size * 1.8}px;transform:rotate(${rot}deg);opacity:${dark ? .22 : .16}">${sprig(color)}</div>`;
  }
  return out;
}

function page(lang) {
  const { slides } = COPY[lang];
  const n = slides.length;
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><style>
${baseCss}
body { width:${W * n}px; height:${H}px; position:relative; overflow:hidden; }
.bg { position:absolute; top:0; width:${W}px; height:${H}px;
  background: radial-gradient(110% 60% at 50% 15%, #FCF7F1 0%, ${C.cream} 55%, ${C.creamDeep} 100%); }
.bg.dark { background: radial-gradient(110% 60% at 50% 15%, #2E1F17 0%, ${C.night} 60%, #0E0907 100%); }
.slide { position:absolute; top:0; width:${W}px; height:${H}px; overflow:hidden; z-index:2; }
.sprig { position:absolute; z-index:1; } .sprig svg { width:100%; height:100%; }
.text { position:absolute; top:170px; left:160px; right:160px; text-align:center; color:${C.ink}; }
.hero .text { top:330px; }
.dark .text { color:#F6E9DC; }
.eyebrow { display:inline-block; font-weight:700; font-size:40px; letter-spacing:.16em; text-transform:uppercase; color:${C.accent};
  padding:14px 36px; border-radius:999px; background:rgba(133,64,36,.08); border:2px solid rgba(133,64,36,.16); }
.dark .eyebrow { color:${C.accentDark}; background:rgba(232,158,110,.10); border-color:rgba(232,158,110,.22); }
h1 { font-weight:800; font-size:132px; line-height:1.02; letter-spacing:-.025em; margin-top:40px; }
.hero h1 { font-size:116px; }
p { font-size:50px; line-height:1.35; color:${C.inkSoft}; margin:34px auto 0; max-width:1500px; }
.dark p { color:#CDB7A6; }
[dir=rtl] .eyebrow { letter-spacing:0; text-transform:none; font-size:46px; }
[dir=rtl] h1 { letter-spacing:0; line-height:1.25; font-size:122px; }
[dir=rtl] .hero h1 { font-size:110px; }
[dir=rtl] p { font-size:52px; line-height:1.5; }
h1 [lang=ar] { font-size:.92em; }
.brand { position:absolute; top:110px; left:0; right:0; display:flex; align-items:center; justify-content:center; gap:30px; }
.brand img { width:170px; height:170px; border-radius:40px; box-shadow:0 24px 50px -16px rgba(80,40,15,.4); }
.brand span { font-weight:800; font-size:80px; color:${C.ink}; letter-spacing:-.02em; }
.dev { position:absolute; left:50%; transform:translateX(-50%); }
.dev.abs { left:auto; }
.tablet { background:linear-gradient(145deg,#d9d6d2,#a9a5a0 40%,#cfccc8); position:relative;
  box-shadow: 0 0 0 3px #8d8984 inset, 0 70px 140px -30px rgba(60,25,10,.45), 0 30px 60px -20px rgba(60,25,10,.3); }
.tablet.dark { background:linear-gradient(145deg,#3b3632,#0d0b0a 40%,#2b2724); box-shadow: 0 0 0 3px #1d1916 inset, 0 70px 140px -30px rgba(0,0,0,.6); }
.tablet::before { content:''; position:absolute; inset:calc(var(--b, 0px)); border-radius:inherit; }
.float { position:absolute; filter: drop-shadow(0 30px 40px rgba(70,35,10,.30)); z-index:5; }
.chip { position:absolute; z-index:6; display:flex; align-items:center; gap:24px; padding:28px 52px 28px 32px;
  background:rgba(255,251,246,.94); border-radius:999px; border:2px solid rgba(133,64,36,.18);
  box-shadow:0 30px 60px -20px rgba(80,40,15,.45); font-size:86px; font-weight:800; color:${C.accent}; }
.chip img { width:104px; height:104px; }
</style></head><body>
${slides.map((s, i) => `<div class="bg ${s.dark ? 'dark' : ''}" style="left:${i * W}px"></div>`).join('')}
${seams(slides)}${slides.map((s, i) => slide(s, i, lang)).join('')}</body></html>`;
}

const browser = await chromium.launch({ executablePath: CHROME });
const ctx = await browser.newContext({ deviceScaleFactor: 1 });
for (const lang of ['en', 'ar']) {
  const n = COPY[lang].slides.length;
  const outDir = path.join(ROOT, 'app-store', 'screenshots-ipad', lang);
  mkdirSync(outDir, { recursive: true });
  const htmlPath = path.join(ROOT, 'src', `.ipad-${lang}.html`);
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
