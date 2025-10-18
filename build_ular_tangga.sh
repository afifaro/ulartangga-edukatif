#!/usr/bin/env bash
set -e

# --- Ubah bila perlu ---
ASSET_DIR="$HOME/ulartangga-assets"   # taruh papan.png, logo_kkg.jpg, optional musik_bawaan.wav & voice_anak.wav di sini
WORKDIR="$HOME/ular-tangga-build"
OUTZIP_FULL="$HOME/ular-tangga-online-full.zip"
OUTZIP_LITE="$HOME/ular-tangga-online-lite.zip"
# ------------------------

echo "Build start — working dir: $WORKDIR"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# helper: ensure python dependencies (Pillow) exist
if ! python3 -c "import PIL" >/dev/null 2>&1; then
  echo "Python pillow (PIL) not found. Installing via pip..."
  python3 -m pip install --user pillow >/dev/null
fi

# copy assets or leave placeholder
mkdir -p "$WORKDIR/assets/img" "$WORKDIR/assets/audio"

if [ -f "$ASSET_DIR/papan.png" ]; then
  cp "$ASSET_DIR/papan.png" "$WORKDIR/assets/img/papan.png"
  echo "Copied papan.png from $ASSET_DIR"
fi

if [ -f "$ASSET_DIR/logo_kkg.jpg" ]; then
  cp "$ASSET_DIR/logo_kkg.jpg" "$WORKDIR/assets/img/logo_kkg.jpg"
  echo "Copied logo_kkg.jpg from $ASSET_DIR"
fi

# optional audio provided?
if [ -f "$ASSET_DIR/musik_bawaan.wav" ]; then
  cp "$ASSET_DIR/musik_bawaan.wav" "$WORKDIR/assets/audio/musik_bawaan.wav"
  echo "Using provided musik_bawaan.wav"
fi
if [ -f "$ASSET_DIR/voice_anak.wav" ]; then
  cp "$ASSET_DIR/voice_anak.wav" "$WORKDIR/assets/audio/voice_anak.wav"
  echo "Using provided voice_anak.wav"
fi

# Create placeholders / favicon if needed using python
python3 - <<PY
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
wdir = Path("$WORKDIR")
imgdir = wdir / "assets" / "img"
imgdir.mkdir(parents=True, exist_ok=True)

# papan placeholder
if not (imgdir/"papan.png").exists():
    board = Image.new("RGBA", (1200,1200), (235,250,235))
    d = ImageDraw.Draw(board)
    for i in range(0,1200,120):
        d.line([(i,0),(i,1200)], fill=(200,230,200))
        d.line([(0,i),(1200,i)], fill=(200,230,200))
    board.save(imgdir/"papan.png")
    print("Placeholder papan.png created")

# logo placeholder
if not (imgdir/"logo_kkg.jpg").exists():
    img = Image.new("RGB",(512,512),(34,139,34))
    d = ImageDraw.Draw(img)
    try:
        fnt = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",48)
    except:
        fnt = None
    d.text((40,220),"KKG", fill=(255,255,255), font=fnt)
    img.save(imgdir/"logo_kkg.jpg")
    print("Placeholder logo_kkg.jpg created")

# favicon 96x96
logo = Image.open(imgdir/"logo_kkg.jpg").convert("RGBA").resize((96,96))
logo.save(imgdir/"favicon.png")
print("Favicon created")
PY

# generate high-quality audio placeholders if not provided (full version)
if [ ! -f "$WORKDIR/assets/audio/musik_bawaan.wav" ] || [ ! -f "$WORKDIR/assets/audio/voice_anak.wav" ]; then
  echo "Creating audio placeholders (high quality) ..."
  python3 - <<PY
import wave, struct, math
from pathlib import Path
out = Path("$WORKDIR/assets/audio")
out.mkdir(parents=True, exist_ok=True)

