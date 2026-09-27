'use strict';
// Emulator pixels are presented inside the WebView. PCM stays in the core extension.
// LCD3X: Gigaherz's public-domain sinusoidal mask (libretro/glsl-shaders).
// lcd-grid-v2: cgwg's integrated LCD subpixel model, preserving ReaGBA's equations.
function createGameVideo(){
 const holder=document.getElementById('game-viewport'),canvas=document.createElement('canvas');
 canvas.id='game-frame';canvas.setAttribute('aria-hidden','true');holder.append(canvas);
 const gl=canvas.getContext('webgl2',{alpha:false,antialias:false,depth:false,stencil:false,preserveDrawingBuffer:true});
 let sourceWidth=240,sourceHeight=160;
 let lastMessage=null,pixels=null,queued=false,program,texture,ctx,source,sourceContext;
 if(gl){
  const compile=(type,text)=>{const shader=gl.createShader(type);gl.shaderSource(shader,text);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(shader));return shader;};
  program=gl.createProgram();
  gl.attachShader(program,compile(gl.VERTEX_SHADER,`#version 300 es
precision highp float;
out vec2 uv;
void main(){uv=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(uv*vec2(2,-2)+vec2(-1,1),0,1);}`));
  gl.attachShader(program,compile(gl.FRAGMENT_SHADER,`#version 300 es
precision highp float;
precision highp int;
in vec2 uv;
uniform sampler2D frame;
uniform vec2 sourceSize;
uniform vec2 outputSize;
uniform int shaderPreset;
out vec4 color;
vec3 sampleFrame(vec2 coordinate){return texture(frame,coordinate).rgb;}
vec3 fetchFrame(ivec2 texel){return texelFetch(frame,clamp(texel,ivec2(0),ivec2(sourceSize)-1),0).rgb;}

vec3 lcd3x(vec2 uv) {
    const float pi = 3.141592654;
    vec2 phase = uv * sourceSize * (2.0 * pi);
    vec3 mask = (4.0 + sin(phase.x + pi * vec3(0.5, -1.0/6.0, -5.0/6.0))) / 5.0;
    return sampleFrame(uv) * mask * ((16.0 + sin(phase.y)) / 17.0);
}

// Antiderivatives of the squared horizontal and vertical subpixel profiles:
// (1-z^2-z^4+z^6)^2 and (1-2z^4+z^6)^2, supported on [-1,1].
vec3 profileIntegral(vec3 z, bool horizontal) {
    vec3 q = z*z;
    if (horizontal)
        return z*(1.0+q*(-2.0/3.0+q*(-1.0/5.0+q*(4.0/7.0+q*(-1.0/9.0+q*(-2.0/11.0+q/13.0))))));
    return z*(1.0+q*q*(-4.0/5.0+q*(2.0/7.0+q*(4.0/9.0+q*(-4.0/11.0+q/13.0)))));
}
vec3 coverage(vec3 distance, float footprint, float radius, bool horizontal) {
    vec3 lo = clamp((distance - footprint*0.5) / radius, -1.0, 1.0);
    vec3 hi = clamp((distance + footprint*0.5) / radius, -1.0, 1.0);
    return max((profileIntegral(hi, horizontal) - profileIntegral(lo, horizontal)) * (radius/footprint),
               vec3(0.0, 0.0, 0.0));
}
vec3 lcdLight(ivec2 texel) {
    vec3 value = fetchFrame(texel) + 0.05;
    return value * value * value;
}
vec3 lcdGrid(vec2 uv) {
    vec2 position = uv*sourceSize - 0.4999;
    ivec2 origin = ivec2(floor(position));
    vec2 fraction = position - vec2(origin);
    // Physical output pixels, not the WebView's CSS size (important on HiDPI).
    vec2 footprint = sourceSize / max(outputSize, vec2(1.0, 1.0));
    vec3 leftMask = coverage(fraction.x*3.0 + vec3(1.0, 0.0, -1.0), footprint.x*3.0, 1.5, true);
    vec3 rightMask = coverage(fraction.x*3.0 + vec3(-2.0, -3.0, -4.0), footprint.x*3.0, 1.5, true);
    vec3 rows = coverage(vec3(fraction.y, fraction.y-1.0, 0.0), footprint.y, 0.63, false);
    vec3 upper = lcdLight(origin)*leftMask + lcdLight(origin+ivec2(1,0))*rightMask;
    vec3 lower = lcdLight(origin+ivec2(0,1))*leftMask + lcdLight(origin+ivec2(1,1))*rightMask;
    return pow(max(upper*rows.x + lower*rows.y, vec3(0.0,0.0,0.0)), vec3(1.0/2.2,1.0/2.2,1.0/2.2));
}
vec3 shadeFrame(vec2 uv) {
    if (shaderPreset == 1) return lcd3x(uv);
    if (shaderPreset == 2) return lcdGrid(uv);
    return sampleFrame(uv);
}

void main(){color=vec4(shadeFrame(uv),1.0);}`));
  gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));
  gl.useProgram(program);texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  gl.uniform1i(gl.getUniformLocation(program,'frame'),0);gl.uniform2f(gl.getUniformLocation(program,'sourceSize'),240,160);
  gl.disable(gl.DITHER);
 }else{
  ctx=canvas.getContext('2d',{alpha:false});source=document.createElement('canvas');source.width=240;source.height=160;sourceContext=source.getContext('2d');
 }
 // CPU fallback uses the same subpixel equations when WebGL2 is unavailable.
 function softwareShader(width,height,preset){
  const image=ctx.createImageData(width,height),out=image.data;
  const sample=(x,y,c)=>pixels[(Math.max(0,Math.min(sourceHeight-1,y))*sourceWidth+Math.max(0,Math.min(sourceWidth-1,x)))*4+c]/255;
  const integral=(z,h)=>{const q=z*z;return h?z*(1+q*(-2/3+q*(-1/5+q*(4/7+q*(-1/9+q*(-2/11+q/13)))))):z*(1+q*q*(-4/5+q*(2/7+q*(4/9+q*(-4/11+q/13)))));};
  const coverage=(distance,footprint,radius,h)=>{
   const lo=Math.max(-1,Math.min(1,(distance-footprint*.5)/radius)),hi=Math.max(-1,Math.min(1,(distance+footprint*.5)/radius));
   return Math.max(0,(integral(hi,h)-integral(lo,h))*radius/footprint);
  };
  const columns=Array.from({length:width},(_,x)=>{
   const u=(x+.5)*sourceWidth/width,position=u-.4999,origin=Math.floor(position),fraction=position-origin;
   return {u,origin,left:[1,0,-1].map(n=>coverage(fraction*3+n,sourceWidth/width*3,1.5,true)),right:[-2,-3,-4].map(n=>coverage(fraction*3+n,sourceWidth/width*3,1.5,true))};
  });
  for(let y=0;y<height;y++){
   const v=(y+.5)*sourceHeight/height,position=v-.4999,origin=Math.floor(position),fraction=position-origin;
   const upper=coverage(fraction,sourceHeight/height,.63,false),lower=coverage(fraction-1,sourceHeight/height,.63,false);
   for(let x=0;x<width;x++){
    const column=columns[x],offset=(y*width+x)*4;
    for(let c=0;c<3;c++){
     let value;
     if(preset==='lcd3x')value=sample(Math.floor(column.u),Math.floor(v),c)*(4+Math.sin(column.u*2*Math.PI+Math.PI*[.5,-1/6,-5/6][c]))/5*(16+Math.sin(v*2*Math.PI))/17;
     else{
      const light=(sx,sy)=>Math.pow(sample(sx,sy,c)+.05,3);
      const top=light(column.origin,origin)*column.left[c]+light(column.origin+1,origin)*column.right[c];
      const bottom=light(column.origin,origin+1)*column.left[c]+light(column.origin+1,origin+1)*column.right[c];
      value=Math.pow(Math.max(0,top*upper+bottom*lower),1/2.2);
     }
     out[offset+c]=Math.max(0,Math.min(255,Math.round(value*255)));
    }
    out[offset+3]=255;
   }
  }
  return image;
 }

 function drawNow(){
  queued=false;if(!pixels)return;
  const ratio=window.devicePixelRatio||1,w=Math.max(1,Math.round(holder.clientWidth*ratio)),h=Math.max(1,Math.round(holder.clientHeight*ratio));
  if(canvas.width!==w)canvas.width=w;if(canvas.height!==h)canvas.height=h;
  let scale=Math.min(w/sourceWidth,h/sourceHeight);if(settings.integer_scaling!==false&&scale>=1)scale=Math.floor(scale);
  const width=Math.max(1,Math.floor(sourceWidth*scale)),height=Math.max(1,Math.floor(sourceHeight*scale));
  const x=Math.floor((w-width)/2),y=Math.floor((h-height)/2);
  if(gl){
   gl.viewport(0,0,w,h);gl.clearColor(0,0,0,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.viewport(x,y,width,height);
   const preset=settings.shader==='lcd3x'?1:settings.shader==='lcd-grid-v2'?2:0;
   const filter=!preset&&settings.filter==='linear'?gl.LINEAR:gl.NEAREST;
   gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,filter);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,filter);
   gl.uniform2f(gl.getUniformLocation(program,'outputSize'),width,height);gl.uniform1i(gl.getUniformLocation(program,'shaderPreset'),preset);
   gl.drawArrays(gl.TRIANGLES,0,3);
  }else{
   ctx.fillStyle='#000';ctx.fillRect(0,0,w,h);
   if(settings.shader==='lcd3x'||settings.shader==='lcd-grid-v2')ctx.putImageData(softwareShader(width,height,settings.shader),x,y);
   else{ctx.imageSmoothingEnabled=settings.filter==='linear';ctx.drawImage(source,x,y,width,height);}
  }
 }
 function isGB(){const system=typeof state==='undefined'?'GBA':state.game?.system||state.system;return system==='GB'||system==='GBC';}
 function draw(){
  if(lastMessage&&sourceWidth!==(isGB()?160:240))upload(lastMessage);
  if(settings.vsync===false)drawNow();else if(!queued){queued=true;requestAnimationFrame(drawNow);}
 }
 canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();toast('Graphics context lost. Reopen ReaGBA.',true);});
 function upload(message){
  if(message.width!==240||message.height!==160||!(message.data instanceof Uint8Array)||message.data.byteLength!==240*160*4)throw Error('Invalid GBA frame');
  const gb=isGB();
  sourceWidth=gb?160:240;sourceHeight=gb?144:160;
  if(gb){
   if(!pixels||pixels.length!==160*144*4)pixels=new Uint8Array(160*144*4);
   for(let y=0;y<144;y++)pixels.set(message.data.subarray(((y+8)*240+40)*4,((y+8)*240+200)*4),y*160*4);
  }else pixels=message.data;
  if(gl){
   gl.uniform2f(gl.getUniformLocation(program,'sourceSize'),sourceWidth,sourceHeight);
   gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA8,sourceWidth,sourceHeight,0,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
  }else{
   if(source.width!==sourceWidth)source.width=sourceWidth;if(source.height!==sourceHeight)source.height=sourceHeight;
   sourceContext.putImageData(new ImageData(new Uint8ClampedArray(pixels.buffer,pixels.byteOffset,pixels.byteLength),sourceWidth,sourceHeight),0,0);
  }
 }
 return {draw,frame(message){upload(message);lastMessage=message;draw();}};
}
