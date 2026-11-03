import cn.console60.control.*;import java.nio.file.*;import java.util.*;
public class StreamTest{
 public static void main(String[]args)throws Exception{
  String[] h=new String(Files.readAllBytes(Paths.get(args[0]))).trim().split("\\s+");byte[] bytes=new byte[h.length];for(int i=0;i<h.length;i++)bytes[i]=(byte)Integer.parseInt(h[i],16);
  StreamProtocol d=new StreamProtocol();int at=0,total=0;
  while(at<bytes.length){int n=11+(bytes[at+4]&255);byte[] f=Arrays.copyOfRange(bytes,at,at+n);byte[] pcm=d.decode(f);if(at==0&&(pcm[0]!=0||(pcm[1]&255)!=255||(pcm[2]&255)!=128))throw new AssertionError("PCM");total+=pcm.length;at+=n;}
  if(!d.ended||total!=70)throw new AssertionError("END");
  byte[] bad=Arrays.copyOfRange(bytes,0,75);bad[12]^=1;try{new StreamProtocol().decode(bad);throw new AssertionError("CRC accepted");}catch(java.io.IOException expected){}
  byte[] a=StreamProtocol.adsr(5,100,50,200,true);if(a.length!=9||a[0]!=1)throw new AssertionError("ADSR");
  if(ExtProtocol.wav(new byte[80080],8008).length!=80124)throw new AssertionError("long WAV");
  StreamProtocol wrap=new StreamProtocol();
  for(int i=0;i<70000;i++){
   byte[] frame=new byte[75];frame[0]=(byte)0xa5;frame[1]=0x5a;frame[2]=(byte)i;frame[3]=(byte)(i>>8);frame[4]=64;
   int sum=0;for(int j=2;j<74;j++)sum+=frame[j]&255;frame[74]=(byte)-sum;
   if(wrap.decode(frame).length!=64)throw new AssertionError("wrap length");
  }
  if(wrap.nextSequence!=(70000&65535))throw new AssertionError("16-bit sequence wrap");
  byte[] dropped=Arrays.copyOfRange(bytes,0,75);dropped[6]=1;int sum=0;for(int i=2;i<74;i++)sum+=dropped[i]&255;dropped[74]=(byte)-sum;
  try{new StreamProtocol().decode(dropped);throw new AssertionError("overflow accepted");}catch(java.io.IOException expected){}
  try{StreamProtocol.adsr(683,100,50,200,true);throw new AssertionError("ADSR range");}catch(IllegalArgumentException expected){}
  System.out.println("PASS 70000 packets across sequence wrap, overflow rejection, ADSR duration boundary");
  System.out.println("PASS RTL-to-Java stream fixture, signed PCM, END, checksum rejection, ADSR and long WAV");
 }
}
