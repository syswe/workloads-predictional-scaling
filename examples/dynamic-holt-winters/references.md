# Dinamik Holt-Winters PHPA

Bu örnek, mevsimsel verilere dayanarak ölçekleme talebini tahmin etmek için Predictive Horizontal Pod Autoscaler (PHPA) kullanımında Holt-Winters yönteminin nasıl kullanılabileceğini göstermektedir. Bu örneğe *dinamik* denmesinin sebebi, ayar değerlerinin sabit kodlanmış olmaması ve çalışma zamanında bir dış kaynaktan çekilerek dinamik olarak hesaplanabilmesidir.

Bu örnek, özellikle çalışma zamanında bir ayarlama servisine HTTP isteği göndererek `alpha`, `beta` ve `gamma` Holt-Winters ayar değerlerini çeker.

Holt-Winters zaman serisi tahmin yöntemi, nasıl ölçekleneceğini tahmin etmek için mevsimleri tanımlamanıza olanak tanır. Örneğin, bir mevsim 24 saat olarak tanımlandığında, düzenli olarak 15:00 ile 17:00 arasında daha yüksek CPU yükü olan bir dağıtım, yeterli sayıda mevsim toplandıktan sonra, 15:00 ile 17:00 arasında CPU yükünün daha yüksek olduğu bilgisine dayanarak tahminler yapacak ve sistem hazır ve yanıt verir durumda tutulacak şekilde önceden ölçeklendirme yapacaktır.

Bu örnek, yukarıda açıklanan örneğin daha küçük ölçekli bir versiyonudur; aralık zamanı 20 saniye ve bir mevsim uzunluğu 6'dır (6 * 20 = 120 saniye = 2 dakika). Örnek, tahmin yapmak için 4 önceki mevsimi saklayacaktır. Örneğe dahil olan yük test cihazı, her dakika 30 saniye çalışır.

Bu, örneğin çalıştırılması sonucunda çizilen grafikle sonuçtur, kırmızı değerler tahmin edilen değerleri ve mavi değerler gerçek değerleri göstermektedir.
Buradan, tahminin fazla tahmin yaptığı ancak hala önceden ölçeklendirme yaptığı görülebilir - daha fazla mevsim saklamak ve alpha, beta ve gamma değerlerini ayarlamak fazla tahmini azaltacak ve daha doğru sonuçlar üretecektir.

## Gereksinimler

Bu örneği kurmak ve burada listelenen adımları takip etmek için ihtiyacınız olanlar:

