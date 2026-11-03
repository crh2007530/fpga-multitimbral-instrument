from pathlib import Path
import os,subprocess,zipfile
p=Path(__file__).resolve().parent
jdk=Path(os.environ['JAVA_HOME']);sdk=Path(os.environ['ANDROID_SDK_ROOT']);bt=Path(os.environ.get('ANDROID_BUILD_TOOLS',str(sdk/'build-tools/35.0.0')));platform=Path(os.environ.get('ANDROID_PLATFORM',str(sdk/'platforms/android-35/android.jar')))
os.environ['PATH']=str(jdk/'bin')+os.pathsep+os.environ['PATH']
def run(*a):subprocess.run([str(x) for x in a],cwd=p,check=True)
out=p/'build';out.mkdir(exist_ok=True);classes=out/'classes';classes.mkdir(exist_ok=True)
run(jdk/'bin/javac.exe','-encoding','UTF-8','-source','8','-target','8','-classpath',platform,'-d',classes,*sorted((p/'src').rglob('*.java')))
run(jdk/'bin/javac.exe','-encoding','UTF-8','-classpath',classes,'-d',classes,p/'ProtocolTest.java')
run(jdk/'bin/java.exe','-cp',classes,'ProtocolTest')
run(jdk/'bin/javac.exe','-encoding','UTF-8','-classpath',classes,'-d',classes,p/'ExtensionsTest.java')
run(jdk/'bin/java.exe','-cp',classes,'ExtensionsTest',p/'testdata/rtl_responses.txt')
run(jdk/'bin/javac.exe','-encoding','UTF-8','-classpath',classes,'-d',classes,p/'StreamTest.java')
run(jdk/'bin/java.exe','-cp',classes,'StreamTest',p/'testdata/stream_fixture.hex')
run(jdk/'bin/javac.exe','-encoding','UTF-8','-classpath',classes,'-d',classes,p/'V20Test.java')
run(jdk/'bin/java.exe','-cp',classes,'V20Test',p/'testdata/stream_controls_wire.hex')
run(jdk/'bin/javac.exe','-encoding','UTF-8','-classpath',classes,'-d',classes,p/'TitleTest.java')
run(jdk/'bin/java.exe','-cp',classes,'TitleTest')
run(jdk/'bin/java.exe','-cp',bt/'lib/d8.jar','com.android.tools.r8.D8','--min-api','23','--lib',platform,'--output',out,*sorted((classes/'cn').rglob('*.class')))
run(bt/'aapt2.exe','link','-o',out/'unsigned.apk','--manifest',p/'AndroidManifest.xml','-I',platform)
with zipfile.ZipFile(out/'unsigned.apk','a',compression=zipfile.ZIP_DEFLATED) as z:z.write(out/'classes.dex','classes.dex')
run(bt/'zipalign.exe','-f','4',out/'unsigned.apk',out/'aligned.apk')
key=Path(os.environ.get('ANDROID_SIGNING_KEY',str(p/'local-test-key.jks')))
if not key.exists():run(jdk/'bin/keytool.exe','-genkeypair','-keystore',key,'-storepass','android','-keypass','android','-alias','console60','-keyalg','RSA','-keysize','2048','-validity','3650','-dname','CN=Console60 Local Test')
run(jdk/'bin/java.exe','-jar',bt/'lib/apksigner.jar','sign','--ks',key,'--ks-key-alias','console60','--ks-pass','pass:android','--key-pass','pass:android','--out',out/'Console60-v30.apk',out/'aligned.apk')
run(jdk/'bin/java.exe','-jar',bt/'lib/apksigner.jar','verify','--verbose',out/'Console60-v30.apk')
run(bt/'aapt.exe','dump','badging',out/'Console60-v30.apk')

