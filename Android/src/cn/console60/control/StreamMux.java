package cn.console60.control;
import java.io.*;import java.util.*;
/** Parse whole binary packets and inter-packet control replies, without scanning PCM for text. */
public final class StreamMux {
 public static final class Event {public byte[] audio;public String extension;public char reply;}
 private byte[] packet=new byte[75];private int used=0,total=0;private StringBuilder line;
 public Event accept(int value)throws IOException{
  if(value<0||value>255)throw new IOException("连接关闭");
  if(used>0){
   packet[used++]=(byte)value;
   if(used==2&&value!=0x5a)throw new IOException("录音同步丢失");
   if(used==5){if(value>64)throw new IOException("录音包长度错误");total=11+value;}
   if(total>0&&used==total){Event e=new Event();e.audio=Arrays.copyOf(packet,total);used=0;total=0;return e;}return null;
  }
  if(line!=null){
   if(value>127||line.length()>=100)throw new IOException("控制回执损坏");line.append((char)value);
   if(value==10){Event e=new Event();e.extension=line.toString();line=null;return e;}return null;
  }
  if(value==0xa5){packet[0]=(byte)value;used=1;return null;}
  if(value=='!'){line=new StringBuilder("!");return null;}
  if(value==10||value==13)return null;
  if("KIENFPRDHJO".indexOf(value)>=0){Event e=new Event();e.reply=(char)value;return e;}
  throw new IOException("录音包边界存在未知数据: "+value);
 }
}
