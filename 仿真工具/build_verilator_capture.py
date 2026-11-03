from pathlib import Path
import subprocess,os,json,hashlib,shutil,sys
root=Path(__file__).resolve().parent;p=Path(os.environ.get('CONSOLE60_SOURCE',root/'single60_v47_valid_datapath128'))
out=root/(sys.argv[1] if len(sys.argv)>1 else 'v47_verilator_capture');out.mkdir(exist_ok=True);(out/'checks').mkdir(exist_ok=True)
top=sys.argv[2] if len(sys.argv)>2 else 'tb_128_spectrum_capture'
bench=out/(top+'.v') if len(sys.argv)>2 else p/('tb/'+top+'.v')
suite=Path(os.environ.get('CONSOLE60_OSS_SUITE',root/'tools/oss-cad-suite'))
env=os.environ.copy();env['PATH']=str(suite/'bin')+';'+str(suite/'lib')+';'+env['PATH'];env['VERILATOR_ROOT']=str(suite/'share/verilator')
if not (out/'assets').exists():shutil.copytree(p/'assets',out/'assets')
sources=[bench,*sorted((p/'rtl').rglob('*.v')),p/'tb/audio_pll_model.v',p/'tb/video_ip_models.v']
# Verilator rejects a constant function inside a generate scope that Gowin
# and Icarus accept. Hoist only the constant bit-plane extraction function;
# its 1024-bit constant is now an explicit argument. No timed logic changes.
phase=p/'rtl/ram_phase_bank.v';s=phase.read_text()
old=' function[31:0]plane_bits;input integer bn;integer n;\n begin for(n=0;n<32;n=n+1)plane_bits[n]=TEST_BITS[n*32+bn];end endfunction\n'
assert old in s
s=s.replace(old,'').replace('PLANE=plane_bits(bit_number)','PLANE=plane_bits_module(TEST_BITS,bit_number)')
s=s.replace('genvar g,bit_number;', 'function[31:0]plane_bits_module;input[1023:0]bits;input integer bn;integer n;\nbegin for(n=0;n<32;n=n+1)plane_bits_module[n]=bits[n*32+bn];end endfunction\ngenvar g,bit_number;')
adapted=out/'ram_phase_bank_portable.v';adapted.write_text(s)
sources=[adapted if f==phase else f for f in sources]
(out/'constant_function_adapter.json').write_text(json.dumps({'original_sha256':hashlib.sha256(phase.read_bytes()).hexdigest(),'adapted_sha256':hashlib.sha256(adapted.read_bytes()).hexdigest(),'change':'Hoist compile-time constant bit-plane function from generate scope, passing TEST_BITS explicitly; no timed logic changes'},indent=2))
hashes={str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for d in ['rtl','assets','ip','tb'] for f in sorted((p/d).rglob('*')) if f.is_file()}
(out/'source_inputs_sha256.json').write_text(json.dumps(hashes,indent=2))
cmd=[str(suite/'bin/verilator_bin.exe'),'--cc','--main','--timing','--top-module',top,'--prefix','Vcapture','--Mdir',str(out/'obj'),'-Wno-fatal','-D__ICARUS__','-I'+str(p),*map(str,sources)]
(out/'codegen_command.json').write_text(json.dumps(cmd,indent=2))
with (out/'codegen.log').open('w') as f:r=subprocess.run(cmd,cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT)
print('Code generation exit',r.returncode,flush=True)
raise SystemExit(r.returncode)
