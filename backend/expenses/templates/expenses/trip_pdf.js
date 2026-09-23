async function pdfRequest(path, file){
 const body=new FormData();body.append('file',file);
 const response=await fetch(boot.api+path,{method:'POST',headers:{'X-CSRFToken':csrf()},body});
 let data;try{data=await response.json()}catch{throw Error(response.status===413?'PDF must be at most 10 MB.':'Could not read the PDF. Check your connection.')}
 if(!response.ok)throw Error(data.error||'Could not read the PDF.');return data;
}
async function importPdf(){
 if(!editable())return;
 const input=document.createElement('input');input.type='file';input.accept='application/pdf,.pdf';
 input.onchange=async()=>{
  const file=input.files[0];if(!file)return;if(file.size>10*1024*1024){toast('PDF must be at most 10 MB.');return;}
  const d=modal('Read PDF ticket',`<p>${esc(file.name)}</p><p>Reading ticket text… Scanned pages may take a little longer.</p><p class="error" role="alert"></p>`);
  try{const result=await pdfRequest('pdf-preview/',file);if(!d.isConnected)return;d.close();reviewPdf(file,result.items,result.warning)}catch(e){if(d.isConnected)d.querySelector('.error').textContent=e.message}
 };input.click();
}
function reviewPdf(file,items,warning){
 if(!items.length)return;
 const d=modal('Review PDF ticket',`<p>${esc(file.name)}</p><p class="muted">The original PDF will be available to invited trip members. Saving does not record a payment.</p><p>${esc(warning||'Check all dates and local times against the original.')}</p>${items.map((item,n)=>`<div class="history-item"><h3>${esc(item.title||'Ticket')}</h3><p>${esc([item.date,item.time,item.address,item.endAddress].filter(Boolean).join(' · '))}</p><button data-pdf-review="${n}">Review item ${n+1}</button></div>`).join('')}<details><summary>Extracted ticket text</summary><p style="white-space:pre-wrap">${esc(items[0].notes)}</p></details>`);
 d.querySelectorAll('[data-pdf-review]').forEach(b=>b.onclick=()=>{
  const n=Number(b.dataset.pdfReview),item=items[n];d.close();
  const fields={};for(const key of ['title','category','date','endDate','time','endTime','timezone','endTimezone','address','endAddress','notes','confirmation'])if(item[key])fields[key]=item[key];
  const incoming=newItem(item.kind||'activity',fields), normalize=s=>String(s||'').toLowerCase().replace(/[^a-z0-9\u3400-\u9fff]/g,'');
  const existing=list().find(i=>{const a=normalize(i.title),b=normalize(incoming.title);return i.kind==='activity'&&incoming.kind==='activity'&&i.date&&i.date===incoming.date&&(i.time||'')===(incoming.time||'')&&a&&b&&(a===b||(a.length>=8&&b.includes(a))||(b.length>=8&&a.includes(b)))});
  const open=value=>editor(value,{file,onSaved:()=>reviewPdf(file,items.filter((_,i)=>i!==n),warning)});
  if(existing){
    const match=modal('Already in your trip?',`<p>${esc(existing.title)} is already saved for the same date and time.</p><div class="row"><button data-update>Update existing</button><button data-separate>Add separately</button><button data-cancel>Cancel</button></div>`);
    match.querySelector('[data-update]').onclick=()=>{match.close();open({...existing,...fields,id:existing.id,kind:existing.kind,status:existing.status})};
    match.querySelector('[data-separate]').onclick=()=>{match.close();open(incoming)};
    match.querySelector('[data-cancel]').onclick=()=>{match.close();reviewPdf(file,items,warning)};
  }else open(incoming);
 });
}
