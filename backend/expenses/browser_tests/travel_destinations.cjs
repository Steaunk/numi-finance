const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const base=process.env.NUMI_TEST_URL || 'http://127.0.0.1:8767';
 assert.ok(['127.0.0.1','localhost'].includes(new URL(base).hostname));
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH || undefined});
 try {
  const context=await browser.newContext({viewport:{width:390,height:844}}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
  await page.route('**/api/geo/currency/',r=>r.fulfill({json:{currency:'SGD'}}));
  await page.route('**/api/rates/',r=>r.fulfill({json:{rates:{usd:1,sgd:1.34}}}));
  await page.route('https://cdn.jsdelivr.net/**',r=>r.abort());
  await page.goto(base+'/expenses/travel/');
  const api=(path,method='GET',body)=>page.evaluate(async({path,method,body})=>{
   const r=await fetch(path,{method,headers:{'Content-Type':'application/json','X-CSRFToken':getCsrf()},...(body?{body:JSON.stringify(body)}:{})});
   if(!r.ok)throw new Error(await r.text());return r.json();
  },{path,method,body});
  const trip=await api('/expenses/api/travel/trips/add/','POST',{destination:'Japan multi-city QA',start_date:'2026-10-01',end_date:'2026-10-03'});
  const planURL=`/expenses/api/travel/trips/${trip.id}/plan/`,ledgerURL=`/expenses/api/travel/trips/${trip.id}/expenses/`;
  const until=async(predicate,path=planURL)=>{for(let n=0;n<300;n++){const data=await api(path);if(predicate(data))return data;await new Promise(r=>setTimeout(r,200));}throw new Error('Sync timeout');};
  await page.reload();await page.locator(`.trip-header[onclick="toggleTrip(${trip.id})"]`).click();
  const root=page.locator(`#planner_${trip.id}`),dialog=page.locator('dialog');
  const route=root.locator('.plan-route > details');
  for(const [name,start,end] of [['Tokyo','2026-10-01','2026-10-02'],['Kyoto','2026-10-02','2026-10-03'],['Osaka','2026-10-03','2026-10-03']]) {
   if(!await root.getByRole('button',{name:'+ Add destination',exact:true}).isVisible())await route.locator(':scope > summary').click();
   await root.getByRole('button',{name:'+ Add destination',exact:true}).click();
   await dialog.locator('[name=title]').fill(name);await dialog.locator('[name=date]').fill(start);await dialog.locator('[name=endDate]').fill(end);
   await dialog.getByRole('button',{name:'Save item',exact:true}).click();await until(p=>p.content.items.some(i=>i.kind==='destination'&&i.title===name));
  }
  let plan=await api(planURL);const ds=Object.fromEntries(plan.content.items.filter(i=>i.kind==='destination').map(i=>[i.title,i.id]));
  if(!await route.locator('.plan-card').filter({hasText:'Osaka'}).isVisible())await route.locator(':scope > summary').click();
  const osaka=route.locator('.plan-card').filter({hasText:'Osaka'});await osaka.locator('summary').click();await osaka.getByRole('button',{name:'↑ Move up'}).click();
  await until(p=>p.content.items.filter(i=>i.kind==='destination')[1].title==='Osaka');
  await root.locator('[data-filter=destination]').selectOption(ds.Kyoto);
  await root.getByRole('tab',{name:'Places',exact:true}).click();await root.getByRole('button',{name:'+ Add place'}).click();
  await dialog.locator('[name=title]').fill('Kyoto dinner');assert.equal(await dialog.locator('[name=destinationId]').inputValue(),ds.Kyoto);
  await dialog.locator('[name=category]').selectOption('Restaurant');await dialog.getByRole('button',{name:'Save item',exact:true}).click();
  await until(p=>p.content.items.some(i=>i.title==='Kyoto dinner'));
  const restaurant=root.locator('.plan-panel .plan-card').filter({hasText:'Kyoto dinner'});await restaurant.locator('summary').click();await restaurant.getByRole('button',{name:'Add to itinerary'}).click();
  assert.equal(await dialog.locator('[data-destination-field]').isVisible(),false);
  await dialog.getByRole('button',{name:'Save item',exact:true}).click();
  let planned=await until(p=>p.content.items.some(i=>i.kind==='activity'&&i.placeId));
  const dinner=planned.content.items.find(i=>i.kind==='activity'&&i.placeId);
  await api(ledgerURL+'add/','POST',{amount:20,currency:'SGD',date:'2026-10-02',category:'Food & Drinks',name:'Kyoto dinner',plan_item_ids:[dinner.id]});
  await root.getByRole('tab',{name:'Bookings',exact:true}).click();
  for(const [name,category,amount] of [['Kyoto hotel','Accommodation','200'],['Tokyo to Kyoto train','Train','50']]) {
   await root.getByRole('button',{name:'+ Add booking'}).click();await dialog.locator('[name=title]').fill(name);await dialog.locator('[name=category]').selectOption(category);
   await dialog.locator('[name=date]').fill('2026-10-02');
   if(category==='Accommodation')await dialog.locator('[name=endDate]').fill('2026-10-03');
   else {await dialog.locator('[name=destinationId]').selectOption(ds.Tokyo);await dialog.locator('[name=endDestinationId]').selectOption(ds.Kyoto);}
   await dialog.getByRole('button',{name:'Save item',exact:true}).click();
   const planned=await until(p=>p.content.items.some(i=>i.title===name));
   await api(ledgerURL+'add/','POST',{amount:Number(amount),currency:'SGD',date:'2026-10-02',category:category==='Accommodation'?'Accommodation':'Transportation',name,plan_item_ids:[planned.content.items.find(i=>i.title===name).id]});
  }
  await page.evaluate(id=>loadTripDetail(id),trip.id);
  await root.getByRole('tab',{name:'Expenses',exact:true}).click();
  await root.locator('[data-expense-filter]').selectOption(ds.Kyoto);
  assert.equal(await root.locator('tr.exp-row-clickable:visible').count(),2);
  assert.match(await root.locator('[data-expense-total]').textContent(),/220\.00/);
  await root.locator('[data-expense-filter]').selectOption('__transfers__');
  assert.equal(await root.locator('tr.exp-row-clickable:visible').count(),1);
  assert.match(await root.locator('[data-expense-total]').textContent(),/50\.00/);
  await page.screenshot({path:'/tmp/numi-multicity-web.png',fullPage:true});
  // Removing a destination offline keeps every itinerary item and payment.
  await context.setOffline(true);
  if(!await route.locator('.plan-card').filter({hasText:'Kyoto'}).isVisible())await route.locator(':scope > summary').click();
  const kyoto=route.locator('.plan-card').filter({hasText:'Kyoto'});await kyoto.locator('summary').click();await kyoto.getByRole('button',{name:'Delete',exact:true}).click();
  await context.setOffline(false);await root.getByRole('button',{name:'Sync now',exact:true}).click();
  await until(p=>!p.content.items.some(i=>i.id===ds.Kyoto));
  assert.equal((await api(ledgerURL)).expenses.length,3);
  plan=await api(planURL);assert.ok(plan.content.items.some(i=>i.title==='Kyoto hotel'));
  assert.ok(plan.content.items.every(i=>i.destinationId!==ds.Kyoto&&i.endDestinationId!==ds.Kyoto));
  await page.reload();await page.locator(`.trip-header[onclick="toggleTrip(${trip.id})"]`).click();
  await root.locator('[data-filter=destination] option').filter({hasText:'Osaka'}).waitFor({state:'attached'});
  assert.deepEqual(errors,[]);
  console.log('Multi-city destinations, ordering, inherited place, transfer spending and offline deletion passed');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
