const fs=require('node:fs'),path=require('node:path');
const sharp=require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=__dirname,old=path.join(root,'../rive-character');
async function trim(input,output,width){
 const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});let l=info.width,t=info.height,r=0,b=0;
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>8){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y);}
 await sharp(input).extract({left:l,top:t,width:r-l+1,height:b-t+1}).resize({width}).png().toFile(output);
}
(async()=>{
 const names=['neck','head','hair','ear_near','kufi','hand_near','hand_far','hand_near_flat','hand_far_flat','shin_near','shin_far','foot_near','foot_far'];
 const layout=JSON.parse(fs.readFileSync(path.join(old,'layout.json')));
 for(const n of names)fs.copyFileSync(path.join(old,'editor',n+'.png'),path.join(root,'assets',n+'.png'));
 await trim(path.join(old,'source/whole_thobe.png'),path.join(root,'assets/robe.png'),640);
 fs.copyFileSync(path.join(old,'room.jpg'),path.join(root,'assets/room.jpg'));
 fs.writeFileSync(path.join(root,'assets/layout.json'),JSON.stringify(Object.fromEntries(layout.parts.filter(p=>names.includes(p.name)).map(p=>[p.name,{bounds:p.bounds,pivot:p.pivot}]))));
 if(fs.existsSync(path.join(root,'assets/sleeve-source.png')))await trim(path.join(root,'assets/sleeve-source.png'),path.join(root,'assets/sleeve.png'),256);
})();
