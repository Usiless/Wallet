const {test}=require('node:test');
const assert=require('node:assert/strict');
const M=require('./model.js');
const expense=(extra={})=>({type:'expense',amount:100000,date:M.TODAY,from:'bank',to:'',merchant:'Mercado Verde',category:'food',quotas:1,splits:[],channel:'Tarjeta física',note:'',...extra});

test('el libro inicial reconcilia saldos, patrimonio y reportes',()=>{
  const d=M.seed();assert.equal(M.balance(d,'bank'),10510000);assert.equal(M.balance(d,'credit'),905000);assert.equal(M.netWorth(d),14462000);
  const r=M.report(d,'2026-10-01','2026-10-31');assert.equal(r.expenses,2033000);assert.equal(r.refunds,60000);assert.equal(r.net,1973000);assert.equal(r.income,4200000);
});
test('gasto nuevo y editar conservan identidad y recalculan efectos',()=>{
  const d=M.seed();const t=M.save(d,expense());assert.equal(M.balance(d,'bank'),10410000);
  const edited=M.save(d,{...t,amount:120000});assert.equal(edited.id,t.id);assert.equal(M.balance(d,'bank'),10390000);
});
test('transferencias y pagos cambian saldos sin duplicar gastos',()=>{
  const d=M.seed();const before=M.report(d,'2026-10-01','2026-10-31').net,worth=M.netWorth(d);
  M.save(d,expense({type:'transfer',from:'bank',to:'saving',category:'',merchant:'',channel:'Transferencia'}));
  M.save(d,expense({type:'payment',from:'bank',to:'credit',category:'',merchant:'',channel:'Transferencia'}));
  assert.equal(M.balance(d,'credit'),805000);assert.equal(M.report(d,'2026-10-01','2026-10-31').net,before);assert.equal(M.netWorth(d),worth);
});
test('división validada y cuota conserva exactamente los totales de cada categoría',()=>{
  const d=M.seed();assert.throws(()=>M.save(d,expense({splits:[{category:'food',amount:50}]})),/sumar/);
  const t=M.save(d,expense({amount:101,from:'credit',quotas:3,splits:[{category:'food',amount:51},{category:'home',amount:50}]}));
  for(const [category,total] of [['food',51],['home',50]])assert.equal([0,1,2].reduce((sum,i)=>{const month=M.addMonths('2026-10-01',i);const end=new Date(new Date(M.addMonths(month,1))-86400000).toISOString().slice(0,10);return sum+M.periodAmount(t,month,end,'quotas',category);},0),total);
});
test('importe total por compras y cuota por período no son equivalentes',()=>{
  const d=M.seed();const t=d.transactions.find(t=>t.id==='computer');assert.equal(M.periodAmount(t,'2026-10-01','2026-10-31','purchases'),0);assert.equal(M.periodAmount(t,'2026-10-01','2026-10-31','quotas'),200000);
});
test('devolución parcial reduce deuda, afecta su fecha y no cambia cuotas futuras',()=>{
  const d=M.seed();const debt=M.balance(d,'credit');M.refund(d,'computer',100000,M.TODAY);assert.equal(M.balance(d,'credit'),debt-100000);assert.equal(M.refundable(d,'computer'),1040000);assert.equal(M.periodAmount(d.transactions.find(t=>t.id==='computer'),'2026-11-01','2026-11-30'),200000);
  assert.throws(()=>M.refund(d,'computer',2000000,M.TODAY),/supera/);assert.throws(()=>M.refund(d,'computer',100,'2026-09-01'),/fecha/);
});
test('eliminación y deshacer respetan devoluciones y límite vigente',()=>{
  const d=M.seed();assert.throws(()=>M.deleteTransaction(d,'computer'),/devoluciones/);M.deleteTransaction(d,'refund');M.deleteTransaction(d,'computer');assert.throws(()=>M.restoreTransaction(d,'refund'),/No se puede/);M.restoreTransaction(d,'computer');M.restoreTransaction(d,'refund');assert.equal(M.balance(d,'credit'),905000);
});
test('no restaurar compra capturada si otro registro de esa propuesta ya existe',()=>{
  const d=M.seed();const first=M.save(d,expense({candidate:'test'}));M.deleteTransaction(d,first.id);M.save(d,expense({candidate:'test'}));assert.throws(()=>M.restoreTransaction(d,first.id),/otro registro/);
});
test('editar por debajo de devoluciones y cambiar tipo están bloqueados',()=>{
  const d=M.seed();const t=d.transactions.find(t=>t.id==='computer');assert.throws(()=>M.save(d,{...t,amount:50000}),/devoluciones/);assert.throws(()=>M.save(d,{...t,type:'transfer',to:'bank',channel:'Transferencia'}),/tipo/);
});
test('canales válidos y cuentas distintas se exigen en el modelo',()=>{
  const d=M.seed();assert.throws(()=>M.save(d,expense({from:'cash'})),/canal/);assert.throws(()=>M.save(d,expense({from:'credit',channel:'Transferencia'})),/canal/);assert.throws(()=>M.save(d,expense({type:'transfer',to:'bank',channel:'Transferencia'})),/diferentes/);
});
test('archivada se conserva al editar una referencia histórica y se rechaza en un registro nuevo',()=>{
  const d=M.seed();d.accounts.find(a=>a.id==='bank').archived=true;assert.throws(()=>M.save(d,expense()),/activa/);const t=d.transactions.find(t=>t.id==='rent');M.save(d,{...t,amount:1400000});assert.equal(d.transactions.find(t=>t.id==='rent').amount,1400000);
});
test('preferencia del comercio se aprende, se elimina sin categoría y no se reemplaza al dividir',()=>{
  const d=M.seed();M.save(d,expense({category:'home'}));assert.equal(d.merchants[0].category,'home');M.save(d,expense({splits:[{category:'food',amount:100000}]}));assert.equal(d.merchants[0].category,'home');M.save(d,expense({category:''}));assert.equal(d.merchants[0].category,'');
});
test('programación conserva día de fin de mes y año bisiesto',()=>{
  const t={anchor:'2026-01-31',next:'2026-01-31',frequency:'monthly'};M.advance(t);assert.equal(t.next,'2026-02-28');M.advance(t);assert.equal(t.next,'2026-03-31');
  const yearly={anchor:'2024-02-29',next:'2024-02-29',frequency:'yearly'};for(let i=0;i<4;i++)M.advance(yearly);assert.equal(yearly.next,'2028-02-29');
});
test('programados preparan pendientes, recuperan atrasos y no descuentan ni duplican',()=>{
  const d=M.seed('scheduled'),before=M.balance(d,'credit'),txCount=d.transactions.length;
  assert.equal(M.processSchedules(d),2);
  const planned=d.obligations.filter(o=>o.templateId==='tpl-stream');assert.equal(planned.length,2);
  assert.equal(M.balance(d,'credit'),before);assert.equal(d.transactions.length,txCount);
  planned[0].cancelled=true;const tpl=d.templates.find(t=>t.id==='tpl-stream');tpl.next=planned[0].due;
  assert.equal(M.processSchedules(d),0);assert.equal(d.obligations.filter(o=>o.templateId==='tpl-stream').length,2);
});
test('conflicto y cuota inválida no registran un programado',()=>{
  const d=M.seed();const t=d.templates[1];t.next='2026-10-02';assert.equal(M.processSchedules(d),0);assert.match(t.pending,/coincidencia/);t.pending=null;t.merchant='Compra distinta';t.quotas=2;t.from='bank';assert.equal(M.processSchedules(d),0);assert.match(t.pending,/cuotas/);
});
test('inicio vacío no contiene cuentas ni automatizaciones activas',()=>{
  const d=M.seed('first');assert.equal(M.netWorth(d),0);assert.equal(d.accounts.length,0);assert.equal(d.onboarding,false);assert.equal(d.settings.wallet,false);assert.equal(d.settings.auto,false);
});

