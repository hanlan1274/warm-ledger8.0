"""Configure only the generated Android shell; never touch ledger sources."""
from pathlib import Path
import re

app = Path('android/app/build.gradle.kts')
source = app.read_text(encoding='utf-8')
source = source.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
source = re.sub(r'minSdk = [^\n]+', 'minSdk = 23', source)
marker = '    buildTypes {'
signing = '''    signingConfigs {
        create("warmRelease") {
            storeFile = rootProject.file("warm-ledger.jks")
            storePassword = System.getenv("WARM_STOREPASS")
            keyAlias = "warmledger"
            keyPassword = System.getenv("WARM_STOREPASS")
        }
    }
'''
if marker not in source:
    raise RuntimeError('Flutter Android template changed; signing insertion was not applied')
source = source.replace(marker, signing + marker, 1)
if 'signingConfigs.getByName("debug")' not in source:
    raise RuntimeError('Flutter release signing template changed')
source = source.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("warmRelease")')
source += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
app.write_text(source, encoding='utf-8')

manifest = Path('android/app/src/main/AndroidManifest.xml')
source = manifest.read_text(encoding='utf-8')
source = source.replace('<application', '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application android:allowBackup="false" android:fullBackupContent="false"', 1)
source = source.replace('android:label="warm_ledger"', 'android:label="暖账"')
source = source.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/warm_icon"')
# The release app has no networking permission; neither account nor analytics SDKs.
if 'android.permission.INTERNET' in source:
    raise RuntimeError('Unexpected Internet permission in release manifest')
manifest.write_text(source, encoding='utf-8')

drawables = Path('android/app/src/main/res/drawable')
drawables.mkdir(parents=True, exist_ok=True)
raw = Path('android/app/src/main/res/raw')
raw.mkdir(parents=True, exist_ok=True)
(raw / 'keep.xml').write_text('''<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_leaf" />''', encoding='utf-8')
(drawables / 'warm_icon.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<path android:fillColor="#F3E5CE" android:pathData="M20,0 L88,0 Q108,0 108,20 L108,88 Q108,108 88,108 L20,108 Q0,108 0,88 L0,20 Q0,0 20,0"/>
<path android:fillColor="#476751" android:pathData="M53,82 C48,66 30,69 25,45 C46,42 57,50 55,64 C55,42 65,27 84,24 C87,48 75,62 60,62 L60,82 Z"/>
<path android:fillColor="#D99059" android:pathData="M31,82 L77,82 L77,87 L31,87 Z"/>
</vector>''', encoding='utf-8')
(drawables / 'ic_stat_leaf.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
<path android:fillColor="#FFFFFFFF" android:pathData="M11,22 L11,14 C5,14 2,10 2,5 C8,5 12,8 12,12 C12,5 16,2 22,2 C22,9 18,14 13,14 L13,22 Z"/>
</vector>''', encoding='utf-8')
Path('test/widget_test.dart').unlink(missing_ok=True)
print('Android configured: offline manifest, release signing, minSdk23, local notifications.')
