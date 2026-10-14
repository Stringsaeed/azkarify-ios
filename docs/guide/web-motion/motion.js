const W=1080,H=1920,PI=Math.PI;
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const mix=(a,b,t)=>a+(b-a)*t;
const smooth=t=>{t=clamp(t);return t*t*(3-2*t)};
const lerp=(a,b,t)=>a.map((x,i)=>mix(x,b[i],t));
const add=(a,b)=>[a[0]+b[0],a[1]+b[1]];
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1]];
const mul=(a,k)=>[a[0]*k,a[1]*k];
const length=a=>Math.hypot(...a);
const norm=a=>mul(a,1/(length(a)||1));
const rotate=(p,a)=>[p[0]*Math.cos(a)-p[1]*Math.sin(a),p[0]*Math.sin(a)+p[1]*Math.cos(a)];
const canvas=document.querySelector('canvas');
const gl=canvas.getContext('webgl',{alpha:true,premultipliedAlpha:true,antialias:true,preserveDrawingBuffer:true});
if(!gl)throw Error('WebGL is unavailable in this browser.');
function shader(type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s;}
const program=gl.createProgram();
gl.attachShader(program,shader(gl.VERTEX_SHADER,`attribute vec2 position;attribute vec2 uv;varying vec2 vuv;void main(){gl_Position=vec4(position.x/540.-1.,1.-position.y/960.,0.,1.);vuv=uv;}`));
gl.attachShader(program,shader(gl.FRAGMENT_SHADER,`precision mediump float;varying vec2 vuv;uniform sampler2D art;void main(){gl_FragColor=texture2D(art,vuv);}`));
gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));gl.useProgram(program);
gl.enable(gl.BLEND);gl.blendFunc(gl.ONE,gl.ONE_MINUS_SRC_ALPHA);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,true);
const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
for(const [n,offset]of [['position',0],['uv',8]]){const loc=gl.getAttribLocation(program,n);gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,2,gl.FLOAT,false,16,offset)}
const textures={},layout=await (await fetch('assets/layout.json')).json();
await Promise.all([...Object.keys(layout),'robe','sleeve'].map(async name=>{const im=new Image();im.src=`assets/${name}.png`;await im.decode();const t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,im);textures[name]=t;}));
function mesh(name,nx,ny,map,range=[0,1]){const data=[];const v=(x,y)=>{const v=mix(range[0],range[1],y/ny),p=map(x/nx,v);data.push(...p,x/nx,v)};for(let y=0;y<ny;y++)for(let x=0;x<nx;x++){v(x,y);v(x+1,y);v(x,y+1);v(x+1,y);v(x+1,y+1);v(x,y+1)}gl.bindTexture(gl.TEXTURE_2D,textures[name]);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.DYNAMIC_DRAW);gl.drawArrays(gl.TRIANGLES,0,data.length/4);}
function part(name,transform=p=>p,rect=layout[name].bounds){mesh(name,1,1,(u,v)=>transform([rect.x+u*rect.width,rect.y+v*rect.height]));}
// Integrate the tangent of one continuous cloth surface. The bend is spread
// over a 220-unit hip region, keeping its inner radius wider than the cloth.
function garment(bend){const a=-PI/2*bend,start=940,end=1160,centers=[];
 centers[end]=[792,end];
 for(let y=end-1;y>=540;y--){const angle=a*(1-smooth((y+.5-start)/(end-start)));centers[y]=add(centers[y+1],[Math.sin(angle),-Math.cos(angle)]);}
 function at(y){if(y>=end)return [792,y];const i=Math.floor(y);return lerp(centers[i],centers[i+1],y-i);}
 function transform(p,correct=false){const angle=a*(1-smooth((p[1]-start)/(end-start)));const point=add(at(p[1]),rotate([p[0]-792,0],angle));if(correct)point[1]+=(940-point[1])*Math.pow(bend,4)*smooth((p[1]-845)/40)*(1-smooth((p[1]-1010)/110))*smooth((p[0]-780)/95);return point;}
 return {transform,a,neck:transform([777,787])};
}
function ik(s,w,l1,l2){const delta=sub(w,s),d=clamp(length(delta),Math.abs(l1-l2)+.01,l1+l2-.01),axis=norm(delta),along=(l1*l1-l2*l2+d*d)/(2*d),height=Math.sqrt(Math.max(0,l1*l1-along*along));return add(add(s,mul(axis,along)),mul([axis[1],-axis[0]],height));}
function catmull(points,t){const n=points.length-1,f=clamp(t)*n,i=Math.min(n-1,Math.floor(f)),u=f-i,p0=points[Math.max(0,i-1)],p1=points[i],p2=points[i+1],p3=points[Math.min(n,i+2)];return [0,1].map(k=>.5*((2*p1[k])+(-p0[k]+p2[k])*u+(2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*u*u+(-p0[k]+3*p1[k]-3*p2[k]+p3[k])*u*u*u));}
function sleeve(s,e,w,width,range=[0,1]){const upper=norm(sub(e,s)),lower=norm(sub(w,e));const points=[sub(s,mul(upper,32)),s,lerp(s,e,.72),e,lerp(e,w,.28),add(w,mul(lower,12))];
 const c=t=>catmull(points,t);
 mesh('sleeve',8,72,(u,v)=>{const p=c(v),tangent=norm(sub(c(Math.min(1,v+.002)),c(Math.max(0,v-.002))));return add(p,mul([tangent[1],-tangent[0]],(u-.5)*width));},range);
}
function hand(name,w,angle){const p=layout[name].pivot;part(name,q=>add(w,rotate(sub(q,[p.x,p.y]),angle)));}
let lastDiagnostics={};
function draw(progress){const t=clamp(progress),bend=smooth((t-.12)/.88),g=garment(bend),release=smooth(t/.45),settle=smooth((t-.30)/.70);
 gl.viewport(0,0,W,H);gl.clearColor(0,0,0,0);gl.clear(gl.COLOR_BUFFER_BIT);
 part('foot_far');part('shin_far',p=>p,{x:708,y:1120,width:90,height:370});
 part('foot_near');part('shin_near',p=>p,{x:767,y:1120,width:103,height:388});
 const nearS=g.transform([845,870]),farS=g.transform([815,870]);
 const nearW=lerp(lerp([753,1005],[830,1120],release),[790,1268],settle);
 const farW=lerp(lerp([704,983],[750,1090],release),[740,1250],settle);
 const nearE=ik(nearS,nearW,181,176),farE=ik(farS,farW,150,145);
 sleeve(farS,farE,farW,69);
 part('neck',g.transform);
 mesh('robe',24,88,(u,v)=>g.transform([656+245*u,804+504*v],true));
 // Head, hair and cap always share one rigid transform and one identity.
 const hp=[777,787];const headMap=q=>add(g.neck,rotate(sub(q,hp),g.a+25*PI/180*bend));
 for(const n of ['head','hair','ear_near','kufi'])part(n,headMap);
 sleeve(farS,farE,farW,69,[.55,1]);
 hand('hand_near',nearW,mix(0,-1.99,smooth(t/.65)));
 sleeve(nearS,nearE,nearW,80);
 hand('hand_far',farW,mix(0,1.20,smooth(t/.65)));
 lastDiagnostics={progress:t,bendDegrees:90*bend,near:{shoulder:nearS,elbow:nearE,wrist:nearW,reach:length(sub(nearS,nearW)),maxReach:357},far:{shoulder:farS,elbow:farE,wrist:farW,reach:length(sub(farS,farW)),maxReach:295},feet:{near:[825,1497],far:[755,1476]},opacity:1};
}
const slider=document.querySelector('#progress'),play=document.querySelector('#play'),loop=document.querySelector('#loop');
let progress=0,playing=false,direction=1,last=0,hold=0;
function setProgress(v){progress=clamp(v);slider.value=Math.round(progress*1000);draw(progress)}
function playTo(target){direction=target===0?-1:1;playing=true;hold=0;play.textContent='Pause';}
play.onclick=()=>{playing=!playing;if(playing&&progress>=1)direction=-1;play.textContent=playing?'Pause':'Play movement'};
document.querySelector('#reverse').onclick=()=>playTo(0);
slider.oninput=()=>{playing=false;play.textContent='Play movement';setProgress(Number(slider.value)/1000)};
document.querySelector('#transparent').onchange=e=>document.querySelector('#stage').classList.toggle('checker',e.target.checked);
function tick(now){const dt=Math.min(.05,(now-last)/1000||0);last=now;if(playing){if(hold>0){hold-=dt;}else{setProgress(progress+direction*dt/2.4);if(progress===1||progress===0){if(loop.checked){hold=1.1;direction*=-1}else{playing=false;play.textContent='Play movement'}}}}requestAnimationFrame(tick)}
window.guide={setProgress,playTo,diagnostics:()=>lastDiagnostics,ready:true};
setProgress(0);document.querySelector('#status').textContent='Ready';requestAnimationFrame(tick);