test('una edición obsoleta o eliminada no sobrescribe el movimiento vigente',()=>{
 const d=M.seed(),old=M.clone(d.transactions.find(t=>t.id==='rent'));
 M.save(d,{...old,amount:1400000});const before=M.clone(d);
 assert.throws(()=>M.save(d,{...old,amount:1300000}),/cambió/);assert.deepEqual(d,before);
 const current=M.clone(d.transactions.find(t=>t.id==='rent'));M.deleteTransaction(d,current.id);
 assert.throws(()=>M.save(d,current),/cambió/);
});
test('movimiento y plantilla son atómicos incluso si la programación es inválida',()=>{
 const d=M.seed(),before=M.clone(d),draft=expense(),tpl={...draft,id:'t-atomic',name:'Mensual',schedule:true,frequency:'monthly',next:M.TODAY,anchor:M.TODAY};
 assert.throws(()=>M.saveWithTemplate(d,draft,{...tpl,type:'income'}),/programación/);assert.deepEqual(d,before);
 assert.throws(()=>M.saveWithTemplate(d,{...draft,amount:0},tpl),/importe/);assert.deepEqual(d,before);
 const tx=M.saveWithTemplate(d,draft,tpl);assert.equal(tx.templateId,tpl.id);assert.equal(d.templates.at(-1).next,'2026-11-06');assert.ok(d.scheduleRuns.includes('t-atomic@2026-10-06'));
 M.deleteTransaction(d,tx.id);d.templates.at(-1).next=M.TODAY;M.processSchedules(d);assert.equal(d.transactions.filter(t=>t.templateId===tpl.id).length,1);
});
test('programación independiente no crea comercio y comercio archivado queda pendiente',()=>{
 const d=M.seed(),t={...expense({merchant:'Comercio nuevo'}),id:'tpl-new',name:'Nueva',schedule:true,frequency:'monthly',next:M.TODAY,anchor:M.TODAY};
 const before=d.merchants.length;M.validateTemplate(d,t);assert.equal(d.merchants.length,before);
 d.merchants.find(m=>m.id==='market').archived=true;d.templates=[{...t,merchant:'Mercado Verde'}];const count=d.transactions.length;
 assert.equal(M.processSchedules(d),0);assert.match(d.templates[0].pending,/archivado/);assert.equal(d.transactions.length,count);
});
test('cuotas usan el resto en la última y reparten categorías con pesos restantes como Flutter',()=>{
 const t=expense({amount:101,quotas:3,from:'credit',splits:[{category:'food',amount:51},{category:'home',amount:50}]});
 const plan=M.installmentSchedule(t);assert.deepEqual(plan.map(i=>i.amount),[33,33,35]);assert.deepEqual(plan.map(i=>i.parts.map(p=>p.amount)),[[16,17],[16,17],[19,16]]);
 assert.equal(plan.reduce((n,i)=>n+i.parts[0].amount,0),51);assert.equal(plan.reduce((n,i)=>n+i.parts[1].amount,0),50);
});
test('devoluciones sucesivas conservan los importes por categoría sin agotar de más una parte',()=>{
 const d=M.seed(),t=M.save(d,expense({amount:3,splits:[{category:'food',amount:1},{category:'home',amount:2}]}));
 const rows=[M.refund(d,t.id,1,M.TODAY),M.refund(d,t.id,1,M.TODAY),M.refund(d,t.id,1,M.TODAY)];
 assert.equal(rows.flatMap(M.parts).filter(p=>p.category==='food').reduce((n,p)=>n+p.amount,0),1);
 assert.equal(rows.flatMap(M.parts).filter(p=>p.category==='home').reduce((n,p)=>n+p.amount,0),2);
 assert.equal(M.refundable(d,t.id),0);
});
const walletData=()=>{const d=M.seed();d.settings.wallet=true;d.settings.permission=true;d.settings.auto=true;return d;};
const capture=(extra={})=>({id:'capture-new',merchant:'MERCADO VERDE PY',alias:'•• 8820',amount:78500,date:M.TODAY,...extra});
test('Wallet reconoce alias únicos, registra nombre canónico y omite categoría archivada',()=>{
 const d=walletData();d.categories.find(c=>c.id==='food').archived=true;const result=M.ingestWallet(d,capture());
 assert.equal(result.status,'registered');assert.equal(result.transaction.merchant,'Mercado Verde');assert.equal(result.transaction.category,'');assert.equal(result.transaction.from,'credit');
});
test('Wallet exige unicidad de cuenta y comercio, no elige la primera coincidencia',()=>{
 const d=walletData();d.accounts.find(a=>a.id==='credit2').aliases.push('•• 8820');const before=d.transactions.length;
 assert.equal(M.ingestWallet(d,capture()).status,'pending');assert.equal(d.transactions.length,before);
 const e=walletData();e.merchants.push({id:'conflict',name:'Otro',aliases:['MERCADO VERDE PY'],category:'food'});
 assert.equal(M.ingestWallet(e,capture()).status,'pending');assert.equal(e.pending.at(-1).merchantState,'Comercio ambiguo');
});
test('Wallet duplicado por alias o registro programado queda pendiente',()=>{
 const d=walletData();M.save(d,expense({from:'credit',amount:78500,source:'Programado',channel:'Google Wallet'}));
 const result=M.ingestWallet(d,capture());assert.equal(result.status,'pending');assert.equal(result.candidate.duplicate,true);
});
test('Wallet repetido sin cambios no duplica y captura actualizada exige revisión',()=>{
 const d=walletData();M.ingestWallet(d,capture());const before=d.transactions.length;
 assert.equal(M.ingestWallet(d,capture()).status,'unchanged');assert.equal(d.transactions.length,before);
 const result=M.ingestWallet(d,capture({amount:79500}));assert.equal(result.status,'pending');assert.equal(result.candidate.updated,true);assert.equal(d.transactions.length,before);assert.equal(d.pending.filter(p=>p.id==='capture-new').length,1);
});
test('importe Wallet inválido queda pendiente y permiso apagado bloquea captura',()=>{
 const d=walletData();assert.equal(M.ingestWallet(d,capture({amount:0})).status,'pending');
 d.settings.permission=false;assert.throws(()=>M.ingestWallet(d,capture()),/permiso/);
});
test('fechas crediticias ajustan febrero y vencen en el mes posterior al cierre',()=>{
 assert.deepEqual(M.cardDates({closing:31,due:31},'2026-02-28'),{closing:'2026-02-28',due:'2026-03-31'});
 assert.deepEqual(M.cardDates({closing:15,due:20},'2026-10-16'),{closing:'2026-11-15',due:'2026-12-20'});
 assert.equal(M.validDate('2026-02-31'),false);assert.equal(M.validDate('2028-02-29'),true);
});

