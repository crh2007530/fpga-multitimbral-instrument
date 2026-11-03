"""Evaluate captured HDL PCM only. Never synthesize or substitute test samples."""
from pathlib import Path
import json,hashlib,csv,sys
import numpy as np
p=(Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent/'single60_v37_independent128')/'checks'
result=json.loads((p/'tb_128_spectrum_capture_result.json').read_text())
if not result.get('passed'):raise RuntimeError('RTL capture has not passed')
names=['spectrum128_all.txt','spectrum128_muted_1_64_65_128.txt']
data=[np.loadtxt(p/n,dtype=np.int16) for n in names]
if any(len(x)!=4096 for x in data):raise RuntimeError('Incomplete PCM file')
# Diagnostic release is 9 amplitude units/sample. Discard the first half of
# the second capture: 512 settling + 2048 discarded samples exceeds 19660/9.
# The final all-on window likewise excludes the attack/decay transient.
fs=24600000/512;n=2048;window=np.hanning(n)
spectra=[np.abs(np.fft.rfft(x[-n:].astype(float)*window)) for x in data]
rows=[];muted={0,63,64,127};fail=[]
for i in range(128):
 frequency=257+83*i;k=round(frequency*n/fs)
 bins=range(max(1,k-1),min(len(spectra[0])-1,k+2))
 peak=max(bins,key=lambda b:spectra[0][b]);a=float(spectra[0][peak])
 b=float(max(spectra[1][j] for j in bins))
 delta=float(20*np.log10(max(b,1e-12)/max(a,1e-12)))
 local=a>spectra[0][peak-1] and a>spectra[0][peak+1]
 if not local or a<max(spectra[0])*0.1:fail.append(f'voice {i+1}: missing distinct audible peak')
 if i in muted and delta>-20:fail.append(f'voice {i+1}: mute attenuation only {delta:.2f} dB')
 if i not in muted and abs(delta)>3:fail.append(f'voice {i+1}: unmuted amplitude changed {delta:.2f} dB')
 rows.append(dict(voice=i+1,target_hz=frequency,fft_bin=peak,bin_hz=peak*fs/n,all_on_magnitude=a,after_mute_magnitude=b,change_db=delta,requested_mute=i in muted,distinct_peak=bool(local)))
with (p/'128路真实RTL频谱测量.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
report=dict(passed=not fail,source='actual RTL monitor_pcm samples, no generated replacement',sample_rate_hz=fs,captured_samples_per_case=4096,fft_samples_per_case=n,window='Hann; final2048 samples; excludes release tail',independent_peaks=sum(r['distinct_peak'] for r in rows),muted_voices=[1,64,65,128],errors=fail,source_sha256={name:hashlib.sha256((p/name).read_bytes()).hexdigest() for name in names})
(p/'spectrum128_analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
if fail:raise SystemExit(1)
