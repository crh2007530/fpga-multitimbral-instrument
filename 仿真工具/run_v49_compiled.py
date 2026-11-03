from pathlib import Path
import os,sys,json,hashlib,subprocess,time
root=Path(__file__).resolve().parent
p=Path(os.environ.get('CONSOLE60_SOURCE',root/'single60_v49_guitar_strum128'));out=root/sys.argv[1]
assert out.parent==root and out.is_dir()
inputs=json.loads((out/'source_inputs_sha256.json').read_text())
def same():return all(hashlib.sha256((p/n).read_bytes()).hexdigest()==h for n,h in inputs.items())
assert same(),'Sources changed since compilation'
env=os.environ.copy();env['PATH']=str(root/'tools/llvm-mingw-20261020-ucrt-x86_64/bin')+';'+env['PATH']
start=time.monotonic()
with (out/'run.log').open('w') as f:r=subprocess.run([str(out/'capture.exe')],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=7200)
log=(out/'run.log').read_text();ok=r.returncode==0 and 'PASS' in log and 'FATAL' not in log and same()
result={'passed':ok,'exit':r.returncode,'wall_seconds':time.monotonic()-start,'source_unchanged':same(),'clock_compression':False,'tool':'Verilator 5.053; two-state; constant-function portability adapter','pass_lines':[s for s in log.splitlines() if 'PASS' in s]}
(out/'result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2),flush=True)
raise SystemExit(0 if ok else 1)