test('V01: secuencia independiente conserva patrimonio y no cuenta pagos/transferencias como gasto',()=>{
 const d=M.seed();d.transactions=[];d.templates=[];d.pending=[];d.accounts.forEach(a=>a.initial=0);
 M.save(d,expense({type:'income',amount:1000000,from:'',to:'bank',merchant:'Pagador ficticio',category:'salary'}));
 M.save(d,expense());
 M.save(d,expense({type:'transfer',amount:200000,to:'cash',category:'',merchant:'',channel:'Transferencia'}));
 M.save(d,expense({amount:90000,from:'credit2'}));
 M.save(d,expense({type:'payment',amount:30000,to:'credit2',category:'',merchant:'',channel:'Transferencia'}));
 assert.equal(M.balance(d,'bank'),670000);assert.equal(M.balance(d,'cash'),200000);
 assert.equal(M.balance(d,'credit2'),60000);assert.equal(M.balance(d,'credit'),0);
 assert.equal(M.netWorth(d),810000);assert.equal(M.report(d,'2026-10-01','2026-10-31').expenses,190000);
});
test('P02/H01: presupuestos de cuotas conservan 101, 51 y 50 con el oráculo por mes',()=>{
 const d=M.seed();d.transactions=[];
 M.save(d,expense({amount:101,from:'credit',quotas:3,splits:[{category:'food',amount:51},{category:'home',amount:50}]}));
 const months=['2026-10','2026-11','2026-12'];
 for(const [category,expected] of [['',[33,33,35]],['food',[16,16,19]],['home',[17,17,16]]]){
  const values=months.map(month=>M.budgetProgress(d,{month,amount:200,category}).consumed);
  assert.deepEqual(values,expected);
 }
 M.refund(d,d.transactions[0].id,40,M.TODAY);
 assert.equal(M.budgetProgress(d,{month:'2026-10',amount:200,category:''}).consumed,-7);
 assert.equal(M.budgetProgress(d,{month:'2026-11',amount:200,category:''}).consumed,33);
});
test('P02: consultar meses y años no escribe y alta queda en mes actual',()=>{
 const d=M.seed(),before=M.clone(d);
 for(const month of ['2026-12','2027-01','2028-02','2025-12'])M.budgetProgress(d,{month,amount:1000,category:''});
 assert.deepEqual(d,before);
 const created=M.createBudget(d,{month:'2027-01',name:'Mes actual',amount:1000,category:'food'});
 assert.equal(created.month,'2026-10');assert.equal(d.budgets.length,before.budgets.length+1);
 const saved=M.clone(d);assert.throws(()=>M.createBudget(d,{amount:0}),/positivo/);assert.deepEqual(d,saved);
 d.categories.find(c=>c.id==='food').archived=true;
 assert.throws(()=>M.createBudget(d,{amount:1000,category:'food'}),/activa/);
});
test('V02/P03: restaurar conserva importaciones históricas y no cambia snapshot ni estado anterior',()=>{
 const d=M.seed();const t=d.transactions[0];t.source='CSV';t.sourceReference='historical-reference';t.importBatchId='legacy';
 d.batches=[{id:'legacy',ids:[t.id],reverted:false}];
 const book=M.clone(d),before=M.clone(d);M.save(d,expense());
 const current=M.clone(d),restored=M.restoreBook(d,book);
 assert.equal(restored.transactions.length,before.transactions.length);
 assert.equal(restored.transactions[0].sourceReference,'historical-reference');
 assert.deepEqual(restored.batches,book.batches);assert.deepEqual(book,before);assert.deepEqual(d,current);
 assert.equal(M.previewCsv,undefined);
 assert.equal(M.balance(restored,'bank'),M.balance(book,'bank'));
});
test('V02: restauración invalida revisiones y avanzar generación impide reutilizar estado viejo',()=>{
 const d=M.seed(),old=M.clone(d.transactions.find(t=>t.id==='rent')),book=M.clone(d);
 const restored=M.restoreBook(d,book),before=M.clone(restored);
 assert.equal(restored.bookRevision,1);
 assert.throws(()=>M.save(restored,old),/cambió/);assert.deepEqual(restored,before);
 assert.equal(M.restoreBook(restored,book).bookRevision,2);
 const original=M.clone(d);assert.throws(()=>M.restoreBook(d,{transactions:[]}),/inválida/);assert.deepEqual(d,original);
});


