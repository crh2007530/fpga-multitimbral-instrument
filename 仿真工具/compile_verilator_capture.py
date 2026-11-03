from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,os,json,time,sys
root=Path(__file__).resolve().parent;out=root/(sys.argv[1] if len(sys.argv)>1 else 'v47_verilator_capture');obj=out/'obj'
llvm=Path(os.environ.get('CONSOLE60_LLVM_BIN',root/'tools/llvm-mingw-20261020-ucrt-x86_64/bin'));inc=Path(os.environ.get('CONSOLE60_OSS_SUITE',root/'tools/oss-cad-suite'))/'share/verilator/include'
env=os.environ.copy();env['PATH']=str(llvm)+';'+env['PATH']
cxx=str(llvm/'clang++.exe')
src=list(obj.glob('*.cpp'))+[inc/(x+'.cpp') for x in ['verilated','verilated_timing','verilated_threads']]
commands=[]
def compile_one(f):
 target=obj/(f.stem+'.o')
 cmd=[cxx,'-std=c++20','-O2','-pthread','-DVL_TIME_CONTEXT','-I'+str(obj),'-I'+str(inc),'-I'+str(inc/'vltstd'),'-c',str(f),'-o',str(target)]
 commands.append(cmd)
 with (obj/(f.stem+'.compile.log')).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
 if r.returncode:raise RuntimeError(str(f)+' compilation failed')
 print('Compiled',f.name,flush=True);return target
with ThreadPoolExecutor(max_workers=4) as pool:objects=list(pool.map(compile_one,src))
cmd=[cxx,'-std=c++20','-O2','-pthread',*map(str,objects),'-o',str(out/'capture.exe')]
commands.append(cmd)
with (out/'link.log').open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT)
(out/'compile_commands.json').write_text(json.dumps(commands,indent=2))
if r.returncode:raise RuntimeError('Link failed')
print('Built',out/'capture.exe',flush=True)
