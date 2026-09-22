function matchesFilters(i){return selectedPeople(i)&&(!destination||(i.destinationId||list().find(p=>p.id===i.placeId)?.destinationId)===destination||i.endDestinationId===destination)}
function renderTimeline(){
  const days=dates(), arrangements=list().filter(i=>['activity','booking'].includes(i.kind)&&matchesFilters(i));
  const label=day=>new Date(day+'T12:00:00Z').toLocaleDateString('en-GB',{weekday:'long',day:'numeric',month:'short',timeZone:'UTC'});
  const jump=day=>`<button data-jump="${esc(day)}">${day?esc(new Date(day+'T12:00:00Z').toLocaleDateString('en-GB',{day:'numeric',month:'short',timeZone:'UTC'})):'Anytime'}</button>`;
  $('#cards').innerHTML=`<nav class="timeline-jump" aria-label="Jump to a day">${['',...days].map(jump).join('')}</nav>`+['',...days].map(day=>{
    const stays=day?arrangements.filter(i=>i.kind==='booking'&&!['cancelled','skipped'].includes(i.status)&&((i.category==='Accommodation'&&i.date<=day&&i.endDate>day)||(i.category==='No accommodation needed'&&i.date===day))):[];
    const rows=arrangements.filter(i=>!day?!i.date:i.kind==='activity'?i.date===day:i.category==='Accommodation'?i.endDate===day:i.category!=='No accommodation needed'&&(i.date===day||i.endDate===day));
    const time=i=>!day?'':i.endDate===day&&i.date!==day?i.endTime:i.time;
    rows.sort((a,b)=>(time(a)||'99:99').localeCompare(time(b)||'99:99'));
    const cities=list().filter(i=>i.kind==='destination'&&!['cancelled','skipped'].includes(i.status)&&i.date<=day&&i.endDate>=day).map(i=>i.title);
    const number=day?Math.round((Date.parse(day)-Date.parse(state.trip.start_date))/86400000)+1:0;
    return `<section class="timeline-day" id="timeline-${day||'anytime'}" data-day="${esc(day)}"><div class="row between"><div><span class="eyebrow">${day?number>0?'Day '+number:'Before departure':'Unscheduled'}</span><h2>${day?esc(label(day)):'Anytime'}</h2>${cities.length?`<span class="muted">${esc(cities.join(' / '))}</span>`:''}</div>${editable()?`<button data-add="activity" data-day="${esc(day)}">＋ Add plan</button>`:''}</div>`+
      rows.map(i=>`<div class="timeline-row"><span class="time">${esc(time(i)||'Anytime')}</span>${arrangementCard(i,time(i),i.category==='Accommodation'?'Check-out':'')}</div>`).join('')+
      stays.map(i=>`<div class="timeline-row"><span class="time">${esc(i.date===day?i.time||'Anytime':'Stay')}</span>${arrangementCard(i,i.date===day?i.time:'Stay',i.category==='No accommodation needed'?'Overnight travel':i.date===day?'Check-in':'Your stay').replace('class="card"','class="card stay-card"')}</div>`).join('')+
      (!rows.length&&!stays.length?`<p class="muted">${day?'No arrangements yet.':'Plans without a date live here.'}</p>`:'')+'</section>';
  }).join('');
}