// P05/F05/F18: aprobación explícita de cuotas mensuales, 2026-10-07.
const emptyLedger=()=>{const d=M.seed();d.transactions=[];return d;};
test('P05: diez cuotas comprometen el total una vez y el pago no duplica gasto',()=>{
 const d=emptyLedger(),t=M.save(d,expense({from:'credit',amount:1000000,quotas:10}));
 assert.equal(t.firstInstallmentDate,M.TODAY);assert.equal(d.transactions.length,1);
 assert.equal(M.balance(d,'credit'),1000000);
 const plan=M.installmentSchedule(t);assert.equal(plan.length,10);assert.equal(plan[9].date,'2027-07-06');
 assert.ok(plan.every(p=>p.amount===100000));
 assert.equal(M.movementRows(d).length,1);assert.equal(M.movementRows(d)[0].purchaseId,t.id);
 assert.equal(M.report(d,'2026-10-01','2026-10-31').expenses,100000);
 M.save(d,expense({type:'payment',from:'bank',to:'credit',merchant:'',category:'',channel:'Transferencia'}));
 assert.equal(M.balance(d,'credit'),900000);assert.equal(M.report(d,'2026-10-01','2026-10-31').expenses,100000);
});
test('P05: primera cuota posterior mantiene deuda, historial futuro enlazado y lectura pura',()=>{
 const d=emptyLedger(),t=M.save(d,expense({from:'credit',amount:1000000,quotas:10,firstInstallmentDate:'2026-11-06'}));
 const before=M.clone(d);assert.equal(M.balance(d,'credit'),1000000);
 assert.equal(M.report(d,'2026-10-01','2026-10-31').expenses,0);assert.deepEqual(M.movementRows(d),[]);
 const future=M.movementRows(d,'2026-12-31');assert.deepEqual(future.map(r=>r.date),['2026-11-06','2026-12-06']);
 assert.ok(future.every(r=>r.planned&&r.purchaseId===t.id&&r.amount===100000));assert.deepEqual(d,before);
});
test('P05: conserva día original tras febrero común y bisiesto',()=>{
 for(const [year,feb] of [['2025','28'],['2024','29']]){
  const d=emptyLedger(),t=M.save(d,expense({from:'credit',date:year+'-01-01',quotas:3,firstInstallmentDate:year+'-01-31'}));
  assert.deepEqual(M.installmentSchedule(t).map(p=>p.date),[year+'-01-31',year+'-02-'+feb,year+'-03-31']);
 }
});
test('P05/H01: fecha exacta y reparto 101/51/50 conservan cada entero',()=>{
 const d=emptyLedger(),t=M.save(d,expense({from:'credit',date:'2026-01-01',firstInstallmentDate:'2026-01-31',amount:101,quotas:3,splits:[{category:'food',amount:51},{category:'home',amount:50}]}));
 assert.equal(M.report(d,'2026-01-01','2026-01-30').expenses,0);
 assert.equal(M.report(d,'2026-01-31','2026-01-31').expenses,33);
 const plan=M.installmentSchedule(t);assert.deepEqual(plan.map(p=>p.amount),[33,33,35]);
 assert.deepEqual(plan.map(p=>p.parts.map(s=>s.amount)),[[16,17],[16,17],[19,16]]);
 assert.equal(M.movementRows(d).reduce((s,r)=>s+r.amount,0),101);
 for(const [category,total] of [['food',51],['home',50]])assert.equal(plan.reduce((s,p)=>s+p.parts.find(c=>c.category===category).amount,0),total);
});
test('P05: devolución mantiene calendario; borrar y deshacer no deja cuotas huérfanas',()=>{
 const d=emptyLedger(),t=M.save(d,expense({from:'credit',quotas:3,firstInstallmentDate:'2026-11-06'})),plan=M.installmentSchedule(t);
 const refund=M.refund(d,t.id,10000,M.TODAY);assert.equal(M.balance(d,'credit'),90000);
 assert.equal(M.report(d,'2026-10-01','2026-10-31').net,-10000);assert.deepEqual(M.installmentSchedule(t),plan);
 assert.throws(()=>M.deleteTransaction(d,t.id),/devoluciones/);
 M.deleteTransaction(d,refund.id);M.deleteTransaction(d,t.id);assert.deepEqual(M.movementRows(d,'2027-12-31'),[]);
 M.restoreTransaction(d,t.id);assert.equal(M.movementRows(d,'2027-12-31').length,3);
});
test('P05: editar sustituye calendario, revisión obsoleta y cuota proyectada no escriben',()=>{
 const d=emptyLedger(),t=M.save(d,expense({from:'credit',quotas:3})),old=M.clone(t);
 M.save(d,{...t,firstInstallmentDate:'2026-11-06'});assert.equal(d.transactions.length,1);assert.deepEqual(M.movementRows(d),[]);
 const before=M.clone(d);assert.throws(()=>M.save(d,old),/cambió/);assert.deepEqual(d,before);
 const row=M.movementRows(d,'2026-11-30')[0];assert.throws(()=>M.save(d,row),/compra original/);assert.deepEqual(d,before);
});
test('P05: fecha inválida o previa y cuota fraccionaria revierten también plantilla y comercio',()=>{
 for(const extra of [{firstInstallmentDate:'2026-10-05'},{firstInstallmentDate:'2026-02-30'},{quotas:2.5}]){
  const d=emptyLedger(),before=M.clone(d);
  assert.throws(()=>M.saveWithTemplate(d,expense({from:'credit',quotas:3,merchant:'Comercio ficticio nuevo',...extra}),{name:'Prueba'}));assert.deepEqual(d,before);
 }
});
test('P05/V02: registros históricos mantienen fechas y backup guarda solo compra canónica',()=>{
 const d=M.seed(),t=d.transactions.find(t=>t.id==='computer'),plan=M.installmentSchedule(t);
 assert.equal(plan[0].date,'2026-09-01');
 M.save(d,{...t,firstInstallmentDate:M.installmentStart(t)});assert.deepEqual(M.installmentSchedule(d.transactions.find(r=>r.id===t.id)),plan);
 const fresh=M.save(d,expense({from:'credit',quotas:3,firstInstallmentDate:'2026-11-06'}));
 const book=JSON.parse(JSON.stringify(d)),restored=M.restoreBook(d,book);
 assert.equal(restored.transactions.length,d.transactions.length);assert.ok(restored.transactions.every(r=>!r.installmentIndex));
 assert.equal(M.installmentStart(restored.transactions.find(r=>r.id===fresh.id)),'2026-11-06');
 assert.equal(M.movementRows(restored,'2027-12-31').length,M.movementRows(d,'2027-12-31').length);
 const bad=M.clone(book);bad.transactions.find(r=>r.id===fresh.id).firstInstallmentDate='2026-02-30';
 const before=M.clone(d);assert.throws(()=>M.restoreBook(d,bad),/cuota/);assert.deepEqual(d,before);
});