def make_stereo(path, freqsL, freqsR, dur=12.0, rate=44100, vol=0.12):
    nframes = int(dur*rate)
    with wave.open(str(path),'w') as wf:
        wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(rate)
        for i in range(nframes):
            t = i / rate
            vl = 0.0
            vr = 0.0
            for f,a in freqsL: vl += a * math.sin(2*math.pi*f*t)
            for f,a in freqsR: vr += a * math.sin(2*math.pi*f*t)
            s = max(sum(a for _,a in freqsL), sum(a for _,a in freqsR), 1.0)
            sl = int(vol*32767.0*(vl/s))
            sr = int(vol*32767.0*(vr/s))
            wf.writeframes(struct.pack('<hh', sl, sr))

if not (out/"musik_bawaan.wav").exists():
    make_stereo(out/"musik_bawaan.wav", [(440,0.6),(660,0.35),(880,0.15)], [(330,0.5),(550,0.35),(660,0.2)], dur=12.0, vol=0.12)
if not (out/"voice_anak.wav").exists():
    make_stereo(out/"voice_anak.wav", [(880,0.9),(1320,0.2)], [(880,0.9),(1320,0.2)], dur=1.2, vol=0.22)
# sfx small
if not (out/"click.wav").exists():
    make_stereo(out/"click.wav", [(1200,1.0)], [(1200,1.0)], dur=0.06, vol=0.28)
if not (out/"correct.wav").exists():
    make_stereo(out/"correct.wav", [(1400,1.0),(1800,0.4)], [(1400,1.0)], dur=0.15, vol=0.28)
if not (out/"wrong.wav").exists():
    make_stereo(out/"wrong.wav", [(200,1.0)], [(200,1.0)], dur=0.15, vol=0.28)
print("Audio placeholders created.")
PY
fi

# helper to write file content
write() {
  cat > "$1"
}

# common files (index, css, js, manifest, sw, questions, README)
# For brevity: create small template files. They include credit "Dibuat oleh Apipudin - Guru SDN NAGREG 05"
# index.html template (we'll create one for full and one for lite)
# Common JS/CSS will be identical, the lite version will point to no audio.

# Create folders for full & lite
FULLDIR="$WORKDIR/ular-tangga-online-full"
LITEDIR="$WORKDIR/ular-tangga-online-lite"
rm -rf "$FULLDIR" "$LITEDIR"
mkdir -p "$FULLDIR/assets/img" "$FULLDIR/assets/audio"
mkdir -p "$LITEDIR/assets/img" "$LITEDIR/assets/audio"

# copy images/audio
cp "$WORKDIR/assets/img/papan.png" "$FULLDIR/assets/img/papan.png"
cp "$WORKDIR/assets/img/logo_kkg.jpg" "$FULLDIR/assets/img/logo_kkg.jpg"
cp "$WORKDIR/assets/img/favicon.png" "$FULLDIR/assets/img/favicon.png"
cp "$WORKDIR/assets/audio/musik_bawaan.wav" "$FULLDIR/assets/audio/musik_bawaan.wav" 2>/dev/null || true
cp "$WORKDIR/assets/audio/voice_anak.wav" "$FULLDIR/assets/audio/voice_anak.wav" 2>/dev/null || true
cp "$WORKDIR/assets/audio/click.wav" "$FULLDIR/assets/audio/click.wav" 2>/dev/null || true
cp "$WORKDIR/assets/audio/correct.wav" "$FULLDIR/assets/audio/correct.wav" 2>/dev/null || true
cp "$WORKDIR/assets/audio/wrong.wav" "$FULLDIR/assets/audio/wrong.wav" 2>/dev/null || true

# lite: copy images only (no music)
cp "$WORKDIR/assets/img/papan.png" "$LITEDIR/assets/img/papan.png"
cp "$WORKDIR/assets/img/logo_kkg.jpg" "$LITEDIR/assets/img/logo_kkg.jpg"
cp "$WORKDIR/assets/img/favicon.png" "$LITEDIR/assets/img/favicon.png"

