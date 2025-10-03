# PHPA Model Deney Laboratuvarı

Bu dizin, Predictive Horizontal Pod Autoscaler (PHPA) modellerini Docker Desktop üzerindeki yerel Kubernetes kümesinde
uçtan uca karşılaştırmak için hazırlanmış otomasyon ortamını içerir. Scriptler; operatörü kurar, örnek uygulamayı ve
yük üreticisini devreye alır, farklı modelleri sırayla koşturur, topladıkları verileri analiz eder ve rapor çıktısı
üretir.

## Amaç

- Standart HPA davranışı ile Linear, Holt-Winters, GBDT, CatBoost, VAR ve XGBoost tabanlı PHPA modellerini aynı yük
  senaryosu altında kıyaslamak.
- Offline eğitim scriptleri ile sentetik veri üzerinde dört modelin metriklerini (RMSE, MAE, MAPE) üretmek.
- Online deneylerden toplanan ölçekleme metriklerini ve offline başarımlarını tek Markdown raporunda birleştirmek.

## Ön koşullar

- Docker Desktop + Kubernetes eklentisi aktif ve `kubectl` erişimi çalışır durumda olmalı.
- `helm`, `python3`, `pip`, `make` ve `docker` komutları PATH içinde olmalı.
- Depo kök dizininden `pip install -r requirements-dev.txt` komutu ile Python bağımlılıkları kurulmalı (scriptler bunu
  otomatik tetikler fakat sanal ortam tercih ediyorsanız önceden etkinleştirin).

## Yapı

- `scripts/` — Kurulum, çevrimiçi deney ve rapor üretimi için shell/Python scriptleri.
- `manifests/` — Laboratuvarın örnek uygulaması, yük üreticisi, HPA ve PHPA tanımları.
- `data/` — Sentetik veri üreticisi ve oluşturulan CSV dosyaları.
- `output/` — Offline ve online sonuçlar ile üretilen raporlar.
- `Makefile` — Tipik iş akışlarını tek komutla çalıştırmak için hedefler.

## Kullanım özet akışı

1. `make -C labs bootstrap` (veya dizin içindeyken sadece `make bootstrap`) — Operatörü, metrics-server'ı ve test uygulamasını kurar.
2. `make -C labs offline` — Sentetik veri üretir, offline model eğitimlerini çalıştırır ve özet metrikleri çıkarır.
3. `make -C labs online` — Her modeli aynı iş yükü altında çalıştırır, ölçümlerin CSV çıktısını üretir ve özetler.
4. `make -C labs report` — Offline/online sonuçlarını birleştirerek `output/report.md` dosyasını oluşturur.
5. İş bitince `make -C labs destroy` komutu laboratuvar kaynaklarını temizler (operatör dahil).

Detaylı açıklamalar ve yapılandırılabilir değişkenler için `labs/Makefile` ve script dosyalarındaki yorumları inceleyin.
