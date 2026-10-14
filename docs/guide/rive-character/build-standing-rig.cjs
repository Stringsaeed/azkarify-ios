const fs=require('node:fs'),path=require('node:path');
const root=__dirname,out=path.join(root,'rive-source');
const layout=require('./layout.json'),{base,poses,names}=require('./poses.cjs');
const parts=layout.parts,partMap=Object.fromEntries(parts.map((p,i)=>[p.name,{...p,index:i,id:`2:${i+1}`} ]));
const bones=Object.values(base),fmt=n=>Number(n.toFixed(6));
const wrap=(a,ref)=>{while(a-ref>Math.PI)a-=Math.PI*2;while(a-ref< -Math.PI)a+=Math.PI*2;return a;};
function local(b,world){const p=world[b.parent];if(!p)return{x:b.x,y:b.y,rotation:b.angle};const dx=b.x-p.x,dy=b.y-p.y,c=Math.cos(p.angle),s=Math.sin(p.angle);return{x:c*dx+s*dy,y:-s*dx+c*dy,rotation:b.angle-p.angle};}
const goalIds=Object.fromEntries(bones.map((b,i)=>[b.name,`40:${i+1}`]));
const goals=bones.map(b=>`<Node name="${b.name}_target" id="${goalIds[b.name]}" x="${b.x}" y="${b.y}" rotation="${b.angle}"/>`).join('');
function boneXML(b){const p=local(b,base),segment=/^(upper_arm|forearm|thigh|shin)_/.test(b.name),endSegment=/^(forearm|shin)_/.test(b.name);let constraints='';
 if(!endSegment)constraints+=`<TranslationConstraint targetId="${goalIds[b.name]}"/>`;
 if(!segment)constraints+=`<RotationConstraint targetId="${goalIds[b.name]}"/>`;
 if(!endSegment&&b.name!=='chest')constraints+=`<ScaleConstraint targetId="${goalIds[b.name]}"/>`;
 if(endSegment){const side=b.name.endsWith('near')?'near':'far',leg=b.name.startsWith('shin');constraints+=`<IKConstraint targetId="${goalIds[(leg?'foot_':'hand_')+side]}" parentBoneCount="1" invertDirection="${leg?'false':'true'}"/>`;}
 return `<RootBone name="${b.name}" id="${b.id}" x="${fmt(p.x)}" y="${fmt(p.y)}" rotation="${fmt(p.rotation)}" length="${b.length}">${constraints}${bones.filter(c=>c.parent===b.name).map(boneXML).join('')}</RootBone>`;
}
function matrix(name,world){const a=base[name],b=world[name],r=b.angle-a.angle,c=Math.cos(r),s=Math.sin(r);return [c,s,-s,c,b.x-c*a.x+s*a.y,b.y-s*a.x-c*a.y];}
const apply=(m,p)=>({x:m[0]*p.x+m[2]*p.y+m[4],y:m[1]*p.x+m[3]*p.y+m[5]});
const inverse=(m,p)=>{const d=m[0]*m[3]-m[1]*m[2],x=p.x-m[4],y=p.y-m[5];return{x:(m[3]*x-m[2]*y)/d,y:(-m[1]*x+m[0]*y)/d};};
function weightRow(y,stops){if(y<=stops[0][0])return[[stops[0][1],255]];for(let i=0;i<stops.length-1;i++)if(y<=stops[i+1][0]){const t=(y-stops[i][0])/(stops[i+1][0]-stops[i][0]),w=Math.round(255*(1-t));return [[stops[i][1],w],[stops[i+1][1],255-w]].filter(x=>x[1]);}return[[stops.at(-1)[1],255]];}
function makeMesh(p){const cloth=p.binding==='mesh',cols=cloth?7:2,rows=cloth?13:2,raw=[];
 const tendons=p.name==='neck'?['head','neck']:p.name==='torso_thobe'?['neck','chest','spine','hips']:p.name==='skirt_thobe'?['spine','hips','thigh_near','shin_near']:p.name.startsWith('skirt_')?['hips','thigh_near','thigh_far']:[p.bone];
 for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){const u=x/(cols-1),v=y/(rows-1);let px=p.bounds.x+u*p.bounds.width,py=p.bounds.y+v*p.bounds.height,tv=v;
  
  
  
  const registration=p.name.startsWith('forearm_')?[[.84,.30],[.025,.59]]:p.name.startsWith('upper_arm_')?[[.5,.10],[.5,.88]]:p.name.startsWith('thigh_')?[[.5,.10],[.5,.90]]:p.name.startsWith('shin_')?[[.5,.07],[.5,.95]]:null;
  if(registration){const [a,z]=registration,bone=base[p.bone],ax=a[0]*p.bounds.width,ay=a[1]*p.bounds.height,dx=(z[0]-a[0])*p.bounds.width,dy=(z[1]-a[1])*p.bounds.height,r=bone.angle-Math.atan2(dy,dx),scale=bone.length/Math.hypot(dx,dy),xx=u*p.bounds.width-ax,yy=v*p.bounds.height-ay;px=bone.x+scale*(Math.cos(r)*xx-Math.sin(r)*yy);py=bone.y+scale*(Math.sin(r)*xx+Math.cos(r)*yy);}
 const w=p.name==='neck'?weightRow(py,[[765,0],[825,1]]):p.name==='torso_thobe'?weightRow(py,[[804,0],[900,1],[1000,2],[1040,3]]):p.name==='skirt_thobe'?weightRow(py,[[1000,0],[1040,1],[1120,1],[1220,2],[1308,3]]):p.name.startsWith('skirt_')?[[0,200],[1,55]]:[[0,255]];
  raw.push({u,v,tv,x:px,y:py,edge:x===0||y===0||x===cols-1||y===rows-1,key:y*cols+x,weights:w});
 }
 const verts=[...raw.filter(v=>v.edge).sort((a,b)=>Math.atan2(a.v-.5,a.u-.5)-Math.atan2(b.v-.5,b.u-.5)),...raw.filter(v=>!v.edge)];const map=Object.fromEntries(verts.map((v,i)=>[v.key,i])),tri=[];
 for(let y=0;y<rows-1;y++)for(let x=0;x<cols-1;x++){const a=map[y*cols+x],b=map[y*cols+x+1],c=map[(y+1)*cols+x+1],d=map[(y+1)*cols+x];tri.push(a,b,c,a,c,d);}
 verts.forEach((v,i)=>v.id=`10:${p.index*1000+i+1}`);
 const xml=`<Mesh name="${p.name}_mesh" triangleIndexBytes="${Buffer.from(tri).toString('base64')}">${verts.map(v=>{let values=0,indices=0;v.weights.forEach(([t,w],i)=>{values|=w<<(8*i);indices|=(t+1)<<(8*i)});const type=v.edge?'ContourMeshVertex':'MeshVertex';return `<${type} id="${v.id}" x="${fmt(v.x)}" y="${fmt(v.y)}" u="${v.u}" v="${v.tv}"><Weight indices="${indices>>>0}" values="${values>>>0}"/></${type}>`;}).join('')}<Skin>${tendons.map(n=>{const b=base[n],c=fmt(Math.cos(b.angle)),s=fmt(Math.sin(b.angle));return `<Tendon name="${n}" boneId="${b.id}" xx="${c}" xy="${s}" yx="${-s}" yy="${c}" tx="${b.x}" ty="${b.y}"/>`;}).join('')}</Skin></Mesh>`;
 return{xml,verts,tendons};
}
const meshes=Object.fromEntries(Object.values(partMap).map(p=>[p.name,makeMesh(p)]));
function image(n){const p=partMap[n];return `<Image name="${n}" id="${p.id}" assetId="3:${p.index+1}">${meshes[n].xml}</Image>`;}
const groups={head:{id:'5:1',options:['base','head_salamRight','head_salamLeft']},nearHand:{id:'5:2',options:['hand_near','hand_near_pointing','hand_near_palm','hand_near_cupped','hand_near_flat']},farHand:{id:'5:3',options:['hand_far','hand_far_palm','hand_far_cupped','hand_far_flat']},nearFoot:{id:'5:4',options:['foot_near','foot_near_tucked','foot_near_seated']},farFoot:{id:'5:5',options:['foot_far','foot_far_tucked']},skirt:{id:'5:6',options:['skirt_thobe','skirt_thobe_folded','skirt_thobe_crossed']}};
const optionId=n=>n==='base'?'5:100':partMap[n].id;
function solo(key){const g=groups[key];return `<Solo name="${key}_views" id="${g.id}" activeComponentId="${optionId(g.options[0])}">${g.options.map(n=>n==='base'?`<Node name="head_base" id="5:100">${['kufi','ear_near','hair','head'].map(image).join('')}</Node>`:image(n)).join('')}</Solo>`;}
const drawOrder=[()=>solo('farFoot'),'thigh_far','shin_far',()=>solo('nearFoot'),'thigh_near','shin_near','upper_arm_far','neck',()=>solo('skirt'),'torso_thobe',()=>solo('head'),'upper_arm_near',()=>solo('nearHand'),'forearm_near',()=>solo('farHand'),'forearm_far'];
const key=(id,prop,value,type='Double',frame=0)=>`<KeyedObject objectId="${id}"><KeyedProperty property="${prop}"><KeyFrame${type} value="${typeof value==='number'?fmt(value):value}" frame="${frame}"/></KeyedProperty></KeyedObject>`;
function posedVertices(p,pose){const mesh=meshes[p.name],b=base[p.bone],target=pose.bones[p.bone];return mesh.verts.map(v=>{let q={x:v.x,y:v.y};
 if(p.binding!=='mesh'&&/^(upper_arm|forearm|thigh|shin)_/.test(p.name)){const c=Math.cos(b.angle),s=Math.sin(b.angle),dx=v.x-b.x,dy=v.y-b.y,along=dx*c+dy*s,ratio=target.length/b.length;q={x:v.x+(ratio-1)*along*c,y:v.y+(ratio-1)*along*s};}
 if(p.name==='skirt_thobe_folded'||p.name==='skirt_thobe_crossed'||(p.name==='skirt_thobe'&&pose.name==='prostrating')){
  const h=pose.bones.hips;let desired;
  if(p.name==='skirt_thobe_folded')desired={x:h.x-295+v.u*385,y:h.y-90+v.v*220};
  else if(p.name==='skirt_thobe_crossed')desired={x:h.x-330+v.u*440,y:h.y-80+v.v*210};
  else {const skinAt=(point)=>{let result={x:0,y:0};for(const [t,w]of v.weights){const a=apply(matrix(mesh.tendons[t],pose.bones),point);result.x+=a.x*w/255;result.y+=a.y*w/255;}return result;};if(v.y<=1120)desired=skinAt(v);else{const t=(v.y-1120)/(1308-1120),top=apply(matrix('hips',pose.bones),{x:v.x,y:1120}),bottom={x:h.x-130+(v.u-.5)*260,y:h.y+200};desired={x:top.x*(1-t)+bottom.x*t,y:top.y*(1-t)+bottom.y*t};}}
  const m=[0,0,0,0,0,0];for(const [t,w] of v.weights){const n=matrix(mesh.tendons[t],pose.bones);n.forEach((z,i)=>m[i]+=z*w/255);}q=inverse(m,desired);
 }
 if(p.name.startsWith('foot_')){const near=p.bone==='foot_near',floor=near?1560:['sitting','tashahhud','salamRight','salamLeft'].includes(pose.name)?1560:pose.name==='after'?1550:1531;q.y+=floor-target.y-(p.bounds.y+p.bounds.height-b.y);}
 return key(v.id,'x',q.x)+key(v.id,'y',q.y);
 }).join('');}
