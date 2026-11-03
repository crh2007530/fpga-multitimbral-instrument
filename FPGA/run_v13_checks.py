from pathlib import Path
import subprocess,sys,json,time,os,shutil
p=Path(__file__).resolve().parent
tool=Path(r'E:\codexput\2026-10-15\id-01a13492-2d74-7ce1-b42b-d8add5f3f54e\outputs\TangConsole60K_8Pad_Handoff_20261015\04_源码与仿真\iverilog\bin')
tool=Path(os.environ['IVERILOG_BIN']) if os.environ.get('IVERILOG_BIN') else (Path(shutil.which('iverilog')).parent if shutil.which('iverilog') else tool)
(p/'checks').mkdir(exist_ok=True)
rtl=[str(x.relative_to(p)) for x in (p/'rtl').rglob('*.v')]+['tb/audio_pll_model.v','tb/video_ip_models.v']
results=[]
for name in sys.argv[1:]:
 print('START',name,flush=True)
 sources=rtl
 if name=='tb_v26_palette':
  sources=['rtl/video_ship.v',os.environ.get('GOWIN_PRIM_SIM',r'E:\Gowin\Gowin_V1.9.12.04_x64\IDE\simlib\gw5a\prim_sim.v')]
 if name=='tb_video_serializer_start':
  sources=['rtl/video_serializer_start.v',os.environ.get('GOWIN_PRIM_SIM',r'E:\Gowin\Gowin_V1.9.12.04_x64\IDE\simlib\gw5a\prim_sim.v')]
 extra=[]
 if name in ['tb_dualrom','tb_web_bank_native','tb_controlrom','tb_state_ram_equivalence','tb_state_ram_small','tb_sum_vectors']:
  sources=['rtl/approved_wave_rom.v',os.environ.get('GOWIN_PRIM_SIM',r'E:\Gowin\Gowin_V1.9.12.04_x64\IDE\simlib\gw5a\prim_sim.v')]
  extra=['-DNATIVE_DPB']
  if name=='tb_controlrom':sources[0]='rtl/approved_control_rom.v'
  if name in ['tb_web_bank_native','tb_state_ram_equivalence','tb_state_ram_small','tb_sum_vectors']:sources+=['rtl/shared_voice_bank.v','rtl/shared_voice_bank_legacy.v','rtl/approved_control_rom.v','rtl/voice_state_ram.v']
 if name in ['tb_state_ram_equivalence','tb_state_ram_small','tb_sum_vectors']:sources+=['tb/reference_voice_bank.v']
 c=subprocess.run([str(tool/'iverilog.exe')]+extra+['-g2012','-s',name,'-o','checks/'+name+'.vvp','tb/'+name+'.v']+sources,cwd=p,capture_output=True,text=True)
 (p/'checks'/(name+'_compile.log')).write_text(c.stdout+c.stderr,encoding='utf-8')
 if c.returncode:raise RuntimeError(c.stderr)
 if name in ['tb_v22_full_render','tb_v26_full_render','tb_v27_full_render']:
  # Independent raster scenes share no state; render them concurrently.
  from concurrent.futures import ThreadPoolExecutor
  def render_mode(mode):
   out=p/'checks'/f'{name}_{mode}.log'
   with out.open('w') as f:
    r=subprocess.run([str(tool/'vvp.exe'),'-v','checks/'+name+'.vvp',f'+MODE={mode}'],cwd=p,stdout=f,stderr=subprocess.STDOUT,timeout=7200)
   return r.returncode,out.read_text()
  with ThreadPoolExecutor(max_workers=4) as pool: frames=list(pool.map(render_mode,range(2 if name in ['tb_v26_full_render','tb_v27_full_render'] else 4)))
  rc=0 if all(code==0 and 'PASS' in log and 'FATAL' not in log and 'ERROR' not in log for code,log in frames) else 1
  (p/'checks'/(name+'.log')).write_text('\n'.join(log for code,log in frames),encoding='utf-8')
 else:
  with (p/'checks'/(name+'.log')).open('w') as f:
   r=subprocess.Popen([str(tool/'vvp.exe'),'-v','checks/'+name+'.vvp'],cwd=p,stdout=f,stderr=subprocess.STDOUT)
   try:rc=r.wait(timeout=21600 if name=='tb_128_spectrum_capture' else 7200 if name=='tb_v22_full_render' else 3600 if name=='tb_approved_melody' else 7200)
   except subprocess.TimeoutExpired:r.terminate();r.wait();rc=-999
 log=(p/'checks'/(name+'.log')).read_text();ok=rc==0 and 'PASS' in log and 'FATAL' not in log and 'ERROR' not in log
 result=dict(test=name,passed=ok,exit=rc)
 results.append(result);(p/'checks'/(name+'_result.json')).write_text(json.dumps(result,indent=2))
 (p/'checks'/'v13_results.json').write_text(json.dumps(results,indent=2))
 print(log[-3000:],flush=True)
 if not ok:raise RuntimeError(name)

