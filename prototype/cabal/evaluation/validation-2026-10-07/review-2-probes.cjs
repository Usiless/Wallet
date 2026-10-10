const M=require('../../model.js'),assert=require('node:assert/strict');
const fresh=()=>{const d=M.seed();d.transactions=[];d.pending=[];d.obligations=[];d.templates=[{id:'probe',name:'Factura dividida',type:'expense',from:'bank',merchant:'Servicio',category:'food',amount:100000,channel:'Transferencia',splits:[{category:'food',amount:40000},{category:'home',amount:60000}],quotas:1,schedule:true,frequency:'monthly',next:M.TODAY,anchor:M.TODAY}];M.processSchedules(d);return d;};
const log=(name,value)=>console.log(name,JSON.stringify(value));
{
 const d=fresh(),id=d.obligations[0].id;
 M.editObligation(d,id,{amount:200000,due:M.TODAY,following:true});
 assert.equal(M.pendingAmount(d,'2026-10-01','2026-10-31'),200000);M.validateTemplate(d,d.templates[0]);
 assert.deepEqual(d.templates[0].splits,[{category:'food',amount:80000},{category:'home',amount:120000}]);
 log('R06 increased + valid template',{pending:200000,splits:d.templates[0].splits});
}
{
 const d=fresh(),id=d.obligations[0].id;
 M.editObligation(d,id,{amount:50000,due:M.TODAY,following:false});
 M.payObligation(d,id,{amount:50000,date:M.TODAY,from:'bank'});
 assert.equal(M.pendingAmount(d,'2026-10-01','2026-10-31'),0);
 log('R06 reduced fully paid',{remaining:M.obligationRemaining(d,d.obligations[0]),pending:0});
}
{
 const d=fresh(),id=d.obligations[0].id;
 M.payObligation(d,id,{amount:90000,date:M.TODAY,from:'bank',carry:true});
 const history=M.clone(d.transactions),r={enabled:true,days:5,time:'10:30',onDue:true};M.saveReminder(d,id,r);
 assert.deepEqual(d.obligations[0].reminder,r);assert.deepEqual(d.obligations[1].reminder,r);assert.deepEqual(d.transactions,history);
 const before=M.clone(d);assert.throws(()=>M.editObligation(d,id,{amount:120000,due:M.TODAY,following:true}),/pagos|trasladados/);assert.deepEqual(d,before);
 log('R05 resolved + carry protected',{selected:d.obligations[0].reminder,remaining:d.obligations.map(o=>M.obligationRemaining(d,o))});
}
{
 const d=fresh(),id=d.obligations[0].id,before=M.clone(d);
 assert.throws(()=>M.editObligation(d,id,{amount:100000,due:d.obligations[1].due,following:false}),/coincide/);assert.deepEqual(d,before);
 log('R06 duplicate atomic rejection',{unchanged:true});
}
{
 const d=fresh(),t=d.templates[0];M.saveTemplate(d,{...M.clone(t),next:'2026-10-31',merchant:'Corregido'},M.TODAY);
 assert.deepEqual(d.obligations.map(o=>o.due),['2026-10-31','2026-11-30']);assert.equal(M.processSchedules(d),0);
 const tx=M.payObligation(d,d.obligations[0].id,{amount:100000,date:M.TODAY,from:'bank'});assert.equal(tx.merchant,'Corregido');
 log('R03/R04 no duplication + merchant',{dates:d.obligations.map(o=>o.due),merchant:tx.merchant});
}
{
 const tx={type:'expense',amount:101,from:'credit',quotas:3,date:M.TODAY,firstInstallmentDate:M.TODAY,splits:[{category:'food',amount:51},{category:'',amount:50}]};
 assert.equal(M.periodAmount(tx,'2026-10-01','2026-10-31','quotas','',true),17);
 log('R02 uncategorized',{total:33,uncategorized:17});
}
{
 const d=fresh();d.obligations=[];d.templates=[];const plan=M.createPlan(d,{name:'Fin de mes',amount:300000,count:3,first:'2027-01-31',from:'bank',category:'home'}),g=d.obligations.filter(o=>o.planId===plan);
 const before=g.map(o=>o.due);M.editObligation(d,g[1].id,{amount:120000,due:g[1].due,following:true});
 const actual=d.obligations.filter(o=>o.planId===plan).map(o=>o.due);assert.equal(actual[2],'2027-03-31');
 log('R07 plan amount-only edit drifts',{before,actual,expected:before,confirmed:actual[2]!==before[2]});
}
{
 const d=fresh();d.obligations=[];d.scheduleRuns=[];d.templates[0].next='2026-10-31';d.templates[0].anchor='2026-10-31';M.processSchedules(d);
 const id=d.obligations[1].id,before=M.clone(d.templates[0]);M.editObligation(d,id,{amount:120000,due:d.obligations[1].due,following:true});
 assert.equal(d.templates[0].next,'2026-12-31');
 log('R07 recurring amount-only edit drifts',{before:{next:before.next,anchor:before.anchor},actual:{next:d.templates[0].next,anchor:d.templates[0].anchor},expectedNext:'2026-12-31'});
}
