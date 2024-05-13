[![License](https://img.shields.io/:license-apache-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

# Tahmin Edici Yatay Pod Ölçeklendirici (PHPA)

Tahmin Edici Yatay Pod Ölçeklendiriciler (PHPA), ek tahmin yetenekleri ile donatılmış Yatay Pod Ölçeklendiricilerdir (HPA), önceden tahmin edilen istatistiksel modeller kullanarak otomatik ölçeklendirme yapmanızı sağlar.

## Neden Kullanmalıyım?

PHPA'lar, talep artmadan önce proaktif kararlar alarak daha iyi ölçeklendirme sonuçları sağlar, bu da kaynağın performansı bozulmadan önce otomatik ölçeklendirmenin devreye girmesi anlamına gelir.

## Hangi Sistemler İhtiyaç Duyar?

Düzenli/tahmin edilebilir talep zirveleri/çukurları olan herhangi bir sistem.

Bazı kullanım örnekleri:

* Hafta içi her gün 15:00 ile 17:00 arasında talep zirvesi yaşayan bir servis, bu düzenli ve tahmin edilebilir yük önceden karşılanabilir.
* Her gün öğlen 12:00'de 10 dakika süren talep artışı yaşayan bir servis, bu çok kısa zaman aralığı olduğu için, standart bir HPA karar verene kadar ciddi performans/erişilebilirlik sorunları yaşanabilir.

PHPA'lar her durum için mükemmel bir çözüm değildir ve gerçek verilerle doğru bir şekilde ayarlanması gerekir. Yanlış ayarlanmış bir PHPA, normal bir HPA'dan daha kötü sonuçlar verebilir.

## Nasıl Çalışır?

Bu proje, bir kaynağın kaç replika sahip olması gerektiğini belirlemek için Yatay Pod Ölçeklendirici'nin yaptığı hesaplamaları yapar, ardından hesaplanan replika sayısına ve replika geçmişine istatistiksel modeller uygular.

## Desteklenen Kubernetes Sürümleri

Autoscaler'ın çalışabilmesi için minimum Kubernetes sürümü `v1.23`tür çünkü sadece `v1.23` ve üzeri sürümlerde `autoscaling/v2` API mevcuttur.

Autoscaler, sadece en yeni Kubernetes sürümüne karşı test edilmiştir - eğer eski Kubernetes sürümlerini etkileyen hatalar varsa bunları düzeltmeye çalışırız ancak destek garantisi yoktur.

## Özellikler

* Tahmin olmadan replica sayısını hesaplamada Yatay Pod Ölçeklendirici ile fonksiyonel olarak aynı.
* Yatay Pod Ölçeklendirici replika sayım mantığına uygulanacak istatistiksel model seçimi.
  * Holt-Winters 
  * Lineer Regresyon
* Kubernetes HPA

eneklerini özelleştirmenize olanak tanır ve böylece EKS veya GCP gibi yönetilen çözümlerde çalışabilir.
  * CPU Başlangıç Süresi.
  * Ölçek Küçültme Stabilizasyonu.
  * Senkronizasyon Periyodu.