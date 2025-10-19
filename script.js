// ========== Variabel dasar ==========
let currentPlayer = 0;
let positions = [1, 1];
let isRolling = false;
let boardSize = 100;

// Elemen utama
const rollBtn = document.getElementById("rollBtn");
const board = document.getElementById("board");
const quizPopup = document.getElementById("quiz-popup");
const quizQuestion = document.getElementById("quiz-question");
const quizOptions = document.getElementById("quiz-options");
const loader = document.getElementById("loader");

// Suara dan musik
const soundStart = new Audio("ulartangga-assets/bismillah.mp3");
const soundUp = new Audio("ulartangga-assets/alhamdulillah.mp3");
const soundDown = new Audio("ulartangga-assets/astaghfirullah.mp3");
const soundFinish = new Audio("ulartangga-assets/allahuakbar.mp3");
const soundClick = new Audio("ulartangga-assets/button.mp3");
const soundRoll = new Audio("ulartangga-assets/dice.mp3");
const bgMusic = new Audio("ulartangga-assets/music.mp3");
bgMusic.loop = false;

// Data kuis dari file soal.xlsx (dibaca via fetch JSON pre-konversi)
let quizData = [];

// Tangga dan ular (contoh — sesuaikan sesuai papan)
const ladders = { 3: 22, 5: 8, 11: 26, 20: 29, 27: 56, 36: 44, 51: 67, 71: 92 };
const snakes = { 17: 4, 19: 7, 54: 34, 62: 18, 64: 60, 87: 24, 93: 73, 98: 79 };

// ========== Fungsi inisialisasi ==========
window.addEventListener("load", async () => {
  loader.style.display = "none";
  soundStart.play(); // Bismillah di awal
  createDice3D();
  createPawns();
  await loadQuiz();
});

// ========== Membuat pion ==========
function createPawns() {
  for (let i = 0; i < 2; i++) {
    const pawn = document.createElement("img");
    pawn.src = `ulartangga-assets/pawn${i + 1}.png`;
    pawn.classList.add("pawn");
    pawn.style.position = "absolute";
    pawn.style.width = "40px";
    pawn.style.transition = "all 0.5s ease";
    board.appendChild(pawn);
  }
  updatePawnPosition();
}

// ========== Fungsi acak dadu ==========
rollBtn.addEventListener("click", () => {
  if (isRolling) return;
  isRolling = true;
  soundClick.play();
  soundRoll.play();
  rollDice3D();
});

// ========== Fungsi lempar dadu ==========
function rollDice3D() {
  const dice = document.getElementById("dice");
  const result = Math.floor(Math.random() * 6) + 1;
  dice.classList.add("rolling");
  setTimeout(() => {
    dice.classList.remove("rolling");
    movePawn(result);
    isRolling = false;
  }, 1500);
}

// ========== Gerak pion ==========
function movePawn(steps) {
  let pos = positions[currentPlayer] + steps;
  if (pos > boardSize) pos = boardSize;
  positions[currentPlayer] = pos;
  updatePawnPosition();

  setTimeout(() => checkSnakeOrLadder(pos), 600);
}

// ========== Periksa ular/tangga ==========
async function checkSnakeOrLadder(pos) {
  if (ladders[pos]) {
    await showQuiz("ladder", pos);
  } else if (snakes[pos]) {
    await showQuiz("snake", pos);
  } else if (pos === 100) {
    soundFinish.play();
    alert("🎉 Allahu Akbar! Kamu menang!");
  } else {
    switchTurn();
  }
}

// ========== Kuis otomatis ==========
async function showQuiz(type, pos) {
  const q = quizData[Math.floor(Math.random() * quizData.length)];
  quizQuestion.textContent = q.question;
  quizOptions.innerHTML = "";

  q.options.forEach((opt) => {
    const btn = document.createElement("button");
    btn.textContent = opt;
    btn.onclick = () => handleAnswer(type, pos, opt === q.answer);
    quizOptions.appendChild(btn);
  });

  quizPopup.classList.remove("hidden");
}

function handleAnswer(type, pos, correct) {
  quizPopup.classList.add("hidden");

  if (type === "ladder") {
    if (correct) {
      soundUp.play();
      positions[currentPlayer] = ladders[pos];
    } else {
      positions[currentPlayer] = Math.max(1, pos - 1);
    }
  } else if (type === "snake") {
    if (correct) {
      positions[currentPlayer] = pos; // batal turun
    } else {
      soundDown.play();
      positions[currentPlayer] = snakes[pos];
    }
  }

  updatePawnPosition();
  if (positions[currentPlayer] === 100) {
    soundFinish.play();
    alert("🎉 Allahu Akbar! Kamu menang!");
  } else {
    switchTurn();
  }
}

// ========== Update posisi pion ==========
function updatePawnPosition() {
  const pawnList = document.querySelectorAll(".pawn");
  pawnList.forEach((p, i) => {
    const cellSize = board.clientWidth / 10;
    const row = Math.floor((positions[i] - 1) / 10);
    const col = (positions[i] - 1) % 10;
    const x = (row % 2 === 0 ? col : 9 - col) * cellSize + 10;
    const y = (9 - row) * cellSize + 10;
    p.style.left = `${x}px`;
    p.style.top = `${y}px`;
  });
}

// ========== Ganti giliran ==========
function switchTurn() {
  currentPlayer = currentPlayer === 0 ? 1 : 0;
}

// ========== Buat efek dadu 3D ==========
function createDice3D() {
  const diceContainer = document.getElementById("dice-container");
  const dice = document.createElement("div");
  dice.id = "dice";
  dice.style.width = "60px";
  dice.style.height = "60px";
  dice.style.margin = "0 auto";
  dice.style.transformStyle = "preserve-3d";
  dice.style.transition = "transform 1s ease";
  diceContainer.appendChild(dice);
}

function rollDice3DAnimation(value) {
  const dice = document.getElementById("dice");
  const x = (Math.random() * 360) + 720;
  const y = (Math.random() * 360) + 720;
  dice.style.transform = `rotateX(${x}deg) rotateY(${y}deg)`;
  return value;
}

// ========== Muat soal ==========
async function loadQuiz() {
  try {
    const response = await fetch("ulartangga-assets/soal.json");
    quizData = await response.json();
  } catch (err) {
    console.error("Gagal memuat soal:", err);
    quizData = [
      { question: "Contoh: 2 + 3 = ?", options: ["4", "5", "6"], answer: "5" }
    ];
  }
}
