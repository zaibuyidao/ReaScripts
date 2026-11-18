var e=`data-fullscreen-fallback`,t=`
  [${e}] {
    position: fixed !important;
    top: var(--r-safe-t) !important;
    left: var(--r-safe-l) !important;
    right: auto !important;
    bottom: auto !important;
    width: calc(100vw - var(--r-safe-l) - var(--r-safe-r)) !important;
    height: calc(100svh - var(--r-safe-t) - var(--r-safe-b)) !important;
    z-index: 99999 !important;
    background: var(--r-color-canvas-bg, black) !important;
    /* Paints the safe-area strips around the stage, which stays clear of them. */
    box-shadow: 0 0 0 100vmax var(--r-color-canvas-bg, black) !important;
  }
`;function n(){return`requestFullscreen`in HTMLElement.prototype||`webkitRequestFullscreen`in HTMLElement.prototype}function r(){if(n())return()=>{};let r=HTMLElement.prototype,i=[],a=(e,t,n)=>{i.push({target:e,key:t,prev:Object.getOwnPropertyDescriptor(e,t)}),Object.defineProperty(e,t,{configurable:!0,...n})},o=document.createElement(`style`);o.textContent=t,document.head.appendChild(o);let s=null,c=e=>{document.dispatchEvent(new Event(`fullscreenchange`)),e.dispatchEvent(new Event(`fullscreenchange`))},l=new MutationObserver(()=>{s&&!s.isConnected&&d()}),u=t=>(s===t||(s&&d(),t.setAttribute(e,``),s=t,l.observe(document,{childList:!0,subtree:!0}),c(t)),Promise.resolve()),d=()=>{let t=s;return t&&(t.removeAttribute(e),s=null,l.disconnect(),c(t)),Promise.resolve()};return a(document,`fullscreenEnabled`,{get:()=>!0}),a(document,`fullscreenElement`,{get:()=>s}),a(document,`fullScreen`,{get:()=>s!==null}),a(document,`exitFullscreen`,{value:d,writable:!0}),a(r,`requestFullscreen`,{value:function(){return u(this)},writable:!0}),a(r,`webkitRequestFullscreen`,{value:function(){u(this)},writable:!0}),()=>{for(d(),l.disconnect(),o.remove();i.length;){let{target:e,key:t,prev:n}=i.pop();n?Object.defineProperty(e,t,n):Reflect.deleteProperty(e,t)}}}var i=1e3;async function a(){if(!document.fullscreenElement)return;let e;await Promise.race([document.exitFullscreen().catch(()=>void 0),new Promise(t=>{e=setTimeout(t,i)})]),clearTimeout(e)}export{a as n,r as t};