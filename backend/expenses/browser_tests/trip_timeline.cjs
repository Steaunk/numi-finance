const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const base=process.env.NUMI_TEST_URL||'http://127.0.0.1:8772';
 assert.ok(['localhost','127.0.0.1'].includes(new URL(base).hostname));
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||undefined});
 const context=await browser.newContext({viewport:{width:390,height:844}}), p=await context.newPage();
 const errors=[];p.on('pageerror',e=>errors.push(e.message));
 const trip=await(await context.request.post(base+'/expenses/api/travel/trips/add/',{data:{destination:'Tokyo',start_date:'2026-10-06',end_date:'2026-10-12'}})).json();
 const api=base+`/expenses/api/travel/trips/${trip.id}/`;
 const items=[{id:'candice',kind:'person',title:'Candice'},{id:'me',kind:'person',title:'Steaunk'},
 {id:'connection',kind:'booking',category:'Flight',title:'Candice Flight · SIN → CAN',participantIds:['candice'],date:''},
 {id:'flight',kind:'booking',category:'Flight',title:'CAN → NRT',date:'2026-10-06',time:'05:00',endDate:'2026-10-06',endTime:'13:40',participantIds:['candice']},
 {id:'dinner',kind:'activity',title:'Chinya',date:'2026-10-06',time:'19:00'},
 {id:'kamakura',kind:'destination',title:'Kamakura',date:'2026-10-07',endDate:'2026-10-09'},
 {id:'hotel',kind:'booking',category:'Accommodation',title:'Kamakura Price Hotel',date:'2026-10-07',endDate:'2026-10-09',destinationId:'kamakura',notes:'Hotel details stay available to invited travellers'},
 {id:'museum',kind:'activity',title:'YAYOI KUSAMA MUSEUM',date:'2026-10-10',time:'11:00'},
 {id:'return',kind:'booking',category:'Flight',title:'HND → SIN',date:'2026-10-12',time:'02:20',participantIds:['candice']}];
 assert.equal((await context.request.put(api+'plan/',{data:{content:{items},revision:0,mutation_id:'seed-timeline'}})).status(),200);
 await p.goto(base+`/expenses/travel/trips/${trip.id}/plan/`);await p.locator('#timeline-anytime').waitFor();
 assert.equal(await p.locator('.timeline-day').count(),8);
 assert.equal(await p.locator('#day-label').isVisible(),false);
 assert.equal(await p.locator('#timeline-anytime h3').innerText(),'Candice Flight · SIN → CAN');
 assert.deepEqual(await p.locator('#timeline-2026-10-06 h3').allTextContents(),['CAN → NRT','Chinya']);
 assert.equal(await p.locator('#timeline-2026-10-08 .stay-card h3').innerText(),'Kamakura Price Hotel');
 await p.locator('#timeline-2026-10-08 summary').click();assert.ok(await p.getByText('Hotel details stay available to invited travellers').nth(1).isVisible());
 await p.locator('[data-jump="2026-10-10"]').click();await p.waitForTimeout(1000);
 assert.equal(await p.locator('.timeline-day').count(),8);
 assert.ok((await p.locator('#timeline-2026-10-10').boundingBox()).y<600);
 await p.locator('#timeline-2026-10-10 [data-add]').click();assert.equal(await p.locator('dialog [name=date]').inputValue(),'2026-10-10');await p.locator('dialog [data-close]').click();
 await p.locator('#timeline-anytime [data-add]').click();assert.equal(await p.locator('dialog [name=date]').inputValue(),'');await p.locator('dialog [data-close]').click();
 await p.locator('[data-edit=connection]').click();await p.locator('dialog [name=title]').fill('Connection · date to decide');await p.locator('dialog [type=submit]').click();await p.waitForFunction(()=>!document.querySelector('dialog'));
 const plan=await(await context.request.get(api+'plan/')).json();assert.equal(plan.content.items.find(i=>i.id==='connection').date,'');
 await p.locator('#person').selectOption('me');assert.equal(await p.locator('[data-edit=connection]').count(),0);assert.equal(await p.locator('[data-edit=dinner]').count(),1);assert.equal(await p.locator('[data-edit=return]').count(),0);
 await p.locator('#person').selectOption('');await p.locator('#destination').selectOption('kamakura');assert.equal(await p.locator('[data-edit=dinner]').count(),0);assert.equal(await p.locator('[data-edit=hotel]').count(),3);
 await p.locator('#destination').selectOption('');
 assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await p.screenshot({path:'/tmp/numi-timeline-phone.png',fullPage:true});
 await p.setViewportSize({width:1200,height:1000});await p.screenshot({path:'/tmp/numi-timeline-desktop.png',fullPage:true});
 assert.deepEqual(errors,[]);await browser.close();console.log('PASS: continuous days, Anytime flight editing, jump navigation, per-day creation, stay details, people/destination filters, narrow layout');
})().catch(e=>{console.error(e);process.exit(1)});
