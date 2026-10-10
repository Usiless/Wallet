// Real composer-type action with injected readDraft/composer seams. Not browser validation.
const fs=require('node:fs'),vm=require('node:vm'),M=require('../../model.js');
const d=M.seed(),fixture={type:'expense',amount:123456,from:'bank',to:'',category:'food',splits:[{category:'food',amount:60000},{category:'home',amount:63456}],quotas:3,merchant:'Prueba',date:M.TODAY,note:'conservar'};
const ctx={window:{Cabal:M,addEventListener(){}},document:{querySelector(){return null},addEventListener(){}},localStorage:{getItem(){return null},setItem(){}},setTimeout,clearTimeout,URLSearchParams,Intl,console};
let src=fs.readFileSync('prototype/cabal/app.js','utf8');src=src.slice(0,src.indexOf("  $('#reset').addEventListener"))+`data=window.data;modalPayload={options:{}};readDraft=()=>M.clone(window.fixture);composer=(draft)=>{window.captured=draft;};window.probe=action;})();`;
ctx.window.data=d;ctx.window.fixture=fixture;vm.runInNewContext(src,ctx);ctx.window.probe('composer-type','expense');
console.log(JSON.stringify({fixture,afterSameType:ctx.window.captured,unchanged:JSON.stringify(ctx.window.captured||fixture)===JSON.stringify(fixture),method:'action simulation with injected draft/composer, no DOM/browser'},null,2));
