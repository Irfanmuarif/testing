const API = "https://script.google.com/macros/s/AKfycbyxvcSvrKp1LYuBisVdyhNjlO5RmHfA16KreXE37MMPqc4_LYbhDsVPLPaUr4IrlXZX/exec";
let currentSheet = "PENGUMUMAN";

// Initialize Lucide Icons
window.onload = () => {
    loadData();
    lucide.createIcons();
};

function changeSheet(btn, sheetName) {
    // Update Sidebar Active State
    document.querySelectorAll('.nav-link').forEach(el => el.classList.remove('active'));
    btn.classList.add('active');
    
    currentSheet = sheetName;
    document.getElementById('current-sheet-title').innerText = sheetName;
    loadData();
}

async function loadData() {
    toggleLoader(true);
    try {
        const res = await fetch(`${API}?sheet=${encodeURIComponent(currentSheet)}`, {
            method: "GET",
            redirect: "follow"
        });
        const data = await res.json();

        // Render Headers
        const thead = document.getElementById("thead");
        thead.innerHTML = `
            <tr>
                ${data.headers.map(h => `<th>${h}</th>`).join("")}
                <th class="text-right">Aksi</th>
            </tr>`;

        // Render Rows
        const tbody = document.getElementById("tbody");
        tbody.innerHTML = data.rows.map(r => `
            <tr class="group">
                ${data.headers.map(h => `
                    <td contenteditable="true" onblur="handleAutoSave(event, ${r._row})">
                        ${r[h] || ""}
                    </td>
                `).join("")}
                <td class="text-right">
                    <button onclick="hapus(${r._row})" class="inline-flex items-center gap-1.5 text-rose-500 hover:bg-rose-50 px-3 py-1.5 rounded-lg transition-colors font-medium">
                        <i data-lucide="trash-2" class="w-4 h-4"></i>
                        Hapus
                    </button>
                </td>
            </tr>
        `).join("");
        
        // Refresh icons for new content
        lucide.createIcons();

    } catch (err) {
        console.error(err);
        alert("Gagal memuat data. Periksa koneksi atau URL API.");
    }
    toggleLoader(false);
}

async function handleAutoSave(event, row) {
    const cells = [...event.target.parentElement.children]
        .slice(0, -1)
        .map(td => td.innerText.trim());
    
    showStatus("Menyimpan...");
    try {
        await fetch(API, {
            method: "POST",
            mode: "no-cors",
            body: JSON.stringify({
                action: "update",
                sheet: currentSheet,
                row,
                values: cells
            })
        });
        showStatus("Tersimpan", true);
    } catch (e) {
        showStatus("Gagal Menyimpan", true);
    }
}

async function hapus(row) {
    if (!confirm("Hapus baris ini secara permanen?")) return;
    toggleLoader(true);
    await fetch(API, {
        method: "POST",
        mode: "no-cors",
        body: JSON.stringify({ action: "delete", sheet: currentSheet, row })
    });
    await loadData();
}

async function addRow() {
    const headersCount = document.querySelectorAll("#thead th").length - 1;
    if (headersCount <= 0) return;

    toggleLoader(true);
    const values = Array(headersCount).fill("");
    await fetch(API, {
        method: "POST",
        mode: "no-cors",
        body: JSON.stringify({ action: "create", sheet: currentSheet, values })
    });
    await loadData();
}

function toggleLoader(show) {
    document.getElementById('main-loader').classList.toggle('hidden', !show);
}

function showStatus(text, autoHide = false) {
    const container = document.getElementById('status-container');
    const badge = document.getElementById('status-badge');
    badge.innerHTML = `<span class="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></span> ${text}`;
    container.classList.remove('hidden');
    
    if (autoHide) {
        setTimeout(() => container.classList.add('hidden'), 3000);
    }
}
