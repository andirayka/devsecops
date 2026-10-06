# Kontrak input Markdown

Generator membaca UTF-8 dari `chapters/bab1.md` sampai `chapters/bab5.md`. Tiap
file menjadi satu laporan mandiri; build penuh membuat lima PDF terpisah dan
satu PDF gabungan. Generator menyediakan cover dan page break, jadi isi file
hanya berisi badan laporan. Jangan masukkan cover LaTeX, `\begin{center}`,
`\includegraphics`, atau perintah `\pagebreak` dari laporan sumber.

## Struktur yang disarankan per file

Gunakan heading Markdown biasa untuk bagian laporan. Contoh kerangkanya:

```markdown
# Pendahuluan
## 1.1 Latar Belakang
## 1.2 Tujuan

# Dasar Teori
## 2.1 ...

# Pelaksanaan Praktikum
## 3.1 ...

# Hasil dan Pembahasan
## 4.1 ...

# Kesimpulan

# Daftar Pustaka
```

Judul/subbagian aktual ditentukan oleh isi bab dan tidak dibuat atau diisi oleh
generator.

## Sintaks yang dirender

- Heading `#` sampai `######` (termasuk penekanan `**tebal**` pada judul).
- Paragraf dipisahkan oleh satu baris kosong; inline `**tebal**`, `*miring*`,
  `` `kode` ``, dan tautan eksternal `[teks](https://...)`.
- Daftar `-`, `*`, `+`, atau `1.`; blok kutipan `>`.
- Tabel Markdown berpipa dengan baris pemisah `| --- | --- |`.
- Blok kode berpagar tiga backtick atau tilde.
- Gambar lokal sebagai satu baris tersendiri, misalnya:
  `![Caption](../evidence/bab1/hasil-uji.png)`.
  Referensi Markdown juga didukung: `![Caption][uji]` dengan definisi
  `[uji]: ../evidence/bab1/hasil-uji.png` di mana pun dalam file yang sama.

Path gambar relatif dicari dari folder file Markdown, lalu dari folder tugas.
Path tersebut harus menunjuk file lokal yang ada; URL gambar jarak jauh tidak
diunduh. Path dengan spasi didukung; bentuk `<path dengan spasi.png>` disarankan
agar tidak rancu dengan judul gambar Markdown. Letakkan gambar pada baris
tersendiri, bukan di tengah paragraf atau daftar. Simpan bukti lokal di
`evidence/babN/` dan rujuk dari `chapters/babN.md` sebagai
`../evidence/babN/nama-file.png`.

Contoh path ber-spasi dengan delimiter sudut:
`![Keterangan](<../evidence/bab1/cuplikan hasil.png>)`.

## Build

```sh
python3 build_report.py                    # lima PDF mandiri + satu gabungan
python3 build_report.py --chapter chapters/bab2.md  # satu PDF bab saja
python3 verify_report.py path/laporan.pdf renders/bab2
```

Build penuh menulis `output/bab1/3123640021_Andi.pdf` hingga
`output/bab5/3123640021_Andi.pdf`, serta `output/3123640021_Andi.pdf`.
`--chapter FILE` hanya menulis PDF mandiri di `output/babN/`; file sumber tidak
dipindah atau diubah.
