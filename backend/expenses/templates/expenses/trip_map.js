// Kept inside the collaboration workspace closure: all writes use its revision merge.
let tripMap, mapLayer, mapSignature='', mapSelected='', mapSaved=true, currentStops=[];
function mapPoint(lat,lng){if(lat==null||lng==null||String(lat).trim()===''||String(lng).trim()==='')return null;lat=Number(lat);lng=Number(lng);return Number.isFinite(lat)&&Number.isFinite(lng)&&Math.abs(lat)<=90&&Math.abs(lng)<=180?[lat,lng]:null}
function googlePoint(url){try{const u=new URL(url);if(!/^https?:$/.test(u.protocol)||! /^(?:www\.)?google\.(?:com|[a-z]{2}|com\.[a-z]{2}|co\.[a-z]{2})$/.test(u.hostname)||u.pathname.includes('/maps/dir/'))return null;const raw=decodeURIComponent(u.pathname+u.search),matches=[...raw.matchAll(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/g)];if(matches.length===1)return mapPoint(matches[0][1],matches[0][2]);if(matches.length>1)return null;for(const k of ['query','q']){const m=(u.searchParams.get(k)||'').match(/^(?:loc:)?\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/);if(m)return mapPoint(m[1],m[2])}}catch{}return null}
function mapStops(){const stops=[];for(const i of list()){
 if(!['place','activity','booking'].includes(i.kind)||['cancelled','skipped'].includes(i.status)||i.category==='No accommodation needed'||(i.kind==='place'?!mapSaved:!selectedPeople(i)))continue;
 const location=list().find(p=>p.id===i.placeId)||i;
 if(destination&&(i.destinationId||location.destinationId)!==destination&&i.endDestinationId!==destination)continue;
 for(const arrival of [false,...(i.kind==='booking'&&i.category!=='Accommodation'&&(i.endAddress||i.endLatitude)?[true]:[])]){
  const day=(arrival?i.endDate:i.date)||'', time=(arrival?i.endTime:i.time)||'';
  if(selectedDay&&i.kind!=='place'&&(i.category==='Accommodation'?!(i.date<=selectedDay&&i.endDate>=selectedDay):day!==selectedDay))continue;
  const links=(location.links||[]).filter(l=>(l.label==='Arrival map')===arrival);
  const point=mapPoint(location[arrival?'endLatitude':'latitude'],location[arrival?'endLongitude':'longitude'])||links.map(l=>googlePoint(l.url)).find(Boolean)||null;
  stops.push({i,location,arrival,key:i.id+(arrival?'-arrival':'-place'),title:title(i)+(arrival?' · Arrival':''),day,time,point,links});
 }
 }
 const represented=new Set(stops.filter(s=>s.i.kind!=='place').map(s=>s.location.id));
 return stops.filter(s=>s.i.kind!=='place'||!represented.has(s.location.id)).sort((a,b)=>(a.i.kind==='place')-(b.i.kind==='place')||`${a.day} ${a.time||'99:99'}`.localeCompare(`${b.day} ${b.time||'99:99'}`));
}
function renderMap(){
 currentStops=mapStops();const pins=currentStops.filter(s=>s.point),active=pins.find(s=>s.key===mapSelected);
 $('#map-count').textContent=`${pins.length} mapped · ${currentStops.length-pins.length} to locate`;
 $('#map-distance').textContent=active?`Distances from ${active.title} · straight-line, not travel times`:'Select a pin to compare straight-line distances. Open Google Maps for actual routes.';
 $('#map-canvas').hidden=!pins.length;$('#map-empty').hidden=!!pins.length;$('#map-fit').disabled=!pins.length;
 const signature=JSON.stringify([pins.map(s=>[s.key,s.point,s.title]),mapSelected]);
 if(pins.length){
  if(!tripMap){tripMap=L.map('map-canvas',{scrollWheelZoom:false});L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,referrerPolicy:'origin',attribution:'© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap contributors</a>'}).addTo(tripMap).on('tileerror',()=>{$('#map-error').hidden=false});mapLayer=L.layerGroup().addTo(tripMap)}
  requestAnimationFrame(()=>tripMap.invalidateSize());
  if(signature!==mapSignature){const oldPoints=mapSignature?JSON.parse(mapSignature)[0].map(s=>s.slice(0,2)):[];mapLayer.clearLayers();pins.forEach((s,n)=>L.marker(s.point,{title:s.title,icon:L.divIcon({className:'numi-map-pin'+(s.key===mapSelected?' chosen':''),html:String(n+1),iconSize:[32,32],iconAnchor:[16,16]})}).on('click',()=>{mapSelected=s.key;renderMap()}).addTo(mapLayer));if(JSON.stringify(oldPoints)!==JSON.stringify(pins.map(s=>[s.key,s.point])))tripMap.fitBounds(L.latLngBounds(pins.map(s=>s.point)),{padding:[36,36],maxZoom:15});mapSignature=signature}
 }
 $('#cards').innerHTML=currentStops.map((s,index)=>{const pin=pins.indexOf(s),distance=active&&s.point&&active!==s?L.latLng(active.point).distanceTo(s.point)/1000:null;const google=s.point?'https://www.google.com/maps/search/?api=1&query='+encodeURIComponent(s.point.join(',')):'';const route=distance!==null?'https://www.google.com/maps/dir/?api=1&origin='+encodeURIComponent(active.point.join(','))+'&destination='+encodeURIComponent(s.point.join(',')):'';
 return `<article class="card"><div class="row between"><h3>${pin<0?'?':pin+1}. ${esc(s.title)}</h3>${chip(s.i.kind==='place'?'Saved place':personLabel(s.i))}</div><p class="muted">${esc([s.day,s.time].filter(Boolean).join(' '))}${distance!==null?' · '+distance.toFixed(1)+' km away':''}${!s.point?' · Location not set':''}</p><div class="row">${s.point?`<button data-map-select="${index}">Select on map</button><a class="button" href="${esc(google)}" target="_blank" rel="noopener noreferrer">Google Maps ↗</a>${route?`<a class="button" href="${esc(route)}" target="_blank" rel="noopener noreferrer">Directions from selected ↗</a>`:''}`:''}${editable()?`<button data-map-locate="${index}">${s.point?'Change map pin':'Locate'}</button>`:''}</div></article>`}).join('')||'<div class="empty">No places in this view.</div>';
 $('#cards').querySelectorAll('[data-map-select]').forEach(b=>b.onclick=()=>{const s=currentStops[Number(b.dataset.mapSelect)];mapSelected=s.key;renderMap();tripMap.setView(s.point,15)});
 $('#cards').querySelectorAll('[data-map-locate]').forEach(b=>b.onclick=()=>locateMap(currentStops[Number(b.dataset.mapLocate)]));
}
function locateMap(stop){
 const revision=state.revision, original=structuredClone(stop.location);
 const d=modal('Locate '+stop.title,`<form><p>Paste the Google Maps share link for this exact place.</p><label>Google Maps link<input name="url" type="url" required maxlength="3000"></label><p class="error" role="alert"></p><div class="row footer"><button class="primary" type="submit">Locate</button></div></form>`);
 d.querySelector('form').onsubmit=async e=>{e.preventDefault();const b=d.querySelector('[type=submit]');b.disabled=true;try{const url=d.querySelector('input').value.trim();const result=await request('map-preview/',{url});const point=mapPoint(result.latitude,result.longitude);if(!point)throw Error('No exact pin found. Share the place itself, not the map view.');const links=original.links||[];if(!links.some(l=>l.url===url)&&links.length<50)links.push({url,purpose:'Map',label:stop.arrival?'Arrival map':'Google Maps'});await submit([{id:original.id,changes:{[stop.arrival?'endLatitude':'latitude']:String(point[0]),[stop.arrival?'endLongitude':'longitude']:String(point[1]),links}}],revision,()=>d.close())}catch(error){d.querySelector('.error').textContent=error.message}finally{b.disabled=false}};
}
$('#map-saved').onchange=e=>{mapSaved=e.target.checked;renderMap()};
$('#map-fit').onclick=()=>tripMap?.fitBounds(L.latLngBounds(currentStops.filter(s=>s.point).map(s=>s.point)),{padding:[36,36],maxZoom:15});
