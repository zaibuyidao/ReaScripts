export function capabilities() {
  const canvas = document.createElement('canvas');
  let gl;
  try { gl = canvas.getContext('webgl2'); } catch {}
  const webgl2 = !!gl;
  gl?.getExtension('WEBGL_lose_context')?.loseContext();
  const audio = document.createElement('audio');
  return { userAgent:navigator.userAgent, origin:location.href, audioContext:!!(window.AudioContext || window.webkitAudioContext),
    decodeAudioData:!!(window.AudioContext || window.webkitAudioContext)?.prototype.decodeAudioData,
    file:typeof File === 'function', blob:typeof Blob === 'function', objectURL:typeof URL.createObjectURL === 'function',
    fileInput:'files' in document.createElement('input'), dragDrop:'ondrop' in document.createElement('div'),
    webgl2, webAssembly:typeof WebAssembly === 'object', audioWorklet:typeof AudioWorkletNode === 'function',
    formats:Object.fromEntries(['audio/wav','audio/mpeg','audio/flac','audio/ogg; codecs="vorbis"','audio/mp4; codecs="mp4a.40.2"'].map(type => [type,audio.canPlayType(type)])) };
}
