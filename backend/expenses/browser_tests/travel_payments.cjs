const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async()=>{
 const base=process.env.NUMI_TEST_URL || 'http://127.0.0.1:8765';
 assert.ok(['127.0.0.1','localhost'].includes(new URL(base).hostname));
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH || undefined});
 try {
  const context=await browser.newContext({viewport:{width:390,height:844}});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
  await page.route('**/api/geo/currency/',r=>r.fulfill({json:{currency:'SGD'}}));
  await page.route('**/api/rates/',r=>r.fulfill({json:{rates:{usd:1,sgd:1.34,jpy:150}}}));
  await page.route('https://cdn.jsdelivr.net/**',r=>r.abort());
  await page.goto(base+'/expenses/travel/');
  const api=async(path,method='GET',body)=>page.evaluate(async({path,method,body})=>{
   const response=await fetch(path,{method,headers:{'Content-Type':'application/json','X-CSRFToken':getCsrf()},...(body?{body:JSON.stringify(body)}:{})});
   if(!response.ok)throw new Error(await response.text());return response.json();
  },{path,method,body});
  const waitLedger=async predicate=>{
    const deadline=Date.now()+90000;
    while(Date.now()<deadline){const data=await api(ledgerURL);if(predicate(data))return data;await new Promise(r=>setTimeout(r,200));}
    throw new Error('Timed out waiting for ledger update');
  };
  const trip=await api('/expenses/api/travel/trips/add/','POST',{destination:'One-entry payments QA',start_date:'2026-10-01',end_date:'2026-10-03'});
  await page.reload();await page.locator(`.trip-header[onclick="toggleTrip(${trip.id})"]`).click();
  await page.getByRole('tab',{name:'Bookings',exact:true}).click();
  await page.getByRole('button',{name:'+ Add booking'}).click();
  const dialog=page.locator('dialog');
  await dialog.locator('[name=title]').fill('Tokyo flight');
  await dialog.locator('[name=category]').selectOption('Flight');
  await dialog.locator('[name=date]').fill('2026-10-01');
  await dialog.locator('[name=amount]').fill('250');
  await dialog.locator('[name=currency]').fill('SGD');
  await dialog.locator('[name=paymentStatus]').selectOption('paid');
  await dialog.locator('[name=paidDate]').fill('2026-09-21');
  await page.getByRole('button',{name:'Save item',exact:true}).click();
  const ledgerURL=`/expenses/api/travel/trips/${trip.id}/expenses/`;
  await waitLedger(data=>data.expenses.length===1);
  let ledger=await api(ledgerURL),expense=ledger.expenses[0];
  assert.equal(expense.category,'Transportation');assert.equal(expense.amount,250);
  await page.getByRole('tab',{name:'Expenses',exact:true}).click();
  const row=page.locator('tr.exp-row-clickable').filter({hasText:'Tokyo flight'});
  await row.click();
  await dialog.locator('[name=amount]').fill('275');
  await page.getByRole('button',{name:'Save item',exact:true}).click();
  await waitLedger(data=>data.expenses[0]?.amount===275);
  ledger=await api(ledgerURL);assert.equal(ledger.expenses.length,1);assert.equal(ledger.expenses[0].id,expense.id);
  // Existing independently recorded ticket gains an activity without another payment.
  const ticket=await api(ledgerURL+'add/','POST',{client_id:'ticket-'+trip.id,amount:30,currency:'SGD',date:'2026-09-21',category:'Sightseeing',name:'Museum ticket'});
  await page.evaluate(id=>loadTripDetail(id),trip.id);
  await page.locator('tr.exp-row-clickable').filter({hasText:'Museum ticket'}).getByRole('button',{name:'Add to itinerary',exact:true}).click();
  assert.equal(await dialog.locator('[name=amount]').inputValue(),'30');
  assert.equal(await dialog.locator('[name=title]').inputValue(),'Museum ticket');
  await page.getByRole('button',{name:'Save item',exact:true}).click();
  await waitLedger(data=>data.expenses.find(e=>e.id===ticket.id)?.plan_item_id);
  ledger=await api(ledgerURL);assert.equal(ledger.expenses.length,2);
  const plan=await api(`/expenses/api/travel/trips/${trip.id}/plan/`);
  assert.equal(plan.content.items.find(i=>i.expenseClientId==='ticket-'+trip.id).kind,'activity');
  // An unassigned paid activity can be saved offline and synchronizes once.
  await page.getByRole('tab',{name:'Itinerary',exact:true}).click();
  await context.setOffline(true);
  await page.getByRole('button',{name:'+ Add activity'}).click();
  await dialog.locator('[name=title]').fill('Offline walking tour');
  await dialog.locator('[name=amount]').fill('20');
  await dialog.locator('[name=currency]').fill('SGD');
  await dialog.locator('[name=paymentStatus]').selectOption('paid');
  await dialog.locator('[name=expenseCategory]').selectOption('Sightseeing');
  await page.getByRole('button',{name:'Save item',exact:true}).click();
  await page.getByText('Saved browser changes are retained.',{exact:false}).waitFor();
  await context.setOffline(false);await page.getByRole('button',{name:'Sync now'}).click();
  await waitLedger(data=>data.expenses.length===3);
  await page.getByRole('button',{name:'Sync now'}).click();
  ledger=await api(ledgerURL);assert.equal(ledger.expenses.length,3);
  await page.getByRole('tab',{name:'Expenses',exact:true}).click();
  await page.screenshot({path:'/tmp/numi-itinerary-payments-web.png',fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('Web paid flight, shared edits, existing-ticket activity and offline payment passed');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