test('plan de débito compromete deuda completa sin descontar dinero y conserva fin de mes',()=>{
  const d=M.seed(),balance=M.balance(d,'bank'),worth=M.netWorth(d);
  const id=M.createPlan(d,{name:'Tele',amount:1000000,count:10,first:'2027-01-31',from:'bank',category:'home'});
  assert.equal(M.balance(d,'bank'),balance);assert.equal(M.netWorth(d),worth-1000000);
  assert.deepEqual(d.obligations.filter(o=>o.planId===id).slice(0,3).map(o=>o.due),['2027-01-31','2027-02-28','2027-03-31']);
});
test('pago parcial traslada el resto sin duplicar deuda y recuerda otra cuenta',()=>{
  const d=M.seed();M.createPlan(d,{name:'Tele',amount:300000,count:3,first:'2026-10-05',from:'bank',category:'home'});
  const first=d.obligations[0],worth=M.netWorth(d),cash=M.balance(d,'cash');
  M.payObligation(d,first.id,{amount:90000,date:M.TODAY,from:'cash',carry:true});
  assert.equal(M.balance(d,'cash'),cash-90000);assert.equal(M.obligationDebt(d),210000);assert.equal(M.netWorth(d),worth);
  assert.equal(M.obligationRemaining(d,d.obligations[0]),0);assert.equal(M.obligationRemaining(d,d.obligations[1]),110000);
  assert.equal(d.obligations[1].from,'cash');assert.equal(d.obligations[1].carriedFrom[0].due,'2026-10-05');
  const saved=M.clone(d);assert.throws(()=>M.payObligation(d,first.id,{amount:90000,date:M.TODAY,from:'cash'}),/saldo/);assert.deepEqual(d,saved);
});
test('última cuota parcial mantiene resto pendiente y pago inválido no deja efectos',()=>{
  const d=M.seed();M.createPlan(d,{name:'Compra',amount:100000,count:1,first:M.TODAY,from:'bank',category:'home'});
  const id=d.obligations[0].id,before=M.clone(d);
  assert.throws(()=>M.payObligation(d,id,{amount:90000,date:'2026-10-30',from:'cash',carry:true}),/fecha/);assert.deepEqual(d,before);
  M.payObligation(d,id,{amount:90000,date:M.TODAY,from:'cash',carry:true});assert.equal(M.obligationRemaining(d,d.obligations[0]),10000);
});
test('presupuesto distingue pendiente de pagado; pago en otro mes sale de la previsión original',()=>{
  const d=M.seed();d.transactions=[];d.templates=[];
  M.createPlan(d,{name:'Compra',amount:100000,count:1,first:'2026-09-05',from:'bank',category:'home'});
  const budget={month:'2026-09',category:'home',amount:200000};
  assert.deepEqual(M.budgetProgress(d,budget),{paid:0,pending:100000,consumed:100000,remaining:100000});
  M.payObligation(d,d.obligations[0].id,{amount:100000,date:M.TODAY,from:'bank'});
  assert.equal(M.budgetProgress(d,budget).consumed,0);
  const october=M.budgetProgress(d,{...budget,month:'2026-10'});assert.equal(october.paid,100000);assert.equal(october.pending,0);
});
test('previsión recurrente futura no resta patrimonio hasta su vencimiento',()=>{
  const d=M.seed();d.templates=[{...d.templates[1],next:'2026-11-02'}];const worth=M.netWorth(d);
  M.processSchedules(d);assert.equal(M.netWorth(d),worth);assert.equal(M.pendingAmount(d,'2026-11-01','2026-11-30'),65000);
});


