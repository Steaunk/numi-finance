const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const base=process.env.NUMI_TEST_URL||'http://127.0.0.1:8768';
 assert.ok(['localhost','127.0.0.1'].includes(new URL(base).hostname),'Local preview only');
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||undefined});
 const owner=await browser.newContext({viewport:{width:1200,height:1000}}), guest=await browser.newContext({viewport:{width:390,height:844}}), viewer=await browser.newContext();
 const p=await owner.newPage(), g=await guest.newPage(), v=await viewer.newPage();
 const errors=[];for(const page of [p,g,v]){page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());}
 const trip=await (await owner.request.post(base+'/expenses/api/travel/trips/add/',{data:{destination:'Tokyo · Together',start_date:'2026-10-06',end_date:'2026-10-12'}})).json();
 const api=base+`/expenses/api/travel/trips/${trip.id}/`, shared=base+`/travel/shared/${trip.id}/`;
 const content={items:[{id:'me',kind:'person',title:'Me'},{id:'nyt',kind:'person',title:'NYT'},
  {id:'museum',kind:'activity',title:'草间弥生',date:'2026-10-06',notes:'Shared museum visit',links:[]},
  {id:'flight',kind:'booking',title:'NYT · CAN → NRT',category:'Flight',date:'2026-10-06',endDate:'2026-10-06',time:'05:00',endTime:'13:40',timezone:'Asia/Shanghai',endTimezone:'Asia/Tokyo',participantIds:['nyt'],links:[]}]};
 assert.equal((await owner.request.put(api+'plan/',{data:{content,revision:0,mutation_id:'seed-collab'}})).status(),200);
 await p.goto(base+`/expenses/travel/trips/${trip.id}/plan/`);await p.getByRole('heading',{name:'Tokyo · Together'}).waitFor();
 await p.getByRole('button',{name:'Invite',exact:true}).click();await p.locator('dialog [name=name]').fill('NYT');await p.locator('dialog [name=person_id]').selectOption('nyt');await p.getByRole('button',{name:'Create invitation'}).click();
 const invite=p.locator('dialog [data-created] input');await invite.waitFor();const inviteURL=await invite.inputValue();
 await p.locator('dialog [data-close]').click();await g.goto(inviteURL);await g.getByRole('heading',{name:'Tokyo · Together'}).waitFor();assert.equal(new URL(g.url()).hash,'');
 await g.locator('#person').selectOption('me');assert.equal(await g.locator('article').count(),1);assert.equal(await g.locator('article h3').innerText(),'草间弥生');
 await g.locator('#person').selectOption('nyt');assert.equal(await g.locator('article').count(),2);
 await g.screenshot({path:'/tmp/numi-collab-phone.png',fullPage:true});await p.screenshot({path:'/tmp/numi-collab-desktop.png',fullPage:true});
 // Independent fields on the same item merge, even with an open stale editor.
 await p.locator('[data-edit=museum]').click();await p.locator('dialog [name=notes]').fill('Meet at the entrance');
 await g.locator('[data-edit=museum]').click();await g.locator('dialog [name=time]').fill('11:00');await g.locator('dialog [type=submit]').click();await g.waitForFunction(()=>!document.querySelector('dialog'));
 await p.locator('dialog [type=submit]').click();await p.waitForFunction(()=>!document.querySelector('dialog'));
 let plan=await(await owner.request.get(api+'plan/')).json(), item=plan.content.items.find(i=>i.id==='museum');assert.equal(item.notes,'Meet at the entrance');assert.equal(item.time,'11:00');
 // Truly simultaneous requests serialize and merge their disjoint fields.
 const rev=plan.revision;
 const writes=await Promise.all([owner.request.post(api+'collaboration/data/',{data:{revision:rev,mutation_id:'parallel-owner',operations:[{id:'museum',changes:{address:'Museum entrance'}}]}}),
   g.evaluate(async({rev})=>{const token=document.cookie.split('; ').find(c=>c.startsWith('csrftoken='))?.split('=')[1];const r=await fetch(location.pathname+'data/',{method:'POST',headers:{'Content-Type':'application/json','X-CSRFToken':token},body:JSON.stringify({revision:rev,mutation_id:'parallel-guest',operations:[{id:'flight',changes:{address:'CAN airport'}}]})});return r.status},{rev})]);
 assert.equal(writes[0].status(),200);assert.equal(writes[1],200);
 await p.reload();await p.locator('[data-edit=museum]').waitFor();
 // One edit is NYT-only, other unchanged arrangements remain Everyone.
 await p.locator('[data-edit=museum]').click();await p.locator('dialog [name=everyone]').uncheck();await p.locator('dialog [name=person][value=nyt]').check();await p.locator('dialog [type=submit]').click();await p.waitForFunction(()=>!document.querySelector('dialog'));
 plan=await(await owner.request.get(api+'plan/')).json();assert.deepEqual(plan.content.items.find(i=>i.id==='museum').participantIds,['nyt']);
 // Concurrent changes to title require a field-level choice.
 await g.reload();await g.locator('[data-edit=museum]').waitFor();await p.locator('[data-edit=museum]').click();await g.locator('[data-edit=museum]').click();
 await g.locator('dialog [name=title]').fill('Museum with NYT');await g.locator('dialog [type=submit]').click();await g.waitForFunction(()=>!document.querySelector('dialog'));
 await p.locator('dialog [name=title]').fill('Museum with me');await p.locator('dialog [name=notes]').fill('Bring tickets');await p.locator('dialog [type=submit]').click();
 await p.getByRole('heading',{name:'Review overlapping changes'}).waitFor();await p.getByRole('button',{name:'Save selected changes'}).click();await p.waitForFunction(()=>!document.querySelector('dialog'));
 plan=await(await owner.request.get(api+'plan/')).json();item=plan.content.items.find(i=>i.id==='museum');assert.equal(item.title,'Museum with NYT');assert.equal(item.notes,'Bring tickets');
 // History restores one arrangement, preserving the flight.
 await p.getByRole('button',{name:'History',exact:true}).click();const oldest=p.locator('dialog .history-item').filter({has:p.locator('strong')}).filter({has:p.locator('[data-id=museum]')}).last();await oldest.locator('summary').click();await oldest.locator('[data-id=museum]').click();await p.waitForFunction(()=>!document.querySelector('dialog'));
 plan=await(await owner.request.get(api+'plan/')).json();assert.equal(plan.content.items.find(i=>i.id==='museum').title,'草间弥生');assert.ok(plan.content.items.find(i=>i.id==='flight'));
 const vi=await(await owner.request.post(api+'collaboration/invites/',{data:{name:'Viewer',role:'viewer'}})).json();await v.goto(vi.url);await v.getByRole('heading',{name:'Tokyo · Together'}).waitFor();assert.equal(await v.locator('[data-edit]').count(),0);assert.equal(await v.locator('[data-add]').count(),0);
 const invites=(await(await owner.request.get(api+'collaboration/invites/')).json()).invites;await owner.request.delete(api+'collaboration/invites/',{data:{id:invites.find(i=>i.name==='NYT').id}});await g.reload();await g.getByText('Open a valid invitation to access this trip.').waitFor();assert.equal(await g.locator('#workspace').isVisible(),false);
 assert.deepEqual(errors,[]);await browser.close();console.log('PASS: participants, shared access, disjoint edits, conflicts, history, viewer, revocation, mobile/desktop');
})().catch(e=>{console.error(e);process.exit(1)});