# questions (convert xlsx -> json if xlsx provided)
if [ -f "$ASSET_DIR/soal.xlsx" ]; then
  echo "Found soal.xlsx — converting to JSON (simple conversion)..."
  # Needs python openpyxl or pandas — do a simple excel to json fallback via pandas if available
  python3 - <<PY
import pandas as pd, json, sys
from pathlib import Path
p=Path("$ASSET_DIR/soal.xlsx")
out=Path("$FULLDIR/questions.json")
if p.exists():
    df=pd.read_excel(p, header=None)
    rows=df.fillna('').values.tolist()
    parsed=[]
    for r in rows:
        q = str(r[0]).strip()
        a = str(r[1]).strip() if len(r)>1 else ''
        b = str(r[2]).strip() if len(r)>2 else ''
        c = str(r[3]).strip() if len(r)>3 else ''
        key = str(r[4]).strip().upper() if len(r)>4 else ''
        tfq = str(r[5]).strip() if len(r)>5 else ''
        tfk = str(r[6]).strip().lower() if len(r)>6 else ''
        if q:
            parsed.append({"type":"pilihan","question":q,"options":[a,b,c],"answerIndex": 1 if key=='B' else (2 if key=='C' else 0)})
        if tfq:
            parsed.append({"type":"benar_salah","question":tfq,"answer": tfk in ['benar','b','true','ya','1']})
    out.write_text(json.dumps(parsed, ensure_ascii=False, indent=2))
    print("questions.json from soal.xlsx created.")
else:
    print("no soal.xlsx")
PY
fi

# if conversion not done, write a default questions.json
if [ ! -f "$FULLDIR/questions.json" ]; then
cat > "$FULLDIR/questions.json" <<Q
[
  {"type":"pilihan","question":"Ibu kota Indonesia?","options":["Jakarta","Bandung","Surabaya"],"answerIndex":0},
  {"type":"benar_salah","question":"Bumi itu bulat.","answer":true},
  {"type":"pilihan","question":"2 + 2 = ?","options":["3","4","5"],"answerIndex":1}
]
Q
fi
# Copy questions.json to lite as well
cp "$FULLDIR/questions.json" "$LITEDIR/questions.json"

# README.md
cat > "$FULLDIR/README.md" <<R
Ular Tangga Edukatif — Versi FULL (musik & suara)
Dibuat oleh Apipudin — Guru SDN NAGREG 05

Cara deploy cepat:
1. Unzip folder 'ular-tangga-online-full' ke repo GitHub Anda.
2. Commit & push ke branch main (root).
3. Settings -> Pages -> pilih branch main, root -> Save.
4. Buka https://<username>.github.io/<repo>/

Catatan:
- Musik akan mulai hanya setelah menekan "Mulai Permainan".
- Jika ingin gunakan soal sendiri, pilih "Unggah Soal Sendiri (.xlsx)" di Pengaturan.
R

cat > "$LITEDIR/README.md" <<R
Ular Tangga Edukatif — Versi LITE (tanpa musik)
Dibuat oleh Apipudin — Guru SDN NAGREG 05

Cara deploy cepat: sama seperti di README full.
R

