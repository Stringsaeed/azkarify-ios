// Shared design tokens and helpers for Azkarify marketing renders.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const ASSETS = path.join(ROOT, 'src', 'assets');
export const RAW = path.join(ROOT, 'raw');

// Colors mirror AppAppearance.accent("brown") and the visual direction doc.
export const C = {
  accent: '#854024',        // brown, light mode (0.52, 0.25, 0.14)
  accentDark: '#E89E6E',    // brown, dark mode (0.91, 0.62, 0.43)
  cream: '#F7EEE4',
  creamDeep: '#EFE0CF',
  ink: '#2A1A12',
  inkSoft: '#6E5546',
  night: '#17100C',
  nightSoft: '#2A1C15',
  gold: '#C9963E',
};

export const fileUrl = (p) => 'file://' + p;
export const asset = (name) => fileUrl(path.join(ASSETS, name));
export const raw = (name) => fileUrl(path.join(RAW, name + '.png'));

export const fontFace = `
@font-face { font-family: 'Alan Sans'; src: url('${asset('AlanSans.ttf')}') format('truetype');
  font-weight: 300 900; font-style: normal; }`;

// Port of BotanicalSprig/BotanicalStem/BotanicalLeaf from Shared/BotanicalBackground.swift.
export function sprig(color, id = 'g' + Math.random().toString(36).slice(2, 8)) {
  const w = 100, h = 180;
  const stem = `M ${w * 0.6} ${h} C ${w * 0.46} ${h * 0.66}, ${w * 0.6} ${h * 0.31}, ${w * 0.44} ${h * 0.05}`;
  const leaves = [];
  for (let i = 0; i < 7; i++) {
    const left = i % 2 === 0;
    const lh = h * (i === 6 ? 0.2 : 0.25), lw = w * 0.3;
    const rot = i === 6 ? -8 : left ? -52 : 48;
    const cx = w * (i === 6 ? 0.44 : left ? 0.32 : 0.68), cy = h * (0.85 - i * 0.115);
    const d = `M ${lw / 2} ${lh} C ${-0.16 * lw} ${0.68 * lh}, ${0.08 * lw} ${0.27 * lh}, ${0.43 * lw} 0 ` +
      `C ${1.03 * lw} ${0.25 * lh}, ${1.12 * lw} ${0.72 * lh}, ${lw / 2} ${lh} Z`;
    leaves.push(`<path d="${d}" fill="url(#${id})" transform="translate(${cx} ${cy}) rotate(${rot}) translate(${-lw / 2} ${-lh / 2})"/>`);
  }
  return `<svg viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg" overflow="visible">
    <defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${color}" stop-opacity=".65"/><stop offset="1" stop-color="${color}"/></linearGradient></defs>
    <path d="${stem}" stroke="${color}" stroke-width="1.5" stroke-linecap="round" fill="none"/>
    ${leaves.join('')}</svg>`;
}

// iPhone-style frame around a real simulator capture (1320 x 2868).
export function phone(src, width, { dark = false, shadow = true } = {}) {
  const bezel = Math.round(width * 0.028);
  const outerW = width + bezel * 2;
  const radius = Math.round(width * 0.135);
  return `<div class="phone" style="width:${outerW}px;border-radius:${radius + bezel}px;padding:${bezel}px;
    ${shadow ? '' : 'box-shadow:none;'}${dark ? 'background:linear-gradient(145deg,#3b3632,#0d0b0a 40%,#2b2724);' : ''}">
    <img src="${src}" style="width:${width}px;border-radius:${radius}px;display:block"/></div>`;
}

export const baseCss = `
${fontFace}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: transparent; -webkit-font-smoothing: antialiased; }
body { font-family: 'Alan Sans', system-ui; }
.phone { position: relative; background: linear-gradient(145deg, #4a443f, #151210 35%, #050404 60%, #3a3531);
  box-shadow: 0 0 0 3px #1d1916 inset, 0 60px 120px -30px rgba(60,25,10,.45), 0 30px 60px -20px rgba(60,25,10,.35); }
.phone::after { content: ''; position: absolute; inset: 0; border-radius: inherit; pointer-events: none;
  box-shadow: inset 0 0 0 1.5px rgba(255,255,255,.18); }
`;

export function readJSON(p) { return JSON.parse(readFileSync(p, 'utf8')); }
