// Independent render-helper simulation. No browser/DOM layout or interactive flow coverage.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const M=require('../../model.js');
function load(file){
 const document={addEventListener(){},querySelector(){return null},querySelectorAll(){return []}};
 const context={window:{Cabal:M,addEventListener(){}},document,localStorage:{getItem(){return null},setItem(){}},console,Intl,URLSearchParams,location:{search:''},setTimeout,clearTimeout};
 let source=fs.readFileSync(file,'utf8');
 source=source.slice(0,source.indexOf("  $('#reset').addEventListener"))+`window.probe={set(d,v={page:'home'},s=[],u={}){data=d;view=v;stack=s;ui={...ui,...u}},field,form,nav,home,accounts,accountDetail,historyList,payments,paymentDetail,templates,reports,wallet,backup,security,info,transactionRow,paymentRow};})();`;
 vm.runInNewContext(source,context);return context.window.probe;
}
const a=load('prototype/cabal/app.js');let checks=0;
function check(name,fn){fn();checks++;console.log('PASS',name)}
const d=M.seed('payments');a.set(d);
for(const [value,expected] of [[0,'0'],[500000,'500.000'],[999999999,'999.999.999'],['500.000','500.000'],['','']])check('numeric initial '+JSON.stringify(value),()=>assert.ok(a.field('Importe','amount',value,'text','inputmode="numeric"').includes(`value="${expected}"`)));
check('form alert semantics',()=>assert.match(a.form('x',''),/role="alert" tabindex="-1"/));
check('home values and fictitious row labels retained',()=>{const html=a.home();for(const value of [M.money(M.availableMoney(d)).replace(' ₲',''),M.money(M.netWorth(d)),M.money(M.pendingAmount(d,'2026-10-01','2026-10-31')),'Dinero disponible','Pendiente este mes','Patrimonio financiero'])assert.ok(html.includes(value),value)});
for(const origin of ['home','history','accounts','analysis','more']){a.set(d,{page:'paymentDetail',id:d.obligations[0].id},[{view:{page:origin}},{view:{page:'payments'}}]);check('payment detail nav origin '+origin,()=>assert.ok(a.nav().includes(`data-id="${origin}" class="active" aria-current="page"`)));}
for(const screen of ['home','accounts','payments','templates','wallet','backup','security','info']){a.set(d);check('render helper '+screen,()=>{const html=a[screen]();assert.ok(html.length>50);assert.ok(!html.includes('undefined'));});}
for(const reportView of ['Resumen','Evolución','Categorías','Comercios','Cuentas']){a.set(d,{page:'analysis'},[],{reportView});check('report render '+reportView,()=>{const html=a.reports();assert.ok(html.includes('Vista del reporte'));assert.ok(!html.includes('NaN'));});}
const empty=M.seed('first');empty.onboarding=true;a.set(empty,{page:'home'});
check('no accounts actionable',()=>{assert.ok(a.home().includes('Sin cuentas'));assert.ok(a.home().includes('data-action="account-new"'));});
a.set(d,{page:'history'},[],{history:{search:'NEVER_MATCH_917821',account:'',merchant:'',category:'',type:'',start:'',end:'',limit:50}});
check('literal empty history message',()=>assert.ok(a.historyList().includes('Sin movimientos')));
const name='Electrodomésticos y muebles de todas las habitaciones de la compra familiar con un nombre muy largo & <escapado>';
a.set(d);check('long payment name escaped and amount intact',()=>{const html=a.paymentRow({...d.obligations[0],name,amount:999999999});assert.ok(html.includes('&amp; &lt;escapado&gt;'));assert.ok(html.includes('999.999.999 ₲'));});
console.log(JSON.stringify({checks,failures:0,method:'VM render helpers, stub document; not browser interaction/layout'},null,2));
