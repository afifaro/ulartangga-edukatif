
document.addEventListener('DOMContentLoaded', function(){
  const loaderOverlay = document.getElementById('loaderOverlay');
  const splash = document.getElementById('splash');
  const gameRoot = document.getElementById('gameRoot');
  const startBtn = document.getElementById('startBtn');
  const settingsBtn = document.getElementById('settingsBtn');
  const settingsMenu = document.getElementById('settingsMenu');
  const uploadBtn = document.getElementById('uploadBtn');
  const closeSettings = document.getElementById('closeSettings');
  const aboutBtn = document.getElementById('aboutBtn');
  const fileInput = document.getElementById('fileInput');
  const toasts = document.getElementById('toasts');
  const musicToggle = document.getElementById('musicToggle');
  const bgMusic = document.getElementById('bgMusic');
  const sfxDice = document.getElementById('sfx-dice');
  const sfxMove = document.getElementById('sfx-move');
  const sfxCorrect = document.getElementById('sfx-correct');
  const sfxWrong = document.getElementById('sfx-wrong');
  const sfxWin = document.getElementById('sfx-win');
  const rollBtns = Array.from(document.querySelectorAll('.roll-btn'));
  const infoText = document.getElementById('infoText');

  function showToast(msg,type='info'){
    const el = document.createElement('div');
    el.textContent = msg;
    el.style.padding='8px 12px'; el.style.borderRadius='8px'; el.style.color='#fff';
    el.style.marginTop='8px'; el.style.boxShadow='0 6px 18px rgba(0,0,0,0.12)';
    el.style.background = type==='success'?'rgba(46,160,67,0.95)':(type==='warn'?'rgba(234,179,18,0.95)':'rgba(200,60,60,0.95)');
    toasts.appendChild(el); setTimeout(()=> el.remove(), 3200);
  }

  async function loadDefaultQuestions(){
    try{
      const res = await fetch('questions.json');
      if(!res.ok) throw new Error('not found');
      const data = await res.json();
      if(Array.isArray(data) && data.length>0){
        window.defaultQuestions = data;
        window.activeQuestions = data.slice();
        showToast('✅ Soal bawaan dimuat.','success');
      } else {
        window.defaultQuestions = []; window.activeQuestions = [];
        showToast('⚠️ Soal bawaan kosong. Unggah soal Anda.','warn');
      }
    }catch(e){
      window.defaultQuestions = []; window.activeQuestions = [];
      showToast('⚠️ Soal bawaan tidak ditemukan. Unggah soal Anda.','warn');
    }
    loaderOverlay.classList.add('hidden');
    splash.classList.remove('hidden');
  }

  function playSfx(el){ if(!el) return; try{ el.currentTime = 0; el.play().catch(()=>{}); }catch(e){} }

  // pawn visuals
  function createPawns(){
    const pawns = document.getElementById('pawns');
    pawns.innerHTML = '';
    for(let i=0;i<4;i++){
      const el = document.createElement('div');
      el.className = 'pawn';
      el.style.background = ['#4caf50','#2196f3','#9c27b0','#ffca28'][i];
      el.dataset.player = i; el.textContent = i+1; el.style.left='50%'; el.style.top='50%';
      pawns.appendChild(el);
    }
  }
  function updatePawnVisual(i){
    const pawn = document.querySelector('.pawn[data-player="'+i+'"]');
    if(!pawn) return;
    const pos = (window.positions && window.positions[i]) || 0;
    const cells = 20;
    const angle = (pos/cells) * Math.PI * 2;
    const radius = (Math.min(document.getElementById('board').clientWidth, document.getElementById('board').clientHeight)/2) - 40;
    const rect = document.getElementById('board').getBoundingClientRect();
    const cx = rect.left + rect.width/2; const cy = rect.top + rect.height/2;
    const x = cx + radius * Math.cos(angle); const y = cy + radius * Math.sin(angle);
    const left = ((x - rect.left)/rect.width)*100; const top = ((y - rect.top)/rect.height)*100;
    pawn.style.left = left + '%'; pawn.style.top = top + '%';
  }

  rollBtns.forEach(rb=>{ rb.addEventListener('click', ()=>{
    const p = Number(rb.dataset.player); if(p !== (window.currentTurn||0)) return;
    playSfx(sfxDice);
    // simple auto-question behavior
    const correct = Math.random() < 0.6;
    if(correct){ playSfx(sfxCorrect); window.positions[p] = (window.positions[p]||0) + 1; playSfx(sfxMove); } else { playSfx(sfxWrong); window.positions[p] = Math.max(0,(window.positions[p]||0)-1); playSfx(sfxMove); }
    updatePawnVisual(p);
    window.currentTurn = ((window.currentTurn||0) + 1) % 4;
  }); });

  settingsBtn.addEventListener('click', ()=> settingsMenu.classList.toggle('hidden'));
  if(closeSettings) closeSettings.addEventListener('click', ()=> settingsMenu.classList.add('hidden'));
  if(aboutBtn) aboutBtn.addEventListener('click', ()=> alert('Ular Tangga Edukatif - Karya Apipudin, SDN NAGREG 05'));
  uploadBtn.addEventListener('click', ()=> fileInput.click());

  fileInput.addEventListener('change', (ev)=>{
    const f = ev.target.files[0]; if(!f) return;
    const reader = new FileReader();
    reader.onload = (e)=>{
      try{
        const wb = XLSX.read(e.target.result, {type:'binary'});
        const sheet = wb.Sheets[wb.SheetNames[0]];
        const rows = XLSX.utils.sheet_to_json(sheet, {header:1});
        const parsed = [];
        for(let r of rows){
          const q = (r[0]||'').toString().trim();
          const a = (r[1]||'').toString().trim();
          const b = (r[2]||'').toString().trim();
          const c = (r[3]||'').toString().trim();
          const key = (r[4]||'').toString().trim().toUpperCase();
          const tfq = (r[5]||'').toString().trim();
          const tfk = (r[6]||'').toString().trim().toLowerCase();
          if(q) parsed.push({type:'pilihan',question:q,options:[a,b,c],answerIndex: key==='B'?1:(key==='C'?2:0)});
          if(tfq) parsed.push({type:'benar_salah',question:tfq,answer:(['benar','b','true','ya','1'].includes(tfk))});
        }
        if(parsed.length>0){ window.activeQuestions = parsed; showToast('✅ Soal berhasil dimuat! Soal bawaan dinonaktifkan.','success'); } else { showToast('⚠️ Format file tidak sesuai atau kosong.','warn'); }
      }catch(err){ console.error(err); showToast('❌ Gagal memuat soal.','error'); }
    };
    reader.readAsBinaryString(f);
  });

  musicToggle.addEventListener('change', ()=>{ if(musicToggle.checked){ bgMusic.play().catch(()=>{}); } else { bgMusic.pause(); } });

  startBtn.addEventListener('click', ()=>{
    splash.classList.add('hidden'); gameRoot.classList.remove('hidden');
    window.positions = [0,0,0,0]; window.currentTurn = 0; createPawns();
    updatePawnVisual(0); updatePawnVisual(1); updatePawnVisual(2); updatePawnVisual(3);
    if(musicToggle.checked) bgMusic.play().catch(()=>{});
  });

  // init
  loadDefaultQuestions();
  createPawns();
  window.positions = [0,0,0,0]; window.currentTurn = 0;
  window.addEventListener('resize', ()=>{ for(let i=0;i<4;i++) updatePawnVisual(i); });
});
