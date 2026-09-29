# Glosarium — The Last Cipher

Panduan istilah untuk siapa saja yang membaca dokumentasi project ini
tanpa latar belakang game development atau pemrograman.

---

## Isi

1. [Tentang Game Ini](#tentang-game-ini)
2. [Elemen dan Mekanik Game](#elemen-dan-mekanik-game)
3. [Manajemen Project](#manajemen-project)
4. [Arsitektur dan Kode](#arsitektur-dan-kode)
5. [Pengujian (Testing)](#pengujian-testing)
6. [Singkatan Umum](#singkatan-umum)

---

## Tentang Game Ini

**The Last Cipher**
Nama game yang sedang dikembangkan. Game bergenre action dengan sistem
sihir berbasis elemen.

**Ayden & Faith (Duo)**
Dua karakter pemain: kakak-beradik android yang berbagi satu inti Prana. Pemain
mengendalikan satu saudara dalam satu waktu dan menukarnya dengan tombol swap
(Q / LB). **Ayden** = kekuatan (jarak dekat, pukulan berat, tahan serangan, tidak
bisa dash). **Faith** = kontrol (jarak jauh, status, satu-satunya yang bisa dash).
HP, meter Special, dan Prana grid dipakai bersama. Lihat ADR-0058.

**Fayde**
Nama *ikatan* (link) antara Ayden dan Faith — **Fa**ith + A**yde**n, artinya
"bantuan". Bukan karakter. Sebelum 2026-09-28, Fayde adalah nama protagonis tunggal;
nama ini masih muncul di kode (mis. `fayde.png`) dan di catatan lama.

**First Playable**
Tahap awal game di mana satu sesi permainan sudah bisa dimainkan dari awal
hingga akhir — meski masih sangat sederhana dan belum ada audio, cerita,
atau fitur lengkap. Tujuannya hanya satu: membuktikan bahwa inti permainan
terasa menyenangkan.

**Fun Hypothesis**
Pertanyaan utama yang ingin dijawab di First Playable:
_"Apakah memilih kombinasi Prana sebelum gelombang musuh, lalu melihat
rencana itu berhasil saat bertarung, terasa seperti keputusan yang bermakna?"_
Jika jawabannya tidak — seluruh desain perlu dievaluasi ulang sebelum lanjut.

---

## Elemen dan Mekanik Game

**Prana**
Energi sihir dalam dunia game. Terbagi menjadi 5 jenis yang masing-masing
punya elemen, efek status, dan kekuatan unik.

| Nama | Elemen | Efek yang Ditimbulkan |
|------|--------|----------------------|
| Ashfire | Api | Burn — musuh terbakar, kehilangan HP perlahan |
| Voidblue | Bayangan | Blind — musuh meleset 50% serangan selama 2 detik |
| Stormgold | Petir | Stun — musuh membeku sesaat (0,5 detik) |
| Deepfrost | Es | Freeze — musuh tidak bisa bergerak, melambat 50% |
| Verdant | Alam | Regenerate — memulihkan HP bersama duo perlahan |

**Prana Grid**
Papan 3×3 tempat pemain menyusun token Prana sebelum gelombang musuh dimulai.
Susunan yang dipilih menentukan mantra apa yang akan dipakai saat bertarung.
Seperti memilih "loadout" atau "deck" sebelum pertandingan dimulai.

**Preparation Phase (Fase Persiapan)**
Waktu sebelum musuh datang. Pemain menyusun Prana Grid di sini.
Tidak ada ancaman selama fase ini.

**Combat Phase (Fase Pertarungan)**
Musuh muncul dan menyerang. Pemain menggunakan mantra yang sudah
disiapkan di fase sebelumnya untuk melawan.

**Combination Resolution**
Sistem yang membaca susunan Prana Grid dan menentukan mantra apa yang
dihasilkan. Seperti "mesin penerjemah" yang mengubah susunan token
menjadi efek nyata saat bertarung.

**SpellEffect**
Paket data hasil dari Combination Resolution. Berisi informasi seperti
jenis elemen, kekuatan serangan, dan berapa kali serangan berantai bisa
dilakukan. Digunakan SpellCastingEffects saat pemain menekan tombol serang.

**Spell Casting & Effects (SC&E)**
Sistem yang menangani momen ketika pemain menekan tombol untuk
melancarkan serangan — dari input diterima, perhitungan damage, sampai
efek visual dan sinyal ke sistem lain.

**Wave (Gelombang)**
Satu ronde musuh yang muncul sekaligus. Pada First Playable: 1 gelombang
berisi 10 musuh. Gelombang berakhir ketika semua musuh terbunuh.

**Status Effect**
Kondisi tambahan yang dikenakan pada musuh atau pemain setelah terkena
serangan tertentu. Contoh: Burn membuat musuh kehilangan HP secara bertahap;
Freeze membuat musuh tidak bisa bergerak.

**Shatter**
Efek spesial: jika musuh sedang dalam kondisi Freeze lalu terkena serangan
langsung (direct hit), musuh menerima bonus kerusakan. Ini mendorong pemain
untuk merencanakan urutan serangan.

**Elemental Affiliation / Weakness (Afinitas Elemen)**
Setiap musuh punya elemen kelemahan. Jika diserang menggunakan elemen yang
tepat, damage dikalikan 2×. Ini adalah jantung dari strategi game.

**HP Zone (Zona HP)**
Sistem yang membagi kondisi HP bersama duo menjadi zona-zona (misalnya: Sehat,
Waspada, Kritis, Sekarat). Setiap zona memicu respons berbeda — misalnya
efek visual bahaya saat HP sangat rendah.

**Chain Attack / Combo**
Serangan berantai. Setelah serangan pertama mendarat, pemain bisa menekan
tombol lagi untuk melanjutkan serangkaian serangan sesuai urutan yang sudah
ditentukan oleh SpellEffect.

**Cast Lock**
Periode singkat setelah serangan di mana pemain tidak bisa menyerang lagi.
Mencegah pemain menekan tombol terlalu cepat dan merusak urutan combo.

**HUD (Heads-Up Display)**
Tampilan informasi di layar saat bermain — seperti bar HP, indikator combo,
jumlah musuh tersisa. Bukan bagian dari dunia game, melainkan informasi
untuk pemain.

---

## Manajemen Project

**Epic**
Kelompok besar fitur yang dikerjakan sebagai satu kesatuan. Contoh:
"Spell Casting & Effects" adalah satu epic yang terdiri dari 4 story.
Seperti "bab" dalam buku — berisi beberapa sub-topik.

**Story**
Satu unit pekerjaan kecil yang bisa diselesaikan dalam beberapa jam.
Setiap story punya deskripsi yang jelas tentang apa yang harus dibuat,
kriteria keberhasilan, dan bukti bahwa pekerjaan sudah selesai.
Seperti satu "tiket tugas" yang lengkap.

**Acceptance Criteria (AC)**
Syarat-syarat yang harus dipenuhi agar sebuah story dianggap selesai.
Ditulis dalam format yang bisa diuji: "Ketika X terjadi, hasilnya adalah Y."
Contoh: "Ketika pemain menekan tombol serang dalam kondisi READY, serangan
diluncurkan dan _combo_index bertambah 1."

**Sprint**
Periode kerja berdurasi 2 minggu. Setiap sprint punya daftar tugas dengan
prioritas: Must Have (harus selesai), Should Have (idealnya selesai),
Nice to Have (kalau sempat). Seperti satu "siklus kerja" yang terstruktur.

**Milestone**
Titik pencapaian besar dalam project. Contoh: "First Playable" adalah
milestone pertama — game bisa dimainkan satu ronde penuh untuk pertama kali.

**Backlog**
Daftar tugas yang belum dijadwalkan ke sprint mana pun. Ide atau pekerjaan
yang diketahui perlu dilakukan, tapi belum waktunya dikerjakan.

**Carryover**
Tugas dari sprint sebelumnya yang belum selesai dan dibawa ke sprint berikutnya.

**Tech Debt (Utang Teknis)**
Keputusan teknis sementara yang disadari tidak ideal, tapi diterima untuk
sekarang demi kecepatan. Suatu saat harus diperbaiki — seperti "hutang"
yang harus dibayar nanti.

**Gate Check**
Pemeriksaan formal sebelum project boleh maju ke tahap berikutnya. Contoh:
sebelum pindah dari "Pre-Production" ke "Production", semua syarat di
gate check harus terpenuhi. Seperti ujian kelulusan sebelum naik kelas.

**Retrospective (Retro)**
Rapat/dokumen evaluasi di akhir sprint: apa yang berjalan baik, apa yang
bermasalah, dan apa yang harus diperbaiki di sprint berikutnya.

**Smoke Check**
Pengujian cepat untuk memastikan fitur-fitur utama masih berjalan setelah
ada perubahan besar. Bukan pengujian mendalam — hanya memastikan tidak ada
yang "berasap" (rusak parah).

**Playtest**
Sesi bermain game untuk mengevaluasi apakah game terasa menyenangkan dan
berfungsi dengan benar. Berbeda dengan testing (yang mencari bug) —
playtest menilai pengalaman bermain.

**Story Type**
Kategori jenis pekerjaan dalam sebuah story, yang menentukan bukti
penyelesaian apa yang diperlukan:
- **Logic** — kode perhitungan/logika: wajib ada unit test yang lulus
- **Integration** — kode yang menghubungkan beberapa sistem: wajib ada integration test
- **Visual/Feel** — animasi, efek visual: cukup screenshot + persetujuan
- **UI** — tampilan layar/menu: cukup walkthrough manual
- **Config/Data** — pengaturan nilai/data: cukup smoke check

---

## Arsitektur dan Kode

**GDD (Game Design Document)**
Dokumen desain yang menjelaskan cara kerja satu sistem game secara lengkap —
aturan, formula matematika, kasus tepi, dan kriteria keberhasilan.
Ditulis sebelum mulai coding. Seperti blueprint bangunan sebelum konstruksi.

**ADR (Architecture Decision Record)**
Dokumen yang mencatat satu keputusan teknis besar: apa yang diputuskan,
kenapa, dan alternatif apa yang ditolak. Tujuannya agar keputusan tidak
dilupakan atau diulang-perdebatkan di masa depan.
Contoh: ADR-0003 memutuskan "sistem hanya boleh berkomunikasi lewat sinyal,
bukan membaca data satu sama lain secara langsung."

**TR-ID (Testable Requirement ID)**
Kode unik untuk satu syarat desain dari GDD. Contoh: `TR-SC-001`.
Digunakan untuk melacak bahwa setiap syarat desain punya implementasi kode
dan pengujian yang memverifikasinya. Seperti nomor pasal dalam kontrak.

**Control Manifest**
Lembar aturan ringkas untuk programmer: apa yang **wajib** dilakukan,
apa yang **dilarang**, dan apa yang perlu **hati-hati** saat mengimplementasi
setiap layer sistem. Diperbarui setiap kali ada keputusan arsitektur baru.

**Autoload / Singleton**
Sistem yang selalu aktif sejak game dinyalakan hingga dimatikan, dan bisa
diakses dari mana saja dalam kode. Contoh: HealthAndDamage (sistem HP)
adalah Autoload — selalu siap menerima laporan "musuh mendapat damage X"
dari sistem mana pun yang memanggilnya.

**Signal**
Cara sistem memberi tahu sistem lain bahwa sesuatu terjadi, tanpa perlu
tahu siapa yang mendengarkan. Seperti bel toko — ketika pintu dibuka,
bel berbunyi; penjual mendengar dan bereaksi, tapi pintu tidak perlu tahu
siapa penjualnya.
Contoh: ketika semua musuh mati, WaveManager mengirim sinyal `wave_cleared`;
GameStateManager mendengar sinyal itu dan berpindah ke fase berikutnya.

**State Machine**
Cara mengatur perilaku sebuah sistem menggunakan "kondisi" yang jelas.
Sistem hanya bisa berada di satu kondisi pada satu waktu, dan hanya boleh
berpindah ke kondisi tertentu yang sudah ditentukan.
Contoh: SpellCastingEffects punya 4 kondisi — IDLE (belum siap), READY (siap
menyerang), CHAINING (dalam rangkaian combo), CAST_LOCKED (sedang jeda setelah
serangan). Tidak bisa melompat dari IDLE langsung ke CHAINING.

**Layer**
Tingkatan dalam arsitektur sistem, menunjukkan urutan ketergantungan:
- **Foundation** — sistem paling dasar, tidak bergantung pada sistem lain
  (contoh: data Prana, data musuh)
- **Core** — sistem gameplay utama yang bergantung pada Foundation
  (contoh: gerakan pemain, sistem damage, mantra)
- **Feature** — fitur permainan yang bergantung pada Core
  (contoh: manajemen gelombang, HUD)

**Isometric View**
Sudut pandang kamera di mana dunia game terlihat "miring 45 derajat" —
seperti melihat dari sudut atas-samping. Memberi kesan tiga dimensi meskipun
game ini dua dimensi.

**Godot Engine**
Program yang digunakan untuk membuat game ini. Seperti Adobe Photoshop
untuk foto, Godot adalah "studio" tempat semua elemen game (kode, gambar,
suara) digabungkan menjadi sebuah game yang bisa dimainkan.

**GDScript**
Bahasa pemrograman khusus yang digunakan di Godot. Seperti bahasa yang
dipakai untuk menulis instruksi kepada Godot tentang apa yang harus
terjadi di dalam game.

**Headless Mode**
Mode menjalankan Godot tanpa tampilan visual — hanya kode yang dijalankan,
tidak ada jendela game yang muncul. Digunakan untuk menjalankan pengujian
otomatis di server CI.

---

## Pengujian (Testing)

**Unit Test**
Pengujian otomatis untuk satu fungsi atau sistem kecil secara terisolasi.
Dijalankan oleh komputer, bukan manusia. Hasilnya selalu: PASS atau FAIL.
Contoh: "Ketika _on_combo_resolved dipanggil dengan SpellEffect valid,
apakah _state berubah menjadi READY?" — dijawab otomatis oleh unit test.

**Integration Test**
Pengujian yang menguji beberapa sistem sekaligus bekerja bersama.
Contoh: apakah WaveManager, HealthAndDamage, dan GameStateManager
bekerja dengan benar ketika semua 10 musuh mati dalam satu ronde?

**Test Evidence**
Bukti bahwa sebuah story sudah selesai dan benar. Untuk story jenis Logic,
buktinya adalah unit test yang lulus. Tidak ada bukti = story belum dianggap
selesai.

**GdUnit4**
Framework (alat bantu) pengujian otomatis yang digunakan di project ini,
khusus untuk Godot. Seperti "mesin penguji" yang menjalankan semua unit
test dan melaporkan hasilnya.

**CI (Continuous Integration)**
Sistem yang secara otomatis menjalankan semua pengujian setiap kali ada
perubahan kode yang dikirim ke repository. Jika ada pengujian yang gagal,
perubahan tidak boleh digabungkan. Seperti "quality control" otomatis.

**Orphan Node**
Node (objek) di Godot yang dibuat tapi tidak pernah dibersihkan dari memori
setelah pengujian selesai. Menyebabkan peringatan dari GdUnit4. Harus
dihindari agar pengujian bersih dan tidak membuang memori.

---

## Singkatan Umum

| Singkatan | Kepanjangan | Arti Singkat |
|-----------|-------------|--------------|
| FP | First Playable | Milestone pertama — game bisa dimainkan satu ronde |
| VS | Vertical Slice | Milestone kedua — satu ronde lengkap dengan semua fitur MVP |
| MVP | Minimum Viable Product | Versi game paling kecil yang sudah layak dirilis |
| AC | Acceptance Criteria | Syarat keberhasilan sebuah story |
| ADR | Architecture Decision Record | Dokumen keputusan arsitektur |
| GDD | Game Design Document | Dokumen desain sistem game |
| TR-ID | Testable Requirement ID | Kode unik untuk satu syarat desain |
| SC&E | Spell Casting & Effects | Sistem eksekusi mantra pemain |
| H&D | Health & Damage | Sistem HP dan damage |
| SEM | Status Effects Manager | Sistem efek status (Burn, Freeze, dll.) |
| GSM | GameStateManager | Sistem yang mengatur alur state game |
| WM | WaveManager | Sistem yang mengelola gelombang musuh |
| CR | CombinationResolution | Sistem yang membaca Prana Grid |
| CI | Continuous Integration | Pengujian otomatis saat kode dikirim |
| HUD | Heads-Up Display | Informasi di layar saat bermain |
