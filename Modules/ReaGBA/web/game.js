'use strict';
const i18n=window.ReaGBAI18n,t=(key,values)=>i18n.t(key,values);
const defaultKeys=['J','K','Space','Return','D','A','W','S','Q','O'];
let settings={},state={loaded:false},toastTimer;
function editing(){return false;}
function toast(message,error=false){const element=document.getElementById('toast');element.textContent=message;element.className='visible'+(error?' error':'');clearTimeout(toastTimer);toastTimer=setTimeout(()=>element.className='',3500);}
async function call(action){const result=await window.nativeRequest({action});if(!result.ok)throw Error(result.error);return result.result;}
window.applyGamePreferences=value=>{
 if(!value)return;
 const changed=JSON.stringify(value)!==JSON.stringify(settings);
 settings=value;i18n.set(settings.language);document.documentElement.lang=i18n.language;i18n.apply();
 if(changed)call('game_viewport').catch(error=>toast(error.message,true));
};
window.onNativeState=value=>{state=value;document.body.classList.toggle('playing',state.loaded);document.title=state.game?.title?'ReaGBA - '+state.game.title:'ReaGBA';};
function resize(){
 call('game_viewport').catch(error=>toast(error.message,true));
}
initReaGBABridge();
new ResizeObserver(resize).observe(document.querySelector('.game-stage'));
document.getElementById('game-viewport').onclick=()=>call('focus_game').catch(error=>toast(error.message,true));
call('get_settings').then(value=>window.applyGamePreferences(value)).catch(error=>toast(error.message,true));
