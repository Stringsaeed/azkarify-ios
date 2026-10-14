const fs=require('node:fs'),path=require('node:path');
const sharp=require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=__dirname, files=require('./source/extras-generated-files.json');
const specs=[
 ['head_salamRight',623,560,225,249,777,787,'head'],
 ['head_salamLeft',623,560,225,249,777,787,'head'],
 ['hand_near_palm',722,899,65,117,753,1005,'hand_near'],
 ['hand_far_palm',659,882,65,117,690,988,'hand_far'],
 ['hand_near_cupped',675,918,108,100,753,1005,'hand_near'],
 ['hand_far_cupped',612,901,108,100,690,988,'hand_far'],
 ['foot_near_tucked',778,1465,83,130,825,1497,'foot_near'],
 ['foot_far_tucked',708,1444,83,130,755,1476,'foot_far'],
 ['skirt_thobe_folded',502,990,375,200,792,1060,'hips'],
 ['skirt_thobe_crossed',472,1000,430,235,792,1060,'hips'],
 ['hand_near_flat',681,993,100,28,753,1005,'hand_near'],
 ['hand_far_flat',618,976,100,28,690,988,'hand_far'],
 ['foot_near_seated',800,1480,150,80,825,1497,'foot_near']
];
async function main(){const layout=require('./layout.json');layout.parts=layout.parts.filter(p=>!specs.some(s=>s[0]===p.name));
 for(const [name,x,y,w,h,px,py,bone] of specs){const dest=path.join(root,'source',name+'.png');if(fs.existsSync(files[name]))fs.copyFileSync(files[name],dest);
 const {data,info}=await sharp(dest).ensureAlpha().raw().toBuffer({resolveWithObject:true});let left=info.width,top=info.height,right=0,bottom=0;
 for(let yy=0;yy<info.height;yy++)for(let xx=0;xx<info.width;xx++)if(data[(yy*info.width+xx)*4+3]>8){left=Math.min(left,xx);top=Math.min(top,yy);right=Math.max(right,xx);bottom=Math.max(bottom,yy);}
 const buf=await sharp(dest).extract({left,top,width:right-left+1,height:bottom-top+1}).resize(w*2,h*2,{fit:'fill'}).png().toBuffer();
 await sharp(buf).toFile(path.join(root,'editor',name+'.png'));
 await sharp({create:{width:2160,height:3840,channels:4,background:'#00000000'}}).composite([{input:buf,left:x*2,top:y*2}]).png().toFile(path.join(root,'parts',name+'.png'));
 layout.parts.push({name,file:'parts/'+name+'.png',croppedFile:'editor/'+name+'.png',pixelSize:[2160,3840],imagePosition:{x:0,y:0},imageScale:.5,position:{x,y},bounds:{x,y,width:w,height:h},pivot:{x:px,y:py},pivotPixels:{x:px*2,y:py*2},pivotInCroppedImagePixels:{x:(px-x)*2,y:(py-y)*2},zOrder:layout.parts.length,bone,visibleInStanding:false,binding:name.startsWith('skirt')?'mesh':'rigid',variant:true});
 }fs.writeFileSync(path.join(root,'layout.json'),JSON.stringify(layout,null,2)+'\n');console.log('Packaged '+specs.length+' alternate parts');}
main().catch(e=>{console.error(e);process.exit(1)});
