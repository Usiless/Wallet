const M=require('../../model.js');
const fs=require('node:fs');const vm=require('node:vm');
const app=fs.readFileSync(require.resolve('../../app.js'),'utf8');
const clean=()=>{const d=M.seed();d.transactions=[];d.templates=[];d.pending=[];return d;};
const tpl=(extra={})=>({id:'probe',name:'Factura',type:'expense',from:'bank',to:'',merchant:'Factura demo',category:'food',amount:100000,channel:'Transferencia',note:'',splits:[],quotas:1,schedule:true,frequency:'monthly',next:'2026-10-06',anchor:'2026-10-06',paused:false,...extra});
{
 const d=clean();d.templates=[tpl({splits:[{category:'food',amount:40000},{category:'home',amount:60000}]})];M.validateTemplate(d,d.templates[0]);M.processSchedules(d);const o=d.obligations[0];
 const before={food:M.pendingAmount(d,'2026-10-01','2026-10-31',{category:'food'}),home:M.pendingAmount(d,'2026-10-01','2026-10-31',{category:'home'})};
 const tx=M.payObligation(d,o.id,{amount:100000,date:M.TODAY,from:'bank'});
 console.log('R01 split scheduled',JSON.stringify({before,paidParts:M.parts(tx),food:M.report(d,'2026-10-01','2026-10-31','quotas',{category:'food'}).net,home:M.report(d,'2026-10-01','2026-10-31','quotas',{category:'home'}).net}));
}
{
 const d=clean();const t=M.save(d,{type:'expense',amount:101,date:M.TODAY,from:'credit',to:'',merchant:'Split',category:'',quotas:3,splits:[{category:'food',amount:51},{category:'',amount:50}],channel:'Tarjeta física'});
 const start=app.indexOf('function rankings('),end=app.indexOf('\n  const menuRow=',start);const rows=[];
 const ctx={M,data:d,ui:{reportCategory:''},reportPeriod:()=>['2026-10-01','2026-10-31'],esc:String,icon:()=>'',empty:()=>'',button:(html,action,id)=>{rows.push({id,html});return html;}};vm.createContext(ctx);vm.runInContext(app.slice(start,end),ctx);const rendered=ctx.rankings(M.report(d,'2026-10-01','2026-10-31'),'Categorías');
 console.log('R02 rank uncategorized',JSON.stringify({total:M.report(d,'2026-10-01','2026-10-31').expenses,rendered,expectedUncategorized:M.installmentSchedule(t)[0].parts.find(p=>p.category==='').amount}));
}
{
 const d=clean();d.templates=[tpl()];M.processSchedules(d);const before=d.obligations.map(o=>o.due);d.templates[0].next='2026-10-07';d.templates[0].anchor='2026-10-07';
 // Handler de plantilla, app.js:301: actualiza importes/referencias pero no fechas existentes.
 for(const o of d.obligations)if(o.templateId==='probe'&&o.due>=M.TODAY&&!o.cancelled&&!M.obligationPayments(d,o.id).length&&!o.carryIn&&!o.carryOut){o.amount=d.templates[0].amount;o.from=d.templates[0].from;o.category=d.templates[0].category;o.name=d.templates[0].name;o.reminder=M.clone(d.templates[0].reminder||M.defaultReminder());}
 M.processSchedules(d);console.log('R03 template date edit',JSON.stringify({before,after:d.obligations.map(o=>o.due),octoberPending:M.pendingAmount(d,'2026-10-01','2026-10-31')}));
}
{
 const d=clean();d.templates=[tpl()];M.processSchedules(d);const old=d.templates[0].merchant;d.templates[0].merchant='Proveedor nuevo';d.templates[0].name='Factura nueva';for(const o of d.obligations)if(o.templateId==='probe'&&o.due>=M.TODAY){o.name=d.templates[0].name;}
 const tx=M.payObligation(d,d.obligations[0].id,{amount:100000,date:M.TODAY,from:'bank'});console.log('R04 template merchant edit',JSON.stringify({template:d.templates[0].merchant,pendingLabel:d.obligations[0].name,paidMerchant:tx.merchant,old}));
}
