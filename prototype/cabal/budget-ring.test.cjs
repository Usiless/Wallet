const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),test=require('node:test');
const M=require('./model.js');
const ctx={window:{Cabal:M,addEventListener(){}},document:{addEventListener(){},querySelector(){return null}},localStorage:{getItem(){return null},setItem(){}},Intl,URLSearchParams,setTimeout,clearTimeout};
let src=fs.readFileSync(__dirname+'/app.js','utf8');
src=src.slice(0,src.indexOf("  $('#reset').addEventListener"))+`window.ring=budgetRingSegments;})();`;
vm.runInNewContext(src,ctx);
function lengths(paid,pending,amount=100){return ctx.window.ring({paid,pending,consumed:paid+pending},amount).map(s=>({zone:s.zone,state:s.state,length:s.length}));}
function expect(paid,pending,expected){const actual=lengths(paid,pending);assert.equal(actual.length,expected.length);expected.forEach(([zone,state,length],i)=>{assert.equal(actual[i].zone,zone);assert.equal(actual[i].state,state);assert.ok(Math.abs(actual[i].length-length)<1e-8);});}
test('250% totalmente pendiente: 40% dentro y 60% exceso, ambos pendientes',()=>expect(0,250,[['within','pending',40],['excess','pending',60]]));
test('340% totalmente pendiente ajusta escala sin vueltas',()=>expect(0,340,[['within','pending',100/3.4],['excess','pending',240/3.4]]));
test('300% pagado: un tercio dentro y dos tercios exceso',()=>expect(300,0,[['within','paid',100/3],['excess','paid',200/3]]));
test('250% mixto: pago ocupa presupuesto antes de pendientes',()=>expect(50,200,[['within','paid',20],['within','pending',20],['excess','pending',60]]));
test('pagos también pueden exceder y pendientes conservan su estado',()=>expect(200,50,[['within','paid',40],['excess','paid',40],['excess','pending',20]]));
test('bajo objetivo conserva tramo vacío',()=>expect(20,30,[['within','paid',20],['within','pending',30]]));
test('cero sin segmentos',()=>assert.equal(lengths(0,0).length,0));
test('devoluciones netean pendientes sin inventar pagos',()=>expect(-20,70,[['within','pending',50]]));
test('longitudes finitas, no negativas y suma coincide con proporción',()=>{for(const paid of [-150,0,25,100,300,9999])for(const pending of [0,20,100,500]){const total=Math.max(0,paid+pending);const rows=lengths(paid,pending);assert.ok(rows.every(s=>Number.isFinite(s.length)&&s.length>0));assert.ok(Math.abs(rows.reduce((a,s)=>a+s.length,0)-Math.min(100,total))<1e-8);}});
