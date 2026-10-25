function sha256bytes(input){
  const K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  function toB(s){const b=[];for(let i=0;i<s.length;i++){let c=s.charCodeAt(i);if(c<0x80)b.push(c);else if(c<0x800)b.push(0xC0|(c>>6),0x80|(c&0x3F));else b.push(0xE0|(c>>12),0x80|((c>>6)&0x3F),0x80|(c&0x3F));}return b;}
  let b=typeof input==='string'?toB(input):Array.from(input);
  const l=b.length;b.push(0x80);while(b.length%64!==56)b.push(0);
  const bl=l*8;b.push(0,0,0,0,(bl>>>24)&0xff,(bl>>>16)&0xff,(bl>>>8)&0xff,bl&0xff);
  let h=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
  const r=(x,n)=>((x>>>n)|(x<<(32-n)))>>>0;const a=(x,y)=>(x+y)>>>0;
  for(let i=0;i<b.length;i+=64){
    const w=Array(64);
    for(let j=0;j<16;j++)w[j]=((b[i+j*4]<<24)|(b[i+j*4+1]<<16)|(b[i+j*4+2]<<8)|b[i+j*4+3])>>>0;
    for(let j=16;j<64;j++){const s0=r(w[j-15],7)^r(w[j-15],18)^(w[j-15]>>>3);const s1=r(w[j-2],17)^r(w[j-2],19)^(w[j-2]>>>10);w[j]=a(a(a(w[j-16],s0),w[j-7]),s1);}
    let[aa,bb,cc,dd,ee,ff,gg,hh]=h;
    for(let j=0;j<64;j++){
      const S1=r(ee,6)^r(ee,11)^r(ee,25);const ch=((ee&ff)^(~ee&gg))>>>0;
      const t1=a(a(a(a(hh,S1),ch),K[j]),w[j]);
      const S0=r(aa,2)^r(aa,13)^r(aa,22);const mj=((aa&bb)^(aa&cc)^(bb&cc))>>>0;
      const t2=a(S0,mj);hh=gg;gg=ff;ff=ee;ee=a(dd,t1);dd=cc;cc=bb;bb=aa;aa=a(t1,t2);
    }
    h[0]=a(h[0],aa);h[1]=a(h[1],bb);h[2]=a(h[2],cc);h[3]=a(h[3],dd);
    h[4]=a(h[4],ee);h[5]=a(h[5],ff);h[6]=a(h[6],gg);h[7]=a(h[7],hh);
  }
  return h.reduce((acc,v)=>{acc.push((v>>>24)&0xff,(v>>>16)&0xff,(v>>>8)&0xff,v&0xff);return acc;},[]);
}
function hmacSha256(key,msg){
  function toB(s){const b=[];for(let i=0;i<s.length;i++){let c=s.charCodeAt(i);if(c<0x80)b.push(c);else if(c<0x800)b.push(0xC0|(c>>6),0x80|(c&0x3F));else b.push(0xE0|(c>>12),0x80|((c>>6)&0x3F),0x80|(c&0x3F));}return b;}
  let kB=toB(key);if(kB.length>64)kB=sha256bytes(kB);
  const kP=new Array(64).fill(0);kB.forEach((v,i)=>kP[i]=v);
  const ipad=kP.map(v=>v^0x36);const opad=kP.map(v=>v^0x5c);
  const mB=toB(msg);
  return sha256bytes([...opad,...sha256bytes([...ipad,...mB])]);
}

function b64url(buf) { return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, ''); }
const STAFF_KEY = () => `${$env.JWT_SECRET}|mypaltan-staff`;
function signStaff(u) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = b64url(Buffer.from(JSON.stringify({ typ: 'staff', sid: u.id, role: u.role, iat: now, exp: now + 12 * 60 * 60 })));
  return { token: `${header}.${body}.${b64url(hmacSha256(STAFF_KEY(), `${header}.${body}`))}`, expires_at: (now + 12 * 60 * 60) * 1000 };
}
function verifyStaff(headers) {
  const auth = String((headers || {}).authorization || '').trim();
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  const fail = { ok: false, error: 'Please log in again.' };
  const parts = token.split('.');
  if (parts.length !== 3) return fail;
  const [h, p, s] = parts;
  if (b64url(hmacSha256(STAFF_KEY(), `${h}.${p}`)) !== s) return fail;
  let c;
  try { c = JSON.parse(Buffer.from(p, 'base64').toString('utf8')); } catch { return fail; }
  if (c.typ !== 'staff' || !Number.isInteger(c.sid)) return fail;
  if (!c.exp || c.exp < Math.floor(Date.now() / 1000)) return { ok: false, error: 'Your session expired. Please log in again.' };
  return { ok: true, sid: c.sid };
}

const auth = verifyStaff($in.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];

