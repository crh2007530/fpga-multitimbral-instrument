import cn.console60.control.*;import java.nio.file.*;import java.io.*;
public class V20Test {
 static void check(boolean b,String m){if(!b)throw new AssertionError(m);}
 static void bad(String s){try{TimedChart.parse(s);throw new AssertionError("accepted "+s);}catch(IllegalArgumentException good){}}
 public static void main(String[] args)throws Exception{
  TimedChart c=TimedChart.parse("01:250 00:500\n03:60000 # chord\n80:20");
  check(c.size()==4&&c.masks[1]==0&&c.durations[2]==60000,"parse");
  byte[] b=c.block(0);check(b.length==14&&(b[9]&255)==96&&(b[10]&255)==234,"wire endian");
  bad("01:19");bad("01:60001");bad("100:500");bad("01:-1");bad("00:0");
  StringBuilder all=new StringBuilder();for(int i=0;i<1024;i++)all.append("01:20 ");c=TimedChart.parse(all.toString());
  check(c.size()==1024&&c.begin()[0]==0&&c.begin()[1]==4&&c.block(1020).length==14,"1024 boundary");bad(all+"01:20");
  int n=0;StreamMux mux=new StreamMux();StreamProtocol decoder=new StreamProtocol();int controls=0,ext=0;
  for(String hex:Files.readAllLines(Paths.get(args[0]))){StreamMux.Event e=mux.accept(Integer.parseInt(hex.trim(),16));if(e==null)continue;
   if(e.audio!=null)n+=decoder.decode(e.audio).length;else if(e.extension!=null){ext++;check(ExtProtocol.response(e.extension,Integer.parseInt(e.extension.substring(2,4),16))[0]==0,"ACK");}else controls++;
  }
  check(decoder.ended&&n>350&&controls==4&&ext==3,"actual RTL stream mixed with control replies");
  // Values that resemble command framing inside audio must remain audio.
  byte[] frame=new byte[75];frame[0]=(byte)0xa5;frame[1]=0x5a;frame[4]=64;for(int i=10;i<74;i++)frame[i]=(byte)(i%2==0?'!':0xa5);
  int sum=0;for(int i=2;i<74;i++)sum+=frame[i]&255;frame[74]=(byte)-sum;
  mux=new StreamMux();int events=0;for(byte v:frame){StreamMux.Event e=mux.accept(v&255);if(e!=null){events++;check(e.audio!=null,"PCM misread as control");}}
  check(events==1,"single audio event");
  System.out.println("PASS V20 chart format/range/1024/chunks, real UART stream + control demux, PCM marker isolation: "+n+" samples");
 }
}
