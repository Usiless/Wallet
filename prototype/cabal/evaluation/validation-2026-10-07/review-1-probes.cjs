const M=require('../../model.js');const fs=require('node:fs'),vm=require('node:vm');
const app=fs.readFileSync(require.resolve('../../app.js'),'utf8');
const fresh=()=>{const d=M.seed();d.transactions=[];d.pending=[];d.templates=[{id:'probe',name:'Factura dividida',type:'expense',from:'bank',merchant:'Servicio',category:'food',amount:100000,channel:'Transferencia',splits:[{category:'food',amount:40000},{category:'home',amount:60000}],quotas:1,schedule:true,frequency:'monthly',next:M.TODAY,anchor:M.TODAY}];M.processSchedules(d);return d;};
function handler(d,kind,id,fields){const marker="}else if(kind==='"+kind+"'){";const start=app.indexOf(marker)+marker.length;const end=app.indexOf('}else if(',start);const values=new Map(Object.entries(fields));const ctx={M,data:d,modalPayload:{id},values,v:key=>values.get(key),obligations:()=>d.obligations,remaining:o=>M.obligationRemaining(d,o),readReminder:()=>fields.reminder,close:()=>{},render:()=>{},notify:()=>{}};vm.runInNewContext(app.slice(start,end),ctx);}
{
 const d=fresh();const id=d.obligations[0].id;handler(d,'obligation-edit',id,{amount:'200000',due:M.TODAY,following:true});const o=d.obligations[0];
 console.log('R06 handler split edit',JSON.stringify({amount:o.amount,splits:o.splits,remaining:M.obligationRemaining(d,o),pending:M.pendingAmount(d,'2026-10-01','2026-10-31'),templateAmount:d.templates[0].amount,templateSplits:d.templates[0].splits}));
 M.payObligation(d,id,{amount:200000,date:M.TODAY,from:'bank'});console.log('R06 after full payment',JSON.stringify({remaining:M.obligationRemaining(d,d.obligations[0]),pending:M.pendingAmount(d,'2026-10-01','2026-10-31'),parts:M.parts(d.transactions[0])}));
 try{M.validateTemplate(d,d.templates[0]);}catch(e){console.log('R06 future template validation',e.message);}
}
{
 const d=fresh();const id=d.obligations[0].id;handler(d,'obligation-edit',id,{amount:'50000',due:M.TODAY});M.payObligation(d,id,{amount:50000,date:M.TODAY,from:'bank'});
 console.log('R06 reduced paid obligation',JSON.stringify({remaining:M.obligationRemaining(d,d.obligations[0]),pending:M.pendingAmount(d,'2026-10-01','2026-10-31'),pendingParts:M.obligationParts(d,d.obligations[0])}));
}
{
 const d=fresh();const id=d.obligations[0].id;M.payObligation(d,id,{amount:90000,date:M.TODAY,from:'bank',carry:true});handler(d,'reminder',id,{reminder:{enabled:true,days:5,time:'10:30',onDue:true}});
 console.log('R05 resolved reminder',JSON.stringify({selected:d.obligations[0].reminder,next:d.obligations[1].reminder,template:d.templates[0].reminder}));
}
{
 const d=fresh(),t=d.templates[0];const before=M.clone(d.obligations);M.saveTemplate(d,{...M.clone(t),next:'2026-10-31'},'2026-10-06');console.log('R03/R04 retest',JSON.stringify({before:before.map(o=>o.due),after:d.obligations.map(o=>o.due),runs:M.processSchedules(d)}));
}
