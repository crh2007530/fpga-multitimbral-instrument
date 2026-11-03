package cn.console60.control;
import java.io.*;
/** Decoder for actual FPGA PCM packets. Corruption is never hidden. */
public final class StreamProtocol {
 public int nextSequence=0;public long dropped=0;public boolean ended=false;
 public byte[] decode(byte[] frame)throws IOException{
  if(frame.length<11 || (frame[0]&255)!=0xa5 || (frame[1]&255)!=0x5a)throw new IOException("录音包头错误");
  int n=frame[4]&255;if(n>64 || frame.length!=11+n)throw new IOException("录音包长度错误");
  int sum=0;for(int i=2;i<frame.length;i++)sum+=frame[i]&255;if((sum&255)!=0)throw new IOException("录音校验失败");
  int seq=ExtProtocol.u16(frame,2);if(seq!=nextSequence)throw new IOException("录音丢包：期望"+nextSequence+"，收到"+seq);
  nextSequence=(nextSequence+1)&65535;
  dropped=0;for(int i=0;i<4;i++)dropped|=(long)(frame[6+i]&255)<<(8*i);
  if(dropped!=0)throw new IOException("FPGA录音缓冲溢出，丢失"+dropped+"个采样；此录音不能作为完整记录");
  if((frame[5]&254)!=0)throw new IOException("未知录音标记");ended=(frame[5]&1)!=0;
  byte[] pcm=new byte[n];System.arraycopy(frame,10,pcm,0,n);return pcm;
 }
 public static byte[] adsr(int attackMs,int decayMs,int sustainPercent,int releaseMs,boolean enabled){
  if(attackMs<0||attackMs>682||decayMs<0||decayMs>682||releaseMs<0||releaseMs>682||sustainPercent<0||sustainPercent>100)throw new IllegalArgumentException("A/D/R范围0–682ms，S范围0–100%");
  int s=(int)Math.round(32767.0*sustainPercent/100);
  int[] vals={step(32767,attackMs),step(32767-s,decayMs),s,step(32767,releaseMs)};
  byte[] b=new byte[9];b[0]=(byte)(enabled?1:0);for(int i=0;i<4;i++){b[1+2*i]=(byte)vals[i];b[2+2*i]=(byte)(vals[i]>>8);}return b;
 }
 static int step(int delta,int ms){return ms==0?32767:Math.max(1,Math.min(32767,(int)Math.ceil(delta/(48.046875*ms))));}
 public static String actualTimes(byte[] b){
  int a=ExtProtocol.u16(b,1),d=ExtProtocol.u16(b,3),s=ExtProtocol.u16(b,5),r=ExtProtocol.u16(b,7);
  return String.format(java.util.Locale.ROOT,"ADSR已应用；量化后A约%.1fms、D约%.1fms、满幅R约%.1fms",
   Math.ceil(32767.0/a)/48.046875,Math.ceil((32767.0-s)/d)/48.046875,Math.ceil(32767.0/r)/48.046875);
 }
}
