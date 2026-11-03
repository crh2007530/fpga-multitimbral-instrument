"""Refine only guitar periodic harmonic-envelope tables from the existing reference.
No recorded PCM is placed in FPGA memory; piano/reed/diagnostic tables unchanged.
"""
from pathlib import Path
import json,hashlib,re,subprocess
import numpy as np
root=Path(__file__).resolve().parent;p=root/'single60_v50_instrument_mixer128'
old=json.loads((p/'assets/approved_nylon_model.json').read_text())
reference=Path('E:/代码/音色参考_网站参数提取_20261024/nylon_samples/A3.mp3')
fs=48000
decoded=subprocess.run(['E:/codexput/2026-10-15/e-mv-gpt-mv-35/work/tools/ffmpeg.exe','-v','error','-i',str(reference),'-f','f64le','-ac','1','-ar',str(fs),'-'],capture_output=True,check=True)
x=np.frombuffer(decoded.stdout,dtype='<f8')
onset=int(np.argmax(np.abs(x)>np.max(np.abs(x))*.025));x=x[onset:]
f0=old['fitted_hz'];h=np.arange(1,33);knots=np.array(old['knots_seconds'])
def fit(t):
    # 6 fundamental cycles resolve partials without smearing the first 93 ms.
    n=round(fs*6/f0);start=max(0,min(len(x)-n,round(t*fs)-n//2))
    a=x[start:start+n];time=(start+np.arange(n))/fs;w=np.hanning(n)
    phase=2*np.pi*time[:,None]*f0*h
    basis=np.column_stack([np.cos(phase),np.sin(phase),np.ones(n)])
    coeff=np.linalg.lstsq(basis*w[:,None],a*w,rcond=None)[0]
    return np.hypot(coeff[:32],coeff[32:64])
amplitudes=np.stack([fit(t) for t in knots]);amplitudes[0]=0;amplitudes[-1]=0
# The attack knot is a rising amplitude, not a nonzero waveform at key-on.
amplitudes[1]*=.75
times=np.linspace(.015,1.5,80);truth=np.stack([fit(t) for t in times])
def error(amps):
    interp=np.stack([np.interp(times,knots,amps[:,i]) for i in range(32)],axis=1)
    # Remove one global gain only; retain envelope/partial relationships.
    gain=float((interp*truth).sum()/(interp*interp).sum())
    return float(np.linalg.norm(interp*gain-truth)/np.linalg.norm(truth))
before=error(np.array(old['amplitudes']));after=error(amplitudes)
assert after<before,(before,after)
phase=np.arange(512)/512
waves=np.array([sum(amp*np.cos(2*np.pi*(i+1)*phase+old['initial_phases_radians'][i]) for i,amp in enumerate(row)) for row in amplitudes])
scale=26000/np.max(np.abs(waves));waves=np.rint(waves*scale).astype(int)
f=p/'assets/approved_oscillators.hex';words=f.read_text().split();tail=words[6656:]
words[:6656]=[f'{int(v)&65535:04x}' for v in waves.ravel()]
assert words[6656:]==tail and len(words)==8192
f.write_text('\n'.join(words)+'\n')
# Regenerate exact native DPB INIT data, preserving the wrapper and timing.
rom=p/'rtl/approved_wave_rom.v';s=rom.read_text();index=0
def init(m):
    global index
    values=words[index*16:(index+1)*16];index+=1
    return m[1]+''.join(reversed(values))+m[3]
s=re.sub(r"(\.INIT_RAM_[0-9A-F]{2}\(256'h)([0-9a-fA-F]{64})(\))",init,s)
assert index==512;rom.write_text(s)
new=dict(old);new.update(amplitudes=amplitudes.tolist(),method='32 harmonic periodic tables; 6-cycle windowed LS envelope refit, original phases retained; no recorded PCM playback',reference_sha256=hashlib.sha256(reference.read_bytes()).hexdigest())
(p/'assets/approved_nylon_model.json').write_text(json.dumps(new,ensure_ascii=False,indent=2))
report={'reference':str(reference),'reference_sha256':new['reference_sha256'],'onset_sample':onset,'reference_sample_rate':fs,'harmonics':32,'periodic_table_words':6656,'fit_window_cycles':6,'relative_harmonic_envelope_error_before':before,'relative_harmonic_envelope_error_after':after,'metric_scope':'Offline 32-partial amplitude-envelope fit, 80 sample times; not a listening score or FPGA output comparison','unchanged_words_after_index':6656,'peak_table_value':int(np.max(np.abs(waves))),'synthesis_scale':scale}
(p/'checks/nylon_refinement.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