function animation(p){let keys='';for(const b of Object.values(p.bones)){const loc=local(b,p.bones),ref=local(base[b.name],base);loc.rotation=wrap(loc.rotation,ref.rotation);for(const [k,v]of Object.entries(loc))keys+=key(b.id,k,v);if(/^(upper_arm|forearm|thigh|shin)_/.test(b.name))keys+=key(b.id,'length',b.length);}
 for(const b of Object.values(p.bones)){keys+=key(goalIds[b.name],'x',b.x)+key(goalIds[b.name],'y',b.y)+key(goalIds[b.name],'rotation',wrap(b.angle,base[b.name].angle));}
 for(const [n,g]of Object.entries(groups))keys+=key(g.id,'activeComponentId',optionId(p[n]),'Id');
 for(const part of Object.values(partMap))keys+=posedVertices(part,p);
 return `<LinearAnimation name="${p.name}" id="20:${p.index+1}" duration="1" fps="60">${keys}</LinearAnimation>`;}
const ease='<CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>';
const transitions=poses.map(p=>`<StateTransition stateToId="30:${p.index+1}" duration="1200" interpolationType="cubic" enableEarlyExit="true"><TransitionNumberCondition inputId="0:40" opValue="equal" value="${p.index}"/>${ease}</StateTransition>`).join('');
const sm=`<StateMachine name="Guide" id="0:10"><StateMachineNumber name="pose" id="0:40" value="0"/><StateMachineLayer name="Poses"><EntryState x="0" y="0"><StateTransition stateToId="30:1"/></EntryState><AnyState x="0" y="-200">${transitions}</AnyState><ExitState x="0" y="200"/>${poses.map(p=>`<AnimationState id="30:${p.index+1}" animationId="20:${p.index+1}" x="${250+(p.index%5)*220}" y="${Math.floor(p.index/5)*220}"/>`).join('')}</StateMachineLayer><StateMachineLayer name="Breathing"><EntryState x="0" y="0"><StateTransition stateToId="30:20"/></EntryState><AnimationState id="30:20" animationId="20:20" x="220" y="0"/><AnyState x="0" y="-150"/><ExitState x="450" y="-150"/></StateMachineLayer></StateMachine>`;
const idle=['scaleX','scaleY'].map(prop=>`<KeyedProperty property="${prop}"><KeyFrameDouble value="1" frame="0" interpolationType="cubic">${ease}</KeyFrameDouble><KeyFrameDouble value="1.02" frame="90" interpolationType="cubic">${ease}</KeyFrameDouble><KeyFrameDouble value="1" frame="180"/></KeyedProperty>`).join('');
const artboard=`<Artboard name="PrayerGuide" id="0:1" width="1080" height="1920" defaultStateMachineId="0:10" styleId="0:2"><LayoutComponentStyle id="0:2"/>${goals}${boneXML(base.hips)}${drawOrder.map(x=>typeof x==='function'?x():image(x)).reverse().join('')}${sm}${poses.map(animation).join('')}<LinearAnimation name="idle" id="20:20" duration="180" fps="60" loopValue="loop"><KeyedObject objectId="${base.chest.id}">${idle}</KeyedObject></LinearAnimation></Artboard>`;
const assets=parts.map((p,i)=>`<ImageAsset name="${p.name}" id="3:${i+1}" file="../${p.croppedFile}"/>`).join('');
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'scene.rml'),`<Rive version="1" kind="fragment">${artboard}${assets}</Rive>`);fs.writeFileSync(path.join(out,'rive.yaml'),'name: guide-character\nmain: PrayerGuide\n');
layout.status='ten-poses-authored-awaiting-render-review';layout.runtimeStatus='Guide has pose 0..9, ten frame-zero postures, 1200 ms eased Any State transitions and an independent idle layer.';layout.poseNames=names;layout.variants=groups;layout.meshes={torso_thobe:{grid:[7,13],bones:['neck','chest','spine','hips'],uvBottom:1,sharedWaistOverlap:[1000,1120]},skirt_thobe:{grid:[7,13],bones:['spine','hips','thigh_near','shin_near'],correctivePose:'prostrating'},skirt_thobe_folded:{grid:[7,13],bones:['hips','thigh_near'],correctivePose:'sitting'},skirt_thobe_crossed:{grid:[7,13],bones:['hips','thigh_near'],correctivePose:'after'}};
layout.meshes.neck={grid:[7,13],bones:['head','neck']};
layout.stateMachine={name:'Guide',input:{name:'pose',type:'Number',default:0},poses:names,transitionMs:1200,ease:[.42,0,.58,1],idleSeconds:3};
layout.registration={upper_arm:[[.5,.10],[.5,.88]],forearm:[[.84,.30],[.025,.59]],thigh:[[.5,.10],[.5,.90]],shin:[[.5,.07],[.5,.95]],meaning:'UV anchors registered to bone origin and tip in the Rive meshes. PNG bounds describe unwarped source artwork.'};
const z={foot_far:0,thigh_far:10,shin_far:20,foot_near:30,thigh_near:40,shin_near:50,upper_arm_far:60,neck:70,skirt_thobe:80,torso_thobe:90,head:100,hair:101,ear_near:102,kufi:103,upper_arm_near:110,hand_near:120,forearm_near:130,hand_far:140,forearm_far:150};
for(const p of layout.parts){let anchor=p.name;if(p.name.startsWith('head_salam'))anchor='head';else if(p.name.startsWith('skirt_'))anchor='skirt_thobe';else if(p.name.startsWith('hand_near'))anchor='hand_near';else if(p.name.startsWith('hand_far'))anchor='hand_far';else if(p.name.startsWith('foot_near'))anchor='foot_near';else if(p.name.startsWith('foot_far'))anchor='foot_far';p.zOrder=z[anchor];p.drawGroup=anchor;}
fs.writeFileSync(path.join(root,'layout.json'),JSON.stringify(layout,null,2)+'\n');fs.writeFileSync(path.join(root,'pose-world-transforms.json'),JSON.stringify(poses,null,2)+'\n');
console.log('Authored Guide, 10 pose animations, idle, '+parts.length+' images, cloth correctives and rigid bindings');
