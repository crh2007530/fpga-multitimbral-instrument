package cn.console60.control;
import android.Manifest;import android.app.*;import android.bluetooth.*;import android.content.*;import android.content.pm.PackageManager;import android.os.*;import android.provider.Settings;import android.view.*;import android.widget.*;
import android.graphics.*;
import java.io.*;import java.util.*;import java.util.concurrent.*;
public class MainActivity extends Activity {
 final Handler ui=new Handler(Looper.getMainLooper());final ExecutorService worker=Executors.newSingleThreadExecutor();
 volatile BluetoothSocket socket;volatile int generation=0;volatile boolean connected=false;boolean busy=false;char mode='?';
 TextView status,log;LinearLayout body;final ArrayList<Button> commands=new ArrayList<>();
 final StringBuilder history=new StringBuilder();
 LinearLayout root,header;TextView summary;ScrollView scroll;LinearLayout[] pages=new LinearLayout[6];Button[] tabs=new Button[6];int selectedPage=0;
 final String[] pageNames={"连接","演奏","音游","曲谱","录音","诊断"};
 int dp(int n){return (int)(n*getResources().getDisplayMetrics().density+.5f);}
 android.graphics.drawable.GradientDrawable surface(int color){android.graphics.drawable.GradientDrawable d=new android.graphics.drawable.GradientDrawable();d.setColor(color);d.setCornerRadius(dp(14));return d;}
 void selectPage(int index){selectedPage=index;for(int i=0;i<6;i++){pages[i].setVisibility(i==index?View.VISIBLE:View.GONE);tabs[i].setTextColor(i==index?0xff081a2d:0xffb4c6dc);tabs[i].setBackground(surface(i==index?0xff65e0ce:0xff18283d));}scroll.smoothScrollTo(0,0);}
 int sectionPage(String s){if(s.contains("连接"))return 0;if(s.contains("音游"))return 2;if(s.contains("曲谱")||s.contains("键位音高"))return 3;if(s.contains("录音")||s.contains("音频回传"))return 4;if(s.contains("诊断")||s.contains("画面")||s.contains("通信记录"))return 5;return 1;}
 void text(String s,int size,int color){
  if(size>=21){LinearLayout card=new LinearLayout(this);card.setOrientation(1);card.setPadding(dp(16),dp(12),dp(16),dp(16));card.setBackground(surface(0xff132238));LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(-1,-2);cp.bottomMargin=dp(14);pages[sectionPage(s)].addView(card,cp);body=card;}
  TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(size>=21?0xffeef6ff:0xffaebed2);t.setLineSpacing(dp(3),1);t.setPadding(0,dp(7),0,dp(10));if(size>=21)t.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));body.addView(t);
 }
 Button button(String s,Runnable r){Button b=new Button(this);b.setText(s);b.setTextSize(15);b.setAllCaps(false);b.setGravity(Gravity.CENTER);b.setPadding(dp(10),dp(8),dp(10),dp(8));b.setMinHeight(dp(52));b.setMaxLines(3);
  android.content.res.ColorStateList colors=new android.content.res.ColorStateList(new int[][]{new int[]{-android.R.attr.state_enabled},new int[]{}},new int[]{0xff1a2a3d,0xff203e59});
  android.graphics.drawable.GradientDrawable bg=surface(0xff203e59);bg.setColor(colors);b.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x4465e0ce),bg,null));
  b.setTextColor(new android.content.res.ColorStateList(new int[][]{new int[]{-android.R.attr.state_enabled},new int[]{}},new int[]{0xff7b8a9c,0xffe5f8ff}));
  b.setOnClickListener(v->r.run());LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(7);body.addView(b,lp);return b;
 }
 void command(String title,char c){Button b=button(title,()->send(c));b.setTag(c);commands.add(b);}
 @Override public void onCreate(Bundle b){super.onCreate(b);
 getWindow().setStatusBarColor(0xff091322);getWindow().setNavigationBarColor(0xff091322);
 root=new LinearLayout(this);root.setOrientation(1);root.setBackgroundColor(0xff091322);setContentView(root);
 root.setOnApplyWindowInsetsListener((v,insets)->{v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
 header=new LinearLayout(this);header.setOrientation(1);header.setPadding(dp(20),dp(18),dp(20),dp(12));root.addView(header);
 TextView brand=new TextView(this);brand.setText("CONSOLE 60K");brand.setTextColor(0xffeef6ff);brand.setTextSize(25);brand.setTypeface(Typeface.create("sans-serif-medium",0));header.addView(brand);
 summary=new TextView(this);summary.setTextSize(13);summary.setPadding(0,dp(7),0,dp(6));summary.setTextColor(0xff93aecb);header.addView(summary);
 HorizontalScrollView nav=new HorizontalScrollView(this);nav.setHorizontalScrollBarEnabled(false);LinearLayout row=new LinearLayout(this);row.setPadding(dp(16),0,dp(16),dp(8));nav.addView(row);root.addView(nav);
 for(int i=0;i<6;i++){final int index=i;Button tab=new Button(this);tab.setText(pageNames[i]);tab.setTextSize(14);tab.setAllCaps(false);tab.setPadding(0,0,0,0);tab.setMinWidth(0);tab.setMinimumWidth(0);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(dp(66),dp(42));lp.rightMargin=dp(7);row.addView(tab,lp);tabs[i]=tab;tab.setOnClickListener(v->selectPage(index));}
 scroll=new ScrollView(this);scroll.setFillViewport(true);LinearLayout content=new LinearLayout(this);content.setOrientation(1);content.setPadding(dp(16),dp(8),dp(16),dp(24));scroll.addView(content);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
 for(int i=0;i<6;i++){pages[i]=new LinearLayout(this);pages[i].setOrientation(1);content.addView(pages[i]);}body=pages[0];
 text("设备连接",21,0xff48e1e8);text("V30 · 先配对 JDY-31，再连接并等待 FPGA 回执。",14,0xffb7c9dd);status=new TextView(this);status.setTextSize(17);status.setTextColor(0xffffc66b);body.addView(status);
 button("① 系统蓝牙：开启并配对 JDY-31",()->startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
 button("② 选择已配对设备并连接",()->choose());button("断开连接",()->disconnect("已断开"));command("查询 FPGA 当前模式",'?');
 text("音游控制",21,0xff48e1e8);command("进入 / 退出音游",'T');command("开始 / 暂停 / 结束后重开",'5');command("重置本局",'6');command("退出游戏",'8');
 // Mark context-specific commands; they cannot accidentally invoke FFT or chord mode.
 for(int i=commands.size()-3;i<commands.size();i++)commands.get(i).setContentDescription("game");
 text("练习指引",21,0xff48e1e8);text("白底波形页面，灯带按曲谱提示目标键。脱机可长按游戏按钮进入，短按开始/暂停，触摸8退出。",13,0xffb7c9dd);command("进入白底曲谱练习",'L');command("练习开始 / 暂停 / 重开",'5');command("重置练习",'6');command("退出练习",'8');
 for(int i=commands.size()-3;i<commands.size();i++)commands.get(i).setContentDescription("practice");
 text("音色与表现",21,0xff48e1e8);command("切换 口琴 / 尼龙吉他 / 钢琴",'A');command("切换滑音",'B');command("切换颤音",'C');command("切换回声",'D');
 text("效果只有切换回执，无开关状态回传。看大屏确认音色，听声音确认效果。",13,0xffb7c9dd);
 text("演奏设置 / 诊断",21,0xff48e1e8);
 String[] names={"低音档","中音档","高音档","选择下一个 Z 区","频谱测试（先开和弦可测64路）","切换扩展和弦","选择全部 Z 区","退出测试 / 恢复"};
 for(int i=0;i<8;i++){command(names[i],(char)('1'+i));commands.get(commands.size()-1).setContentDescription("normal");}
 text("画面选择（固件的显示控制）",21,0xff48e1e8);command("波形",'W');command("频谱",'S');command("李萨如 / XY",'X');command("轮换显示",'R');
 text("手机不替代 Z1–Z8 压力演奏，不显示未回传的分数。模块 UART 须预先设置 115200 / 8N1（模块须先配置）。",13,0xffb7c9dd);
 extensionUi();
 text("通信记录",21,0xff48e1e8);log=new TextView(this);log.setTextSize(13);log.setTextColor(0xffb7c9dd);log.setTextIsSelectable(true);body.addView(log);button("清空记录",()->{history.setLength(0);log.setText("");});((android.view.ViewGroup)transfer.getParent()).removeView(transfer);transfer.setTextSize(12);header.addView(transfer);selectPage(0);refresh();}
 void note(String s){history.append(s).append('\n');if(history.length()>6000)history.delete(0,history.length()-6000);log.setText(history);if(summary!=null)summary.setContentDescription(s);if(log!=null && selectedPage!=5)Toast.makeText(this,s,Toast.LENGTH_SHORT).show();}
 void refresh(){if(summary!=null)summary.setText((connected?"● 蓝牙已连接":"○ 蓝牙未连接")+"  ·  "+Protocol.label(mode)+(busy?"  ·  处理中":""));for(Button b:extensionButtons)b.setEnabled(connected&&(!busy || streaming && !controlQueued && "streamFx".equals(b.getTag())));status.setText((connected?"蓝牙已连接 · ":"未连接 · ")+Protocol.label(mode)+(busy?" · 等待回执":""));for(Button b:commands){char c=(Character)b.getTag();boolean allowed=Protocol.allowed(c,mode);String context=String.valueOf(b.getContentDescription());if(context.equals("game"))allowed&="PRD".indexOf(mode)>=0;if(context.equals("practice"))allowed&="HJO".indexOf(mode)>=0;if(context.equals("normal")){allowed&="NF".indexOf(mode)>=0;if(c=='4')b.setText(mode=='F'?"选择下一个测试声部":"选择下一个Z区");if(c=='6')b.setText(mode=='F'?"关闭 / 打开选中测试声部":"切换扩展和弦");if(c=='7')b.setText(mode=='F'?"全部测试声部打开":"选择全部Z区");}b.setEnabled(connected&&(!busy || streaming && !controlQueued)&&allowed);}}
 void closeSocket(){BluetoothSocket s=socket;socket=null;if(s!=null)try{s.close();}catch(IOException ignored){}}
 void disconnect(String reason){generation++;connected=false;busy=false;mode='?';closeSocket();refresh();note(reason);}
 boolean permission(){if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){requestPermissions(new String[]{Manifest.permission.BLUETOOTH_CONNECT},1);return false;}return true;}
 @Override public void onRequestPermissionsResult(int r,String[] p,int[] g){super.onRequestPermissionsResult(r,p,g);if(r==1&&g.length>0&&g[0]==PackageManager.PERMISSION_GRANTED)choose();else note("未获得附近设备权限，请在系统应用权限中允许。");}
 void choose(){if(!permission())return;try{BluetoothManager m=(BluetoothManager)getSystemService(BLUETOOTH_SERVICE);BluetoothAdapter a=m.getAdapter();if(a==null||!a.isEnabled()){note("请先在系统设置开启蓝牙。");return;}ArrayList<BluetoothDevice> devices=new ArrayList<>(a.getBondedDevices());if(devices.isEmpty()){note("没有已配对设备，请先在系统蓝牙设置配对模块。");return;}String[] labels=new String[devices.size()];for(int i=0;i<labels.length;i++)labels[i]=devices.get(i).getName()+"\n"+devices.get(i).getAddress();new AlertDialog.Builder(this).setTitle("选择你的 JDY-31").setItems(labels,(d,i)->connect(devices.get(i))).setNegativeButton("取消",null).show();}catch(Exception e){note("无法读取设备："+e.getMessage());}}
 void connect(BluetoothDevice device){disconnect("准备连接设备");final int token=generation;busy=true;refresh();ui.postDelayed(()->{if(token==generation&&!connected)disconnect("连接超时，请检查供电、配对，关闭其他蓝牙串口软件。");},12000);
 worker.execute(()->{try{BluetoothSocket s=device.createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"));if(token!=generation){s.close();return;}socket=s;if(token!=generation){s.close();return;}s.connect();if(token!=generation){s.close();return;}ui.post(()->{if(token==generation)note("蓝牙SPP已接通，正在等待FPGA通信；此步骤与手机配对不同。");});recoverStream(s,token);ui.post(()->{if(token!=generation)return;connected=true;busy=false;note("SPP 已连接，正在查询 FPGA。");refresh();send('?');});}catch(Exception e){ui.post(()->{if(token==generation)disconnect("连接失败："+e.getMessage());});}});}
 // A disconnected phone may leave the FPGA streaming. Stop it before the
 // ordinary mode query, then drain the bounded FIFO and final packet.
 void recoverStream(BluetoothSocket s,int token)throws Exception{
  accepted(s,'K',new byte[0],token);
  InputStream in=s.getInputStream();long limit=SystemClock.elapsedRealtime()+3000,quiet=SystemClock.elapsedRealtime();
  while(SystemClock.elapsedRealtime()<limit){
   if(token!=generation)throw new IOException("连接已取消");
   if(in.available()>0){in.read();quiet=SystemClock.elapsedRealtime();}
   else if(SystemClock.elapsedRealtime()-quiet>=300)return;
   else Thread.sleep(5);
  }
  throw new IOException("旧录音未停止，请检查固件版本");
 }
 char exchange(BluetoothSocket s,char c)throws Exception{InputStream in=s.getInputStream();while(in.available()>0)in.read();s.getOutputStream().write(Protocol.frame(c));s.getOutputStream().flush();long until=SystemClock.elapsedRealtime()+2200;
 while(SystemClock.elapsedRealtime()<until){if(in.available()>0){int v=in.read();if(v<0)throw new IOException("连接关闭");char r=(char)v;if((c=='?'&&Protocol.mode(r))||(c!='?'&&r=='K')||r=='I'||r=='E')return r;}Thread.sleep(10);}throw new IOException("FPGA 回执超时；不自动重发切换命令，请检查接线和固件");}
 void send(char c){if(streaming){queueControl(new Pending(c,null,null));return;}if(!connected||busy)return;busy=true;refresh();note("发送 @"+c+" + LF");final int token=generation;final BluetoothSocket s=socket;
 worker.execute(()->{try{char reply=exchange(s,c);char next=Protocol.mode(reply)?reply:exchange(s,'?');ui.post(()->{if(token!=generation)return;mode=Protocol.mode(next)?next:'?';busy=false;note("收到 "+reply+": "+(reply=='K'?"指令已接受":reply=='I'?"当前模式禁止":reply=='E'?"指令无效":Protocol.label(reply)));refresh();});}catch(Exception e){ui.post(()->{if(token==generation)disconnect(e.getMessage());});}});}

 final ArrayList<Button> extensionButtons=new ArrayList<>();EditText chartText,mapText,urlText,chartName;TextView transfer;
 byte[] savedWav;int extSequence=0;
 EditText edit(String initial){EditText e=new EditText(this);e.setTextColor(0xffecf5ff);e.setText(initial);e.setTextSize(15);e.setHintTextColor(0xff91a5bd);e.setPadding(dp(12),dp(10),dp(12),dp(10));e.setBackground(surface(0xff091725));e.setMinHeight(dp(48));e.setMaxLines(8);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(8);body.addView(e,lp);return e;}
 void extButton(String label,Runnable r){Button b=button(label,r);if(label.contains("混响")||label.contains("合唱"))b.setTag("streamFx");extensionButtons.add(b);}
 void extensionUi(){
  text("光电拨弦",21,0xff48e1e8);
  text("先松开压力键。拨弦模式：按压力键选音和力度，再用遮光片划过红外槽；遮挡时只触发一次。模块D0接J10.9/W17，VCC仅接3.3V。",13,0xffb7c9dd);
  extButton("启用拨弦：遮挡时D0高",()->perform('P',new byte[]{3},"光电拨弦开启，高电平遮挡"));
  extButton("启用拨弦：遮挡时D0低",()->perform('P',new byte[]{1},"光电拨弦开启，低电平遮挡"));
  extButton("恢复直接按压演奏",()->perform('P',new byte[]{2},"直接按压模式"));
  text("ADSR包络控制",21,0xff48e1e8);
  text("输入 A毫秒 D毫秒 S百分比 R毫秒。作用于三音色外层包络；保留原乐器内部音色变化。R表示从满幅释放的最长时间，短音实际释放更短。参数有整数步长量化；A/D/R最长约682ms，提交后显示实际量化时间，超过上限不会延长。",13,0xffb7c9dd);
  adsrText=edit("5 100 70 200");
  extButton("应用ADSR（先松开压力键）",()->{try{String[] v=adsrText.getText().toString().trim().split("\\s+");if(v.length!=4)throw new IllegalArgumentException("请输入4个数");byte[] config=StreamProtocol.adsr(Integer.parseInt(v[0]),Integer.parseInt(v[1]),Integer.parseInt(v[2]),Integer.parseInt(v[3]),true);perform('E',config,StreamProtocol.actualTimes(config));}catch(Exception e){note(e.getMessage());}});
  extButton("恢复原乐器包络",()->perform('E',StreamProtocol.adsr(5,100,70,200,false),"已恢复原音色包络"));
  text("连续录音",21,0xff48e1e8);
  text("连接设备后，点击开始录音并演奏。结束时点击停止，再将录音保存到手机。",13,0xffb7c9dd);
  extButton("开始连续录音",()->continuousRecording());
  button("停止连续录音",()->{stopStreaming=true;});
  text("混响与合唱",21,0xff48e1e8);
  extButton("仅开混响",()->perform('F',new byte[]{1},"已设置：混响开、合唱关"));
  extButton("仅开合唱",()->perform('F',new byte[]{2},"已设置：混响关、合唱开"));
  extButton("混响＋合唱",()->perform('F',new byte[]{3},"已设置：混响和合唱均开"));
  extButton("关闭混响与合唱",()->perform('F',new byte[]{0},"混响与合唱均已关闭；回声仍由上方回声按钮独立控制"));
  text("空间预设、干湿比例及细调请使用设备上的调音台旋钮。手机保留混响与合唱开关控制。测试音模式会旁路全部效果。先退出测试模式，再演奏听效果；恢复默认键位不改变效果器。",13,0xffb7c9dd);
  text("曲谱下载与导入",21,0xff48e1e8);
  text("最多1024个事件，每项为掩码:毫秒，例如01:250、00:500休止、03:750和弦。时长为到下一事件的间隔，20–60000ms；不是长按时值判定。上传后可断开手机脱机演奏；断电恢复内置谱。仍兼容原32项固定节奏文件。",13,0xffb7c9dd);
  chartName=edit("我的曲谱");chartName.setHint("曲谱名称，将同步显示到大屏");
  chartText=edit("01:500 02:250 04:250 00:500\n03:750 08:250 10:500 80:1000");
  urlText=edit("");urlText.setHint("HTTPS曲谱文件地址（纯文本，最多1024项）");urlText.setHintTextColor(0xff8194ad);
  button("从HTTPS地址下载到编辑框",()->downloadChart());
  button("导入本地曲谱文件",()->{if(busy)return;Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,100);});
  extButton("上传当前曲谱到FPGA",()->{try{uploadChart(TimedChart.parse(chartText.getText().toString()));}catch(Exception e){note(e.getMessage());}});
  text("任意键位音高",21,0xff48e1e8);text("依次为Z1–Z8的MIDI音高0–127；60=C4，69=A4。先退出音游、松开全部压力键，再提交。",13,0xffb7c9dd);
  mapText=edit("72 74 76 77 79 81 83 84");
  extButton("应用8个键位音高",()->{try{perform('M',ExtProtocol.keymap(mapText.getText().toString()),"键位已应用；请逐键试听");}catch(Exception e){note(e.getMessage());}});
  extButton("恢复内置曲谱和默认键位",()->perform('D',new byte[0],"曲谱和键位已恢复默认"));
  text("短录音回传",21,0xff48e1e8);text("点击开始录音并演奏，录制完成后点击回传，再保存到手机。",13,0xffb7c9dd);
  extButton("开始短录音",()->perform('B',new byte[0],"正在录音，请演奏；录制完成后自动停止"));
  extButton("停止短录音",()->perform('S',new byte[0],"录音已停止，可回传"));
  extButton("回传录音到手机",()->fetchRecording());
  transfer=new TextView(this);transfer.setTextColor(0xff48e1e8);body.addView(transfer);
  button("保存录音到手机",()->{if(savedWav==null){note("请先回传录音");return;}Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("audio/wav").addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE,"Console60_"+System.currentTimeMillis()+".wav");startActivityForResult(i,101);});
 }
 interface Job {void run(BluetoothSocket s,int token)throws Exception;}
 void job(Job action){if(!connected||busy)return;busy=true;refresh();final int token=generation;final BluetoothSocket s=socket;worker.execute(()->{try{action.run(s,token);}catch(Exception e){ui.post(()->{if(token==generation)note("操作未完成："+e.getMessage());});}finally{ui.post(()->{if(token==generation){busy=false;refresh();}});}});}
 byte[] extExchange(BluetoothSocket s,char op,byte[] data,int token)throws Exception{
  int seq=(++extSequence)&255;byte[] frame=ExtProtocol.frame(op,seq,data);IOException last=null;
  for(int attempt=0;attempt<3;attempt++){
   if(token!=generation)throw new IOException("已取消连接");
   InputStream in=s.getInputStream();while(in.available()>0)in.read();s.getOutputStream().write(frame);s.getOutputStream().flush();
   long deadline=SystemClock.elapsedRealtime()+2400;StringBuilder line=new StringBuilder();
   while(SystemClock.elapsedRealtime()<deadline){
    if(token!=generation)throw new IOException("已取消连接");
    if(in.available()==0){Thread.sleep(5);continue;}int c=in.read();if(c<0)throw new IOException("连接已关闭");
    if(c=='!')line.setLength(0);line.append((char)c);if(line.length()>100)line.setLength(0);
    if(c==10){try{byte[] reply=ExtProtocol.response(line.toString(),seq);return reply;}catch(IOException e){last=e;line.setLength(0);}}
   }
   last=new IOException("响应超时，已尝试"+(attempt+1)+"次");
  }
  throw last;
 }
 byte[] accepted(BluetoothSocket s,char op,byte[] data,int token)throws Exception{byte[] r=extExchange(s,op,data,token);if(r[0]!=0)throw new IOException(ExtProtocol.status(r[0]&255));return r;}
 void perform(char op,byte[] data,String message){if(streaming && op=='F'){queueControl(new Pending(op,data,message));return;}job((s,token)->{accepted(s,op,data,token);ui.post(()->{if(token==generation){if(op=='B'){savedWav=null;transfer.setText("录制完成后，请点击回传录音");}note(message);}});});}
 void fetchRecording(){if(!connected||busy)return;savedWav=null;transfer.setText("准备回传录音");job((s,token)->{
  byte[] h=accepted(s,'H',new byte[0],token);if(h.length!=7||h[1]!=14)throw new IOException("需要兼容录音协议的固件");
  if((h[2]&1)!=0)throw new IOException("正在录音，请稍后回传");if((h[2]&2)==0)throw new IOException("还没有录音");
  int n=ExtProtocol.u16(h,3),rate=ExtProtocol.u16(h,5);if(n<1||n>32768||rate!=12012)throw new IOException("录音元数据错误");
  byte[] clip=new byte[n];for(int offset=0;offset<n;offset+=32){byte[] r=accepted(s,'G',new byte[]{(byte)offset,(byte)(offset>>8)},token);int length=Math.min(32,n-offset);if(r.length!=length+1)throw new IOException("录音块长度不匹配");System.arraycopy(r,1,clip,offset,length);final int progress=(offset+length)*100/n;ui.post(()->{if(token==generation)transfer.setText("录音回传 "+progress+"%");});}
  final byte[] wav=ExtProtocol.wav(clip,rate);ui.post(()->{if(token==generation){savedWav=wav;note("录音回传完成："+n+"个采样已接收，可保存到手机");}});
 });}
 static String songFileName(String name){
 if(name==null || name.trim().isEmpty())return "我的曲谱";
 int dot=name.lastIndexOf('.');return dot>0?name.substring(0,dot):name;
 }
 void downloadChart(){if(busy)return;final String address=urlText.getText().toString().trim();busy=true;refresh();final int token=generation;worker.execute(()->{javax.net.ssl.HttpsURLConnection c=null;try{
  java.net.URL u=new java.net.URL(address);if(!u.getProtocol().equals("https"))throw new IOException("只接受HTTPS地址");c=(javax.net.ssl.HttpsURLConnection)u.openConnection();c.setConnectTimeout(10000);c.setReadTimeout(10000);c.setInstanceFollowRedirects(false);if(c.getResponseCode()!=200)throw new IOException("HTTP "+c.getResponseCode()+"；请提供直接文件地址");
  final String content;try(InputStream in=c.getInputStream()){content=new String(ExtProtocol.limitedRead(in,65536),java.nio.charset.StandardCharsets.UTF_8);}TimedChart.parse(content);ui.post(()->{if(token==generation){chartText.setText(content.trim());chartName.setText(songFileName(android.net.Uri.decode(new java.io.File(u.getPath()).getName())));note("曲谱已下载并校验，点击上传写入FPGA");}});
 }catch(Exception e){ui.post(()->{if(token==generation)note("下载失败："+e.getMessage());});}finally{if(c!=null)c.disconnect();ui.post(()->{if(token==generation){busy=false;refresh();}});}});}
 @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null||data.getData()==null)return;
  try{if(request==100){String content;try(InputStream in=getContentResolver().openInputStream(data.getData())){content=new String(ExtProtocol.limitedRead(in,65536),java.nio.charset.StandardCharsets.UTF_8);}TimedChart.parse(content);chartText.setText(content.trim());
 try(android.database.Cursor cursor=getContentResolver().query(data.getData(),new String[]{android.provider.OpenableColumns.DISPLAY_NAME},null,null,null)){
  if(cursor!=null && cursor.moveToFirst())chartName.setText(songFileName(cursor.getString(0)));
 }
 note("已导入曲谱，点击上传应用");}
  else if(request==101&&savedWav!=null){try(OutputStream out=getContentResolver().openOutputStream(data.getData(),"wt")){out.write(savedWav);}note("WAV已保存，可用手机播放器试听或分享");}}catch(Exception e){note("文件操作失败："+e.getMessage());}
 }


 volatile boolean stopStreaming=false;EditText adsrText;
 int streamByte(InputStream in,int token,long deadline)throws Exception{
  while(in.available()==0){if(token!=generation)throw new IOException("连接已取消");if(SystemClock.elapsedRealtime()>deadline)throw new IOException("录音数据超时");Thread.sleep(2);}int b=in.read();if(b<0)throw new IOException("蓝牙断开");return b;
 }
 static final class Pending {final char op;final byte[] data;final String message;int seq;boolean query;long deadline;
  Pending(char o,byte[] d,String m){op=o;data=d;message=m;}}
 volatile boolean streaming=false,controlQueued=false;
 final ConcurrentLinkedQueue<Pending> streamCommands=new ConcurrentLinkedQueue<>();
 void queueControl(Pending p){if(!connected||!streaming||controlQueued||stopStreaming)return;controlQueued=true;streamCommands.add(p);note("录音中发送控制 "+p.op);refresh();}
 void uploadChart(TimedChart chart){
 final String title=chartName.getText().toString().trim();
 if(title.length()==0){note("请先填写曲谱名称");return;}
 final byte[] bitmap=titleBitmap(title);
 job((s,token)->{
  accepted(s,'U',chart.begin(),token);
  // Wait for the display to hide the previous name at a frame boundary
  // before rewriting the single title RAM (three 60 Hz frames).
  Thread.sleep(50);
  for(int offset=0;offset<chart.size();offset+=10){accepted(s,'V',chart.block(offset),token);final int n=Math.min(chart.size(),offset+10);ui.post(()->{if(token==generation)transfer.setText("曲谱上传 "+n+"/"+chart.size());});}
  for(int off=0;off<512;off+=30)accepted(s,'N',TitleProtocol.block(bitmap,off),token);
  accepted(s,'Z',new byte[0],token);ui.post(()->{if(token==generation)note("已提交"+chart.size()+"个变节奏事件；进入练习或音游演奏，断开手机仍可使用");});
 });}
 static byte[] titleBitmap(String title){
  Bitmap b=Bitmap.createBitmap(256,16,Bitmap.Config.ARGB_8888);Canvas c=new Canvas(b);
  c.drawColor(Color.BLACK);Paint paint=new Paint();paint.setColor(Color.WHITE);paint.setAntiAlias(false);
  paint.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL));paint.setTextSize(15);
  // Ellipsize on Unicode code-point boundaries; never shrink to unreadable text.
  String shown=title;
  while(paint.measureText(shown)>254 && shown.length()>0)shown=shown.substring(0,shown.offsetByCodePoints(shown.length(),-1));
  if(!shown.equals(title)){while(paint.measureText(shown+"…")>254 && shown.length()>0)shown=shown.substring(0,shown.offsetByCodePoints(shown.length(),-1));shown+="…";}
  c.drawText(shown,0,13,paint);byte[] data=new byte[512];
  for(int y=0;y<16;y++)for(int x=0;x<256;x++)if((b.getPixel(x,y)&255)>127)data[y*32+x/8]|=(byte)(128>>(x%8));
  b.recycle();return data;
 }
 void continuousRecording(){if(!connected||busy)return;stopStreaming=false;savedWav=null;streamCommands.clear();controlQueued=false;
  job((s,token)->{ByteArrayOutputStream pcm=new ByteArrayOutputStream();StreamProtocol decoder=new StreamProtocol();StreamMux mux=new StreamMux();boolean requestedStop=false;Pending pending=null;int stopSeq=-1;
   try{
    accepted(s,'J',new byte[0],token);streaming=true;ui.post(()->{if(token==generation)refresh();});
    InputStream in=s.getInputStream();long begin=SystemClock.elapsedRealtime(),deadline=begin+4000;
    while(!decoder.ended){
     long now=SystemClock.elapsedRealtime();
     if(pending!=null && now>pending.deadline)throw new IOException("录音中控制回执超时，不自动重复切换；本次录音未标为完整");
     if(pending==null && !requestedStop){
      pending=streamCommands.poll();
      if(pending!=null){pending.deadline=now+2400;byte[] command;
       if(pending.data==null)command=Protocol.frame(pending.op);else{pending.seq=(++extSequence)&255;command=ExtProtocol.frame(pending.op,pending.seq,pending.data);}
       s.getOutputStream().write(command);s.getOutputStream().flush();
      }else if(stopStreaming || now-begin>=600000){stopSeq=(++extSequence)&255;s.getOutputStream().write(ExtProtocol.frame('K',stopSeq,new byte[0]));s.getOutputStream().flush();requestedStop=true;}
     }
     StreamMux.Event event=mux.accept(streamByte(in,token,deadline));if(event==null)continue;
     if(event.audio!=null){
      pcm.write(decoder.decode(event.audio));deadline=SystemClock.elapsedRealtime()+4000;
      if(pcm.size()>5000000)throw new IOException("录音超出手机缓冲限制");
      if(decoder.nextSequence%32==0){final int count=pcm.size();ui.post(()->{if(token==generation)transfer.setText(String.format(java.util.Locale.ROOT,"正在录音 · %.1f秒",count/8007.8125));});}
     }else if(event.extension!=null){
      if(pending!=null && pending.data!=null && !pending.query){byte[] r=ExtProtocol.response(event.extension,pending.seq);if(r[0]!=0)throw new IOException(ExtProtocol.status(r[0]&255));final String message=pending.message;ui.post(()->{if(token==generation)note(message);});pending.query=true;pending.deadline=SystemClock.elapsedRealtime()+2400;s.getOutputStream().write(Protocol.frame('?'));s.getOutputStream().flush();}
      else if(requestedStop){byte[] r=ExtProtocol.response(event.extension,stopSeq);if(r[0]!=0)throw new IOException("停止录音被拒绝");}
      else throw new IOException("意外扩展回执");
     }else if(pending!=null){
      char reply=event.reply;
      if(pending.query || pending.op=='?'){
       if(!Protocol.mode(reply))throw new IOException("模式回执错误");final char next=reply;pending=null;controlQueued=false;ui.post(()->{if(token==generation){mode=next;note("录音中控制完成："+Protocol.label(next));refresh();}});
      }else{if(reply!='K'&&reply!='I'&&reply!='E')throw new IOException("控制回执错误");final char r=reply;ui.post(()->{if(token==generation)note("录音中回执 "+r);});pending.query=true;pending.deadline=SystemClock.elapsedRealtime()+2400;s.getOutputStream().write(Protocol.frame('?'));s.getOutputStream().flush();}
     }else throw new IOException("没有待处理命令却收到回执");
    }
    final byte[] wav=ExtProtocol.wav(pcm.toByteArray(),8008);ui.post(()->{if(token==generation){savedWav=wav;note("连续录音完成，点击保存录音到手机");transfer.setText("录音已就绪，请保存到手机");}});
   }finally{streaming=false;controlQueued=false;streamCommands.clear();try{s.getOutputStream().write(ExtProtocol.frame('K',(++extSequence)&255,new byte[0]));s.getOutputStream().flush();}catch(Exception ignored){}}
  });
 }

 @Override protected void onDestroy(){generation++;connected=false;closeSocket();worker.shutdownNow();ui.removeCallbacksAndMessages(null);super.onDestroy();}
}
