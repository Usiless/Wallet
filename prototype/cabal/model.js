/* Libro ficticio compartido por todas las pantallas. No usa servicios de Cabal. */
(function (root) {
  'use strict';
  const TODAY = '2026-10-06';
  const clone = value => JSON.parse(JSON.stringify(value));
  const uid = prefix => `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
  const month = date => date.slice(0, 7);
  const money = amount => new Intl.NumberFormat('es-PY', {maximumFractionDigits: 0}).format(amount) + ' ₲';
  const parseMoney = value => { const raw = String(value).trim(); return /^[\d.\s]+$/.test(raw) ? Number(raw.replace(/[.\s]/g, '')) : NaN; };
  const normalize = value => String(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim().replace(/\s+/g, ' ');
  function addMonths(date, count) {
    const [y, m, d] = date.split('-').map(Number);
    const target = new Date(Date.UTC(y, m - 1 + count, 1));
    const last = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
    return `${target.getUTCFullYear()}-${String(target.getUTCMonth() + 1).padStart(2, '0')}-${String(Math.min(d, last)).padStart(2, '0')}`;
  }
  function seed(scenario = 'daily') {
    const data = {
      scenario, bookRevision:0, onboarding: scenario !== 'first', settings: {wallet: false, auto: false, permission: false, lock: false, sms: false, diagnostic: false},
      accounts: [
        {id:'bank',name:'Cuenta diaria',type:'bank',initial:2450000,aliases:['•• 4201'],available:true},
        {id:'cash',name:'Efectivo',type:'cash',initial:380000,aliases:[],available:true},
        {id:'saving',name:'Reserva',type:'saving',initial:4200000,aliases:[],available:false},
        {id:'credit',name:'Crédito demo',type:'credit',initial:0,aliases:['•• 8820'],limit:6000000,closing:20,due:5,available:false},
        {id:'credit2',name:'Crédito viajes',type:'credit',initial:0,aliases:['•• 7712'],limit:3000000,closing:15,due:1,available:false}
      ],
      categories:[{id:'food',name:'Alimentación',kind:'expense'},{id:'home',name:'Hogar',kind:'expense'},{id:'transport',name:'Transporte',kind:'expense'},{id:'leisure',name:'Ocio',kind:'expense'},{id:'salary',name:'Salario',kind:'income'}],
      merchants:[{id:'market',name:'Mercado Verde',aliases:['MERCADO VERDE PY'],category:'food'},{id:'tech',name:'Casa Nube',aliases:[],category:'home'},{id:'coffee',name:'Café del Patio',aliases:[],category:'food'},{id:'stream',name:'Cine en Casa',aliases:[],category:'leisure'}],
      transactions:[], budgets:[{id:'general',name:'Mi mes',month:'2026-10',amount:2200000,category:''},{id:'food-budget',name:'Alimentación',month:'2026-10',amount:650000,category:'food'}],
      templates:[{id:'tpl-coffee',name:'Mi café',type:'expense',from:'cash',to:'',merchant:'Café del Patio',category:'food',amount:null,channel:'Efectivo',note:'',splits:[],quotas:1,schedule:false},
        {id:'tpl-stream',name:'Cine en Casa',type:'expense',from:'credit',to:'',merchant:'Cine en Casa',category:'leisure',amount:65000,channel:'Pago online',note:'Suscripción',splits:[],quotas:1,schedule:true,frequency:'monthly',next:'2026-11-02',anchor:'2026-11-02',paused:false},
        {id:'tpl-old',name:'Servicio del hogar',type:'expense',from:'bank',to:'',merchant:'Servicio demo',category:'home',amount:180000,channel:'Transferencia',note:'',splits:[],quotas:1,schedule:true,frequency:'monthly',next:'2026-10-04',anchor:'2026-10-04',pending:'Revisar una posible coincidencia con una compra detectada',paused:false}],
      scheduleRuns:[], pending:[{id:'p1',merchant:'Mercado Verde',amount:185000,date:TODAY,from:'credit',category:'food',alias:'•• 8820',reason:'Comercio reconocido · Cuenta reconocida'},
        {id:'p2',merchant:'Tienda Horizonte',amount:95000,date:TODAY,from:'',category:'',alias:'•• 1935',reason:'Comercio nuevo · Cuenta por asociar'},
        {id:'p3',merchant:'Servicio demo',amount:180000,date:'2026-10-04',from:'bank',category:'home',alias:'•• 4201',reason:'Posible coincidencia con un registro programado',duplicate:true}],
      batches:[], diagnostic:[]
    };
    const tx = (id,date,type,amount,from,to,merchant,category,extra={}) => ({id,date,type,amount,from,to,merchant,category,quotas:1,splits:[],channel:'Otro',source:'Manual',note:'',...extra});
    for (let m=5;m<=9;m++) {
      const mm=String(m).padStart(2,'0');
      data.transactions.push(tx(`salary-${m}`,`2026-${mm}-01`,'income',4200000,'','bank','Trabajo demo','salary'));
      data.transactions.push(tx(`cost-${m}`,`2026-${mm}-12`,'expense',1250000+m*37000,'bank','','Mercado Verde','food'));
      data.transactions.push(tx(`rent-${m}`,`2026-${mm}-03`,'expense',1450000,'bank','','Alquiler demo','home'));
    }
    data.transactions.push(
      tx('computer','2026-09-22','expense',1200000,'credit','','Casa Nube','home',{quotas:6,channel:'Tarjeta física'}),
      tx('salary','2026-10-01','income',4200000,'','bank','Trabajo demo','salary'),
      tx('rent','2026-10-02','expense',1450000,'bank','','Alquiler demo','home',{channel:'Transferencia'}),
      tx('stream','2026-10-02','expense',65000,'credit','','Cine en Casa','leisure',{source:'Programado',channel:'Pago online'}),
      tx('market','2026-10-03','expense',245000,'bank','','Mercado Verde','food',{channel:'Tarjeta física',splits:[{category:'food',amount:195000},{category:'home',amount:50000}]}),
      tx('save','2026-10-03','transfer',350000,'bank','saving','',''),
      tx('coffee','2026-10-04','expense',28000,'cash','','Café del Patio','food',{channel:'Efectivo'}),
      tx('refund','2026-10-05','refund',60000,'credit','','Casa Nube','home',{purchase:'computer'}),
      tx('pay','2026-10-05','payment',300000,'bank','credit','','',{channel:'Transferencia'}),
      tx('transport','2026-10-06','expense',45000,'cash','','Viaje demo','transport')
    );
    if(scenario==='first') {data.accounts=[];data.transactions=[];data.pending=[];data.templates=[];data.budgets=[];data.merchants=[];}
    if(scenario==='wallet') {data.settings.wallet=true;data.settings.permission=true;data.accounts[4].aliases.push('•• 8820');data.pending[0].from='';data.pending[0].reason='Alias compartido · Elegí la cuenta correcta';}
    if(scenario==='scheduled') {data.templates[1].next='2026-08-02';data.templates.push({...clone(data.templates[1]),id:'paused',name:'Suscripción pausada',paused:true,next:'2026-10-10'});}
    if(scenario==='analysis') {data.transactions=data.transactions.filter(t=>!['cost-8','rent-8'].includes(t.id));data.transactions.push(tx('old-return','2026-08-08','refund',1300000,'bank','','Mercado Verde','food',{purchase:'cost-5'}));}
    if(scenario==='developer') {data.settings.permission=true;data.diagnostic=[{title:'Evento de demostración',text:'Mercado Verde · 185.000 PYG · •• 8820'}];}
    if(scenario==='payments') {
      data.templates=data.templates.filter(t=>t.id!=='tpl-old');
      data.templates.push({id:'tpl-electric',name:'Electricidad',type:'expense',from:'bank',merchant:'Electricidad',category:'home',amount:180000,channel:'Transferencia',quotas:1,splits:[],schedule:true,frequency:'monthly',next:'2026-10-09',anchor:'2026-10-09',reminder:{enabled:true,days:3,time:'09:00',onDue:true}});
      createPlan(data,{name:'Tele del living',amount:5000000,count:10,first:'2026-10-09',from:'bank',category:'home'});
      createPlan(data,{name:'Bicicleta',amount:300000,count:3,first:'2026-09-05',from:'bank',category:'transport'});
      const bike=data.obligations.find(o=>o.name==='Bicicleta');
      payObligation(data,bike.id,{amount:90000,date:'2026-10-05',from:'bank',carry:true});
      data.accounts.find(a=>a.id==='bank').initial-=10000000;
    }
    return data;
  }
  const activeTransactions = data => data.transactions.filter(t=>!t.deleted);
  const account = (data,id) => data.accounts.find(a=>a.id===id);
  function balance(data,id) {
    const a=account(data,id); if(!a) return 0;
    let value=a.initial;
    for(const t of activeTransactions(data)) {
      if(t.type==='adjustment' && t.from===id) value+=t.amount;
      else if(t.type==='expense' && t.from===id) value+=a.type==='credit'?t.amount:-t.amount;
      else if(t.type==='income' && t.to===id) value+=a.type==='credit'?-t.amount:t.amount;
      else if(t.type==='refund' && t.from===id) value+=a.type==='credit'?-t.amount:t.amount;
      else if(t.type==='transfer'||t.type==='payment') {
        if(t.from===id) value+=a.type==='credit'?t.amount:-t.amount;
        if(t.to===id) value+=a.type==='credit'?-t.amount:t.amount;
      }
    } return value;
  }
  const netWorth = data => data.accounts.filter(a=>!a.archived).reduce((sum,a)=>sum+balance(data,a.id)*(a.type==='credit'?-1:1),0)-obligationDebt(data);
  function channels(type,from,to) {
    if(type==='transfer'||type==='payment') return from?.type==='cash'&&to?.type==='cash'?['Efectivo','Otro']:['Transferencia','Otro'];
    const a=type==='income'?to:from;
    if(!a) return ['Otro'];
    if(a.type==='cash') return ['Efectivo','Otro'];
    return ['Tarjeta física','Google Wallet','Pago online',...(a.type==='credit'?[]:['Transferencia']),'Otro'];
  }
  function parts(t) { return t.splits?.length?t.splits:[{category:t.category||'',amount:t.amount}]; }
  // Mismo reparto entero que InstallmentCalculator y ReportService de Flutter.
  function allocate(amount,weights) {
    const total=weights.reduce((sum,n)=>sum+n,0);let cumulative=0,assigned=0;
    return weights.map(weight=>{cumulative+=weight;const next=total?Math.floor(amount*cumulative/total):0;const value=next-assigned;assigned=next;return value;});
  }
  // Las compras históricas sin fecha explícita conservan su calendario anterior.
  const installmentStart=t=>t.firstInstallmentDate||(t.firstPeriod||t.date.slice(0,7))+'-01';
  function installmentSchedule(t) {
    const count=t.quotas||1,base=Math.floor(t.amount/count),remaining=parts(t).map(p=>p.amount);
    return Array.from({length:count},(_,i)=>{const amount=base+(i===count-1?t.amount-base*count:0),values=allocate(amount,remaining);values.forEach((v,j)=>remaining[j]-=v);return {date:addMonths(installmentStart(t),i),amount,parts:parts(t).map((p,j)=>({category:p.category,amount:values[j]}))};});
  }
  // Filas de lectura: nunca se persisten ni participan otra vez en el saldo.
  function movementRows(data,until=TODAY) {
    return activeTransactions(data).flatMap(t=>t.type==='expense'&&t.quotas>1?
      installmentSchedule(t).map((item,index)=>({...clone(t),amount:item.amount,date:item.date,splits:item.parts,installmentIndex:index+1,purchaseId:t.id,planned:item.date>TODAY})):[clone(t)]
    ).filter(t=>!until||t.date<=until);
  }
  function periodAmount(t,start,end,mode='quotas',category='',unclassified=false) {
    if(!['expense','income','refund'].includes(t.type)||t.deleted)return 0;
    const impacts=mode==='quotas'&&t.type==='expense'&&t.quotas>1?installmentSchedule(t):[{date:t.date,parts:parts(t)}];
    return impacts.filter(i=>i.date>=start&&i.date<=end).reduce((sum,i)=>sum+i.parts.filter(p=>unclassified?!p.category:!category||p.category===category).reduce((n,p)=>n+p.amount,0),0);
  }
  const matchingMerchants=(data,name,archived=false)=>data.merchants.filter(m=>(archived||!m.archived)&&(normalize(m.name)===normalize(name)||(m.aliases||[]).some(a=>normalize(a)===normalize(name))));
  function cardDates(a,date=TODAY) {
    const safe=(month,day)=>addMonths(month+'-'+String(day).padStart(2,'0'),0);
    let closing=safe(date.slice(0,7),a.closing);if(date>closing)closing=safe(addMonths(date.slice(0,7)+'-01',1).slice(0,7),a.closing);
    return {closing,due:safe(addMonths(closing.slice(0,7)+'-01',1).slice(0,7),a.due)};
  }
  function validateTemplate(data,t) {
    if(!String(t.name||'').trim())throw Error('Escribí un nombre para la plantilla.');
    if(t.schedule&&(t.type!=='expense'||t.quotas>1||!Number.isSafeInteger(t.amount)||t.amount<=0))throw Error('La programación requiere un gasto de importe fijo, sin cuotas.');
    if(t.schedule&&(!validDate(t.next)||!['monthly','yearly'].includes(t.frequency)))throw Error('Elegí una próxima fecha y frecuencia válidas.');
    validate(data,{...t,id:undefined,date:TODAY,firstInstallmentDate:undefined,firstPeriod:undefined,amount:t.amount===null?1:t.amount,splits:t.amount===null?[]:t.splits});
    const matches=matchingMerchants(data,t.merchant,true);
    if(t.schedule&&(matches.length>1||matches.some(m=>m.archived)))throw Error('Revisá el comercio archivado o ambiguo de la plantilla.');
  }
  function saveWithTemplate(data,draft,template) {
    const work=clone(data);if(template)validateTemplate(work,template);
    const tx=save(work,draft);
    if(template){const saved=clone(template);if(saved.schedule&&saved.next===tx.date){work.scheduleRuns.push(saved.id+'@'+saved.next);tx.templateId=saved.id;advance(saved);}work.templates.push(saved);}
    Object.assign(data,work);return tx;
  }
  function validDate(date){if(!/^\d{4}-\d{2}-\d{2}$/.test(date||''))return false;const d=new Date(date+'T12:00:00Z');return Number.isFinite(d.getTime())&&d.toISOString().slice(0,10)===date;}
  function ingestWallet(data,capture) {
    if(!data.settings.wallet||!data.settings.permission)throw Error('Activá detección y concedé el permiso simulado primero.');
    const prior=data.pending.find(p=>p.id===capture.id);
    if(prior&&['merchant','alias','amount','date'].every(k=>prior[k]===capture[k]))return {status:'unchanged',candidate:prior};
    const merchants=matchingMerchants(data,capture.merchant),accounts=data.accounts.filter(a=>!a.archived&&a.aliases.some(alias=>normalize(alias)===normalize(capture.alias)));
    const merchant=merchants.length===1?merchants[0]:null,from=accounts.length===1?accounts[0].id:'';
    const category=data.categories.find(c=>c.id===merchant?.category&&!c.archived&&c.kind!=='income')?.id||'';
    const p={...capture,id:capture.id||uid('candidate'),from,category,confirmed:false,ignored:false,updated:!!prior,merchantState:merchants.length>1?'Comercio ambiguo':merchant?'Comercio reconocido':'Comercio nuevo'};
    const canonical=name=>{const m=matchingMerchants(data,name);return m.length===1?m[0].id:normalize(name);};
    p.duplicate=(data.obligations||[]).some(o=>obligationRemaining(data,o)>0&&o.from===from&&canonical(o.merchant||o.name)===canonical(p.merchant)&&obligationRemaining(data,o)===p.amount&&Math.abs(new Date(o.due)-new Date(p.date))<=3*86400000)||data.transactions.some(t=>!t.deleted&&(t.candidate===p.id||t.type==='expense'&&t.from===from&&canonical(t.merchant)===canonical(p.merchant)&&t.amount===p.amount&&Math.abs(new Date(t.date)-new Date(p.date))<=3*86400000))||data.pending.some(other=>other.id!==p.id&&!other.ignored&&!other.confirmed&&other.from===from&&canonical(other.merchant)===canonical(p.merchant)&&other.amount===p.amount&&Math.abs(new Date(other.date)-new Date(p.date))<=3*86400000);
    const draft={type:'expense',amount:p.amount,date:p.date,from,to:'',merchant:merchant?.name||p.merchant,category,channel:'Google Wallet',quotas:1,splits:[],source:'Google Wallet',note:'',candidate:p.id};
    let invalid='';try{validate(data,draft);}catch(error){invalid=error.message;}
    p.reason=p.updated?'Captura actualizada · Revisá antes de registrar':p.duplicate?'Posible coincidencia con otro movimiento o propuesta':invalid||(!from?(accounts.length>1?'Alias compartido · Elegí la cuenta correcta':'Cuenta por asociar'):p.merchantState);
    if(prior)data.pending[data.pending.indexOf(prior)]=p;else data.pending.push(p);
    if(data.settings.auto&&from&&merchant&&!p.updated&&!p.duplicate&&!invalid){const tx=save(data,draft);p.confirmed=true;return {status:'registered',transaction:tx,candidate:p};}
    return {status:'pending',candidate:p};
  }
  function report(data,start,end,mode='quotas',filters={}) {
    let expenses=0,refunds=0,income=0; const rows=[];
    for(const t of activeTransactions(data)) {
      if(filters.account&&t.from!==filters.account&&t.to!==filters.account) continue;
      const amount=periodAmount(t,start,end,mode,filters.category);
      if(!amount) continue;
      if(t.type==='expense')expenses+=amount; if(t.type==='refund')refunds+=amount; if(t.type==='income')income+=amount;
      rows.push({transaction:t,amount});
    }return {expenses,refunds,income,net:expenses-refunds,rows};
  }
  function validate(data,t,original=null) {
    if(t.installmentIndex)throw Error('La cuota pertenece a una compra. Editá la compra original.');
    if(original&&(original.type!==t.type)) throw Error('No se puede cambiar el tipo al editar.');
    if(!Number.isSafeInteger(t.amount)||t.amount<=0) throw Error('Ingresá un importe entero mayor que cero.');
    if(!validDate(t.date)||t.date>TODAY) throw Error('Elegí una fecha válida hasta el 6 de octubre de 2026.');
    const from=account(data,t.from),to=account(data,t.to);
    const usable=a=>a&&(!a.archived||original&&(original.from===a.id||original.to===a.id));
    if(t.type==='income'?!usable(to):!usable(from)) throw Error('Seleccioná una cuenta activa.');
    if(['transfer','payment'].includes(t.type)&&(!usable(to)||t.from===t.to)) throw Error('Elegí dos cuentas activas diferentes.');
    if(t.type==='payment'&&to.type!=='credit') throw Error('El destino debe ser una tarjeta de crédito.');
    if(!channels(t.type,from,to).includes(t.channel)) throw Error('El canal no corresponde a las cuentas elegidas.');
    if(!Number.isSafeInteger(t.quotas||1)||(t.quotas||1)<1)throw Error('Elegí una cantidad entera de cuotas.');
    if(t.quotas>1&&(t.type!=='expense'||from.type!=='credit'))throw Error('Las cuotas requieren un gasto con tarjeta de crédito.');
    if(t.quotas>1&&t.firstInstallmentDate){
      const historical=original&&t.firstInstallmentDate===installmentStart(original)&&t.date===original.date;
      if(!validDate(t.firstInstallmentDate)||(!historical&&t.firstInstallmentDate<t.date))throw Error('La primera cuota debe ser una fecha válida desde la compra.');
    }
    if(t.splits?.length) {
      if(t.splits.some(s=>!Number.isSafeInteger(s.amount)||s.amount<=0)||t.splits.reduce((sum,s)=>sum+s.amount,0)!==t.amount)throw Error('Las divisiones deben ser positivas y sumar el importe total.');
    }
    for(const p of parts(t)) if(p.category) {
      const c=data.categories.find(c=>c.id===p.category);
      const historic=original&&parts(original).some(part=>part.category===p.category);
      if(!c||(c.archived&&!historic)||(t.type==='income'?c.kind==='expense':c.kind==='income'))throw Error('La categoría no corresponde al movimiento.');
    }
    if(original&&(original.type!==t.type)) throw Error('No se puede cambiar el tipo al editar.');
    const returned=t.id?data.transactions.filter(r=>!r.deleted&&r.purchase===t.id).reduce((s,r)=>s+r.amount,0):0;
    if(returned>t.amount)throw Error('El importe no puede ser menor que las devoluciones activas.');
    if(returned&&original&&(original.from!==t.from||original.date!==t.date))throw Error('Esta compra tiene devoluciones: conservá la cuenta y la fecha de origen.');
  }
  function save(data,draft) {
    const original=data.transactions.find(t=>t.id===draft.id);
    if(draft.id&&(!original||original.deleted||(draft.revision||0)!==(original.revision||0)))throw Error('El movimiento cambió desde que lo abriste. Cancelá y volvé a abrirlo para editar la versión actual.');
    if(!original&&draft.type==='expense'&&draft.quotas>1&&!draft.firstInstallmentDate)draft={...draft,firstInstallmentDate:draft.date};
    validate(data,draft,original);
    const t={...clone(original||{}),...clone(draft),id:draft.id||uid('tx'),source:original?.source||draft.source||'Manual',revision:(original?.revision||0)+1,deleted:false};
    if(t.quotas<=1){delete t.firstInstallmentDate;delete t.firstPeriod;}
    if(original)data.transactions[data.transactions.indexOf(original)]=t;else data.transactions.push(t);
    if(t.type==='expense'&&t.merchant) {
      let m=data.merchants.find(m=>!m.archived&&(normalize(m.name)===normalize(t.merchant)||m.aliases.some(a=>normalize(a)===normalize(t.merchant))));
      if(!m) {m={id:uid('merchant'),name:t.merchant,aliases:[],category:''};data.merchants.push(m);}
      if(!t.splits?.length)m.category=t.category||'';
    }return t;
  }
  function refundable(data,id) {const t=data.transactions.find(t=>t.id===id);return t.amount-data.transactions.filter(r=>!r.deleted&&r.purchase===id).reduce((sum,r)=>sum+r.amount,0);}
  function refund(data,id,amount,date,note='') {
    const purchase=data.transactions.find(t=>t.id===id&&!t.deleted&&t.type==='expense');
    if(!purchase)throw Error('La compra ya no está disponible.');
    if(!Number.isSafeInteger(amount)||amount<=0||amount>refundable(data,id))throw Error('La devolución supera el importe restante o no es válida.');
    if(!validDate(date)||date<purchase.date||date>TODAY)throw Error('La fecha debe estar entre la compra y hoy.');
    const weights=new Map();for(const p of parts(purchase))weights.set(p.category,(weights.get(p.category)||0)+p.amount);
    for(const prior of data.transactions.filter(t=>!t.deleted&&t.purchase===id))for(const p of parts(prior))weights.set(p.category,Math.max(0,(weights.get(p.category)||0)-p.amount));
    const categories=[...weights.keys()],values=allocate(amount,[...weights.values()]);const splits=categories.map((category,i)=>({category,amount:values[i]})).filter(p=>p.amount>0);
    const t={id:uid('refund'),type:'refund',amount,date,from:purchase.from,to:'',merchant:purchase.merchant,category:purchase.category,splits,quotas:1,purchase:id,note,source:'Manual',channel:purchase.channel};data.transactions.push(t);return t;
  }
  function deleteTransaction(data,id) {
    const t=data.transactions.find(t=>t.id===id);if(!t||t.deleted)throw Error('El movimiento ya fue eliminado.');
    if(data.transactions.some(r=>!r.deleted&&r.purchase===id))throw Error('Eliminá primero las devoluciones de esta compra.');t.deleted=true;t.revision=(t.revision||0)+1;
  }
  function restoreTransaction(data,id) {
    const t=data.transactions.find(t=>t.id===id);if(!t)throw Error('Movimiento no disponible.');
    if(t.purchase) {
      const p=data.transactions.find(p=>p.id===t.purchase);if(!p||p.deleted||refundable(data,p.id)<t.amount)throw Error('No se puede deshacer: la compra o su límite cambió.');
    }
    if(t.candidate&&data.transactions.some(r=>r.id!==id&&!r.deleted&&r.candidate===t.candidate))throw Error('Esta compra ya tiene otro registro activo.');t.deleted=false;t.revision=(t.revision||0)+1;
  }
  // En este prototipo, la programación prepara compromisos; nunca cobra ni registra pagos.
  function processSchedules(data) {
    data.obligations ||= [];
    let count=0;
    const horizon=new Date(new Date(addMonths(TODAY.slice(0,7)+'-01',2)+'T12:00:00Z')-86400000).toISOString().slice(0,10);
    for(const template of data.templates.filter(t=>t.schedule&&!t.paused&&!t.pending)) {
      let loops=0;
      while(template.next<=horizon&&loops++<120) {
        const key=template.id+'@'+template.next;
        if(data.scheduleRuns.includes(key)||(data.obligations||[]).some(o=>o.templateId===template.id&&o.due===template.next)){if(!data.scheduleRuns.includes(key))data.scheduleRuns.push(key);advance(template);continue;}
        const same=data.transactions.some(t=>!t.deleted&&t.type==='expense'&&t.from===template.from&&normalize(t.merchant)===normalize(template.merchant)&&t.amount===template.amount&&Math.abs(new Date(t.date)-new Date(template.next))<=3*86400000);
        const pending=data.pending.some(p=>!p.ignored&&!p.confirmed&&p.from===template.from&&normalize(p.merchant)===normalize(template.merchant)&&p.amount===template.amount&&Math.abs(new Date(p.date)-new Date(template.next))<=3*86400000);
        if(same||pending){template.pending='Posible coincidencia. Revisá antes de preparar otro pendiente.';break;}
        try {
          validateTemplate(data,template);
          data.obligations.push({id:key,templateId:template.id,frequency:template.frequency,name:template.name,merchant:template.merchant,category:template.category,splits:clone(template.splits||[]),from:template.from,amount:template.amount,due:template.next,reminder:clone(template.reminder||defaultReminder())});
          data.scheduleRuns.push(key);advance(template);count++;
        } catch(error){template.pending=error.message;break;}
      }
    }return count;
  }
  const defaultReminder=()=>({enabled:true,days:3,time:'09:00',onDue:true});
  const obligationPayments=(data,id)=>activeTransactions(data).filter(t=>t.obligationId===id);
  function obligationRemaining(data,o){return o.cancelled?0:Math.max(0,o.amount+(o.carryIn||0)-(o.carryOut||0)-obligationPayments(data,o.id).reduce((s,t)=>s+t.amount,0));}
  function obligationDebt(data){return (data.obligations||[]).filter(o=>o.planId||o.due<=TODAY).reduce((s,o)=>s+obligationRemaining(data,o),0);}
  function obligationParts(data,o){
    if(o.cancelled)return [];
    const totals=new Map();
    const add=(rows,sign=1)=>{for(const p of rows)totals.set(p.category,(totals.get(p.category)||0)+sign*p.amount);};
    add(parts(o));
    add(o.carryInParts||[{category:o.category||'',amount:o.carryIn||0}]);
    for(const tx of obligationPayments(data,o.id))add(parts(tx),-1);
    add(o.carryOutParts||[{category:o.category||'',amount:o.carryOut||0}],-1);
    return [...totals].filter(([,amount])=>amount>0).map(([category,amount])=>({category,amount}));
  }
  function pendingAmount(data,start,end,filters={}){return (data.obligations||[]).filter(o=>o.due>=start&&o.due<=end&&(!filters.account||o.from===filters.account)).reduce((s,o)=>s+obligationParts(data,o).filter(p=>!filters.category||p.category===filters.category).reduce((sum,p)=>sum+p.amount,0),0);}
  function nextTemplateDate(data,t){return (data.obligations||[]).filter(o=>o.templateId===t.id&&!o.cancelled&&o.due>=month(TODAY)+'-01'&&obligationRemaining(data,o)>0&&!obligationPayments(data,o.id).length&&!o.carryIn&&!o.carryOut).sort((a,b)=>a.due.localeCompare(b.due))[0]?.due||t.next;}
  // Reconcilia la edición con los compromisos proyectados en una sola operación.
  function saveTemplate(data,draft,effectiveDate){
    const work=clone(data);validateTemplate(work,draft);
    const index=work.templates.findIndex(t=>t.id===draft.id),old=work.templates[index],t=clone(draft);
    if(old&&t.schedule){
      const cutoff=effectiveDate||nextTemplateDate(work,old),dateChanged=t.next!==cutoff||t.frequency!==old.frequency;
      const editable=(work.obligations||[]).filter(o=>o.templateId===t.id&&o.due>=cutoff&&o.due>=month(TODAY)+'-01'&&!o.cancelled&&!obligationPayments(work,o.id).length&&!o.carryIn&&!o.carryOut).sort((a,b)=>a.due.localeCompare(b.due));
      const oldFrequency=old.frequency==='yearly'?12:1,newFrequency=t.frequency==='yearly'?12:1;
      for(const o of editable){
        if(dateChanged){const offset=(Number(o.due.slice(0,4))-Number(cutoff.slice(0,4)))*12+Number(o.due.slice(5,7))-Number(cutoff.slice(5,7));const key=t.id+'@'+o.due;work.scheduleRuns=work.scheduleRuns.filter(k=>k!==key);o.due=addMonths(t.next,Math.max(0,Math.round(offset/oldFrequency))*newFrequency);}
        o.amount=t.amount;o.from=t.from;o.category=t.category;o.splits=clone(t.splits||[]);o.name=t.name;o.merchant=t.merchant;o.frequency=t.frequency;o.reminder=clone(t.reminder||defaultReminder());
      }
      const dates=(work.obligations||[]).filter(o=>o.templateId===t.id).map(o=>o.due);
      if(new Set(dates).size!==dates.length)throw Error('La fecha coincide con otro vencimiento. Elegí una fecha diferente.');
      for(const o of editable){const key=t.id+'@'+o.due;if(!work.scheduleRuns.includes(key))work.scheduleRuns.push(key);}
      if(dateChanged){t.anchor=t.next;const last=dates.filter(d=>d>=cutoff).sort().at(-1);while(last&&t.next<=last)advance(t);}else{t.next=old.next;t.anchor=old.anchor||old.next;}
    }
    if(index<0)work.templates.push(t);else work.templates[index]=t;
    processSchedules(work);Object.assign(data,work);return t;
  }
  function saveReminder(data,id,reminder){
    const o=(data.obligations||[]).find(n=>n.id===id);
    if(!o)throw Error('El pendiente ya no está disponible.');
    for(const n of data.obligations)if(n.id===id||n.due>=o.due&&(o.planId?n.planId===o.planId:n.templateId===o.templateId)&&obligationRemaining(data,n)>0)n.reminder=clone(reminder);
    const t=data.templates.find(t=>t.id===o.templateId);if(t)t.reminder=clone(reminder);
  }
  function editObligation(data,id,draft){
    const work=clone(data),o=(work.obligations||[]).find(n=>n.id===id),{amount,due,following}=draft;
    if(!o||o.cancelled)throw Error('El pendiente ya no está disponible.');
    if(!Number.isSafeInteger(amount)||amount<=0||!validDate(due))throw Error('Ingresá un importe positivo y una fecha válida.');
    if(obligationPayments(work,id).length||o.carryIn||o.carryOut)throw Error('Este pendiente tiene pagos o saldos trasladados. Confirmá el saldo restante para conservar el historial.');
    const oldDue=o.due,scale=n=>{if(n.splits?.length){const values=allocate(amount,n.splits.map(p=>p.amount));n.splits=n.splits.map((p,i)=>({...p,amount:values[i]})).filter(p=>p.amount>0);}n.amount=amount;};
    const targets=work.obligations.filter(n=>n.id===id||following&&n.due>=oldDue&&(o.planId?n.planId===o.planId:n.templateId===o.templateId));
    for(const n of targets)if(!n.cancelled&&!obligationPayments(work,n.id).length&&!n.carryIn&&!n.carryOut){
      const offset=(Number(n.due.slice(0,4))-Number(oldDue.slice(0,4)))*12+Number(n.due.slice(5,7))-Number(oldDue.slice(5,7));
      // El vencimiento viejo sigue consumido: editar una sola ocurrencia no debe regenerarlo.
      scale(n);if(due!==oldDue)n.due=addMonths(due,offset);
      if(n.templateId){const key=n.templateId+'@'+n.due;if(!work.scheduleRuns.includes(key))work.scheduleRuns.push(key);}
    }
    const group=work.obligations.filter(n=>o.planId?n.planId===o.planId:n.templateId===o.templateId);
    if(new Set(group.map(n=>n.due)).size!==group.length)throw Error('La fecha coincide con otro vencimiento. Elegí una fecha diferente.');
    const t=work.templates.find(t=>t.id===o.templateId);
    if(t&&following){scale(t);if(due!==oldDue){t.anchor=due;t.next=addMonths(due,Math.max(t.frequency==='yearly'?12:1,(Number(t.next.slice(0,4))-Number(oldDue.slice(0,4)))*12+Number(t.next.slice(5,7))-Number(oldDue.slice(5,7))));}validateTemplate(work,t);}
    Object.assign(data,work);
  }
  const availableMoney=data=>data.accounts.filter(a=>!a.archived&&a.type!=='credit'&&a.available).reduce((sum,a)=>sum+balance(data,a.id),0);
  function createPlan(data,draft){
    if(!String(draft.name||'').trim())throw Error('Ingresá una descripción del gasto.');
    if(!Number.isSafeInteger(draft.amount)||draft.amount<=0||!Number.isSafeInteger(draft.count)||draft.count<1||draft.count>120||draft.amount<draft.count)throw Error('Revisá el importe total y la cantidad de cuotas (1 a 120).');
    if(!validDate(draft.first))throw Error('Elegí una fecha válida para la primera cuota.');
    const a=account(data,draft.from);if(!a||a.archived||a.type==='credit')throw Error('Elegí una cuenta de débito, efectivo o ahorro. Las tarjetas de crédito tienen su propio plan.');
    if(draft.category&&!data.categories.some(c=>c.id===draft.category&&!c.archived&&c.kind!=='income'))throw Error('Elegí una categoría de gasto activa.');
    if(draft.splits?.length){
      if(draft.splits.some(s=>!Number.isSafeInteger(s.amount)||s.amount<=0)||draft.splits.reduce((sum,s)=>sum+s.amount,0)!==draft.amount)throw Error('Las divisiones deben ser positivas y sumar el importe total.');
      if(draft.splits.some(s=>s.category&&!data.categories.some(c=>c.id===s.category&&!c.archived&&c.kind!=='income')))throw Error('Elegí categorías de gasto activas.');
    }
    const schedule=installmentSchedule({...draft,quotas:draft.count,firstInstallmentDate:draft.first});
    data.obligations ||= [];
    const planId=uid('plan'),base=Math.floor(draft.amount/draft.count);
    for(let i=0;i<draft.count;i++)data.obligations.push({id:uid('due'),planId,note:draft.note||'',date:draft.date||TODAY,name:draft.name.trim(),merchant:draft.name.trim(),from:draft.from,category:draft.category,splits:draft.splits?.length?clone(schedule[i].parts):[],amount:i===draft.count-1?draft.amount-base*i:base,due:addMonths(draft.first,i),index:i+1,count:draft.count,reminder:clone(draft.reminder||defaultReminder())});
    return planId;
  }
  function payObligation(data,id,payment){
    const work=clone(data),o=(work.obligations||[]).find(o=>o.id===id);
    if(!o||o.cancelled)throw Error('El pendiente ya no está disponible.');
    if(payment.finalAmount&&o.templateId&&!o.carryIn&&!o.carryOut&&!obligationPayments(work,id).length){
      if(!Number.isSafeInteger(payment.amount)||payment.amount<=0)throw Error('Ingresá un importe positivo.');
      if(o.splits?.length){const values=allocate(payment.amount,o.splits.map(p=>p.amount));o.splits=o.splits.map((p,i)=>({...p,amount:values[i]})).filter(p=>p.amount>0);}
      o.amount=payment.amount;
    }
    const remaining=obligationRemaining(work,o);
    if(!Number.isSafeInteger(payment.amount)||payment.amount<=0||payment.amount>remaining)throw Error('El pago debe ser positivo y no superar el saldo pendiente.');
    const a=account(work,payment.from);if(!a||a.archived||o.planId&&a.type==='credit')throw Error('Elegí una cuenta activa de débito, efectivo o ahorro.');
    const allocation=obligationParts(work,o),values=allocate(payment.amount,allocation.map(p=>p.amount)),paidParts=allocation.map((p,i)=>({...p,amount:values[i]})).filter(p=>p.amount>0);
    const tx=save(work,{type:'expense',amount:payment.amount,date:payment.date,from:payment.from,to:'',merchant:o.merchant||o.name,category:paidParts.length===1?paidParts[0].category:o.category||'',quotas:1,splits:o.splits?.length||paidParts.length>1?paidParts:[],channel:channels('expense',a)[0],source:'Pago confirmado',note:(o.planId?'Cuota '+o.index+'/'+o.count:'Gasto recurrente')+(o.note?' · '+o.note:''),obligationId:o.id});
    const template=work.templates.find(t=>t.id===o.templateId);
    if(template){template.from=payment.from;template.channel=channels('expense',a).includes(template.channel)?template.channel:channels('expense',a)[0];}
    if(payment.carry&&payment.amount<remaining&&template&&!work.obligations.some(n=>n.templateId===o.templateId&&n.due>o.due&&!n.cancelled&&obligationRemaining(work,n)>0)){
      const key=template.id+'@'+template.next;
      if(!work.scheduleRuns.includes(key)){
        validateTemplate(work,template);
        work.obligations.push({id:key,templateId:template.id,frequency:template.frequency,name:template.name,merchant:template.merchant,category:template.category,splits:clone(template.splits||[]),from:payment.from,amount:template.amount,due:template.next,reminder:clone(template.reminder||defaultReminder())});
        work.scheduleRuns.push(key);advance(template);
      }
    }
    const group=work.obligations.filter(n=>o.planId?n.planId===o.planId:n.templateId===o.templateId);
    for(const n of group)if(n.due>=o.due)n.from=payment.from;
    const rest=remaining-payment.amount;
    const next=group.filter(n=>!n.cancelled&&n.due>o.due&&obligationRemaining(work,n)>0).sort((a,b)=>a.due.localeCompare(b.due))[0];
    if(rest&&payment.carry&&next){const carried=obligationParts(work,o);o.carryOutParts=[...(o.carryOutParts||[]),...clone(carried)];next.carryInParts=[...(next.carryInParts||[{category:next.category||'',amount:next.carryIn||0}]),...clone(carried)];o.carryOut=(o.carryOut||0)+rest;next.carryIn=(next.carryIn||0)+rest;(next.carriedFrom||=[]).push({id:o.id,due:o.due,amount:rest,parts:clone(carried)});}
    Object.assign(data,work);return tx;
  }
  function advance(template) {
    const frequency=template.frequency==='yearly'?12:1;
    const anchor=template.anchor||template.next;
    const elapsed=(Number(template.next.slice(0,4))-Number(anchor.slice(0,4)))*12+Number(template.next.slice(5,7))-Number(anchor.slice(5,7));
    template.next=addMonths(anchor,elapsed+frequency);
  }
  // P02: query has no side effects and shares the exact report allocation in this demo.
  function budgetProgress(data,budget) {
    const start=budget.month+'-01';
    const end=new Date(new Date(addMonths(start,1)+'T12:00:00Z')-86400000).toISOString().slice(0,10);
    const consumed=report(data,start,end,'quotas',{category:budget.category}).net;
    const pending=pendingAmount(data,start,end,{category:budget.category});
    return {paid:consumed,pending,consumed:consumed+pending,remaining:budget.amount-consumed-pending};
  }
  function createBudget(data,draft) {
    if(!Number.isSafeInteger(draft.amount)||draft.amount<=0)throw Error('El objetivo debe ser un importe entero positivo.');
    if(draft.category&&!data.categories.some(c=>c.id===draft.category&&!c.archived&&c.kind!=='income'))throw Error('Elegí una categoría activa de gasto.');
    const budget={id:uid('budget'),name:String(draft.name||'').trim()||'Mi mes',month:month(TODAY),amount:draft.amount,category:draft.category||''};
    data.budgets.push(budget);return budget;
  }
  // V02: only a session-book simulation, with no file validation or cryptography.
  function restoreBook(current,book) {
    if(!book||!['accounts','transactions','categories','merchants','budgets','templates','scheduleRuns','pending','batches'].every(key=>Array.isArray(book[key])))throw Error('Copia ficticia inválida. Los datos actuales se conservan.');
    if(book.transactions.some(t=>t.firstInstallmentDate&&!validDate(t.firstInstallmentDate)))throw Error('Fecha de primera cuota inválida. Los datos actuales se conservan.');
    const restored=clone(book);restored.bookRevision=(current.bookRevision||0)+1;
    for(const t of restored.transactions)t.revision=Math.max(t.revision||0,current.transactions.find(old=>old.id===t.id)?.revision||0)+1;
    return restored;
  }
  const api={TODAY,clone,uid,month,money,parseMoney,normalize,addMonths,seed,activeTransactions,account,balance,netWorth,channels,parts,periodAmount,report,validate,save,refundable,refund,deleteTransaction,restoreTransaction,processSchedules,advance,allocate,installmentStart,installmentSchedule,movementRows,matchingMerchants,cardDates,validateTemplate,saveWithTemplate,validDate,ingestWallet,budgetProgress,createBudget,restoreBook,defaultReminder,obligationPayments,obligationRemaining,obligationDebt,pendingAmount,availableMoney,createPlan,payObligation,obligationParts,saveTemplate,nextTemplateDate,saveReminder,editObligation};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;root.Cabal=api;
})(typeof window!=='undefined'?window:globalThis);