test('factura variable permite confirmar su importe real sin dejar un falso resto',()=>{
 const d=M.seed('payments');M.processSchedules(d);const o=d.obligations.find(o=>o.templateId==='tpl-electric'),bank=M.balance(d,'bank');
 M.payObligation(d,o.id,{amount:210000,date:M.TODAY,from:'bank',finalAmount:true,carry:true});
 assert.equal(M.balance(d,'bank'),bank-210000);assert.equal(M.obligationRemaining(d,d.obligations.find(n=>n.id===o.id)),0);
 assert.equal(M.report(d,M.TODAY,M.TODAY).rows.filter(r=>r.transaction.obligationId===o.id)[0].amount,210000);
});
test('pago parcial recurrente prepara el siguiente vencimiento y recuerda su cuenta',()=>{
 const d=M.seed();d.transactions=[];d.templates=[{...d.templates[1],from:'bank',next:M.TODAY,anchor:M.TODAY}];M.processSchedules(d);
 const o=d.obligations.at(-1);M.payObligation(d,o.id,{amount:60000,date:M.TODAY,from:'cash',carry:true});
 const next=d.obligations.find(n=>n.due>o.due);assert.equal(next.carryIn,5000);assert.equal(next.from,'cash');assert.equal(d.templates[0].from,'cash');
});


