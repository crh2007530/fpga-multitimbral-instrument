import cn.console60.control.*;
public class TitleTest { public static void main(String[] args){
 byte[] data=new byte[512];for(int i=0;i<512;i++)data[i]=(byte)i;int copied=0;
 for(int offset=0;offset<512;offset+=30){byte[] b=TitleProtocol.block(data,offset);if(ExtProtocol.u16(b,0)!=offset || b.length>32)throw new AssertionError();
  for(int i=2;i<b.length;i++)if(b[i]!=data[copied++])throw new AssertionError();
  byte[] wire=ExtProtocol.frame('N',offset,b);if(wire[1]!='N')throw new AssertionError();}
 if(copied!=512)throw new AssertionError();System.out.println("PASS V23 title 512-byte bitmap, 18 bounded blocks, offsets and protocol");}}
