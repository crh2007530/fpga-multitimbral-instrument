import cn.console60.control.Protocol;
public class ProtocolTest {public static void main(String[]args){int count=0;
for(char c:"12345678TLABCDWSXR?".toCharArray()){byte[] b=Protocol.frame(c);if(b.length!=3||b[0]!=64||b[1]!=c||b[2]!=10)throw new AssertionError();count++;}
for(char m:"NFPRDHJO?".toCharArray()){
 if(Protocol.allowed('L',m)!=(m=='N'))throw new AssertionError("practice entry guard");
 if(!Protocol.allowed('?',m))throw new AssertionError();
 for(char c:"ABCDT".toCharArray())if(Protocol.allowed(c,m)!=(m!='F'&&m!='?'))throw new AssertionError();
 for(char c:"WSXR".toCharArray())if(Protocol.allowed(c,m)!=(m=='N'))throw new AssertionError();count++;
}
for(char m:"PRDHJO".toCharArray()){for(char c:"12347".toCharArray())if(Protocol.allowed(c,m))throw new AssertionError();for(char c:"568".toCharArray())if(!Protocol.allowed(c,m))throw new AssertionError();}
try{Protocol.frame('Z');throw new AssertionError();}catch(IllegalArgumentException expected){}
System.out.println("PASS protocol framing, invalid input, FFT guards, game/normal command gating: "+count+" groups");}}
