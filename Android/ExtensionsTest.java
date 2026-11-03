import cn.console60.control.ExtProtocol;
import java.io.*;import java.nio.file.*;import java.nio.charset.StandardCharsets;import java.util.*;
public class ExtensionsTest {
 static void check(boolean value){if(!value)throw new AssertionError();}
 interface Action{void run()throws Exception;}
 static void rejects(Action a)throws Exception{try{a.run();}catch(IllegalArgumentException|IOException expected){return;}throw new AssertionError("accepted invalid data");}
 public static void main(String[] args)throws Exception {
  check(new String(ExtProtocol.frame('B',10,new byte[0]),StandardCharsets.US_ASCII).equals("!B0A00B4\n"));
  int responses=0;for(String line:Files.readAllLines(Paths.get(args[0]),StandardCharsets.US_ASCII)){
   int seq=Integer.parseInt(line.substring(2,4),16);byte[] r=ExtProtocol.response(line+"\n",seq);check(r.length>=1);
   rejects(()->ExtProtocol.response(line+"\n",seq+1));
   char[] corrupt=(line+"\n").toCharArray();corrupt[corrupt.length-2]=corrupt[corrupt.length-2]=='0'?'1':'0';
   rejects(()->ExtProtocol.response(new String(corrupt),seq));responses++;
  }
  check(responses>=20);
  String chart=String.join(" ",Collections.nCopies(32,"81"));check(ExtProtocol.chart(chart).length==32);
  rejects(()->ExtProtocol.chart(chart+" 01"));rejects(()->ExtProtocol.chart(chart.replaceFirst("81","00")));rejects(()->ExtProtocol.chart(chart.replaceFirst("81","FF")));
  check(ExtProtocol.keymap("0 127 69 60 61 62 63 64")[1]==127);
  rejects(()->ExtProtocol.keymap("0 128 69 60 61 62 63 64"));rejects(()->ExtProtocol.keymap("0 1"));
  for(int n:new int[]{1,31,32,32767,32768}){byte[] pcm=new byte[n];for(int i=0;i<n;i++)pcm[i]=(byte)i;byte[] wav=ExtProtocol.wav(pcm,12012);check(wav.length==44+n+(n&1));check(ExtProtocol.u16(wav,24)==12012);check(ExtProtocol.u16(wav,34)==8);check(ExtProtocol.u16(wav,40)==n);for(int i=0;i<n;i++)check(wav[44+i]==pcm[i]);}
  rejects(()->ExtProtocol.wav(new byte[0],12012));rejects(()->ExtProtocol.limitedRead(new ByteArrayInputStream(new byte[4097]),4096));
  check(ExtProtocol.limitedRead(new ByteArrayInputStream(new byte[4096]),4096).length==4096);
  Files.write(Paths.get("build/protocol_fixture.wav"),ExtProtocol.wav(new byte[]{0,(byte)255,(byte)128},12012));
  System.out.println("PASS Android extension protocol against "+responses+" actual RTL responses; corrupted/stale packets; chart/map bounds; WAV odd/even/full lengths; file size limits");
 }
}
