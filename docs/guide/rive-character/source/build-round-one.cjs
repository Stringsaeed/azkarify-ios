const fs=require('node:fs');
const path=require('node:path');
const root=__dirname, out=path.join(root,'rive-source');
fs.mkdirSync(out,{recursive:true});
const layout=require('./layout.json');
const bones=[
 ['hips',null,792,1060,-90,50],['spine','hips',792,1010,-90,70],
 ['chest','spine',792,940,-93.23,124],['neck','chest',785,816,-105.42,30],
 ['head','neck',777,787,-105,175],
 ['upper_arm_far','chest',753,851,85.24,144.5],['forearm_far','upper_arm_far',765,995,-174.67,75.33],['hand_far','forearm_far',690,988,0,65],
 ['upper_arm_near','chest',850,851,90,156],['forearm_near','upper_arm_near',850,1007,-178.82,97.02],['hand_near','forearm_near',753,1005,180,70],
 ['thigh_far','hips',750,1085,88.62,208.06],['shin_far','thigh_far',755,1293,90,183],['foot_far','shin_far',755,1476,180,90],
 ['thigh_near','hips',814,1090,88.4,215.08],['shin_near','thigh_near',820,1305,88.51,192.07],['foot_near','shin_near',825,1497,180,90]
].map(([name,parent,x,y,degrees,length],i)=>({name,parent,x,y,angle:degrees*Math.PI/180,length,id:`1:${i+1}`}));
const byName=Object.fromEntries(bones.map(b=>[b.name,b]));
function local(b){const p=byName[b.parent];if(!p)return{x:b.x,y:b.y,rotation:b.angle};const dx=b.x-p.x,dy=b.y-p.y,c=Math.cos(p.angle),s=Math.sin(p.angle);return{x:c*dx+s*dy,y:-s*dx+c*dy,rotation:b.angle-p.angle};}
const fmt=n=>Number(n.toFixed(6));
function boneXML(b){const p=local(b);return `<RootBone name="${b.name}" id="${b.id}" x="${fmt(p.x)}" y="${fmt(p.y)}" rotation="${fmt(p.rotation)}" length="${b.length}">${bones.filter(c=>c.parent===b.name).map(boneXML).join('')}</RootBone>`;}
function mesh(p){
 const grid=p.binding==='mesh'?{cols:5,rows:9}:{cols:2,rows:2};
 const {cols,rows}=grid;const raw=[];
 for(let y=0;y<rows;y++)for(let x=0;x<cols;x++)raw.push({x:x/(cols-1),y:y/(rows-1),edge:x===0||y===0||x===cols-1||y===rows-1,key:y*cols+x});
 const edge=raw.filter(v=>v.edge).sort((a,b)=>Math.atan2(a.y-.5,a.x-.5)-Math.atan2(b.y-.5,b.x-.5));
 const vertices=[...edge,...raw.filter(v=>!v.edge)];const idx=Object.fromEntries(vertices.map((v,i)=>[v.key,i]));
 const triangles=[];for(let y=0;y<rows-1;y++)for(let x=0;x<cols-1;x++){const a=idx[y*cols+x],b=idx[y*cols+x+1],c=idx[(y+1)*cols+x+1],d=idx[(y+1)*cols+x];triangles.push(a,b,c,a,c,d);}
 const tendons=p.name==='torso_thobe'?['hips','spine','chest']:p.name==='skirt_thobe'?['hips','thigh_near','shin_near']:[p.bone];
 function weights(v){if(tendons.length===1)return{indices:1,values:255};
 const gy=p.bounds.y+v.y*p.bounds.height;
 const stops=p.name==='torso_thobe'?[[804,2],[960,1],[1060,0]]:[[1028,0],[1155,1],[1308,2]];
 if(gy<=stops[0][0])return{indices:stops[0][1]+1,values:255};
 for(let k=0;k<stops.length-1;k++)if(gy<=stops[k+1][0]){const a=stops[k],b=stops[k+1],t=(gy-a[0])/(b[0]-a[0]),wa=Math.round(255*(1-t)),wb=255-wa;return{indices:(a[1]+1)|((b[1]+1)<<8),values:wa|(wb<<8)};}
 return{indices:stops.at(-1)[1]+1,values:255};}
 return `<Mesh name="${p.name}_mesh" triangleIndexBytes="${Buffer.from(triangles).toString('base64')}">${vertices.map(v=>{const w=weights(v),type=v.edge?'ContourMeshVertex':'MeshVertex';return `<${type} x="${fmt(p.bounds.x+v.x*p.bounds.width)}" y="${fmt(p.bounds.y+v.y*p.bounds.height)}" u="${v.x}" v="${v.y}"><Weight indices="${w.indices}" values="${w.values}"/></${type}>`;}).join('')}<Skin>${tendons.map(n=>{const b=byName[n],c=fmt(Math.cos(b.angle)),s=fmt(Math.sin(b.angle));return `<Tendon name="${n}" boneId="${b.id}" xx="${c}" xy="${s}" yx="${-s}" yy="${c}" tx="${b.x}" ty="${b.y}"/>`;}).join('')}</Skin></Mesh>`;
}
const keyed=(id,prop,value,frame=0)=>`<KeyedObject objectId="${id}"><KeyedProperty property="${prop}"><KeyFrameDouble value="${value}" frame="${frame}"/></KeyedProperty></KeyedObject>`;
const posed=bones.map(b=>Object.entries(local(b)).map(([k,v])=>keyed(b.id,k,fmt(v))).join('')).join('');
const ease='<CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>';
const idle=['scaleX','scaleY'].map(prop=>`<KeyedProperty property="${prop}"><KeyFrameDouble value="1" frame="0" interpolationType="cubic">${ease}</KeyFrameDouble><KeyFrameDouble value="1.02" frame="90" interpolationType="cubic">${ease}</KeyFrameDouble><KeyFrameDouble value="1" frame="180"/></KeyedProperty>`).join('');
const xml=`<Rive version="1" kind="fragment">
 <Artboard name="PrayerGuide" id="0:1" width="1080" height="1920" defaultStateMachineId="0:10" styleId="0:2"><LayoutComponentStyle id="0:2"/>
 ${boneXML(bones[0])}
 ${layout.parts.map((p,i)=>`<Image name="${p.name}" id="2:${i+1}" assetId="3:${i+1}" opacity="${p.visibleInStanding?1:0}">${mesh(p)}</Image>`).reverse().join('\n')}
 <StateMachine name="StandingPreview" id="0:10"><StateMachineLayer name="Pose"><EntryState x="0" y="0"><StateTransition stateToId="0:11"/></EntryState><AnimationState x="200" y="0" animationId="0:20" id="0:11"/><AnyState x="0" y="-140"/><ExitState x="400" y="-140"/></StateMachineLayer><StateMachineLayer name="Breathing"><EntryState x="0" y="0"><StateTransition stateToId="0:12"/></EntryState><AnimationState x="200" y="0" animationId="0:21" id="0:12"/><AnyState x="0" y="-140"/><ExitState x="400" y="-140"/></StateMachineLayer></StateMachine>
 <LinearAnimation name="standing" id="0:20" duration="1" fps="60">${posed}</LinearAnimation>
 <LinearAnimation name="idle" id="0:21" duration="180" fps="60" loopValue="loop"><KeyedObject objectId="${byName.chest.id}">${idle}</KeyedObject></LinearAnimation>
 </Artboard>
 ${layout.parts.map((p,i)=>`<ImageAsset name="${p.name}" id="3:${i+1}" file="../${p.croppedFile}"/>`).join('\n')}
 </Rive>`;
fs.writeFileSync(path.join(out,'scene.rml'),xml);
fs.writeFileSync(path.join(out,'rive.yaml'),'name: standing-rig-preview\nmain: PrayerGuide\n');
layout.bones=bones.map(b=>({...b,rotationDegrees:fmt(b.angle*180/Math.PI),rotationRadians:fmt(b.angle),localTransform:local(b)}));
layout.meshes={torso_thobe:{grid:[5,9],bones:['hips','spine','chest'],weightRows:[[804,'chest'],[960,'spine'],[1060,'hips']]},skirt_thobe:{grid:[5,9],bones:['hips','thigh_near','shin_near'],weightRows:[[1028,'hips'],[1155,'thigh_near'],[1308,'shin_near']]}};
layout.runtimeStatus='The included standing-rig-preview files contain standing and idle only. Complete the remaining poses and Guide state machine using BUILD-GUIDE.md.';
fs.writeFileSync(path.join(root,'layout.json'),JSON.stringify(layout,null,2)+'\n');
console.log('Wrote real Rive standing rig with 17 bones, 20 bound images and two animations.');
