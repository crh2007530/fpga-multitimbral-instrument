package cn.console60.control;
import java.util.*;
/** Finite offline score: a pad mask and time to next event, in milliseconds. */
public final class TimedChart {
 public final int[] masks,durations;
 private TimedChart(int[] m,int[] d){masks=m;durations=d;}
 public int size(){return masks.length;}
 public static TimedChart parse(String text){
  ArrayList<Integer> m=new ArrayList<>(),d=new ArrayList<>();
  String cleaned=text.replace("\uFEFF","").trim();
  if(!cleaned.contains(":")){
   byte[] legacy=ExtProtocol.chart(cleaned);
   for(byte b:legacy){m.add(b&255);d.add(500);}
  }else for(String raw:cleaned.split("\\r?\\n")){
   String line=raw.split("#",2)[0].trim();if(line.isEmpty())continue;
   for(String item:line.split("[\\s,;]+")){
    String[] a=item.split(":",-1);
    if(a.length!=2||!a[0].matches("[0-9a-fA-F]{2}")||!a[1].matches("[0-9]{1,5}"))throw new IllegalArgumentException("格式为 掩码:毫秒，例如01:250；00表示休止");
    int mask=Integer.parseInt(a[0],16),ms=Integer.parseInt(a[1]);
    if(ms<20||ms>60000)throw new IllegalArgumentException("每项时长范围20–60000ms");
    m.add(mask);d.add(ms);if(m.size()>1024)throw new IllegalArgumentException("曲谱最多1024个事件");
   }
  }
  if(m.isEmpty())throw new IllegalArgumentException("曲谱不能为空");
  int[] mm=new int[m.size()],dd=new int[m.size()];for(int i=0;i<mm.length;i++){mm[i]=m.get(i);dd[i]=d.get(i);}
  return new TimedChart(mm,dd);
 }
 public byte[] begin(){return new byte[]{(byte)size(),(byte)(size()>>8)};}
 public byte[] block(int offset){
  if(offset<0||offset>=size())throw new IllegalArgumentException("offset");
  int n=Math.min(10,size()-offset);byte[] b=new byte[2+3*n];b[0]=(byte)offset;b[1]=(byte)(offset>>8);
  for(int i=0;i<n;i++){int j=offset+i;b[2+3*i]=(byte)masks[j];b[3+3*i]=(byte)durations[j];b[4+3*i]=(byte)(durations[j]>>8);}return b;
 }
}
