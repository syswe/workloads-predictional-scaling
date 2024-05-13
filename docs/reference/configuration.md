# Konfigürasyon

Predictive Horizontal Pod Autoscaler'lar için bir dizi konfigürasyon seçeneği mevcuttur.

## minReplicas

```yaml
minReplicas: 2
```

Otomatik ölçekleyicinin ölçeklendirebileceği minimum replika sayısı sınırı. En az bir Nesne veya Harici metrik yapılandırılmışsa `minReplicas` 0 olabilir. En az bir metrik değeri mevcut olduğu sürece ölçeklendirme aktiftir.

Varsayılan değer: `1`.

## maxReplicas

```yaml
maxReplicas: 15
```

Otomatik ölçekleyicinin ölçeklendirebileceği maksimum replika sayısı sınırı.
MinReplicas değerinden küçük olamaz.

Varsayılan değer: `10`.

## syncPeriod

```yaml
syncPeriod: 10000
```

`--horizontal-pod-autoscaler-sync-period` ile eşdeğerdir; PHPA'nın replika sayılarını hesaplama ve ölçeklendirme sıklığı milisaniye cinsindendir.

Milisaniye cinsinden ayarlanır.

Varsayılan değer: `15000` (15 saniye).

Milisaniye cinsinden ayarlanır.

## cpuInitializationPeriod

```yaml
cpuInitializationPeriod: 150
```

`--horizontal-pod-autoscaler-cpu-initialization-period` ile eşdeğerdir; pod başlatıldıktan sonraki CPU örneklerinin atlanabileceği dönem.

Saniye cinsinden ayarlanır.

Varsayılan değer: `300` (5 dakika).

## initialReadinessDelay

```yaml
initialReadinessDelay: 45
```

`--horizontal-pod-autoscaler-initial-readiness-delay` ile eşdeğerdir; pod başlatıldıktan sonraki hazır olma durumunun başlangıç hazır olma durumu olarak kabul edileceği dönem.

Saniye cinsinden ayarlanır.

Varsayılan değer: `30` (30 saniye).

## tolerance

```yaml
tolerance: 0.25
```

`--horizontal-pod-autoscaler-tolerance` ile eşdeğerdir; yatay pod otomatik ölçekleyicisinin ölçeklendirmeyi dikkate alması için istenen-gerçek metrik oranındaki minimum değişiklik (1.0'dan).

Varsayılan değer: `0.1`.

## decisionType

```yaml
decisionType: mean
```

Birden fazla model sağlanmışsa hangi değerlendirmeyi seçeceğini belirler.

Olası değerler:

- **maximum** - modellerin en yüksek değerlendirmesini seçer.
- **minimum** - modellerin en düşük değerlendirmesini seçer.
- **mean** - modeller arasındaki ortalama replika sayısını (en yakın tam sayıya yuvarlanmış) hesaplar.
- **median** - modeller arasındaki medyan replika sayısını hesaplar.

Varsayılan değer: `maximum`.

## behavior

Uygulanacak ölçeklendirme davranışı.

Kubernetes HPA davranışı ile eşdeğer olacak şekilde tasarlanmıştır.

[Horizontal Pod Autoscaler dokümanlarına](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#configurable-scaling-behavior) bakın.

## models

Uygulanacak istatistiksel modellerin listesi.
Detaylar için [modeller bölümüne](../../user-guide/models) bakın.

## metrics

Replika sayılarını değerlendirmek için hedeflenecek metriklerin listesi.
Detaylar için [metrikler bölümüne](../../user-guide/metrics) bakın.