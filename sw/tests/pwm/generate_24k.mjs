// Run with Node.js to regenerate pwm_24k_program.hex and program_24k.lst.
import fs from 'node:fs';
const code=[], labels={}, fix=[];
const emit=(w,s)=>code.push({w:w>>>0,s});
const label=n=>labels[n]=code.length;
const addi=(d,s,i)=>emit(((i&4095)<<20)|(s<<15)|(d<<7)|0x13,`addi x${d}, x${s}, ${i}`);
const store=(s,b,o,f=2)=>emit(((o>>5)<<25)|(s<<20)|(b<<15)|(f<<12)|((o&31)<<7)|0x23,`${f===2?'sw':'sb'} x${s}, ${o}(x${b})`);
const load=(d,b,o)=>emit((o<<20)|(b<<15)|(2<<12)|(d<<7)|3,`lw x${d}, ${o}(x${b})`);
const bne=(a,b,l)=>{fix.push({i:code.length,a,b,l});emit(0,`bne x${a}, x${b}, ${l}`);};
const check=(offset)=>{load(3,1,offset);bne(3,2,'fail');};
const li=(d,v)=>{const upper=(v+2048)>>12; emit((upper<<12)|(d<<7)|0x37,`lui x${d}, ${upper}`); addi(d,d,v-(upper<<12));};
const delay=(n)=>{li(4,4000); label(n); addi(4,4,-1); bne(4,0,n);};
emit(0x000120b7,'lui x1, 0x12');
li(2,2000);store(2,1,4);check(4);
li(2,500);store(2,1,8);check(8);
addi(2,0,1);store(2,1,0);check(0);
delay('d25');
for(const h of [1000,1500]){
 li(2,h);store(2,1,8);check(8);delay('d'+h);
}
addi(2,0,0);store(2,1,0);check(0);
addi(20,0,1);label('pass');emit(0x6f,'jal x0, pass');
label('fail');addi(20,0,-1);emit(0x6f,'jal x0, fail_loop');
for(const {i,a,b,l} of fix){
 const o=(labels[l]-i)*4;
 code[i].w=((((o>>12)&1)<<31)|(((o>>5)&63)<<25)|(b<<20)|(a<<15)|(1<<12)|(((o>>1)&15)<<8)|(((o>>11)&1)<<7)|0x63)>>>0;
}
const dir=new URL('./',import.meta.url);
fs.writeFileSync(new URL('pwm_24k_program.hex',dir),code.map(x=>x.w.toString(16).padStart(8,'0')).join('\n')+'\n');
fs.writeFileSync(new URL('program_24k.lst',dir),code.map((x,i)=>(0x1000+i*4).toString(16)+' '+x.w.toString(16).padStart(8,'0')+' '+x.s).join('\n')+'\n');