- [kubectl](https://kubernetes.io/docs/tasks/tools/).
- kubectl'in yapılandırıldığı bir Kubernetes kümesi - yerel testler için [k3d veya Docker-Desktop] iyi bir seçenektir.
- PHPA operatörünü yüklemek için [helm](https://helm.sh/docs/intro/install/).
- Bazı JSON çıktılarını formatlamak için [jq](https://stedolan.github.io/jq/).

## Kullanım

Bu örneği kümenize dağıtmak istiyorsanız, önce Predictive Horizontal Pod Autoscaler Operatörünü yüklemelisiniz, operatörü yüklemek için [kurulum kılavuzunu](https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest/user-guide/installation) takip edin.

Bu örnek, [Horizontal Pod Autoscaler Yürüyüşü](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) üzerine kurulmuştur.

1. `php-apache` adlı uygulamayı/dağıtımı yönetmek için bu komutu çalıştırın:

```bash
kubectl apply -f deployment.yaml
```

2. Ayarlama görüntüsünü oluşturmak ve Kubernetes kümenize aktarmak için bu komutu çalıştırın:

```bash
docker build -t tuning tuning && k3d image import tuning
```

3. Ayarlama servisini dağıtmak için bu komutu çalıştırın:

```bash
kubectl apply -f tuning/tuning.yaml
```

4. Daha önce oluşturulan dağıtımı gösteren otoscaler'ı başlatmak için bu komutu çalıştırın:

```bash
kubectl apply -f phpa.yaml
```

5. Yük test cihazı görüntüsünü oluşturmak ve Kubernetes kümenize aktarmak için bu komutu çalıştırın:

```bash
docker build -t load-tester load && k3d image import load-tester
```

6. Yük test cihazını dağıtmak için bu komutu çalıştırın, zamanı not alın çünkü her dakika 30 saniye çalışacaktır:

```bash
kubectl apply -f load/load.yaml
```

7. Otoscaler'in çalıştığını ve ürettiği günlük çıktısını görmek için bu komutu çalıştırın:

```bash
kubectl logs -l name=predictive-horizontal-pod-autoscaler -f
```

8. Ayarlama servisinin günlüklerini görmek için bu komutu çalıştırın, sorgulandığı zaman rapor verecek ve kendisine sağlanan değeri yazdıracaktır:

```bash
kubectl logs -l run=tuning -f
```

9. Otoscaler tarafından saklanan ve takip edilen replica geçmişini görmek için bu komutu çalıştırın:

```bash
kubectl get configmap predictive-horizontal-pod-autoscaler-dynamic-holt-winters-data -o=json | jq -r '.data.data | fromjson | .modelHistories["HoltWintersPrediction"].replicaHistory[] | .time,.replicas'
```

Her dakika yük test cihazı, otoscale edilen uygulama üzerinde 30 saniye boyunca yükü artıracaktır. PHPA başlangıçta herhangi bir veri olmadan sadece bir Horizontal Pod Autoscaler gibi davranacak ve talep başladıktan sonra bu talebi karşılamak için en iyi şekilde tepkisel olarak ölçeklendirecektir. Yük test cihazı birkaç kez çalıştıktan sonra, PHPA yeterli veri toplamış olacak ve Holt Winters modelini kullanarak zamanından önce tahminler yapmaya başlayacak ve geçmişte toplanan verilere dayanarak beklenen talebi karşılamak için zamanından önce proaktif olarak ölçeklendirmeye başlayacaktır.

## Açıklama

Bu örnek dört bölüme ayrılmıştır:

- Ölçeklendirilecek dağıtım
- Predictive Horizontal Pod Autoscaler (PHPA)
- Ayarlama Servisi
- Yük Test Cihazı

### Dağıtım

Ölçeklendirilecek dağıtım, HTTP isteklerine yanıt veren basit bir servistir, `k8s.gcr.io/hpa-example` görüntüsünü kullanarak herhangi bir HTTP GET isteğine `OK!` döner. Bu dağıtım, atanmış pod sayısını artırıp azaltacak şekilde ölçeklendirilecektir.

### Predictive Horizontal Pod Autoscaler

PHPA, ölçeklendirmenin nasıl uygulanacağına dair bazı yapılandırmalar içerir, bu yapılandırmalar otoscaler'in nasıl davranacağını tanımlar:

```yaml
apiVersion: jamiethompson.me/v1alpha1
kind: PredictiveHorizontalPodAutoscaler
metadata:
  name: dynamic-holt-winters
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  syncPeriod: 20000
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 30


  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  models:
  - type: HoltWinters
    name: HoltWintersPrediction
    startInterval: 60s
    resetDuration: 5m
    holtWinters:
      runtimeTuningFetchHook:
        type: "http"
        timeout: 2500
        http:
          method: "GET"
          url: "http://tuning/holt_winters"
          successCodes:
            - 200
          parameterMode: body
      seasonalPeriods: 6
      storedSeasons: 4
      trend: "additive"
      seasonal: "additive"
```

- `scaleTargetRef` otoscaler'in ölçeklendirmek için hedef aldığı kaynağı belirtir.
- `minReplicas` ve `maxReplicas` otoscaler'in kaynağı ölçeklendirebileceği minimum ve maksimum replica sayılarını belirtir.
- `syncPeriod` otoscaler'in ne sıklıkla çalışacağını milisaniye cinsinden belirtir, bu otoscaler her 20000 milisaniyede (20 saniye) bir çalışacaktır.
- `behavior.scaleDown.stabilizationWindowSeconds` bir otoscaler'in ne kadar hızlı ölçek küçültebileceğini yönetir, varsayılan olarak geçmişte tanımlanan son zaman dilimi içinde meydana gelen en yüksek değerlendirmeyi seçer. Bu durumda geçmiş 30 saniye içinde meydana gelen en yüksek değerlendirmeyi seçecektir.
- `metrics` PHPA'nın ölçeklendirme yaparken kullanması gereken metrikleri tanımlar, bu örnekte her podun ortalama CPU kullanımını %50 seviyesinde tutmaya çalışır.
- `models` - uygulanacak tahmin modellerini içerir.
  - `type` - 'HoltWinters', Holt-Winters tahmin modelini kullanır.
  - `name` - Modelin adı.
  - `startInterval` - Model sadece bir sonraki tam dakikanın başında uygulanacaktır.
  - `resetDuration` - Modelin replica geçmişi, herhangi bir veri kaydedilmediği süre 5 dakikadan fazla olduğunda (örneğin, küme kapatıldığında) temizlenecektir.
  - `holtWinters` - Holt-Winters'a özgü yapılandırma.
    * `runtimeTuningFetchHook` - Bu, çalışma zamanında `alpha`, `beta` ve `gamma` değerlerini dinamik olarak çekmek için kullanılan bir [kancadır](https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest/user-guide/hooks). Bu örnekte, `http://tuning/holt_winters` adresine `HTTP` isteği kullanılmaktadır.
    * `seasonalPeriods` - bir mevsimin temel birim senkronizasyon periyotları cinsinden uzunluğu, bu örnekte senkronizasyon periyodu `20000` (20 saniye) ve mevsim uzunluğu `6`'dır, bu da 20 * 6 = 120 saniye = 2 dakika mevsim uzunluğu sonucunu verir.
    * `storedSeasons` - saklanacak mevsim sayısı, bu örnekte `4`, eğer 4'ten fazla mevsim saklanırsa en eskileri kaldırılır.
    * `trend` - 'add'/`additive` veya `mul`/`multiplicative`, trend elemanı için yöntemi tanımlar.
    * `seasonal` - 'add'/`additive` veya `mul`/`multiplicative`, mevsimsel eleman için yöntemi tanımlar.

### Ayarlama Servisi

Ayarlama servisi, Holt Winters çalışma zamanı ayarlaması için gerekli formatta (JSON formunda) `alpha`, `beta` ve `gamma` değerlerini döndüren basit bir Flask servisidir. Ayrıca, Holt Winters iste

ği tarafından kendisine sağlanan değerleri de yazdırır; bu değerler ayarlama değerlerinin hesaplanmasına yardımcı olabilir.

### Yük Test Uygulaması [TO-DO NEW METHODS]

Bu, `php-apache` dağıtımına olabildiğince hızlı HTTP istekleri göndermek için bir bash script çalıştıran basit bir poddur. Artan yükü simüle etmek için kullanılır.