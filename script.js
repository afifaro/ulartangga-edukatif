/* script.js - Ular Tangga Edukatif (online-ready) */
document.addEventListener('DOMContentLoaded', () => {
  // elements
  const loader = document.getElementById('loaderOverlay');
  const splash = document.getElementById('splash');
  const startBtn = document.getElementById('startBtn');
  const settingsBtn = document.getElementById('settingsBtn');
  const settingsMenu = document.getElementById('settingsMenu');
  const settingsCard = document.querySelector('.settings-card');
  const uploadBtn = document.getElementById('uploadBtn');
  const closeSettings = document.getElementById('closeSettings');
  const musicToggle = document.getElementById('musicToggle');
  const bgMusic = document.getElementById('bgMusic');
  const voiceKid = document.getElementById('voiceKid');
  const clickSfx = document.getElementById('clickSfx');
  const fileInput = document.getElementById('fileInput');
  const toasts = document.getElementById('toasts');
  const gameRoot = document.getElementById('gameRoot');
  const homeBtn = document.getElementById('homeBtn');
  const infoText = document.getElementById('infoText');

  // watermark
  const watermark = document.createElement('img');
  watermark.src = 'assets/img/logo_kkg.jpg';
  watermark.className = 'watermark';
  document.body.appendChild(watermark);

  // questions
  let defaultQuestions = [];
  let activeQuestions = [];
  // positions and turn
  window.positions = [0,0,0,0];
  window.currentTurn = 0;

  // small toast
  function showToast(msg, type='info') {
    const el = document.createElement('div');
    el.textContent = msg;
    el.style.background = type==='success' ? '#2ea043' : (type==='warn' ? '#eab312' : '#c94a4a');
    el.style.color = '#fff'; el.style.padding = '8px 12px'; el.style.borderRadius = '8px'; el.style.marginTop = '8px';
    toasts.appendChild(el); setTimeout(()=> el.remove(), 3000);
  }

  // load default questions.json (if present) but don't block UI
  fetch('questions.json').then(r => {
    if (!r.ok) throw new Error('no questions.json');
    return r.json();
  }).then(data => {
    if (Array.isArray(data) && data.length) {
      defaultQuestions = data;
      activeQuestions = data.slice();
      showToast('Soal bawaan dimuat','success');
    } else {
      showToast('Soal bawaan kosong','warn');
    }
  }).catch(()=> {
    // try assets/soal.xlsx if exists? we skip heavy fetch; defaultQuestions stays []
    defaultQuestions = []; activeQuestions = [];
  }).finally(() => {
    // keep loader visible ~2s then show splash and play voice
    setTimeout(()=> {
      loader.classList.add('hidden');
      splash.classList.remove('hidden');
      splash.classList.add('show');
      try { voiceKid.play().catch(()=>{}); } catch(e){}
    }, 2000);
  });

  // Settings behavior
  settingsBtn.addEventListener('click', ()=>{
    clickSfx.play().catch(()=>{});
    settingsMenu.classList.toggle('hidden');
    settingsCard.classList.toggle('show');
    if (!settingsMenu.classList.contains('hidden')) {
      // pause music while settings open
      if (!bgMusic.paused) bgMusic.pause();
    } else {
      if (musicToggle.checked) bgMusic.play().catch(()=>{});
    }
  });
  closeSettings.addEventListener('click', ()=> {
    settingsMenu.classList.add('hidden'); settingsCard.classList.remove('show');
    if (musicToggle.checked) bgMusic.play().catch(()=>{});
  });

  // upload .xlsx
  uploadBtn.addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', (ev) => {
    const f = ev.target.files[0]; if(!f) return;
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const wb = XLSX.read(e.target.result, { type: 'binary' });
        const sheet = wb.Sheets[wb.SheetNames[0]];
        const rows = XLSX.utils.sheet_to_json(sheet, { header:1 });
        const parsed = [];
        for (let r of rows) {
          // assume: A question, B opt1, C opt2, D opt3, E key (A/B/C), F TF question, G TF key
          const q = (r[0]||'').toString().trim();
          const a = (r[1]||'').toString().trim();
          const b = (r[2]||'').toString().trim();
          const c = (r[3]||'').toString().trim();
          const key = (r[4]||'').toString().trim().toUpperCase();
          const tfq = (r[5]||'').toString().trim();
          const tfk = (r[6]||'').toString().trim().toLowerCase();
          if (q) parsed.push({ type:'pilihan', question:q, options:[a,b,c], answerIndex: key==='B'?1:(key==='C'?2:0) });
          if (tfq) parsed.push({ type:'benar_salah', question:tfq, answer: (['benar','b','true','ya','1'].includes(tfk)) });
        }
        if (parsed.length) {
          activeQuestions = parsed;
          showToast('Soal berhasil diunggah — soal bawaan dinonaktifkan','success');
        } else showToast('Format file tidak sesuai atau kosong','warn');
      } catch(err) { console.error(err); showToast('Gagal memproses file','warn'); }
    };
    reader.readAsBinaryString(f);
  });

  // Start game
  startBtn.addEventListener('click', () => {
    clickSfx.play().catch(()=>{});
    splash.classList.add('hidden');
    gameRoot.classList.remove('hidden');
    // init
    window.currentTurn = 0; window.positions = [0,0,0,0]; createPawns(); setActiveButtons();
    infoText.textContent = 'Giliran: Pemain 1';
    if (musicToggle.checked) bgMusic.play().catch(()=>{});
  });

  // Home button
  homeBtn.addEventListener('click', ()=>{
    clickSfx.play().catch(()=>{});
    gameRoot.classList.add('hidden');
    splash.classList.remove('hidden');
    splash.classList.add('show');
    if (!bgMusic.paused) { bgMusic.pause(); bgMusic.currentTime = 0; }
  });

  // pawn visuals
  function createPawns(){
    const pawns = document.getElementById('pawns'); pawns.innerHTML = '';
    for (let i=0;i<4;i++){
      const el = document.createElement('div');
      el.className = 'pawn';
      el.style.background = ['#4caf50','#2196f3','#9c27b0','#ffca28'][i];
      el.dataset.player = i; el.textContent = i+1;
      el.style.left='50%'; el.style.top='50%';
      pawns.appendChild(el);
    }
  }
  function updatePawnVisual(i){
    const pawn = document.querySelector('.pawn[data-player="'+i+'"]'); if(!pawn) return;
    const pos = window.positions[i]||0; const cells = 20;
    const angle = (pos/cells)*Math.PI*2;
    const rect = document.getElementById('board').getBoundingClientRect();
    const radius = (Math.min(rect.width, rect.height)/2) - 40;
    const cx = rect.left + rect.width/2; const cy = rect.top + rect.height/2;
    const x = cx + radius*Math.cos(angle); const y = cy + radius*Math.sin(angle);
    pawn.style.left = (((x-rect.left)/rect.width)*100) + '%';
    pawn.style.top = (((y-rect.top)/rect.height)*100) + '%';
  }
  function movePawnBy(i,delta){
    window.positions[i] = (window.positions[i]||0) + delta;
    if (window.positions[i] < 0) window.positions[i] = 0;
    updatePawnVisual(i);
  }

  // roll buttons logic (simple Q/A)
  const rollBtns = Array.from(document.querySelectorAll('.roll-btn'));
  function setActiveButtons(){
    rollBtns.forEach(btn=>{
      const p = Number(btn.dataset.player);
      if (p === window.currentTurn) { btn.classList.add('active'); btn.disabled = false; } else { btn.classList.remove('active'); btn.disabled = true; }
    });
  }
  rollBtns.forEach(btn=>{
    btn.addEventListener('click', ()=>{
      const p = Number(btn.dataset.player); if (p !== window.currentTurn) return;
      clickSfx.play().catch(()=>{});
      // if no questions uploaded, simulate random Q/A: 60% benar
      if (!activeQuestions || activeQuestions.length === 0) {
        const correct = Math.random() < 0.6;
        if (correct) { document.getElementById('sfx-correct') && document.getElementById('sfx-correct').play().catch(()=>{}); movePawnBy(p,1); }
        else { document.getElementById('sfx-wrong') && document.getElementById('sfx-wrong').play().catch(()=>{}); movePawnBy(p,-1); }
        window.currentTurn = (window.currentTurn+1) % 4; setActiveButtons(); return;
      }
      // otherwise use uploaded/bawaan questions
      const q = activeQuestions[Math.floor(Math.random()*activeQuestions.length)];
      if (q.type === 'pilihan') {
        const input = prompt(q.question + '\n' + q.options.map((o,i)=>(i+1)+'. '+o).join('\n'));
        const pick = Number(input)-1; const correct = (pick === q.answerIndex);
        if (correct) { document.getElementById('sfx-correct') && document.getElementById('sfx-correct').play().catch(()=>{}); movePawnBy(p,1); }
        else { document.getElementById('sfx-wrong') && document.getElementById('sfx-wrong').play().catch(()=>{}); movePawnBy(p,-1); }
      } else {
        const input = prompt(q.question + '\nJawab: Benar / Salah');
        const pick = (input||'').toLowerCase().includes('benar'); const correct = (pick === q.answer);
        if (correct) { document.getElementById('sfx-correct') && document.getElementById('sfx-correct').play().catch(()=>{}); movePawnBy(p,1); }
        else { document.getElementById('sfx-wrong') && document.getElementById('sfx-wrong').play().catch(()=>{}); movePawnBy(p,-1); }
      }
      window.currentTurn = (window.currentTurn+1) % 4; setActiveButtons();
    });
  });

  // init
  createPawns(); setActiveButtons();
  window.addEventListener('resize', ()=> { for (let i=0;i<4;i++) updatePawnVisual(i); });
});
