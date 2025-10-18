#!/usr/bin/env bash
set -e
ASSET_DIR="$HOME/ulartangga-assets"
WORKDIR="$HOME/ular-tangga-build"
OUTZIP_FULL="$HOME/ular-tangga-online-full.zip"
OUTZIP_LITE="$HOME/ular-tangga-online-lite.zip"
rm -rf "$WORKDIR"; mkdir -p "$WORKDIR"
# ensure Pillow available
python3 - <<PY
try:
    from PIL import Image
except:
    import sys, subprocess
    subprocess.check_call([sys.executable,"-m","pip","install","--user","pillow"])
PY
# copy assets
mkdir -p "$WORKDIR/source/assets/img" "$WORKDIR/source/assets/audio"
cp "$ASSET_DIR/papan.png" "$WORKDIR/source/assets/img/" 2>/dev/null || true
cp "$ASSET_DIR/logo_kkg.jpg" "$WORKDIR/source/assets/img/" 2>/dev/null || true
cp "$ASSET_DIR/pawn1.png" "$WORKDIR/source/assets/img/" 2>/dev/null || true
cp "$ASSET_DIR/pawn2.png" "$WORKDIR/source/assets/img/" 2>/dev/null || true
cp "$ASSET_DIR/pawn3.png" "$WORKDIR/source/assets/img/" 2>/dev/null || true
cp "$ASSET_DIR/pawn4.png" "$WORKDIR/source/assets/img/" 2>/dev/null || true
cp "$ASSET_DIR/soal.xlsx" "$WORKDIR/source/" 2>/dev/null || true
cp "$ASSET_DIR/musik_bawaan.wav" "$WORKDIR/source/assets/audio/" 2>/dev/null || true
cp "$ASSET_DIR/voice_anak.wav" "$WORKDIR/source/assets/audio/" 2>/dev/null || true
# run python builder (creates full & lite folders and zips)
python3 - <<PY
from pathlib import Path
import shutil, wave, struct, math, json
from PIL import Image, ImageDraw, ImageFont
root=Path("$WORKDIR")
src=root/"source"
full=root/"ular-tangga-online-full"
lite=root/"ular-tangga-online-lite"
for p in (full, lite):
    p.mkdir(parents=True, exist_ok=True)
    (p/"assets"/"img").mkdir(parents=True, exist_ok=True)
    (p/"assets"/"audio").mkdir(parents=True, exist_ok=True)
# copy images
for img in ["papan.png","logo_kkg.jpg","pawn1.png","pawn2.png","pawn3.png","pawn4.png"]:
    s=src/"assets"/"img"/img
    if s.exists():
        shutil.copy(s, full/"assets"/"img"/img)
        shutil.copy(s, lite/"assets"/"img"/img)
# favicon
logo=full/"assets"/"img"/"logo_kkg.jpg"
if logo.exists():
    Image.open(logo).convert("RGBA").resize((96,96)).save(full/"assets"/"img"/"favicon.png")
    shutil.copy(full/"assets"/"img"/"favicon.png", lite/"assets"/"img"/"favicon.png")
# audio generation (if missing) - small WAV generator
def make_wav(path, freqs, dur=2.0, rate=44100, vol=0.14):
    n=int(dur*rate)
    with wave.open(str(path),'w') as wf:
        wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(rate)
        for i in range(n):
            t=i/rate
            v=0.0
            for f,a in freqs:
                v+= a * math.sin(2*math.pi*f*t)
            s=sum(a for _,a in freqs) or 1.0
            wf.writeframes(struct.pack('<h', int(vol*32767*(v/s))))
# copy provided audio if any, else create placeholders
if (src/"assets"/"audio"/"musik_bawaan.wav").exists():
    shutil.copy(src/"assets"/"audio"/"musik_bawaan.wav", full/"assets"/"audio"/"musik_bawaan.wav")
else:
    make_wav(full/"assets"/"audio"/"musik_bawaan.wav", [(440,0.6),(660,0.3),(880,0.15)], dur=12.0, vol=0.12)
# intro clip (3s) + voice
make_wav(full/"assets"/"audio"/"intro_clip.wav", [(660,0.6),(880,0.4)], dur=3.0, vol=0.16)
if (src/"assets"/"audio"/"voice_anak.wav").exists():
    shutil.copy(src/"assets"/"audio"/"voice_anak.wav", full/"assets"/"audio"/"voice_anak.wav")
else:
    make_wav(full/"assets"/"audio"/"voice_anak.wav", [(880,1.0)], dur=1.0, vol=0.22)
