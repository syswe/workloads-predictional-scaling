[![License](https://img.shields.io/:license-apache-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

# Tahmin Edici Yatay Pod Ölçeklendirici (PHPA) ve Standart HPA Karşılaştırması

Tahmin Edici Yatay Pod Ölçeklendiriciler (PHPA), standart Yatay Pod Ölçeklendiriciler (HPA) ile aynı işlevselliğe sahiptir ancak ekstra tahmin kabiliyetlerine sahip olarak, istatistiksel modeller kullanarak zamandan önce tahminlerle ölçeklendirme yapmanızı sağlar.

## Neden Kullanmalıyım?

PHPA'lar, talebin artmasından önce proaktif kararlar alarak daha iyi ölçeklendirme sonuçları sunar, bu sayede bir kaynağın performansı bozulmadan önce otomatik ölçeklendirme devreye girer.

## Hangi Sistemler İçin Gerekli?

Düzenli/tahmin edilebilir talep zirveleri/çukurları olan herhangi bir sistem.

Bazı kullanım örnekleri:

* Hafta içi her gün 15:00 ile 17:00 arasında talep zirvesi yaşayan bir servis, bu düzenli ve tahmin edilebilir yük önceden karşılanabilir.
* Her gün öğlen 12:00'de 10 dakika süren talep artışı yaşayan bir servis, bu çok kısa zaman aralığı olduğu için, standart bir HPA karar verene kadar ciddi performans/erişilebilirlik sorunları yaşanabilir.

PHPA'lar her durum için mükemmel bir çözüm değildir ve gerçek verilerle ayar yapılarak kullanılması gerekir. Yanlış ayarlanmış bir PHPA, normal bir HPA'dan daha kötü sonuçlar verebilir.

## Nasıl Çalışır?

Bu proje, bir kaynağın kaç replika sahip olması gerektiğini belirlemek için Yatay Pod Ölçeklendirici'nin yaptığı hesaplamaları yapar, ardından hesaplanan replika sayısına ve replika geçmişine istatistiksel modeller uygular.

## Desteklenen Kubernetes Sürümleri

Autoscaler'ın çalışabilmesi için minimum Kubernetes sürümü `v1.23`tür çünkü sadece `v1.23` ve üzeri sürümlerde `autoscaling/v2` API mevcuttur.

Autoscaler, sadece en yeni Kubernetes sürümüne karşı test edilmiştir - eğer eski Kubernetes sürümlerini etkileyen hatalar varsa bunları düzeltmeye çalışırız ancak destek garantisi yoktur.

## Özellikler

* Tahmin olmadan replica sayısını hesaplamada Yatay Pod Ölçeklendirici ile fonksiyonel olarak aynı.
* Yatay Pod Ölçeklendirici replika sayım mantığına uygulanacak istatistiksel model seçimi.
  * Holt-Winters Yumuşatma
  * Lineer Regresyon
* Kubernetes ölçeklendirme seçeneklerini özelleştirmenize olanak tanır ve böylece EKS veya GCP gibi yönetilen çözümlerde çalışabilir.
  * CPU Başlangıç Süresi.
  * Ölçek Küçültme Stabilizasyonu.
  * Senkronizasyon Periyodu.

## Bir Tahmin Edici Yatay Pod Ölçeklendirici Nasıl Görünür?

PHPA'lar, ek konfigürasyon seçenekleri ile mümkün olduğunca Yatay Pod Ölçeklendiricilere benzer şekilde yapılandırılmıştır.

PHPA'lar kendi özel kaynaklarına sahiptir:

```yaml
apiVersion: jamiethompson.me/v1alpha1
kind: PredictiveHorizontalPodAutoscaler
metadata:
  name: simple-linear
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 0
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 50
          type: Utilization
  models:
    - type: Linear
      name: simple-linear
      linear:
        lookAhead: 10000
        historySize: 6
```

Bu PHPA, hedef kaynağın CPU kullanımını %50'de tutmaya çalışırken ekstra tahmin katmanı olarak lineer regresyon modeli uygulanmış bir Yatay Pod Ölçeklendirici gibi davranır.

## Kurulum

Tahmin Edici Yatay Pod Ölçeklendiricileri yönetmek için operatör, Helm kullanılarak kurulabilir:

```bash
VERSION=v0.13.2
HELM_CHART=predictive-horizontal-pod-autoscaler-operator
helm install ${HELM_CHART} https://github.com/jthomperoo/predictive-horizontal-pod-autoscaler/releases/download/${VERSION}/predictive-horizontal-pod-autoscaler-${VERSION}.tgz
```

## Hızlı Başlangıç

[Tanıtım kılavuzuna](https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest/user-guide/getting-started/) ve [örnekler](./examples/) bölümüne göz atarak Tahmin Edici Yatay Pod Ölçeklendiricileri kullanmanın yollarını keşfedin.

## Daha Fazla Bilgi

Daha fazla bilgi, rehber ve referanslar için [wiki'yi ziyaret edin](https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest/).

Çalışan kod örnekleri için [`examples/` dizinine](./examples) bakın.