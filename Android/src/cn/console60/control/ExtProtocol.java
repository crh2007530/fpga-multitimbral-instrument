package cn.console60.control;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
/** Wire protocol and files; deliberately independent of Android for host tests. */
public final class ExtProtocol {
 public static byte[] frame(char op,int seq,byte[] data){
  if("CMDBSHGFPEJKUVZN".indexOf(op)<0 || data.length>32)throw new IllegalArgumentException("命令或长度无效");
  int sum=op+(seq&255)+data.length;StringBuilder b=new StringBuilder("!").append(op);
  hex(b,seq);hex(b,data.length);for(byte v:data){hex(b,v);sum+=v&255;}hex(b,-sum);b.append('\n');
  return b.toString().getBytes(StandardCharsets.US_ASCII);
 }
 static void hex(StringBuilder b,int v){b.append("0123456789ABCDEF".charAt((v>>4)&15)).append("0123456789ABCDEF".charAt(v&15));}
 static int value(String s,int pos)throws IOException {if(pos+2>s.length())throw new IOException("短帧");int a=Character.digit(s.charAt(pos),16),b=Character.digit(s.charAt(pos+1),16);if(a<0||b<0)throw new IOException("非十六进制数据");return a*16+b;}
 public static byte[] response(String s,int seq)throws IOException {
  if(!s.startsWith("!r")||!s.endsWith("\n")||s.length()<11)throw new IOException("响应格式错误");
  int id=value(s,2),n=value(s,4);if(id!=(seq&255)||n<1||n>33||s.length()!=9+2*n)throw new IOException("响应序号或长度错误");
  byte[] data=new byte[n];int sum='r'+id+n;for(int i=0;i<n;i++){data[i]=(byte)value(s,6+i*2);sum+=data[i]&255;}
  if(((sum+value(s,6+2*n))&255)!=0)throw new IOException("响应校验失败");return data;
 }
 public static String status(int c){String[] a={"成功","格式不符","请退出音游并松开压力键，或等待录音结束","暂无完整录音","数值超出范围","校验失败"};return c<a.length?a[c]:"未知错误 "+c;}
 public static byte[] chart(String text){
  String[] words=text.trim().split("\\s+");
  if(words.length!=32)throw new IllegalArgumentException("曲谱需恰好32个十六进制按键掩码，空格分隔；每拍500ms");
  byte[] out=new byte[32];int notes=0;for(int i=0;i<32;i++){if(!words[i].matches("[0-9a-fA-F]{2}"))throw new IllegalArgumentException("第"+(i+1)+"拍格式无效");int v=Integer.parseInt(words[i],16);if(v==0)throw new IllegalArgumentException("本版每拍至少一个音符，不能为00");notes+=Integer.bitCount(v);out[i]=(byte)v;}if(notes>64)throw new IllegalArgumentException("每首最多64次音符命中，请减少和弦");return out;
 }
 public static byte[] keymap(String text){String[] words=text.trim().split("[\\s,，]+");if(words.length!=8)throw new IllegalArgumentException("请填写Z1至Z8的8个MIDI音高");byte[] b=new byte[8];for(int i=0;i<8;i++){int v=Integer.parseInt(words[i]);if(v<0||v>127)throw new IllegalArgumentException("MIDI音高范围0至127");b[i]=(byte)v;}return b;}
 public static byte[] wav(byte[] pcm,int rate){if(pcm.length<1||pcm.length>10000000||rate<1)throw new IllegalArgumentException("录音无效");int pad=pcm.length&1;byte[] b=new byte[44+pcm.length+pad];ascii(b,0,"RIFF");le(b,4,36+pcm.length+pad,4);ascii(b,8,"WAVEfmt ");le(b,16,16,4);le(b,20,1,2);le(b,22,1,2);le(b,24,rate,4);le(b,28,rate,4);le(b,32,1,2);le(b,34,8,2);ascii(b,36,"data");le(b,40,pcm.length,4);System.arraycopy(pcm,0,b,44,pcm.length);return b;}
 static void ascii(byte[] b,int o,String s){byte[] v=s.getBytes(StandardCharsets.US_ASCII);System.arraycopy(v,0,b,o,v.length);}
 static void le(byte[] b,int o,int v,int n){for(int i=0;i<n;i++)b[o+i]=(byte)(v>>(8*i));}
 public static int u16(byte[] b,int o){return (b[o]&255)|((b[o+1]&255)<<8);}
 public static byte[] limitedRead(InputStream in,int limit)throws IOException {ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] b=new byte[1024];int n;while((n=in.read(b))!=-1){if(out.size()+n>limit)throw new IOException("文件超出允许大小");out.write(b,0,n);}return out.toByteArray();}
}
