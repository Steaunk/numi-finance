const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const base=process.env.NUMI_TEST_URL||'http://127.0.0.1:8773';
 assert.ok(['localhost','127.0.0.1'].includes(new URL(base).hostname));
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||undefined});
 try{
 const context=await browser.newContext({viewport:{width:390,height:844}}), page=await context.newPage(), errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
 await page.route('https://cdn.jsdelivr.net/**',r=>r.abort());
 const request=async(path,method='GET',data)=>{const r=await context.request.fetch(base+path,{method,data});assert.ok(r.ok(),await r.text());return r.json()};
 const trip=await request('/expenses/api/travel/trips/add/','POST',{destination:'Expense links QA',start_date:'2026-10-01',end_date:'2026-10-03'});
 const api=`/expenses/api/travel/trips/${trip.id}/`;
 const items=[{id:'museum',kind:'activity',title:'Museum',category:'Sightseeing',date:'2026-10-01',time:'11:00'}, {id:'park',kind:'activity',title:'Park',category:'Park',date:'2026-10-02'}];
 await request(api+'plan/','PUT',{content:{items},revision:0,mutation_id:'seed'});
 const expense=await request(api+'expenses/add/','POST',{amount:50,currency:'SGD',date:'2026-09-23',category:'Sightseeing',name:'Travel pass',client_id:'pass-'+trip.id});
 await page.goto(base+'/expenses/travel/');await page.locator(`.trip-header[onclick="toggleTrip(${trip.id})"]`).click();
 const root=page.locator(`#planner_${trip.id}`);
 await root.getByRole('tab',{name:'Expenses',exact:true}).click();
 await root.getByRole('button',{name:'Link itinerary',exact:true}).click();
 const d=page.locator('dialog');
 await d.locator('[name=item][value=museum]').check();await d.locator('[name=item][value=park]').check();
 await page.screenshot({path:'/tmp/numi-expense-links-web.png',fullPage:true});
 await d.getByRole('button',{name:'Save links',exact:true}).click();await d.waitFor({state:'detached'});
 let data=await request(api+'expenses/');assert.deepEqual(data.expenses[0].plan_item_ids,['museum','park']);assert.equal(data.expenses.length,1);
 assert.equal(data.expenses[0].amount,50);
 await root.getByRole('button',{name:'2 linked · Edit links',exact:true}).click();await d.locator('[name=item][value=park]').uncheck();await d.getByRole('button',{name:'Save links',exact:true}).click();await d.waitFor({state:'detached'});
 assert.deepEqual((await request(api+'expenses/')).expenses[0].plan_item_ids,['museum']);
 await root.getByRole('tab',{name:'Itinerary',exact:true}).click();
 await root.locator('[data-item=museum] summary').click();await root.locator('[data-item=museum]').getByRole('button',{name:'Edit',exact:true}).click();
 assert.equal(await d.locator('[name=amount]').count(),0);await d.locator('[name=category]').selectOption('Restaurant');await d.getByRole('button',{name:'Save item',exact:true}).click();await d.waitFor({state:'detached'});
 await page.waitForFunction(id=>JSON.parse(localStorage.getItem(`numi.travel.plan.v1.${id}`)).dirty===false,trip.id);
 assert.equal((await request(api+'plan/')).content.items[0].category,'Restaurant');
 // The shared workspace exposes the same editable category and no money fields.
 await page.goto(base+`/expenses/travel/trips/${trip.id}/plan/`);await page.locator('[data-edit=museum]').click();
 await d.locator('[name=category]').selectOption('Sightseeing');await page.screenshot({path:'/tmp/numi-activity-type-web.png',fullPage:true});await d.locator('[type=submit]').click();await d.waitFor({state:'detached'});
 const plan=await request(api+'plan/');assert.equal(plan.content.items[0].category,'Sightseeing');assert.ok(plan.content.items.every(i=>!('amount' in i)));
 await request(api+`expenses/${expense.id}/`,'PUT',{amount:60,currency:'SGD',date:'2026-09-23',category:'Sightseeing',name:'Travel pass'});
 assert.deepEqual((await request(api+'expenses/')).expenses[0].plan_item_ids,['museum']);
 assert.equal((await request(api+'plan/')).content.items.length,2);
 assert.deepEqual(errors,[]);await request(api+'delete/','DELETE');
 console.log('Expense links: many-to-many selection, unlink, totals, independent editing and activity types passed');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
