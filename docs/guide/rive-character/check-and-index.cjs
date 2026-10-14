const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const sharp=require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=__dirname,layout=require('./layout.json');
const required=['kufi','hair','head','neck','torso_thobe','skirt_thobe','upper_arm_near','forearm_near','hand_near','hand_near_pointing','upper_arm_far','forearm_far','hand_far','thigh_near','shin_near','foot_near','thigh_far','shin_far','foot_far'];
async function main(){
 const checks=[];const add=(name,pass,detail)=>{checks.push({name,pass,detail});if(!pass)throw new Error(name+': '+detail)};
 const layers=[],cells=layout.parts.length;let labels='';
 for(let i=0;i<cells;i++){
  const p=layout.parts[i],file=path.join(root,p.file),m=await sharp(file).metadata();
  const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let nonzero=0,left=2160,top=3840,right=-1,bottom=-1;
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>8){nonzero++;left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
  add(p.name,m.width===2160&&m.height===3840&&m.hasAlpha&&nonzero>1000&&nonzero<2160*3840,{pixelSize:[m.width,m.height],alpha:true,paintedPixels:nonzero,visibleBoundsPixels:[left,top,right+1,bottom+1]});
  const x=i%4*300,y=Math.floor(i/4)*320;
  const thumb=await sharp(path.join(root,p.croppedFile)).resize(250,240,{fit:'inside'}).png().toBuffer();const tm=await sharp(thumb).metadata();
  layers.push({input:thumb,left:x+Math.round((300-tm.width)/2),top:y+15+Math.round((240-tm.height)/2)});
  labels+=`<text x="${x+16}" y="${y+280}" font-size="16" fill="#312e2a">${p.name}</text><text x="${x+16}" y="${y+303}" font-size="12" fill="#68625b">z ${p.zOrder} · pivot ${p.pivot.x}, ${p.pivot.y}</text>`;
 }
 add('Required parts',required.every(n=>layout.parts.some(p=>p.name===n)),required.length);
 add('Standing anchors',layout.parts.find(p=>p.name==='kufi').bounds.y===560&&layout.parts.find(p=>p.name==='foot_near').bounds.y+layout.parts.find(p=>p.name==='foot_near').bounds.height===1560,'Head 560, near sole 1560');
 add('Pointing hand hidden at rest',!layout.parts.find(p=>p.name==='hand_near_pointing').visibleInStanding,true);
 const room=await sharp(path.join(root,'room.jpg')).metadata();add('Room dimensions',room.width===1232&&room.height===2208,[room.width,room.height]);
 const h=Math.ceil(cells/4)*320;
 layers.push({input:Buffer.from(`<svg width="1200" height="${h}" xmlns="http://www.w3.org/2000/svg"><style>text{font-family:Arial,sans-serif}</style>${labels}</svg>`),left:0,top:0});
 await sharp({create:{width:1200,height:h,channels:4,background:'#eee9df'}}).composite(layers).png().toFile(path.join(root,'preview','parts-contact-sheet.png'));
 const a=await sharp(path.join(root,'screenshots/01-rive-standing.png')).raw().toBuffer();const b=await sharp(path.join(root,'screenshots/02-rive-inhale.png')).raw().toBuffer();let changes=0;for(let i=0;i<a.length;i++)if(a[i]!==b[i])changes++;
 add('Rive breathing changes the render',changes>1000,{changedChannels:changes});
 fs.writeFileSync(path.join(root,'validation.json'),JSON.stringify({checks,rig:{compiler:'Rive CLI 1.5.1',verify:'passed',inspectProblems:[],boneCount:17,imageCount:20,animations:['standing','idle'],poseRangeTested:['standing'],fullGuideStateMachine:false,editorRoundTrip:'pending'},limitations:['The other nine posture animations and Guide state machine are not authored.','No extreme-pose overlap or floor-contact validation has been performed.','Waist blend and far wrist need visual refinement.','Head-turn, palm-facing, and tucked-foot variants are not included.']},null,2)+'\n');
 const files=[...layout.parts.map(p=>p.file),'room.jpg','layout.json','preview/standing-over-room.png','standing-rig-preview.riv','standing-rig-preview.rev'];
 fs.writeFileSync(path.join(root,'manifest.sha256'),files.map(f=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex')+'  '+f).join('\n')+'\n');
 console.log(JSON.stringify({checks:checks.length,allPassed:checks.every(c=>c.pass),runtimeBytes:fs.statSync(path.join(root,'standing-rig-preview.riv')).size,editorBytes:fs.statSync(path.join(root,'standing-rig-preview.rev')).size}));
}
main().catch(e=>{console.error(e);process.exit(1)});
