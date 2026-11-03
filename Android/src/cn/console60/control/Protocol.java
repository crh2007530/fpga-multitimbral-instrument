package cn.console60.control;
import java.nio.charset.StandardCharsets;
public final class Protocol {
 public static byte[] frame(char c) {if("12345678TLABCDWSXR?".indexOf(c)<0)throw new IllegalArgumentException("Invalid command");return ("@"+c+"\n").getBytes(StandardCharsets.US_ASCII);}
 public static boolean mode(char c){return "NFPRDHJO".indexOf(c)>=0;}
 public static String label(char c){switch(c){case 'H':return "曲谱练习 · 待开始 / 暂停";case 'J':return "曲谱练习 · 运行中";case 'O':return "曲谱练习 · 已结束";case 'N':return "正常演奏";case 'F':return "FFT 测试";case 'P':return "游戏待开始 / 暂停";case 'R':return "游戏运行中";case 'D':return "游戏结束";default:return "未知，请查询";}}
 public static boolean allowed(char c,char mode){if(c=='?')return true;if(!mode(mode))return false;boolean game="PRDHJO".indexOf(mode)>=0;
 if(c=='L')return mode=='N';if(c=='T')return mode!='F';if("ABCD".indexOf(c)>=0)return mode!='F';if("WSXR".indexOf(c)>=0)return mode=='N';
 if(game)return c=='5'||c=='6'||c=='8';if(mode=='F'&&"123".indexOf(c)>=0)return false;return true;}
}