# create simple index, css, js (templates). For brevity, provide working minimal files.
cat > "$FULLDIR/index.html" <<'H'
<!doctype html><html lang="id"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>Ular Tangga Edukatif</title><link rel="icon" href="assets/img/favicon.png"><link rel="stylesheet" href="style.css"></head><body>
<div id="loaderOverlay" class="loader"><div class="loader-card"><div class="spinner"></div><div class="loader-text">🔄 Sedang memuat... Mohon tunggu sebentar</div></div></div>
<main id="splash" class="hidden"><img src="assets/img/logo_kkg.jpg" class="logo"><h1>🎲 Ular Tangga Edukatif</h1><p class="byline">Dibuat oleh Apipudin — Guru SDN NAGREG 05</p><div class="splash-actions"><button id="settingsBtn" class="btn">⚙️</button><button id="startBtn" class="btn primary">▶ Mulai Permainan</button></div><p class="hint">Tekan Pengaturan → Musik untuk memutar musik.</p></main>
<div id="settingsMenu" class="hidden"><div class="settings-card"><h3>Pengaturan</h3><div class="row"><button id="uploadBtn" class="btn">🎓 Unggah Soal Sendiri (.xlsx)</button></div><label class="row"><input type="checkbox" id="musicToggle"> Musik</label><div class="row"><button id="closeSettings" class="btn">Tutup</button></div></div></div>
<div id="toasts" aria-live="polite"></div>
<div id="gameRoot" class="hidden"><button id="homeBtn" class="home-btn">🏠</button><button id="helpBtn" class="help-btn">❓</button><div id="boardContainer"><div class="board" id="board"></div><div id="pawns"></div></div><div class="controls"><div id="infoText">Siap bermain!</div></div><button class="roll-btn" id="rollBtn-1" data-player="0">🎲</button><button class="roll-btn" id="rollBtn-2" data-player="1">🎲</button><button class="roll-btn" id="rollBtn-3" data-player="2">🎲</button><button class="roll-btn" id="rollBtn-4" data-player="3">🎲</button></div>
<input type="file" id="fileInput" accept=".xlsx" style="display:none"/>
<audio id="introClip" src="assets/audio/musik_bawaan.wav" preload="auto"></audio>
<audio id="voiceKid" src="assets/audio/voice_anak.wav" preload="auto"></audio>
<audio id="bgMusic" src="assets/audio/musik_bawaan.wav" loop preload="auto"></audio>
<audio id="clickSfx" src="assets/audio/click.wav" preload="auto"></audio>
<audio id="sfx-correct" src="assets/audio/correct.wav" preload="auto"></audio>
<audio id="sfx-wrong" src="assets/audio/wrong.wav" preload="auto"></audio>
<script src="script.js"></script>
</body></html>
H

cat > "$LITEDIR/index.html" <<'H'
<!doctype html><html lang="id"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>Ular Tangga Edukatif (Lite)</title><link rel="icon" href="assets/img/favicon.png"><link rel="stylesheet" href="style.css"></head><body>
<div id="loaderOverlay" class="loader"><div class="loader-card"><div class="spinner"></div><div class="loader-text">🔄 Sedang memuat... Mohon tunggu sebentar</div></div></div>
<main id="splash" class="hidden"><img src="assets/img/logo_kkg.jpg" class="logo"><h1>🎲 Ular Tangga Edukatif</h1><p class="byline">Dibuat oleh Apipudin — Guru SDN NAGREG 05</p><div class="splash-actions"><button id="settingsBtn" class="btn">⚙️</button><button id="startBtn" class="btn primary">▶ Mulai Permainan</button></div><p class="hint">Versi ringan (tanpa musik)</p></main>
<div id="settingsMenu" class="hidden"><div class="settings-card"><h3>Pengaturan</h3><div class="row"><button id="uploadBtn" class="btn">🎓 Unggah Soal Sendiri (.xlsx)</button></div><div class="row"><button id="closeSettings" class="btn">Tutup</button></div></div></div>
<div id="toasts" aria-live="polite"></div>
<div id="gameRoot" class="hidden"><button id="homeBtn" class="home-btn">🏠</button><button id="helpBtn" class="help-btn">❓</button><div id="boardContainer"><div class="board" id="board"></div><div id="pawns"></div></div><div class="controls"><div id="infoText">Siap bermain!</div></div><button class="roll-btn" id="rollBtn-1" data-player="0">🎲</button><button class="roll-btn" id="rollBtn-2" data-player="1">🎲</button><button class="roll-btn" id="rollBtn-3" data-player="2">🎲</button><button class="roll-btn" id="rollBtn-4" data-player="3">🎲</button></div>
<input type="file" id="fileInput" accept=".xlsx" style="display:none"/>
<audio id="clickSfx" src="assets/audio/click.wav" preload="auto"></audio>
<audio id="sfx-correct" src="assets/audio/correct.wav" preload="auto"></audio>
<audio id="sfx-wrong" src="assets/audio/wrong.wav" preload="auto"></audio>
<script src="script.js"></script>
</body></html>
H

