const fs=require('node:fs'),path=require('node:path');
const root=__dirname,layout=JSON.parse(fs.readFileSync(path.join(root,'assets/layout.json'))),art={};
for(const name of [...Object.keys(layout),'robe','sleeve'])art[name]='data:image/png;base64,'+fs.readFileSync(path.join(root,'assets',name+'.png')).toString('base64');
const room='data:image/jpeg;base64,'+fs.readFileSync(path.join(root,'assets/room.jpg')).toString('base64');
let js=fs.readFileSync(path.join(root,'motion.js'),'utf8').replace("layout=await (await fetch('assets/layout.json')).json()",'layout='+JSON.stringify(layout)).replace('im.src=`assets/${name}.png`','im.src=ART[name]');
js='const ART='+JSON.stringify(art)+';\n'+js;
const html=fs.readFileSync(path.join(root,'index.html'),'utf8').replace('url(assets/room.jpg)',`url(${room})`).replace('<script type="module" src="motion.js"></script>',`<script type="module">${js}</script>`);
fs.writeFileSync(path.join(root,'standalone.html'),html);console.log('Created standalone.html: opens without a local server or network requests.');
