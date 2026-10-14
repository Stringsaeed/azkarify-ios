const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=__dirname,{names}=require('./poses.cjs');
const harness=path.join(root,'render-source');fs.mkdirSync(harness,{recursive:true});
function source(from,to,room,filter){let scene=fs.readFileSync(path.join(root,'rive-source/scene.rml'),'utf8').replace('<Artboard name="PrayerGuide"','<Artboard isComponent="true" x="1200" name="PrayerGuide"');
 if(filter)scene=scene.replace(/<Image name="([^"]+)"/g,(tag,n)=>filter(n)?tag:tag+' opacity="0"');
 const wrapper=`<ComponentAsset id="90:1" artboardId="0:1" name="PrayerGuide"/>
 <Artboard name="RenderStage" id="91:1" width="1080" height="1920" styleId="91:2" defaultStateMachineId="91:10"><LayoutComponentStyle id="91:2"/>
 <NestedArtboard name="Character" artboardId="0:1" id="91:3"><NestedStateMachine animationId="0:10"><NestedNumber name="pose" inputId="0:40" nestedValue="${from}" id="91:4"/></NestedStateMachine></NestedArtboard>
 ${room?'<Image name="room" x="540" y="960" scaleX="0.876623377" scaleY="0.869565217" assetId="92:1"/>':''}
 <StateMachine name="Capture" id="91:10"><StateMachineLayer name="Drive pose"><EntryState x="0" y="0"><StateTransition stateToId="91:11"/></EntryState><AnimationState id="91:11" animationId="91:20" x="220" y="0"/><AnyState x="0" y="-180"/><ExitState x="440" y="-180"/></StateMachineLayer></StateMachine>
 <LinearAnimation name="Drive pose" id="91:20" duration="900" fps="60"><KeyedObject objectId="91:4"><KeyedProperty property="nestedValue"><KeyFrameDouble value="${from}" frame="0"/><KeyFrameDouble value="${to}" frame="120"/></KeyedProperty></KeyedObject></LinearAnimation></Artboard>
 ${room?'<ImageAsset name="room" id="92:1" file="../room.jpg"/>':''}`;
 return scene.replace('</Rive>',wrapper+'</Rive>');}
function render(from,to,frames,file,room=true,filter){fs.writeFileSync(path.join(harness,'scene.rml'),source(from,to,room,filter));fs.writeFileSync(path.join(harness,'rive.yaml'),'name: render-guide\nmain: RenderStage\n');fs.mkdirSync(path.dirname(file),{recursive:true});const r=cp.spawnSync('rive',[harness,'--screenshot='+file,'--advance='+frames],{encoding:'utf8'});if(r.status!==0)throw Error(r.stdout+r.stderr);console.log(path.relative(root,file));}
if(require.main===module){
const selected=process.argv.slice(2);
for(let i=0;i<names.length;i++)if(!selected.length||selected.includes(names[i]))render(i,i,119,path.join(root,'renders/poses',names[i]+'.png'));
if(!selected.length||selected.includes('transitions'))for(const [a,b]of [[0,2],[3,4],[4,5]])render(a,b,156,path.join(root,'renders/transitions',names[a]+'-to-'+names[b]+'-600ms.png'));
if(!selected.length||selected.includes('transparency'))for(const i of [0,2,4,5,9])render(i,i,119,path.join(root,'renders/transparency',names[i]+'.png'),false);
}
module.exports={render,source};