# shared style & script (minimal but functional)
cat > "$FULLDIR/style.css" <<'C'
/* (same styling used for both full & lite) */
*{box-sizing:border-box}html,body{height:100%;margin:0;font-family:Arial,Helvetica,sans-serif;background:linear-gradient(180deg,#eaf7e9,#f7fff4);color:#0f3d1b;overflow:hidden}.loader{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:linear-gradient(180deg,rgba(255,255,255,0.95),rgba(245,255,240,0.95));z-index:9999}.loader-card{display:flex;flex-direction:column;align-items:center;padding:18px;border-radius:12px;box-shadow:0 8px 30px rgba(0,0,0,0.12);background:#fff}.spinner{width:56px;height:56px;border-radius:50%;border:6px solid rgba(0,0,0,0.06);border-top-color:#2fa84f;animation:spin .9s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}.hidden{display:none}#splash{width:100vw;height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:12px;opacity:0;transition:opacity .6s}#splash.show{opacity:1}.logo{width:120px;height:120px;border-radius:12px;object-fit:cover;margin-bottom:10px}.splash-actions{display:flex;gap:12px;margin-top:14px}.primary{background:#4caf50;color:#fff;border:none;padding:10px 20px;border-radius:10px;font-size:1.05rem;cursor:pointer}.btn{background:#fff;border-radius:8px;border:none;padding:8px 10px;box-shadow:0 4px 12px rgba(0,0,0,0.08);cursor:pointer}#settingsMenu{position:fixed;top:12px;right:12px;z-index:2000}.settings-card{background:#fff;padding:12px;border-radius:10px;box-shadow:0 8px 20px rgba(0,0,0,0.12);min-width:220px;opacity:0;transform:translateY(-8px);transition:all .28s}.settings-card.show{opacity:1;transform:none}#boardContainer{display:flex;align-items:center;justify-content:center;padding:12px}.board{width:78vmin;height:78vmin;background-size:cover;background-position:center;border-radius:12px;box-shadow:0 8px 30px rgba(0,0,0,0.08)}#pawns{position:absolute;inset:0;pointer-events:none}.pawn{width:28px;height:28px;border-radius:50%;position:absolute;transform:translate(-50%,-50%);display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700}.controls{width:100%;display:flex;justify-content:center;align-items:center;padding:10px;background:linear-gradient(180deg,#b6f0a6,#fff9d9);box-shadow:0 -2px 10px rgba(0,0,0,0.06)}.roll-btn{position:fixed;width:56px;height:56px;border-radius:50%;border:none;background:rgba(255,255,255,0.95);box-shadow:0 6px 18px rgba(0,0,0,0.12);display:flex;align-items:center;justify-content:center;font-size:22px;cursor:pointer;z-index:50;opacity:0.35}.roll-btn.active{opacity:1;transform:scale(1.04)}#rollBtn-1{left:12px;bottom:12px;background:#4caf50}#rollBtn-2{right:12px;bottom:12px;background:#2196f3}#rollBtn-3{right:12px;top:12px;background:#9c27b0}#rollBtn-4{left:12px;top:12px;background:#ffca28}.home-btn{position:fixed;left:10px;top:8px;width:44px;height:44px;border-radius:8px;border:none;background:rgba(255,255,255,0.95);box-shadow:0 6px 18px rgba(0,0,0,0.12);font-size:20px;z-index:100;cursor:pointer}.help-btn{position:fixed;right:10px;top:8px;width:44px;height:44px;border-radius:8px;border:none;background:rgba(255,255,255,0.95);box-shadow:0 6px 18px rgba(0,0,0,0.12);font-size:20px;z-index:100;cursor:pointer}.watermark{position:fixed;right:8px;bottom:8px;opacity:0.18;width:84px;height:84px;border-radius:8px;pointer-events:none}@media (max-width:700px){ .board{width:92vmin;height:62vmin} .primary{padding:8px 14px} .roll-btn{width:48px;height:48px;font-size:18px} .pawn{width:22px;height:22px;font-size:10px} .home-btn{left:8px;top:8px;width:40px;height:40px} }.hint{margin-top:12px;color:#2f6b2f;font-size:0.95rem}
C

cp "$FULLDIR/style.css" "$LITEDIR/style.css"

cat > "$FULLDIR/script.js" <<'J'
/* simplified but functional game script (full) */
document.addEventListener('DOMContentLoaded', function(){
  const loader = document.getElementById('loaderOverlay');
  const splash = document.getElementById('splash');
  const startBtn = document.getElementById('startBtn');
  const settingsBtn = document.getElementById('settingsBtn');
  const settingsMenu = document.getElementById('settingsMenu');
  const settingsCard = document.querySelector('.settings-card');
  const uploadBtn = document.getElementById('uploadBtn');
  const closeSettings = document.getElementById('closeSettings');
  const musicToggle = document.getElementById('musicToggle');
  const introClip = document.getElementById('introClip');
  const voiceKid = document.getElementById('voiceKid');
  const bgMusic = document.getElementById('bgMusic');
  const fileInput = document.getElementById('fileInput');
  const toasts = document.getElementById('toasts');
  const gameRoot = document.getElementById('gameRoot');
  const homeBtn = document.getElementById('homeBtn');
  const infoText = document.getElementById('infoText');
  const helpBtn = document.getElementById('helpBtn');
  const clickSfx = document.getElementById('clickSfx');
  let defaultQuestions = [], activeQuestions = [];
  window.positions = [0,0,0,0]; window.currentTurn = 0;

  function showToast(msg){ const el=document.createElement('div'); el.textContent=msg; el.style.padding='8px 12px'; el.style.borderRadius='8px'; el.style.color='#fff'; el.style.marginTop='8px'; el.style.background='#2ea043'; toasts.appendChild(el); setTimeout(()=>el.remove(),3000); }

  try{ const saved = JSON.parse(localStorage.getItem('ular_tangga_state')||'null'); if(saved){ window.positions = saved.positions || window.positions; window.currentTurn = saved.currentTurn || window.currentTurn; if(saved.activeQuestions) activeQuestions = saved.activeQuestions; showToast('Progres dimuat'); } }catch(e){}

  fetch('questions.json').then(r=>r.json()).then(d=>{ defaultQuestions=d; if(activeQuestions.length===0) activeQuestions=d.slice(); showToast('Soal bawaan dimuat'); }).catch(()=>{});

  setTimeout(()=>{ loader.classList.add('hidden'); splash.classList.remove('hidden'); splash.classList.add('show'); },1400);

  settingsBtn.addEventListener('click', ()=>{ if(!settingsMenu.classList.contains('hidden')){ settingsMenu.classList.add('hidden'); settingsCard.classList.remove('show'); if(musicToggle.checked) bgMusic.play().catch(()=>{}); } else { settingsMenu.classList.remove('hidden'); settingsCard.classList.add('show'); if(!bgMusic.paused) bgMusic.pause(); } });

  uploadBtn&&uploadBtn.addEventListener('click', ()=> fileInput.click());
  fileInput&&fileInput.addEventListener('change', (ev)=>{ const f=ev.target.files[0]; if(!f) return; const reader=new FileReader(); reader.onload=(e)=>{ try{ const wb=XLSX.read(e.target.result,{type:'binary'}); const sheet=wb.Sheets[wb.SheetNames[0]]; const rows=XLSX.utils.sheet_to_json(sheet,{header:1}); const parsed=[]; for(let r of rows){ const q=(r[0]||'').toString().trim(); const a=(r[1]||'').toString().trim(); const b=(r[2]||'').toString().trim(); const c=(r[3]||'').toString().trim(); const key=(r[4]||'').toString().trim().toUpperCase(); const tfq=(r[5]||'').toString().trim(); const tfk=(r[6]||'').toString().trim().toLowerCase(); if(q) parsed.push({type:'pilihan',question:q,options:[a,b,c],answerIndex:key==='B'?1:(key==='C'?2:0)}); if(tfq) parsed.push({type:'benar_salah',question:tfq,answer:(['benar','b','true','ya','1'].includes(tfk))}); } if(parsed.length>0){ activeQuestions=parsed; saveState(); showToast('Soal berhasil dimuat — soal bawaan dinonaktifkan'); } else showToast('Format tidak sesuai'); }catch(err){ console.error(err); showToast('Gagal memproses file'); } }; reader.readAsBinaryString(f); });

  startBtn.addEventListener('click', ()=>{ splash.classList.add('hidden'); gameRoot.classList.remove('hidden'); createPawns(); setActiveButtons(); infoText.textContent='Giliran: Pemain '+(window.currentTurn+1); // play intro once
    try{ voiceKid.play().catch(()=>{}); introClip.currentTime=0; introClip.play().catch(()=>{}); }catch(e){} if(musicToggle.checked) bgMusic.play().catch(()=>{}); });

  homeBtn.addEventListener('click', ()=>{ gameRoot.classList.add('hidden'); splash.classList.remove('hidden'); splash.classList.add('show'); if(!bgMusic.paused){ bgMusic.pause(); bgMusic.currentTime=0; } saveState(); });

  helpBtn.addEventListener('click', ()=>{ const modal=document.createElement('div'); modal.style.position='fixed'; modal.style.inset='12%'; modal.style.zIndex=9999; modal.style.background='#fff'; modal.style.padding='14px'; modal.style.borderRadius='12px'; modal.innerHTML='<h3>Cara Bermain</h3><ol><li>Tekan tombol dadu sesuai giliran pemain.</li><li>Jawab soal: benar maju, salah turun.</li><li>Pemain pertama sampai kotak terakhir menang.</li></ol><button id=\"closeHelp\" class=\"btn\">Tutup Panduan</button>'; document.body.appendChild(modal); if(!bgMusic.paused) bgMusic.pause(); document.getElementById('closeHelp').addEventListener('click', ()=>{ modal.remove(); if(musicToggle.checked) bgMusic.play().catch(()=>{}); }); });

  function createPawns(){ const pawns=document.getElementById('pawns'); pawns.innerHTML=''; for(let i=0;i<4;i++){ const el=document.createElement('div'); el.className='pawn'; el.style.background=['#4caf50','#2196f3','#9c27b0','#ffca28'][i]; el.dataset.player=i; el.textContent=i+1; el.style.left='50%'; el.style.top='50%'; pawns.appendChild(el);} for(let i=0;i<4;i++) updatePawnVisual(i); }

  function updatePawnVisual(i){ const pawn=document.querySelector('.pawn[data-player=\"'+i+'\"]'); if(!pawn) return; const pos=window.positions[i]||0; const cells=20; const angle=(pos/cells)*Math.PI*2; const rect=document.getElementById('board').getBoundingClientRect(); const radius=(Math.min(rect.width,rect.height)/2)-40; const cx=rect.left+rect.width/2; const cy=rect.top+rect.height/2; const x=cx+radius*Math.cos(angle); const y=cy+radius*Math.sin(angle); pawn.style.left=(((x-rect.left)/rect.width)*100)+'%'; pawn.style.top=(((y-rect.top)/rect.height)*100)+'%'; }

  function movePawnBy(i,delta){ window.positions[i]=(window.positions[i]||0)+delta; if(window.positions[i]<0) window.positions[i]=0; updatePawnVisual(i); saveState(); }

  const rollBtns=Array.from(document.querySelectorAll('.roll-btn'));
  function setActiveButtons(){ rollBtns.forEach(btn=>{ const p=Number(btn.dataset.player); if(p===window.currentTurn){ btn.classList.add('active'); btn.disabled=false; } else { btn.classList.remove('active'); btn.disabled=true; } }); }
  rollBtns.forEach(rb=>{ rb.addEventListener('click', ()=>{ const p=Number(rb.dataset.player); if(p!==window.currentTurn) return; clickSfx.play().catch(()=>{}); if(!activeQuestions||activeQuestions.length===0){ const correct=Math.random()<0.6; if(correct){ document.getElementById('sfx-correct')&&document.getElementById('sfx-correct').play().catch(()=>{}); movePawnBy(p,1); } else { document.getElementById('sfx-wrong')&&document.getElementById('sfx-wrong').play().catch(()=>{}); movePawnBy(p,-1); } window.currentTurn=(window.currentTurn+1)%4; setActiveButtons(); return; } const q=activeQuestions[Math.floor(Math.random()*activeQuestions.length)]; if(q.type==='pilihan'){ const ans=prompt(q.question+'\\n'+q.options.map((o,i)=>(i+1)+'. '+o).join('\\n')); const pick=Number(ans)-1; const correct=(pick===q.answerIndex); if(correct){ document.getElementById('sfx-correct')&&document.getElementById('sfx-correct').play().catch(()=>{}); movePawnBy(p,1); } else { document.getElementById('sfx-wrong')&&document.getElementById('sfx-wrong').play().catch(()=>{}); movePawnBy(p,-1); } } else { const ans=prompt(q.question+'\\nJawab: Benar / Salah'); const pick=(ans||'').toLowerCase().includes('benar'); const correct=(pick===q.answer); if(correct){ document.getElementById('sfx-correct')&&document.getElementById('sfx-correct').play().catch(()=>{}); movePawnBy(p,1); } else { document.getElementById('sfx-wrong')&&document.getElementById('sfx-wrong').play().catch(()=>{}); movePawnBy(p,-1); } } window.currentTurn=(window.currentTurn+1)%4; setActiveButtons(); }); });

  function saveState(){ try{ const state={positions:window.positions,currentTurn:window.currentTurn,activeQuestions:activeQuestions}; localStorage.setItem('ular_tangga_state',JSON.stringify(state)); }catch(e){} }
  const boardEl=document.getElementById('board'); boardEl.style.backgroundImage='url(assets/img/papan.png)';
  createPawns(); setActiveButtons();
  window.addEventListener('resize', ()=>{ for(let i=0;i<4;i++) updatePawnVisual(i); });
});
J

cp "$FULLDIR/script.js" "$LITEDIR/script.js"

# copy audio files to lite where only sfx needed
cp "$FULLDIR/assets/audio/click.wav" "$LITEDIR/assets/audio/click.wav" 2>/dev/null || true
cp "$FULLDIR/assets/audio/correct.wav" "$LITEDIR/assets/audio/correct.wav" 2>/dev/null || true
cp "$FULLDIR/assets/audio/wrong.wav" "$LITEDIR/assets/audio/wrong.wav" 2>/dev/null || true

# Create zips
cd "$WORKDIR"
echo "Creating zip: $OUTZIP_FULL"
rm -f "$OUTZIP_FULL"
zip -r "$OUTZIP_FULL" "ular-tangga-online-full" > /dev/null
echo "Creating zip: $OUTZIP_LITE"
rm -f "$OUTZIP_LITE"
zip -r "$OUTZIP_LITE" "ular-tangga-online-lite" > /dev/null

echo "DONE. Files created:"
echo " - $OUTZIP_FULL"
echo " - $OUTZIP_LITE"
echo ""
echo "Upload salah satu folder hasil unzip ke repo GitHub Anda, lalu aktifkan GitHub Pages (branch: main, folder: /)."