test('Wallet coincide con compromiso pendiente y pide revisión antes de duplicar',()=>{
 const d=M.seed();d.settings.wallet=true;d.settings.permission=true;d.settings.auto=true;
 d.obligations=[{id:'planned',templateId:'tpl-stream',name:'Cine en Casa',from:'credit',amount:65000,due:M.TODAY}];
 const result=M.ingestWallet(d,{id:'capture-pending',merchant:'Cine en Casa',alias:'•• 8820',amount:65000,date:M.TODAY});
 assert.equal(result.status,'pending');assert.equal(result.candidate.duplicate,true);
});

test('regresión R01: previsión dividida y pago parcial conservan categorías al arrastrar',()=>{
 const d=M.seed();d.transactions=[];d.pending=[];d.templates=[{id:'divided',name:'Servicios',type:'expense',from:'bank',merchant:'Servicios',category:'food',amount:100000,channel:'Transferencia',splits:[{category:'food',amount:40000},{category:'home',amount:60000}],quotas:1,schedule:true,frequency:'monthly',next:'2026-10-06',anchor:'2026-10-06'}];
 M.processSchedules(d);
 assert.equal(M.pendingAmount(d,'2026-10-01','2026-10-31',{category:'food'}),40000);
 assert.equal(M.pendingAmount(d,'2026-10-01','2026-10-31',{category:'home'}),60000);
 const tx=M.payObligation(d,d.obligations[0].id,{amount:90000,date:M.TODAY,from:'bank',carry:true});
 assert.deepEqual(M.parts(tx),[{category:'food',amount:36000},{category:'home',amount:54000}]);
 assert.equal(M.pendingAmount(d,'2026-11-01','2026-11-30',{category:'food'}),44000);
 assert.equal(M.pendingAmount(d,'2026-11-01','2026-11-30',{category:'home'}),66000);
 assert.equal(M.report(d,'2026-10-01','2026-10-31','quotas',{category:'home'}).net,54000);
});
test('regresión R02: seleccionar sin categoría conserva el reparto original de cuota',()=>{
 const t=expense({amount:101,from:'credit',quotas:3,splits:[{category:'food',amount:51},{category:'',amount:50}],firstInstallmentDate:M.TODAY});
 assert.equal(M.periodAmount(t,'2026-10-01','2026-10-31','quotas','',true),17);
 assert.equal(M.periodAmount(t,'2026-11-01','2026-11-30','quotas','',true),17);
 assert.equal(M.periodAmount(t,'2026-12-01','2026-12-31','quotas','',true),16);
});
test('regresión R03/R04: editar plantilla reconcilia fechas y comercio sin duplicar pendientes',()=>{
 const d=M.seed('payments');M.processSchedules(d);const t=d.templates.find(t=>t.id==='tpl-electric');
 M.saveTemplate(d,{...M.clone(t),next:'2026-10-10',anchor:'2026-10-10',merchant:'Proveedor corregido'},'2026-10-09');
 assert.deepEqual(d.obligations.filter(o=>o.templateId===t.id).map(o=>o.due),['2026-10-10','2026-11-10']);
 assert.equal(M.pendingAmount(d,'2026-10-01','2026-10-31'),790000);
 assert.equal(M.processSchedules(d),0);
 const o=d.obligations.find(o=>o.templateId===t.id);
 const tx=M.payObligation(d,o.id,{amount:180000,date:M.TODAY,from:'bank',finalAmount:true});
 assert.equal(tx.merchant,'Proveedor corregido');
});
test('regresión R03: edición futura preserva pago previo y año bisiesto de la plantilla',()=>{
 const d=M.seed();d.transactions=[];d.pending=[];d.templates=[{...d.templates[1],from:'bank',next:'2026-09-30',anchor:'2026-09-30',merchant:'Nuevo servicio'}];M.processSchedules(d);
 const old=d.obligations[0];M.payObligation(d,old.id,{amount:65000,date:M.TODAY,from:'bank'});
 const saved=M.clone(d.transactions),t=d.templates[0];
 M.saveTemplate(d,{...M.clone(t),amount:75000,next:'2026-10-31',anchor:'2026-10-31'},'2026-10-30');
 assert.deepEqual(d.transactions,saved);assert.equal(d.obligations[0].due,'2026-09-30');assert.equal(d.obligations[0].amount,65000);
 assert.deepEqual(d.obligations.slice(1).map(o=>o.due),['2026-10-31','2026-11-30']);
 assert.equal(M.processSchedules(d),0);
});

