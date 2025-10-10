# Makale Bölümleri

Bu dizin, makale için oluşturulan bölümleri içermektedir. Her bölüm ayrı bir `.tex` dosyası olarak hazırlanmıştır.

## Dosya Yapısı

### Hazır Dosyalar

1. **cover-page.tex** - Kapak sayfası (ayrı dosya olarak)

   - Yazar bilgileri
   - Öne çıkanlar (Türkçe + İngilizce)
   - Türkçe Öz ve Abstract
   - Anahtar kelimeler

2. **01-preamble.tex** - Başlangıç bölümü

   - Document class ve paketler
   - Başlık ve abstract

3. **03-results-continued.tex** - Bulgular bölümünün devamı

   - Çevrimiçi deney sonuçları
   - Karşılaştırmalı analiz
   - Tablolar

4. **04-discussion.tex** - Tartışma bölümü

   - Bulguların literatür ile karşılaştırılması
   - Çevrimdışı ve çevrimiçi bulguların değerlendirilmesi
   - Güçlü ve zayıf yönler
   - Pratik uygulamalar için öneriler

5. **05-symbols.tex** - Simgeler bölümü

   - Latin harfleri
   - Yunan harfleri
   - Kısaltmalar

6. **06-conclusions.tex** - Sonuçlar bölümü

   - Ana sonuçlar
   - Gelecek çalışmalar

7. **07-acknowledgments-references.tex** - Teşekkür ve Kaynaklar
   - Teşekkür
   - 20 kaynak (dergi formatına uygun)

## Birleştirme Talimatları

### Yöntem 1: Manuel Birleştirme

`main.tex` dosyasını açın ve şu bölümleri sırayla ekleyin:

1. Mevcut `main.tex`'in Giriş ve Materyal-Yöntem bölümleri zaten güncellenmiş durumda
2. Bulgular bölümünün sonuna `03-results-continued.tex` içeriğini ekleyin
3. `04-discussion.tex` içeriğini ekleyin
4. `05-symbols.tex` içeriğini ekleyin
5. `06-conclusions.tex` içeriğini ekleyin
6. `07-acknowledgments-references.tex` içeriğini ekleyin

### Yöntem 2: LaTeX Include Kullanımı

`main.tex` dosyasında şu komutları kullanabilirsiniz:

```latex
\input{sections/03-results-continued}
\input{sections/04-discussion}
\input{sections/05-symbols}
\input{sections/06-conclusions}
\input{sections/07-acknowledgments-references}
```

## Tamamlanan İçerik

### ✅ Giriş Bölümü (main.tex'te)

- Literatür taraması (15+ referans)
- Motivasyon ve problem tanımı
- Yüksek lisans tezi katkıları
- Çalışmanın temel katkıları

### ✅ Materyal ve Yöntem (main.tex'te)

- Sistem mimarisi
- 6 yük örüntüsü matematiksel formülasyonları
- 7 makine öğrenmesi modeli
- Tablo 1: Pattern-Model Optimization Results
- LLM entegrasyonu
- Kod ve dağıtım altyapısı
- Model katmanı entegrasyonu
- Laboratuvar altyapısı

### ✅ Bulgular (main.tex + sections/03-results-continued.tex)

- Yüksek lisans tezi bulguları
- Tablo 2: LLM Performance Metrics
- Çevrimdışı kıyaslama sonuçları
- Tablo 3: Offline Benchmark Results
- Çevrimiçi deney sonuçları
- Tablo 4: Online Benchmark Results
- Karşılaştırmalı analiz
- Tablo 5: Comparative Analysis

### ✅ Tartışma (sections/04-discussion.tex)

- Bulguların literatür ile karşılaştırılması
- Çevrimdışı bulguların değerlendirilmesi
- Çevrimiçi bulguların değerlendirilmesi
- Güçlü yönler
- Zayıf yönler ve sınırlamalar
- Pratik uygulamalar için öneriler

### ✅ Simgeler (sections/05-symbols.tex)

- Latin harfleri (A-Z)
- Yunan harfleri
- Kısaltmalar (API, BIC, CatBoost, vb.)

### ✅ Sonuçlar (sections/06-conclusions.tex)

- Ana sonuçlar özeti
- Gelecek çalışmalar

### ✅ Teşekkür ve Kaynaklar (sections/07-acknowledgments-references.tex)

- TÜBİTAK 1005 desteği
- 20 kaynak (dergi formatına uygun)

## Sayfa Sayısı Tahmini

- Giriş: ~2 sayfa
- Materyal ve Yöntem: ~4-5 sayfa
- Bulgular: ~3-4 sayfa
- Tartışma: ~3-4 sayfa
- Simgeler: ~1 sayfa
- Sonuçlar: ~2 sayfa
- Kaynaklar: ~2 sayfa

**Toplam: ~17-20 sayfa** (dergi kurallarına uygun)

## Notlar

- Tüm başlıklar Türkçe + İngilizce (parantez içinde 8 punto)
- Tüm tablolar Türkçe + İngilizce başlıklı
- Times New Roman 9 punto
- 1,5 satır aralığı
- 2,5 cm kenar boşlukları
- Referanslar aritmetik sıraya göre
- Ondalık sayılarda virgül kullanımı (Türkçe standart)
