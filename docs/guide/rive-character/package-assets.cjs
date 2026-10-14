const fs = require('node:fs');
const path = require('node:path');
const sharp = require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = __dirname;
const provenance = require('./source/generated-files.json');
const sources = Object.fromEntries(Object.entries(provenance).map(([name, original]) => {
 const local = path.join(root, 'source', name === 'roomResult' ? 'room-source.png' : name + '.png');
 return [name, fs.existsSync(local) ? local : original];
}));
// Placement is in 1x artboard units. All sprites are complete generated artwork.
const spec = [
 ['foot_far',657,1459,131,72,755,1476,'foot_far'],
 ['thigh_far',697,1063,105,259,750,1085,'thigh_far'],
 ['shin_far',708,1280,90,210,755,1293,'shin_far'],
 ['foot_near',725,1478,132,82,825,1497,'foot_near'],
 ['thigh_near',757,1070,119,240,814,1090,'thigh_near'],
 ['shin_near',767,1285,103,223,820,1305,'shin_near'],
 ['upper_arm_far',715,832,76,193,753,851,'upper_arm_far'],
 ['neck',749,765,73,83,785,816,'neck'],
 ['skirt_thobe',656,1028,245,280,792,1060,'hips'],
 ['torso_thobe',680,804,215,292,792,1060,'chest'],
 ['head',643,611,193,199,777,787,'head'],
 ['hair',623,605,221,164,777,787,'head'],
 ['ear_near',791,712,33,53,777,787,'head'],
 ['kufi',631,560,217,134,777,787,'head'],
 ['forearm_far',670,967,126,75,765,995,'forearm_far'],
 ['upper_arm_near',808,831,83,207,850,851,'upper_arm_near'],
 ['hand_near',681,973,100,60,753,1005,'hand_near'],
 ['forearm_near',744,974,142,79,850,1007,'forearm_near'],
 ['hand_far',666,957,99,59,690,988,'hand_far'],
 ['hand_near_pointing',675,974,106,59,753,1005,'hand_near']
];
async function main(){
 const parts=[];const composite=[];
 for(let i=0;i<spec.length;i++){
  const [name,x,y,w,h,px,py,bone,mirror=false]=spec[i];
  const savedSource=path.join(root,'source',name+'.png');
  if(sources[name]!==savedSource)fs.copyFileSync(sources[name],savedSource);
  const {data,info}=await sharp(sources[name]).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let left=info.width,top=info.height,right=0,bottom=0;
  for(let yy=0;yy<info.height;yy++)for(let xx=0;xx<info.width;xx++)if(data[(yy*info.width+xx)*4+3]>8){left=Math.min(left,xx);top=Math.min(top,yy);right=Math.max(right,xx);bottom=Math.max(bottom,yy);}
  const crop={left,top,width:right-left+1,height:bottom-top+1};
  let sprite=sharp(sources[name]).extract(crop).resize(w*2,h*2,{fit:'fill'});
  if(mirror)sprite=sprite.flop();
  const buffer=await sprite.png().toBuffer();
  await sharp({create:{width:2160,height:3840,channels:4,background:'#00000000'}}).composite([{input:buffer,left:x*2,top:y*2}]).png().toFile(path.join(root,'parts',name+'.png'));
  await sharp(buffer).png().toFile(path.join(root,'editor',name+'.png'));
  const visible=name!=='hand_near_pointing';
  if(visible)composite.push({input:buffer,left:x*2,top:y*2});
  parts.push({name,file:'parts/'+name+'.png',pixelSize:[2160,3840],imagePosition:{x:0,y:0},imageScale:0.5,position:{x,y},bounds:{x,y,width:w,height:h},pivot:{x:px,y:py},pivotPixels:{x:px*2,y:py*2},pivotInCroppedImagePixels:{x:(px-x)*2,y:(py-y)*2},zOrder:i,bone,visibleInStanding:visible,binding:['torso_thobe','skirt_thobe'].includes(name)?'mesh':'rigid',croppedFile:'editor/'+name+'.png',sourceArtworkReusedFrom:name==='upper_arm_near'?'upper_arm_far':undefined});
 }
 await sharp(sources.roomResult).resize(1232,2208,{fit:'fill'}).jpeg({quality:96,chromaSubsampling:'4:4:4'}).toFile(path.join(root,'room.jpg'));
 await sharp({create:{width:2160,height:3840,channels:4,background:'#00000000'}}).composite(composite).png().toFile(path.join(root,'preview','standing-transparent.png'));
 const room=await sharp(path.join(root,'room.jpg')).resize(2160,3840,{fit:'fill'}).png().toBuffer();
 const flattened=await sharp(room).composite(composite).png().toBuffer();
 await sharp(flattened).resize(1080,1920).png().toFile(path.join(root,'preview','standing-over-room.png'));
 const layout={schemaVersion:1,status:'parts-and-editor-handoff',artboard:{name:'PrayerGuide',width:1080,height:1920,background:'transparent'},coordinates:{origin:'top-left',x:'right',y:'down',units:'1x artboard units',pngScale:2,fullCanvasImport:'Import at scale 0.5 with top-left at 0,0. Rive image center is 540,960.'},view:{facing:'left',near:'left side of boy',far:'right side of boy'},room:{file:'room.jpg',width:1232,height:2208,reference:'guide-pose-standing.jpg',approvedAdjustment:'Floor and mat raised so near foot bottom is y=1560',displayRect:{x:0,y:0,width:1080,height:1920}},standing:{headTopY:560,nearFootBottomY:1560,farFootBottomY:1531,handOrder:'right/far over left/near'},trousers:'Included in thigh and shin artwork; no separate trousers images needed.',parts};
 fs.writeFileSync(path.join(root,'layout.json'),JSON.stringify(layout,null,2)+'\n');
 console.log('Packaged '+parts.length+' parts');
}
main().catch(e=>{console.error(e);process.exit(1)});
