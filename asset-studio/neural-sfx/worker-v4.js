// Stable Audio Open Small browser candidate. No inference server or credentials.
const MODEL="atauser001/stable-audio-open-small-onnx";
const FILES={
 "cond.onnx":[439547211,"847822809975d0c36a665594fad0312c4c225147910657820e9936b09014629c"],
 "dit.onnx":[1364171978,"8e9c8b14baac4a26159d5ecf3d365ef5a097f321541f9548d62d136354a23d8b"],
 "dec.onnx":[312575029,"96029859b4d563f3aff266e97e715190e8d53278c6e27ab94095535a0da4c911"],
 "tokenizer.json":[1389353,"d2acde0d8d71dd30a711834b07781b9c89feaac33fd332f60507699282740066"]
};
let phase="worker startup", localProgress=null;
const status=message=>{phase=message;if(localProgress)localProgress(message);else postMessage({type:"progress",message});};
let runtime=null,busy=false;
async function artifact(name){
 const [size,hash]=FILES[name],cache=await caches.open("jk-sfx-onnx-sha256-v1"),key=new URL("model-cache/"+hash,self.location.href).href;
 let res=await cache.match(key),cached=!!res;
 if(!res){status(name+" download ("+Math.round(size/1048576)+" MiB)");res=await fetch("https://huggingface.co/"+MODEL+"/resolve/main/"+name,{credentials:"omit"});}
 if(!res.ok)throw Error(name+" HTTP "+res.status);
 let bytes;
 if(!cached&&res.body){
  const reader=res.body.getReader(),out=new Uint8Array(size);let offset=0,last=0;
  for(;;){const {done,value}=await reader.read();if(done)break;if(offset+value.length>size)throw Error(name+" exceeds expected size");out.set(value,offset);offset+=value.length;const pct=Math.floor(offset/size*100);if(pct>=last+5){last=pct;status(name+" download "+pct+"%");}}
  if(offset!==size)throw Error(name+" incomplete download "+offset+"/"+size);
  bytes=out.buffer;
 }else bytes=await res.arrayBuffer();
 status(name+" integrity check");
 if(bytes.byteLength!==size)throw Error(name+" wrong size");
 if(!cached){
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",bytes)),v=>v.toString(16).padStart(2,"0")).join("");
  if(digest!==hash)throw Error(name+" SHA-256 mismatch");
  try{await cache.put(key,new Response(bytes));}catch{status(name+" verified; browser cache quota exceeded");}
 }
 return bytes;
}
async function initialize(){
 status("GPU adapter check");
 if(!navigator.gpu)throw Error("WebGPU unavailable");
 const adapter=await navigator.gpu.requestAdapter({powerPreference:"high-performance"});
 if(!adapter||adapter.info?.isFallbackAdapter)throw Error("Hardware GPU adapter unavailable");
 status("ONNX Runtime module import");
 const ort=await import("https://cdn.jsdelivr.net/npm/onnxruntime-web@1.23.2/dist/ort.webgpu.min.mjs");
 status("T5 tokenizer module import");
 const {T5Tokenizer}=await import("https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.8.1/dist/transformers.min.js");
 if(typeof T5Tokenizer!=="function")throw Error("T5Tokenizer export unavailable");
 ort.env.wasm.numThreads=1;ort.env.wasm.wasmPaths="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.23.2/dist/";
 ort.env.webgpu.powerPreference="high-performance";
 const tokenizer=new T5Tokenizer(JSON.parse(new TextDecoder().decode(await artifact("tokenizer.json"))),{pad_token:"<pad>",eos_token:"</s>",unk_token:"<unk>",model_max_length:64});
 const sessions=[];
 try{
  for(const name of ["cond.onnx","dit.onnx"]){
   const bytes=await artifact(name);status(name+" initializing");
   sessions.push(await ort.InferenceSession.create(bytes,{executionProviders:[name==="cond.onnx"?"wasm":"webgpu"],graphOptimizationLevel:"all"}));
  }
  return {ort,tokenizer,cond:sessions[0],dit:sessions[1]};
 }catch(e){for(const s of sessions)await s.release();throw e;}
}
function normal(n,seed){
 let state=seed>>>0;const rand=()=>{state=(Math.imul(1664525,state)+1013904223)>>>0;return (state+1)/4294967297;};
 const data=new Float32Array(n);for(let i=0;i<n;i+=2){const r=Math.sqrt(-2*Math.log(rand())),a=2*Math.PI*rand();data[i]=r*Math.cos(a);if(i+1<n)data[i+1]=r*Math.sin(a);}return data;
}
function tensor(ort,meta,data,shape){
 const actual=meta.shape||[];if(actual.length!==shape.length||actual.some((v,i)=>typeof v==="number"&&v>0&&v!==shape[i]))throw Error("Unexpected shape: "+meta.name+" "+actual+" vs "+shape);
 if(meta.type==="int64")data=BigInt64Array.from(data,BigInt);
 else if(meta.type==="int32")data=Int32Array.from(data,Number);
 else if(meta.type==="bool")data=Uint8Array.from(data,Number);
 else if(meta.type==="float32")data=Float32Array.from(data,Number);
 else throw Error("Unsupported tensor: "+meta.name+" "+meta.type);
 return new ort.Tensor(meta.type,data,shape);
}
function makeWav(audio,seconds){
 const frames=audio.dims.at(-1),channels=audio.dims.at(-2);
 if(![1,2].includes(channels)||frames<seconds*44100||audio.data.length!==frames*channels)throw Error("Unexpected audio output");
 const n=Math.round(seconds*24000),pcm=new Float32Array(n);let peak=0;
 for(let i=0;i<n;i++){
  const p=i*44100/24000,j=Math.floor(p),k=Math.min(j+1,frames-1),f=p-j;
  let v=0;for(let c=0;c<channels;c++)v+=(audio.data[c*frames+j]*(1-f)+audio.data[c*frames+k]*f)/channels;
  if(!Number.isFinite(v))throw Error("Non-finite model output");pcm[i]=v;peak=Math.max(peak,Math.abs(v));
 }
 if(peak<1e-5)throw Error("Model produced silence");
 const out=new Uint8Array(44+n*2),dv=new DataView(out.buffer),tag=(p,s)=>{for(let i=0;i<s.length;i++)out[p+i]=s.charCodeAt(i);};
 tag(0,"RIFF");dv.setUint32(4,out.length-8,true);tag(8,"WAVE");tag(12,"fmt ");dv.setUint32(16,16,true);dv.setUint16(20,1,true);dv.setUint16(22,1,true);dv.setUint32(24,24000,true);dv.setUint32(28,48000,true);dv.setUint16(32,2,true);dv.setUint16(34,16,true);tag(36,"data");dv.setUint32(40,n*2,true);
 for(let i=0;i<n;i++){const fade=Math.min(1,i/120,(n-1-i)/120);dv.setInt16(44+i*2,Math.round(pcm[i]/peak*.78*fade*32767),true);}
 let str="";for(let i=0;i<out.length;i+=8192)str+=String.fromCharCode(...out.subarray(i,i+8192));return btoa(str);
}
// The exported decoder has a dynamic sequence axis. 256 latent frames
// represent 524288 audio samples; crop channel-major latent with context.
function cropDecoderLatent(x,dims,seconds){
 const full=dims[2],channels=dims[1],length=Math.min(full,Math.ceil(seconds*44100/2048)+8);
 if(dims[0]!==1||channels!==64||x.length!==channels*full||length<1)throw Error("Invalid latent geometry");
 const cropped=new Float32Array(channels*length);
 for(let c=0;c<channels;c++)cropped.set(x.subarray(c*full,c*full+length),c*length);
 if(!cropped.every(Number.isFinite))throw Error("Non-finite diffusion output");
 return {data:cropped,dims:[1,channels,length]};
}
async function decoderOrt(){
 const ort=await import("https://cdn.jsdelivr.net/npm/onnxruntime-web@1.23.2/dist/ort.webgpu.min.mjs");
 ort.env.wasm.numThreads=1;
 ort.env.wasm.wasmPaths="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.23.2/dist/";
 return ort;
}
async function decodeWithProvider({data,dims,seconds,provider},progress){
 const ort=await decoderOrt();
 const bytes=await artifact("dec.onnx");
 progress("Decoder "+provider+" initialization");
 const dec=await ort.InferenceSession.create(bytes,{executionProviders:[provider],graphOptimizationLevel:"all"});
 let input,outputs;
 try{
  const m=dec.inputMetadata[0];
  if(!m||dec.inputNames.length!==1)throw Error("Unexpected decoder inputs "+dec.inputNames);
  progress("Decoder "+provider+" run "+dims.join("x"));
  input=tensor(ort,m,data,dims);
  outputs=await dec.run({[m.name]:input});
  const audio=outputs[dec.outputNames[0]];
  const wav=makeWav(audio,seconds);
  return {wav,provider,outputShape:audio.dims};
 }finally{
  input?.dispose?.();
  for(const v of Object.values(outputs||{}))v.dispose?.();
  await dec.release();
 }
}
// Run decoder in a fresh worker so an ORT GPU exception cannot poison the
// CPU fallback's WASM heap. No upload: the latent remains on this device.
async function isolatedDecode(data,dims,seconds,provider){
 status("Decoder "+provider+" worker starting");
 const worker=new Worker("/asset-studio/neural-sfx/worker-v4.js",{type:"module"});
 return new Promise((resolve,reject)=>{
  let timer;
  function finish(error,result){clearTimeout(timer);worker.terminate();if(error)reject(error);else resolve(result);}
  function arm(){clearTimeout(timer);timer=setTimeout(()=>finish(Error("Decoder "+provider+" timed out")),240000);}
  worker.onerror=e=>finish(Error(e.message||"Decoder worker startup error"));
  worker.onmessage=({data:m})=>{
   if(m.type==="progress"){status(m.message);arm();}
   else if(m.type==="decoded")finish(null,m);
   else if(m.type==="error")finish(Error(m.message));
  };
  arm();worker.postMessage({type:"decode",data,dims,seconds,provider});
 });
}
async function decodeGenerated(x,dims,seconds){
 const cropped=cropDecoderLatent(x,dims,seconds);
 let gpuError;
 try{return await isolatedDecode(cropped.data,cropped.dims,seconds,"webgpu");}
 catch(e){gpuError=e.message||String(e);status("GPU decoder failed ("+gpuError+") · retrying on this PC CPU");}
 // Free the text/diffusion sessions before retrying to reduce peak memory.
 if(runtime){
  const r=await runtime;runtime=null;
  for(const session of [r.cond,r.dit]){try{await session.release();}catch{}}
 }
 try{return await isolatedDecode(cropped.data,cropped.dims,seconds,"wasm");}
 catch(e){throw Error("GPU: "+gpuError+"; CPU: "+(e.message||String(e)));}
}
async function generate(prompt,seconds,seed){
 runtime??=initialize().catch(e=>{runtime=null;throw e;});
 const {ort,tokenizer,cond,dit}=await runtime;
 const idsMeta=cond.inputMetadata.find(m=>/input_ids|token_ids|^ids$/i.test(m.name));
 if(!idsMeta)throw Error("Unknown conditioner inputs: "+cond.inputNames.join(","));
 const len=Number(idsMeta.shape.at(-1))||64;
 status("Tokenizer encode");
 const tokens=await tokenizer(prompt,{padding:"max_length",max_length:len,truncation:true});
 const feeds={};
 for(const m of cond.inputMetadata){
  if(m===idsMeta)feeds[m.name]=tensor(ort,m,tokens.input_ids.data,[1,len]);
  else if(/mask/i.test(m.name))feeds[m.name]=tensor(ort,m,tokens.attention_mask.data,[1,len]);
  else if(/seconds|duration/i.test(m.name))feeds[m.name]=tensor(ort,m,[/start/i.test(m.name)?0:seconds],m.shape.length===0?[]:m.shape.length===2?[1,1]:[1]);
  else throw Error("Unknown conditioner input "+m.name);
 }
 status("Text conditioning "+JSON.stringify(cond.inputMetadata.map(m=>[m.name,m.shape,m.type])));
 const conditioning=await cond.run(feeds);
 const cross=Object.entries(conditioning).find(([k,v])=>/cross/i.test(k)||v.dims.length===3)?.[1];
 const global=Object.entries(conditioning).find(([k,v])=>/global/i.test(k)||v.dims.length===2)?.[1];
 if(!cross||!global)throw Error("Unknown conditioner outputs: "+Object.keys(conditioning).join(","));
 const xmeta=dit.inputMetadata.find(m=>/^(x|latent|latents|sample|noise)$/i.test(m.name));
 if(!xmeta)throw Error("Unknown latent input: "+dit.inputNames.join(","));
 const dims=xmeta.shape.map((v,i)=>typeof v==="number"&&v>0?v:[1,64,256][i]);
 if(dims.length!==3||dims[0]!==1||dims[1]!==64||dims[2]<1||dims[2]>256)throw Error("Unsupported latent geometry "+dims);
 let x=normal(dims[1]*dims[2],seed);
 const times=Array.from({length:9},(_,i)=>i===0?1:i===8?0:1/(1+Math.exp(-(8.2*(1-i/8)-2))));
 for(let i=0;i<8;i++){
  status("GPU diffusion "+(i+1)+"/8");
  const f={};
  for(const m of dit.inputMetadata){
   if(m===xmeta)f[m.name]=tensor(ort,m,x,dims);
   else if(/^(t|time|timestep|timesteps)$/i.test(m.name))f[m.name]=tensor(ort,m,[times[i]],m.shape.length===0?[]:[1]);
   else if(/cross|context/i.test(m.name))f[m.name]=cross;
   else if(/global/i.test(m.name))f[m.name]=global;
   else throw Error("Unknown diffusion input "+m.name);
  }
  const outputs=await dit.run(f),v=outputs[dit.outputNames[0]];
  if(v.data.length!==x.length)throw Error("Wrong diffusion output size");
  const next=times[i+1],noise=next>0?normal(x.length,(seed+i+1)>>>0):null;
  for(let j=0;j<x.length;j++)x[j]=(1-next)*(x[j]-times[i]*v.data[j])+(noise?next*noise[j]:0);
  v.dispose?.();
 }
 cross.dispose?.();global.dispose?.();
 status("Waveform decoding · requested duration "+seconds+" s");
 const decoded=await decodeGenerated(x,dims,seconds);
 return {seed,wav:decoded.wav,decoder:decoded.provider};
}
async function runNeuralSfx(data,progress){
 if(busy)throw Error("Generation already running");busy=true;localProgress=progress;
 try{
  if(typeof data.prompt!=="string"||!data.prompt.trim()||data.prompt.length>450||!Number.isFinite(data.seconds)||data.seconds<.5||data.seconds>3)throw Error("Invalid input");
  const variants=[];
  for(let i=0;i<2;i++){status("Variant "+(i+1)+"/2");variants.push(await generate(data.prompt,data.seconds,crypto.getRandomValues(new Uint32Array(1))[0]));}
  return {type:"complete",model:MODEL,variants};
 }catch(e){throw Error("["+phase+"] "+(e?.message||String(e)));}finally{busy=false;localProgress=null;}
}
if(typeof document==="undefined"){
 self.onmessage=async({data})=>{
  if(data.type==="ping"){postMessage({type:"pong",version:4});return;}
  if(data.type==="decode"){
   try{
    if(!["wasm","webgpu"].includes(data.provider)||!(data.data instanceof Float32Array)||data.dims?.length!==3||data.dims[0]!==1||data.dims[1]!==64||data.dims[2]>80||data.dims[2]<1||data.data.length!==64*data.dims[2]||!Number.isFinite(data.seconds)||data.seconds<.5||data.seconds>3)throw Error("Invalid decoder request");
    const result=await decodeWithProvider(data,msg=>postMessage({type:"progress",message:msg}));postMessage({type:"decoded",...result});
   }catch(e){postMessage({type:"error",message:"["+phase+"] "+(e?.message||String(e))});}return;
  }
  if(data.type!=="generate")return;
  try{postMessage(await runNeuralSfx(data,msg=>postMessage({type:"progress",message:msg})));}
  catch(e){postMessage({type:"error",message:e.message});}
 };
}else{
 globalThis.JKNeuralSfxLocal=Object.freeze({version:4,run:runNeuralSfx});
}
