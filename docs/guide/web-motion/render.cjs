const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process');
const {chromium}=require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('/Users/saeed/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=__dirname,output=path.join(root,'renders');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:1060}});const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(process.argv.includes('--standalone')?'file://'+path.join(root,'standalone.html'):'http://127.0.0.1:8766');await page.waitForFunction(()=>window.guide?.ready);
 await page.screenshot({path:path.join(output,'browser.png')});
 const stats=await page.evaluate(()=>{const stats=[];for(let i=0;i<=100;i++){guide.setProgress(i/100);stats.push(guide.diagnostics())}return stats});
 const room=await sharp(path.join(root,'assets/room.jpg')).resize(1080,1920,{fit:'fill'}).png().toBuffer();
 const poses=[0,.25,.5,.75,1];for(const t of poses){await page.evaluate(t=>guide.setProgress(t),t);const url=await page.evaluate(()=>document.querySelector('canvas').toDataURL());const data=Buffer.from(url.split(',')[1],'base64');fs.writeFileSync(path.join(output,`pose-${t}-transparent.png`),data);await sharp(room).composite([{input:data}]).png().toFile(path.join(output,`pose-${t}.png`));}
 // Compare rendered feet, rather than trusting the joint declarations.
 const feet=[];for(const t of poses)feet.push(await sharp(path.join(output,`pose-${t}-transparent.png`)).extract({left:650,top:1450,width:230,height:120}).raw().toBuffer());
 const feetIdentical=feet.every(b=>b.equals(feet[0]));
 await page.evaluate(()=>guide.setProgress(0));await page.locator('#loop').uncheck();await page.locator('#play').click();await page.waitForTimeout(550);const advanced=await page.evaluate(()=>guide.diagnostics().progress);await page.locator('#play').click();const paused=await page.evaluate(()=>guide.diagnostics().progress);await page.waitForTimeout(200);const pauseStable=paused===await page.evaluate(()=>guide.diagnostics().progress);
 await page.locator('#reverse').click();await page.waitForTimeout(650);const reversed=await page.evaluate(()=>guide.diagnostics().progress);await page.locator('#progress').fill('500');await page.locator('#progress').dispatchEvent('input');const scrubbed=await page.evaluate(()=>guide.diagnostics().progress);
 await page.locator('#transparent').check();await page.screenshot({path:path.join(output,'transparency-check.png')});await page.locator('#transparent').uncheck();
 const report={renderer:'Chromium / WebGL',samples:stats.length,pageErrors:errors,feetPixelsIdentical:feetIdentical,maxNearReachExcess:Math.max(...stats.map(p=>p.near.reach-p.near.maxReach)),maxFarReachExcess:Math.max(...stats.map(p=>p.far.reach-p.far.maxReach)),controls:{playAdvanced:advanced>0,pauseStable,returnReachedStanding:reversed===0,scrubberAtHalf:scrubbed===.5},scope:'Standing to bowing and back; visual review still required'};
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(output,'mobile.png'),fullPage:true});report.mobileNoHorizontalOverflow=await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth);
 fs.writeFileSync(path.join(output,'verification.json'),JSON.stringify(report,null,2));fs.writeFileSync(path.join(output,'diagnostics.json'),JSON.stringify(stats,null,2));console.log(report);
 if(errors.length||!feetIdentical||report.maxNearReachExcess>0||report.maxFarReachExcess>0||!Object.values(report.controls).every(Boolean)||!report.mobileNoHorizontalOverflow)throw Error('Motion verification failed; see renders/verification.json');
 if(!process.argv.includes('--stills')){
 await page.evaluate(async()=>{window.recordCanvas=document.createElement('canvas');recordCanvas.width=720;recordCanvas.height=1280;window.roomImage=new Image();roomImage.src='assets/room.jpg';await roomImage.decode();});
 const encoder=spawn('/opt/homebrew/bin/ffmpeg',['-y','-loglevel','error','-f','image2pipe','-framerate','30','-i','pipe:0','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',path.join(output,'standing-to-bowing.mp4')]);let encoderError='';encoder.stderr.on('data',d=>encoderError+=d);
 const done=new Promise((resolve,reject)=>encoder.on('close',code=>code===0?resolve():reject(Error(encoderError))));
 for(let frame=0;frame<240;frame++){const time=frame/30;const t=time<1?0:time<3.4?(time-1)/2.4:time<4.6?1:time<7?1-(time-4.6)/2.4:0;const url=await page.evaluate(t=>{guide.setProgress(t);const ctx=recordCanvas.getContext('2d');ctx.drawImage(roomImage,0,0,720,1280);ctx.drawImage(document.querySelector('#guide'),0,0,720,1280);return recordCanvas.toDataURL('image/png');},t);const b=Buffer.from(url.split(',')[1],'base64');if(!encoder.stdin.write(b))await new Promise(r=>encoder.stdin.once('drain',r));if(frame%60===0)console.log(`Video ${frame}/240`);}
 encoder.stdin.end();await done;console.log('Video complete: 8 seconds, 720 × 1280, 30 fps.');
 }
 await browser.close();
 const tiles=[];for(let i=0;i<poses.length;i++){const input=await sharp(path.join(output,`pose-${poses[i]}.png`)).extract({left:180,top:520,width:800,height:1100}).resize(320,440).toBuffer();tiles.push({input,left:i*320,top:0});}
 await sharp({create:{width:1600,height:440,channels:3,background:'#ede4d6'}}).composite(tiles).png().toFile(path.join(output,'movement-sheet.png'));
})();
