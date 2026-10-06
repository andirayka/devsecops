# Diagnosis percobaan pertama Bab 2

- Log mentah: `runtime-attempt-1-failed.txt`.
- Semua langkah runtime sebelum cleanup berhasil: `hello-world`, Ubuntu 24.04 ARM64, Nginx pada `127.0.0.1:18082` (HTTP 200), build `pens-web:1.0`, uji metadata `EXPOSE`, dan web kustom pada `127.0.0.1:19092` (HTTP 200).
- Skrip lalu berstatus keluar 1 saat memeriksa daftar container berlabel. Penyebabnya adalah argumen filter Docker ditulis sebagai `com.andi.lab=devsecops-bab12`; CLI memerlukan bentuk `label=com.andi.lab=devsecops-bab12` dan menolak filter tanpa awalan `label=`.
- Sebelum baris pemeriksaan tersebut, skrip sudah menghapus container Nginx, uji `EXPOSE`, dan web kustom yang dibuat percobaan itu. Pemeriksaan setelahnya memastikan tidak ada container berlabel milik praktikum dan empat container pengguna tetap aktif.
- Perbaikan: tambahkan awalan `label=` pada filter dan catat hanya container yang dibuat oleh proses skrip saat ini untuk cleanup. Dengan demikian nama container yang kebetulan sudah ada tidak akan dihapus ketika preflight menolak benturan.
- Percobaan ini tidak mengubah konfigurasi sistem, tidak menghapus image/volume, dan tidak menghentikan stack Bab 3 atau Axon Sales.
