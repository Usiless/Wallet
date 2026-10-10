const M=require('../../model.js'),assert=require('node:assert/strict');
const log=(name,result)=>console.log(name,JSON.stringify(result));
const clean=()=>{const d=M.seed();d.transactions=[];d.templates=[];d.obligations=[];d.pending=[];d.scheduleRuns=[];return d;};
let cases=0;
for(const first of ['2027-01-31','2028-01-31','2026-08-31','2026-09-30','2026-12-29','2026-10-28'])for(const following of [false,true]){
 const d=clean(),id=M.createPlan(d,{name:'Fechas',amount:1200000,count:12,first,from:'bank',category:'home'}),g=d.obligations.filter(o=>o.planId===id),before=g.map(o=>o.due);
 M.editObligation(d,g[1].id,{amount:120000,due:g[1].due,following});assert.deepEqual(d.obligations.map(o=>o.due),before);cases++;
}
log('R07 amount-only plan matrix',{cases,allDatesPreserved:true});
{
 const d=clean();d.templates=[{id:'r',name:'Servicio',merchant:'Servicio',type:'expense',from:'bank',amount:100000,splits:[{category:'food',amount:40000},{category:'home',amount:60000}],category:'food',channel:'Transferencia',quotas:1,schedule:true,frequency:'monthly',next:'2026-10-31',anchor:'2026-10-31'}];M.processSchedules(d);
 const before=M.clone(d.templates[0]);M.editObligation(d,d.obligations[1].id,{amount:120000,due:'2026-11-30',following:true});assert.equal(d.templates[0].anchor,before.anchor);assert.equal(d.templates[0].next,before.next);assert.equal(M.processSchedules(d),0);M.validateTemplate(d,d.templates[0]);
 const tx=M.payObligation(d,d.obligations[1].id,{amount:90000,date:M.TODAY,from:'cash',carry:true});
 assert.deepEqual(M.parts(tx),[{category:'food',amount:36000},{category:'home',amount:54000}]);assert.equal(M.obligationRemaining(d,d.obligations.find(o=>o.due==='2026-12-31')),150000);
 log('R07/R01/R06 recurring + carry',{anchor:d.templates[0].anchor,next:d.templates[0].next,carriedDue:'2026-12-31',carriedRemaining:150000});
 const backup=M.clone(d),savedRemaining=d.obligations.map(o=>M.obligationRemaining(d,o));M.createPlan(d,{name:'Posterior',amount:80000,count:1,first:M.TODAY,from:'bank',category:'home'});
 const restored=M.restoreBook(d,backup);assert.deepEqual(restored.obligations,backup.obligations);assert.deepEqual(restored.obligations.map(o=>M.obligationRemaining(restored,o)),savedRemaining);assert.equal(M.processSchedules(restored),0);
 log('session snapshot restore model',{obligations:restored.obligations.length,pendingPreserved:true,paidAndCarryPreserved:true,revision:restored.bookRevision});
}
{
 const d=clean(),capture={id:'fresh-known',merchant:'Mercado Verde',alias:'•• 8820',amount:123457,date:M.TODAY};d.settings={wallet:false,permission:false,auto:true};const before=M.clone(d);
 assert.throws(()=>M.ingestWallet(d,capture),/permiso/);assert.deepEqual(d,before);d.settings.wallet=true;assert.throws(()=>M.ingestWallet(d,capture),/permiso/);assert.equal(d.transactions.length,0);
 d.settings.permission=true;const result=M.ingestWallet(d,capture);assert.equal(result.status,'registered');assert.equal(d.transactions.length,1);assert.equal(M.ingestWallet(d,capture).status,'unchanged');assert.equal(d.transactions.length,1);
 const unknown=M.ingestWallet(d,{...capture,id:'unknown',merchant:'Proveedor distinto',amount:222222});assert.equal(unknown.status,'pending');assert.equal(d.transactions.length,1);
 log('Wallet simulated gate + auto + unknown',{withoutPermission:0,knownStatus:result.status,repeatedTransactions:1,unknownStatus:unknown.status});
}
{
 const d=clean(),id=M.createPlan(d,{name:'Pago',amount:100000,count:1,first:'2026-09-30',from:'bank',category:'home'});M.payObligation(d,d.obligations[0].id,{amount:100000,date:M.TODAY,from:'bank'});
 const sept=M.budgetProgress(d,{month:'2026-09',category:'home',amount:200000}),oct=M.budgetProgress(d,{month:'2026-10',category:'home',amount:200000});assert.equal(sept.consumed,0);assert.equal(oct.paid,100000);assert.equal(oct.pending,0);
 log('paid vs due month',{september:sept,october:oct});
}
