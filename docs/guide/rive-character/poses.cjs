const layout=require('./layout.json');
const rad=d=>d*Math.PI/180;
const base=Object.fromEntries(layout.bones.map(b=>[b.name,{...b,angle:b.rotationRadians??b.angle}]));
const names=['standing','takbir','bowing','rising','prostrating','sitting','tashahhud','salamRight','salamLeft','after'];
function copy(){return structuredClone(base);}
function move(b,n,x,y,degrees){Object.assign(b[n],{x,y});if(degrees!==undefined)b[n].angle=rad(degrees);}
function chain(b,side,kind,points,tipAngle){
 const ns=kind==='arm'?[`upper_arm_${side}`,`forearm_${side}`,`hand_${side}`]:[`thigh_${side}`,`shin_${side}`,`foot_${side}`];
 for(let i=0;i<3;i++){const [x,y]=points[i];move(b,ns[i],x,y);if(i<2){const [xx,yy]=points[i+1];b[ns[i]].angle=Math.atan2(yy-y,xx-x);b[ns[i]].length=Math.hypot(xx-x,yy-y);}else b[ns[i]].angle=rad(tipAngle);}
}
function upright(b,x,y){const dx=x-base.hips.x,dy=y-base.hips.y;for(const n of ['hips','spine','chest','neck','head'])move(b,n,base[n].x+dx,base[n].y+dy);return [dx,dy];}
function seated(b,cross=false){const [dx,dy]=upright(b,cross?800:825,cross?1400:1380);
 chain(b,'near','leg',[[814+dx,1090+dy],[cross?650:620,1490],[cross?780:815,1497]],180);
 chain(b,'far','leg',[[750+dx,1085+dy],[cross?570:650,1460],[cross?650:885,cross?1495:1462]],180);
 chain(b,'near','arm',[[850+dx,851+dy],[805+dx,1010+dy],[705,1425]],180);
 chain(b,'far','arm',[[753+dx,851+dy],[725+dx,1000+dy],[665,1395]],0);
}
const poses=names.map((name,index)=>{const b=copy();
 const p={name,index,bones:b,head:'base',nearHand:'hand_near',farHand:'hand_far',nearFoot:'foot_near',farFoot:'foot_far',skirt:'skirt_thobe'};
 if(name==='standing'){
  chain(b,'far','arm',[[748,851],[710,1020],[706,985]],0);
 }
 if(name==='takbir'){
  chain(b,'near','arm',[[850,851],[825,1010],[797,847]],180);
  chain(b,'far','arm',[[753,851],[678,974],[665,823]],0);
  p.nearHand='hand_near_palm';p.farHand='hand_far_palm';
 }
 if(name==='rising'){
  chain(b,'near','arm',[[850,851],[855,1015],[840,1140]],90);
  chain(b,'far','arm',[[753,851],[750,1000],[690,1110]],90);
 }
 if(name==='bowing'){
  upright(b,850,1060);
  move(b,'spine',800,1060,-180);move(b,'chest',730,1060,-180);move(b,'neck',606,1060,-180);move(b,'head',577,1060,-180);
  chain(b,'near','leg',[[872,1090],[870,1305],[883,1497]],180);
  chain(b,'far','leg',[[808,1085],[806,1293],[813,1476]],180);
  chain(b,'near','arm',[[660,1090],[755,1190],[842,1290]],110);
  chain(b,'far','arm',[[625,1070],[715,1170],[791,1265]],70);
 }
 if(['sitting','tashahhud','salamRight','salamLeft'].includes(name)){
  seated(b);p.skirt='skirt_thobe_folded';p.farFoot='foot_far_tucked';p.nearFoot='foot_near_seated';p.nearHand='hand_near_flat';p.farHand='hand_far_flat';
  if(name==='tashahhud'){p.nearHand='hand_near_pointing';b.head.angle-=rad(8);}
  if(name.startsWith('salam'))p.head='head_'+name;
 }
 if(name==='after'){
  seated(b,true);p.skirt='skirt_thobe_crossed';
  chain(b,'near','arm',[[858,1191],[810,1340],[700,1260]],180);
  chain(b,'far','arm',[[761,1191],[720,1315],[652,1230]],0);
  p.nearHand='hand_near_cupped';p.farHand='hand_far_cupped';
 }
 if(name==='prostrating'){
  move(b,'hips',825,1290,-90);move(b,'spine',760,1300,-160);move(b,'chest',660,1340,135);move(b,'neck',560,1440,140);move(b,'head',530,1465,-179);
  chain(b,'near','leg',[[817,1307],[710,1505],[905,1462]],180);
  chain(b,'far','leg',[[790,1300],[685,1476],[884,1433]],180);
  chain(b,'near','arm',[[660,1360],[680,1450],[630,1544]],180);
  chain(b,'far','arm',[[615,1338],[625,1430],[575,1515]],0);
  p.nearFoot='foot_near_tucked';p.farFoot='foot_far_tucked';p.nearHand='hand_near_flat';p.farHand='hand_far_flat';
 }
 return p;
});
module.exports={base,poses,names,rad};