test('regresión R05: editar recordatorio actualiza el seleccionado saldado y siguientes pendientes',()=>{
 const d=M.seed('payments');M.processSchedules(d);const o=d.obligations.find(o=>o.templateId==='tpl-electric');M.payObligation(d,o.id,{amount:180000,date:M.TODAY,from:'bank'});
 const r={enabled:false,days:5,time:'10:30',onDue:false};M.saveReminder(d,o.id,r);
 assert.deepEqual(d.obligations.find(n=>n.id===o.id).reminder,r);assert.deepEqual(d.templates.find(t=>t.id===o.templateId).reminder,r);
 assert.ok(d.obligations.filter(n=>n.templateId===o.templateId&&n.due>o.due).every(n=>JSON.stringify(n.reminder)===JSON.stringify(r)));
});
test('regresión R06: editar pendiente dividido escala categorías y plantilla sin pendientes fantasma',()=>{
 const d=M.seed('payments');M.processSchedules(d);const t=d.templates.find(t=>t.id==='tpl-electric');M.saveTemplate(d,{...t,next:'2026-10-09',amount:100000,splits:[{category:'food',amount:40000},{category:'home',amount:60000}]},'2026-10-09');
 const o=d.obligations.find(o=>o.templateId===t.id);M.editObligation(d,o.id,{amount:50000,due:'2026-10-10',following:true});
 assert.equal(M.obligationRemaining(d,d.obligations.find(n=>n.id===o.id)),50000);
 assert.equal(M.pendingAmount(d,'2026-10-10','2026-10-10'),50000);
 assert.deepEqual(d.templates.find(n=>n.id===t.id).splits,[{category:'food',amount:20000},{category:'home',amount:30000}]);
 M.validateTemplate(d,d.templates.find(n=>n.id===t.id));
 M.payObligation(d,o.id,{amount:50000,date:M.TODAY,from:'bank'});
 assert.equal(M.pendingAmount(d,'2026-10-10','2026-10-10'),0);assert.equal(M.processSchedules(d),0);
});

test('regresión R07: cambiar solo importe conserva ancla fin de mes de plan y plantilla',()=>{
 const d=M.seed();d.transactions=[];d.templates=[];M.createPlan(d,{name:'Fin mes',amount:300000,count:3,first:'2027-01-31',from:'bank',category:'home'});
 M.editObligation(d,d.obligations[1].id,{amount:120000,due:'2027-02-28',following:true});assert.deepEqual(d.obligations.map(o=>o.due),['2027-01-31','2027-02-28','2027-03-31']);
 const t={...M.seed().templates[1],from:'bank',next:'2026-10-31',anchor:'2026-10-31'};d.obligations=[];d.templates=[t];M.processSchedules(d);
 M.editObligation(d,d.obligations[1].id,{amount:75000,due:'2026-11-30',following:true});assert.equal(d.templates[0].next,'2026-12-31');assert.equal(d.templates[0].anchor,'2026-10-31');
});

test('plan dividido conserva totales por categoría y no descuenta antes de pagar',()=>{
  const d=M.seed(),before=M.balance(d,'bank');
  const id=M.createPlan(d,{name:'Tratamiento',amount:100001,count:3,first:M.TODAY,from:'bank',category:'',splits:[{category:'food',amount:60001},{category:'home',amount:40000}]});
  const dues=d.obligations.filter(o=>o.planId===id);
  assert.equal(M.balance(d,'bank'),before);
  assert.equal(dues.reduce((s,o)=>s+M.obligationParts(d,o).filter(p=>p.category==='food').reduce((s,p)=>s+p.amount,0),0),60001);
  assert.equal(dues.reduce((s,o)=>s+o.amount,0),100001);
});
test('plan rechaza reparto inválido sin crear pendientes',()=>{
  const d=M.seed(),before=JSON.stringify(d);
  assert.throws(()=>M.createPlan(d,{name:'Servicio',amount:100,count:2,first:M.TODAY,from:'bank',splits:[{category:'food',amount:99}]}));
  assert.equal(JSON.stringify(d),before);
});
