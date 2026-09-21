document.addEventListener('DOMContentLoaded', () => {
    // 1. Suntikkan HTML Pop-up ke dalam body
    const popupHTML = `
    <div id="countdownPopup" class="countdown-overlay">
        <div class="countdown-box">
            <button id="closeCountdownBtn" class="countdown-close-btn">
                <i class="fas fa-times"></i>
            </button>
            <div class="countdown-icon">
                <img src="images/abdul.jpeg" alt="Korlap" class="countdown-img">
            </div>
            <h3 class="countdown-title">Menuju Pergantian Korlap ke bapak ABDUL</h3>
            <p class="countdown-subtitle">Tanggal 1 Oktober 2026</p>
            <div class="countdown-timer">
                <div class="time-unit">
                    <span id="cdDays" class="time-num">0</span>
                    <span class="time-label">Hari</span>
                </div>
                <div class="time-unit">
                    <span id="cdHours" class="time-num">0</span>
                    <span class="time-label">Jam</span>
                </div>
                <div class="time-unit">
                    <span id="cdMins" class="time-num">0</span>
                    <span class="time-label">Menit</span>
                </div>
                <div class="time-unit">
                    <span id="cdSecs" class="time-num">0</span>
                    <span class="time-label">Detik</span>
                </div>
            </div>
        </div>
    </div>`;
    
    document.body.insertAdjacentHTML('beforeend', popupHTML);

    // 2. Logika Pop-up Countdown
    const countdownPopup = document.getElementById('countdownPopup');
    const closeCountdownBtn = document.getElementById('closeCountdownBtn');

    // Tampilkan popup saat aplikasi dibuka (dengan jeda singkat)
    setTimeout(() => {
        countdownPopup.classList.add('active');
    }, 800);

    // Event tombol close
    closeCountdownBtn.addEventListener('click', () => {
        countdownPopup.classList.remove('active');
    });

    // Target Countdown: 1 Oktober 2026, 00:00:00
    const targetDate = new Date("2026-10-01T00:00:00").getTime();

    function updateCountdown() {
        const now = new Date().getTime();
        const distance = targetDate - now;

        if (distance < 0) {
            document.getElementById('cdDays').innerText = "0";
            document.getElementById('cdHours').innerText = "0";
            document.getElementById('cdMins').innerText = "0";
            document.getElementById('cdSecs').innerText = "0";
            return;
        }

        const days = Math.floor(distance / (1000 * 60 * 60 * 24));
        const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((distance % (1000 * 60)) / 1000);

        document.getElementById('cdDays').innerText = days;
        document.getElementById('cdHours').innerText = hours;
        document.getElementById('cdMins').innerText = minutes;
        document.getElementById('cdSecs').innerText = seconds;
    }

    // Jalankan countdown setiap 1 detik
    setInterval(updateCountdown, 1000);
    updateCountdown(); // Panggil sekali saat awal load
});
