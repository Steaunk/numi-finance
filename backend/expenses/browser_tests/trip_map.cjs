const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const base=process.env.NUMI_TEST_URL||'http://127.0.0.1:8770';
 assert.ok(['localhost','127.0.0.1'].includes(new URL(base).hostname));
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH});
 const ctx=await browser.newContext({viewport:{width:390,height:844}});
 // Development checks never download real OSM tiles.
 await ctx.route('https://tile.openstreetmap.org/**',r=>r.fulfill({contentType:'image/png',body:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==','base64')}));
 const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
 const trip=await(await ctx.request.post(base+'/expenses/api/travel/trips/add/',{data:{destination:'Map check',start_date:'2026-10-07',end_date:'2026-10-10'}})).json();
 const api=base+`/expenses/api/travel/trips/${trip.id}/`;
 const content={items:[{id:'me',kind:'person',title:'Me'},{id:'candice',kind:'person',title:'Candice'},
 {id:'hotel',kind:'booking',title:'Hotel',category:'Accommodation',date:'2026-10-07',endDate:'2026-10-09',latitude:'35.3',longitude:'139.5'},
 {id:'museum',kind:'activity',title:'Museum',date:'2026-10-10'},
 {id:'solo',kind:'activity',title:'Solo walk',date:'2026-10-10',latitude:'35.7',longitude:'139.7',participantIds:['me']},
 {id:'saved',kind:'place',title:'Cafe',latitude:'35.6',longitude:'139.6'}]};
 assert.equal((await ctx.request.put(api+'plan/',{data:{content,revision:0,mutation_id:'seed-map'}})).status(),200);
 await page.goto(base+`/expenses/travel/trips/${trip.id}/plan/`);await page.getByRole('button',{name:'Map',exact:true}).click();
 assert.equal(await page.locator('#map-count').textContent(),'2 mapped · 0 to locate');
 await page.locator('#day').selectOption('2026-10-08');assert.equal(await page.locator('#map-count').textContent(),'2 mapped · 0 to locate');
 await page.locator('#day').selectOption('2026-10-10');await page.locator('#person').selectOption('candice');
 assert.equal(await page.locator('#map-count').textContent(),'1 mapped · 1 to locate');
 await page.locator('#map-saved').uncheck();assert.equal(await page.locator('#map-count').textContent(),'0 mapped · 1 to locate');
 await page.getByRole('button',{name:'Locate',exact:true}).click();await page.locator('dialog input').fill('https://www.google.com/maps/place/Museum/@35,139,17z/data=!3d35.69!4d139.72');
 await page.locator('dialog [type=submit]').click();await page.waitForFunction(()=>!document.querySelector('dialog'));
 assert.equal(await page.locator('#map-count').textContent(),'1 mapped · 0 to locate');
 const result=await(await ctx.request.get(api+'plan/')).json();assert.equal(result.content.items.find(i=>i.id==='museum').longitude,'139.72');
 await page.locator('#map-saved').check();await page.locator('.numi-map-pin').first().click();
 assert.match(await page.locator('#map-distance').textContent(),/Distances from Museum/);
 assert.equal(await page.getByRole('link',{name:'Directions from selected ↗'}).count(),1);
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 assert.equal(await page.locator('.leaflet-control-attribution').isVisible(),true);
 await page.screenshot({path:'/tmp/numi-map-phone.png',fullPage:true});
 await page.getByRole('button',{name:'Itinerary',exact:true}).click();await page.getByRole('button',{name:'Map',exact:true}).click();
 assert.equal(await page.locator('.numi-map-pin').count(),2);
 assert.deepEqual(errors,[]);console.log('Map UI: filters, stay overlap, pin save, distances, routes, phone layout and re-entry passed.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