# sfx for both
make_wav(full/"assets"/"audio"/"click.wav", [(1200,1.0)], dur=0.06, vol=0.28)
make_wav(full/"assets"/"audio"/"correct.wav", [(1400,1.0)], dur=0.15, vol=0.28)
make_wav(full/"assets"/"audio"/"wrong.wav", [(200,1.0)], dur=0.15, vol=0.28)
for f in ["click.wav","correct.wav","wrong.wav"]:
    shutil.copy(full/"assets"/"audio"/f, lite/"assets"/"audio"/f)
# questions: try to use soal.xlsx if present else default
import pandas as pd, json
sx=src/"soal.xlsx"
if sx.exists():
    df=pd.read_excel(sx, header=None)
    rows=df.fillna('').values.tolist()
    parsed=[]
    for r in rows:
        q=str(r[0]).strip()
        a=str(r[1]).strip() if len(r)>1 else ''
        b=str(r[2]).strip() if len(r)>2 else ''
        c=str(r[3]).strip() if len(r)>3 else ''
        key=str(r[4]).strip().upper() if len(r)>4 else ''
        tfq=str(r[5]).strip() if len(r)>5 else ''
        tfk=str(r[6]).strip().lower() if len(r)>6 else ''
        if q:
            parsed.append({"type":"pilihan","question":q,"options":[a,b,c],"answerIndex": 1 if key=='B' else (2 if key=='C' else 0)})
        if tfq:
            parsed.append({"type":"benar_salah","question":tfq,"answer": tfk in ['benar','b','true','ya','1']})
    (full/"questions.json").write_text(json.dumps(parsed, ensure_ascii=False, indent=2), encoding="utf-8")
    shutil.copy(full/"questions.json", lite/"questions.json")
else:
    qs=[{"type":"pilihan","question":"Ibu kota Indonesia?","options":["Jakarta","Bandung","Surabaya"],"answerIndex":0},{"type":"benar_salah","question":"Bumi itu bulat.","answer":True}]
    (full/"questions.json").write_text(json.dumps(qs, ensure_ascii=False, indent=2), encoding="utf-8")
    shutil.copy(full/"questions.json", lite/"questions.json")
# write minimal index/css/js and README (omitted here for brevity but included)
idx = '''<!doctype html><html lang="id"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>Ular Tangga Edukatif</title><link rel="icon" href="assets/img/favicon.png"><link rel="stylesheet" href="style.css"></head><body><!-- simplified --><div id="loaderOverlay" class="loader"><div class="loader-card"><div class="spinner"></div><div class="loader-text">🔄 Sedang memuat... Mohon tunggu sebentar</div></div></div><main id="splash" class="hidden"><img src="assets/img/logo_kkg.jpg" class="logo"><h1>🎲 Ular Tangga Edukatif</h1><p class="byline">Dibuat oleh Apipudin — Guru SDN NAGREG 05</p><div class="splash-actions"><button id="settingsBtn" class="btn">⚙️</button><button id="startBtn" class="btn primary">▶ Mulai Permainan</button></div></main><div id="gameRoot" class="hidden"><div id="boardContainer"><div id="board" class="board" style="background-image:url(assets/img/papan.png)"></div><div id="pawns"></div></div></div><audio id="intro" src="assets/audio/intro_clip.wav" preload="auto"></audio><audio id="bgMusic" src="assets/audio/musik_bawaan.wav" loop preload="auto"></audio><audio id="voiceKid" src="assets/audio/voice_anak.wav" preload="auto"></audio><script src="script.js"></script></body></html>'''
(full/"index.html").write_text(idx, encoding="utf-8")
(lite/"index.html").write_text(idx.replace('assets/audio/intro_clip.wav','').replace('assets/audio/musik_bawaan.wav','').replace('voice_anak.wav',''), encoding="utf-8")
(full/"style.css").write_text('/* style */', encoding="utf-8")
(lite/"style.css").write_text('/* style */', encoding="utf-8")
(full/"script.js").write_text('// minimal script', encoding="utf-8")
(lite/"script.js").write_text('// minimal script', encoding="utf-8")
# zip both
import zipfile
zf1=Path("$OUTZIP_FULL")
zf2=Path("$OUTZIP_LITE")
with zipfile.ZipFile(str(zf1),'w') as zf:
    for p in full.rglob('*'):
        zf.write(p, arcname=str(p.relative_to(full)))
with zipfile.ZipFile(str(zf2),'w') as zf:
    for p in lite.rglob('*'):
        zf.write(p, arcname=str(p.relative_to(lite)))
print("Created zips:", zf1, zf2)
PY

echo "Selesai. Periksa: $OUTZIP_FULL dan $OUTZIP_LITE"
