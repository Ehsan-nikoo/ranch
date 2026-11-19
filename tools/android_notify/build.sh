#!/bin/bash
# Builds addons/ranch_notify/ranch_notify.aar (the phone-notification plugin) from src/.
# Needs a JDK and python3 with Pillow. Compiles against the Godot Android library and the Android
# framework classes from Maven Central (Robolectric's android-all jar), so no Android SDK is needed.
# The AAR is plain: classes.jar, the manifest, and the white notification icon; Gradle dexes it at export.
set -e
here=$(cd "$(dirname "$0")" && pwd)
out=$here/../../addons/ranch_notify/ranch_notify.aar
work=$(mktemp -d)
cache=${CACHE:-$HOME/.cache/ranch_notify}
mkdir -p "$cache"
[ -f "$cache/godot-lib.aar" ] || curl -sfL -o "$cache/godot-lib.aar" https://repo1.maven.org/maven2/org/godotengine/godot/4.7.2.stable/godot-4.7.2.stable.aar
[ -f "$cache/android-all.jar" ] || curl -sfL -o "$cache/android-all.jar" https://repo1.maven.org/maven2/org/robolectric/android-all/14-robolectric-10818077/android-all-14-robolectric-10818077.jar
unzip -q -o "$cache/godot-lib.aar" classes.jar -d "$work/godot"
javac --release 8 -nowarn -encoding UTF-8 -cp "$cache/android-all.jar:$work/godot/classes.jar" -d "$work/classes" $(find "$here/src" -name '*.java')
mkdir -p "$work/aar/res/drawable-nodpi"
(cd "$work/classes" && jar cf "$work/aar/classes.jar" .)
cp "$here/AndroidManifest.xml" "$work/aar/"
echo "int drawable ranch_notify_icon 0x7f080001" > "$work/aar/R.txt"
python3 - "$work/aar/res/drawable-nodpi/ranch_notify_icon.png" <<'PY'
# white lawman's star on clear ground: Android paints small notification icons from their alpha
import math, sys
from PIL import Image, ImageDraw
S = 4
im = Image.new("RGBA", (96 * S, 96 * S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
c, pts = 48 * S, []
for i in range(10):
    r = (44 if i % 2 == 0 else 19) * S
    a = math.radians(-90 + i * 36)
    pts.append((c + math.cos(a) * r, c + 2 * S + math.sin(a) * r))
d.polygon(pts, fill=(255, 255, 255, 255))
im.resize((96, 96), Image.LANCZOS).save(sys.argv[1])
PY
mkdir -p "$(dirname "$out")"
rm -f "$out"
(cd "$work/aar" && zip -q -X -r "$out" AndroidManifest.xml classes.jar R.txt res)
rm -rf "$work"
echo "built $out"
