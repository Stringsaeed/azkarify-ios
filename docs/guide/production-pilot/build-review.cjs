const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const sharp=require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=__dirname;
const beats=[
 {pose:'standing',duration:1.1,title:'Hold standing',time:'0.00–1.10 s',lines:['Right hand rests over the left.','Eyes down. Feet planted.','Keep the original drawing’s proportions.'],status:'Existing key-pose reference'},
 {pose:'rising',duration:.7,title:'Release the hands',time:'1.10–1.80 s',lines:['Release the fingers first.','Separate and lower the forearms.','Keep the torso upright until the hands clear.'],status:'Endpoint shown · intermediate drawings required'},
 {pose:'bowing',duration:1.4,title:'Hinge into the bow',time:'1.80–3.20 s',lines:['Lead from the hips; keep the feet planted.','Hands travel toward the knees.','Draw the cloth compression and changing overlaps.'],status:'Endpoint shown · intermediate drawings required'},
 {pose:'bowing',duration:1.6,title:'Hold bowing',time:'3.20–4.80 s',lines:['Back flat and horizontal. Head in line.','Hands settle onto the knees.','Correct the back shape in this reference.'],status:'Key drawing needs flat-back correction'},
 {pose:'rising',duration:1.4,title:'Rise with control',time:'4.80–6.20 s',lines:['Release the hands from the knees.','Bring the torso upright without a body-wide scale.','Preserve the weight and planted foot contacts.'],status:'Endpoint shown · intermediate drawings required'},
 {pose:'standing',duration:.9,title:'Replace the hands',time:'6.20–7.10 s',lines:['Place the left hand on the chest.','Then settle the right hand over it.','Keep wrist and finger contact readable.'],status:'Endpoint shown · intermediate drawings required'},
 {pose:'standing',duration:.9,title:'Settle into the hold',time:'7.10–8.00 s',lines:['Return to the opening drawing.','Allow a small, calm settling movement.','Review the loop at normal playback speed.'],status:'Existing key-pose reference'}
];
const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
async function main(){
 let elapsed=0;const montage=[];
 for(let i=0;i<beats.length;i++){const b=beats[i],img=await sharp(path.join(root,'references',b.pose+'.jpg')).resize(400,717,{fit:'inside'}).png().toBuffer();
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="900"><style>text{font-family:Arial;fill:#39332d}.small{font-size:18px;fill:#766b5e}</style><rect width="1280" height="900" fill="#f0ebe2"/><text x="40" y="45" font-size="21">PRAYER GUIDE · TIMING ANIMATIC</text><text x="40" y="76" class="small">Existing still illustrations. Final movement is not drawn yet.</text><text x="500" y="160" class="small">${i+1} / 7    ${b.time}</text><text x="500" y="213" font-size="39">${b.title}</text>${b.lines.map((l,j)=>`<text x="500" y="${290+j*47}" font-size="22">${esc(l)}</text>`).join('')}<rect x="500" y="482" width="730" height="78" rx="8" fill="#e3d7c5"/><text x="518" y="528" font-size="18">${b.status}</text><text x="500" y="636" class="small">Production test: standing → bowing → standing.</text><text x="500" y="669" class="small">Judge the character and movement before scaling to ten poses.</text><rect x="500" y="780" width="730" height="10" rx="5" fill="#d8cebf"/><rect x="${500+elapsed/8*730}" y="780" width="${b.duration/8*730}" height="10" fill="#776a57"/><text x="500" y="825" class="small">8-second shot specification · no audio · fixed camera</text></svg>`;
 const card=path.join(root,'cards',String(i).padStart(2,'0')+'.png');await sharp(Buffer.from(svg)).composite([{input:img,left:40,top:105}]).png().toFile(card);elapsed+=b.duration;
 montage.push({input:await sharp(card).resize(640,450).png().toBuffer(),left:i%4*640,top:Math.floor(i/4)*450});}
 await sharp({create:{width:2560,height:900,channels:4,background:'#f0ebe2'}}).composite(montage).png().toFile(path.join(root,'storyboard.png'));
 const list=beats.map((b,i)=>`file 'cards/${String(i).padStart(2,'0')}.png'\nduration ${b.duration}`).join('\n')+"\nfile 'cards/06.png'\n";fs.writeFileSync(path.join(root,'animatic.ffconcat'),list);fs.writeFileSync(path.join(root,'shot-plan.json'),JSON.stringify({fps:24,duration:8,kind:'timed-still animatic, not finished character animation',beats},null,2)+'\n');
 const r=cp.spawnSync('ffmpeg',['-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i','animatic.ffconcat','-t','8','-r','24','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','timing-animatic.mp4'],{cwd:root,encoding:'utf8'});if(r.status)throw Error(r.stderr);
 const panels=[
 ['Original standing','references/standing.jpg',{left:630,top:620,width:430,height:1420}],
 ['Rejected rig standing','../rive-character/renders/poses/standing.png',{left:590,top:530,width:390,height:1060}],
 ['Original bowing','references/bowing.jpg',{left:170,top:820,width:960,height:1220}],
 ['Rejected rig bowing','../rive-character/renders/poses/bowing.png',{left:280,top:900,width:690,height:700}]
 ];const layers=[];let labels='';for(let i=0;i<panels.length;i++){const [name,file,crop]=panels[i],buf=await sharp(path.join(root,file)).extract(crop).resize(290,760,{fit:'inside'}).png().toBuffer(),m=await sharp(buf).metadata();layers.push({input:buf,left:20+i*320+Math.floor((290-m.width)/2),top:850-m.height});labels+=`<text x="${20+i*320}" y="65" font-size="20">${name}</text>`;}
 const base=Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="940"><rect width="1280" height="940" fill="#f0ebe2"/><g font-family="Arial" fill="#39332d">${labels}<text x="20" y="900" font-size="18">Uniform scaling within each panel. Bowing reference still requires the flat-back correction.</text></g></svg>`);await sharp(base).composite(layers).png().toFile(path.join(root,'reference-vs-rig.png'));
 console.log('Created 8-second animatic, seven storyboard cards, comparison board, and shot-plan.json.');
}
main().catch(e=>{console.error(e);process.exit(1)});
