package cn.console60.control;
public final class TitleProtocol {
 public static byte[] block(byte[] bitmap,int offset){
  if(bitmap.length!=512 || offset<0 || offset>=512)throw new IllegalArgumentException("Invalid title bitmap");
  int n=Math.min(30,512-offset);byte[] out=new byte[n+2];out[0]=(byte)offset;out[1]=(byte)(offset>>8);System.arraycopy(bitmap,offset,out,2,n);return out;
 }
}
