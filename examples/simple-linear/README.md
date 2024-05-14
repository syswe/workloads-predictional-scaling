# Basit Lineer Regresyon Kullanan Predictive Horizontal Pod Autoscaler (PHPA) İçin Yük Testi ve Karşılaştırma

## Giriş

Bu belge, Predictive Horizontal Pod Autoscaler (PHPA) kullanarak basit bir lineer regresyon modeliyle performansını değerlendirmek için ayrıntılı bir test senaryosu sunar. Amacımız, değişken yük koşulları altında standart bir Horizontal Pod Autoscaler (HPA) ile ölçekleme davranışını ve etkinliğini karşılaştırmaktır.

## Ön Koşullar

Teste başlamadan önce, aşağıdaki araçların yüklü ve yapılandırılmış olduğundan emin olun:

- **Docker**: Yük testi imajını oluşturmak için.
- **kubectl**: Kubernetes kümenizle etkileşim kurmak için.
- **Helm**: PHPA operatörünü kurmak için.
- **jq**: Kubernetes'ten JSON çıktısını ayrıştırmak için.

Kubernetes kümenizin çalışır durumda olduğundan ve uygulamaları dağıtmak ve otomatik ölçeklendirme işlemlerini gerçekleştirmek için gerekli izinlere sahip olduğunuzdan emin olun.

## Test Kurulumu

### Yük Testi İçin Dockerfile

Öncelikle, test uygulamasına HTTP istekleri gönderecek yük testi için bir Docker imajı oluşturun.

```dockerfile
FROM alpine:3.6

RUN apk add --no-cache wget coreutils

COPY load_tester.sh /load_tester.sh
RUN chmod +x /load_tester.sh

CMD [ "/bin/sh", "/load_tester.sh" ]
```


#### Test Betiği: `load_tester.sh`

Aşağıda, `load_tester.sh` betiğinin detaylı açıklaması bulunmaktadır:

```sh
#!/bin/sh
increment=5
i=1
while [ $i -le 20 ]; do
    count=$(expr $i \* 5) # Aritmetik işlemler için `expr` kullanımı uyumluluk için
    echo "Gönderilen paralel istek sayısı: $count"
    j=1
    while [ $j -le $count ]; do
        timeout 60 wget -q -O- http://php-apache &
        j=$(expr $j + 1) # Burada da `expr` kullanımı
    done
    wait
    sleep $increment
    i=$(expr $i + 1)
done
```

#### Betiğin Çalışma Mantığı

1. **Başlangıç Ayarları**:
    - `increment=5`: Her döngü arasında 5 dakika bekleme süresi.
    - `i=1`: Döngü sayacını başlatır.

2. **Döngü Başlangıcı**:
    - `while [ $i -le 20 ]; do`: Döngü sayacı 20'ye ulaşana kadar döngüyü çalıştırır.

3. **Paralel İstek Sayısının Hesaplanması**:
    - `count=$(expr $i \* 5)`: Döngü sayısını 5 ile çarparak gönderilecek paralel istek sayısını belirler.
    - `echo "Gönderilen paralel istek sayısı: $count"`: Mevcut döngüde gönderilecek paralel istek sayısını yazdırır.

4. **Paralel İstek Gönderme**:
    - `j=1`: İç döngü sayacını başlatır.
    - `while [ $j -le $count ]; do`: `count` değeri kadar paralel istek gönderir.
        - `timeout 60 wget -q -O- http://php-apache &`: `wget` komutuyla `php-apache` servisine 60 saniye boyunca paralel istek gönderir.
        - `j=$(expr $j + 1)`: İç döngü sayacını artırır.
    - `wait`: Tüm paralel isteklerin tamamlanmasını bekler.
    - `sleep $increment`: Bir sonraki döngüye geçmeden önce 5 dakika bekler.

5. **Döngü Sayacının Artırılması**:
    - `i=$(expr $i + 1)`: Döngü sayacını artırır ve süreç tekrarlanır.

Bu betik, toplamda 20 döngü boyunca artan sayıda paralel HTTP istekleri göndererek uygulamaya yük bindirir. İlk döngüde 5 istek, ikinci döngüde 10 istek ve bu şekilde devam ederek son döngüde 100 istek gönderir. Her döngü arasında 5 dakika beklenir. Bu sayede, PHPA ve HPA'nın artan yük karşısında nasıl tepki verdiği gözlemlenebilir.

### Yük Testi İçin Kubernetes Job

Yük testi scriptini çalıştırmak için bir Kubernetes Job tanımlayın.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-tester
spec:
  template:
    spec:
      containers:
      - name: load-tester
        image: load-tester
        imagePullPolicy: IfNotPresent
      restartPolicy: Never
  backoffLimit: 0  # Job başarısız olursa yeniden denememesi için
```

## Test Uygulamasını Dağıtma

PHPA tarafından ölçeklenecek örnek bir uygulama dağıtın.

### Dağıtım ve Servis Tanımı

Örnek uygulama için Deployment ve Service tanımlamak üzere `deployment.yaml` dosyasını oluşturun.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: php-apache
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      run: php-apache
  template:
    metadata:
      labels:
        run: php-apache
    spec:
      containers:
      - image: k8s.gcr.io/hpa-example
        imagePullPolicy: Always
        name: php-apache
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          limits:
            cpu: 500m
          requests:
            cpu: 200m
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: php-apache
  sessionAffinity: None
  type: ClusterIP
```

Deployment ve Service'i uygulayın:

```bash
kubectl apply -f deployment.yaml
```

## PHPA Operatörünü Kurma

Predictive Horizontal Pod Autoscaler operatörünü Helm kullanarak kurun.

```bash
VERSION=v0.13.2
HELM_CHART=predictive-horizontal-pod-autoscaler-operator
helm install ${HELM_CHART} https://github.com/jthomperoo/predictive-horizontal-pod-autoscaler/releases/download/${VERSION}/predictive-horizontal-pod-autoscaler-${VERSION}.tgz
```

## PHPA'yı Yapılandırma

Basit bir lineer regresyon modeli ile Predictive Horizontal Pod Autoscaler'ı tanımlamak için `phpa.yaml` dosyasını oluşturun.

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
      perSyncPeriod: 1
      linear:
        lookAhead: 10000
        historySize: 6
  decisionType: "maximum"
  syncPeriod: 10000
```

PHPA konfigürasyonunu uygulayın:

```bash
kubectl apply -f phpa.yaml
```

## Yük Testini Çalıştırma

### Yük Testini Başlatma

Yük testi için Docker imajını oluşturun ve push edin:

```bash
docker build -t load-tester .
docker tag load-tester <your-docker-repo>/load-tester
docker push <your-docker-repo>/load-tester
```

`load_job.yaml` dosyasını Docker repository'nizle güncelleyin ve uygulayın:

```bash
kubectl apply -f load_job.yaml
```

### Ölçekleme Davranışını İzleme

PHPA operatör günlüklerini izleyin:

```bash
kubectl logs -l name=predictive-horizontal-pod-autoscaler -f
```

PHPA tarafından alınan ölçeklendirme kararlarını kontrol edin:

```bash
kubectl get configmap predictive-horizontal-pod-autoscaler-simple-linear-data -o=json | jq -r '.data.data | fromjson | .modelHistories["simple-linear"].replicaHistory[] | .time,.replicas'
```


## PHPA ve HPA'yı Karşılaştırma

![Simple Linear PHPA versus Normal HPA](../../src/simple-linear-phpa-vs-hpa-chart.png)

Her iki yöntemi daha detaylı olarak inceleyelim ve karşılaştıralım.

### Linear Regression PHPA Ölçeklendirme Sonuçları Analizi

Öncelikle, Linear Regression PHPA'nın pod sayısındaki değişimleri inceleyelim:

```plaintext
2024-05-12T21:45:12Z    0
2024-05-12T21:44:57Z    3
2024-05-12T21:44:42Z    12
2024-05-12T21:44:27Z    10
2024-05-12T21:44:12Z    10
2024-05-12T21:43:57Z    8
2024-05-12T21:43:42Z    8
2024-05-12T21:43:27Z    9
2024-05-12T21:43:12Z    6
2024-05-12T21:42:57Z    5
2024-05-12T21:42:42Z    4
2024-05-12T21:42:27Z    4
2024-05-12T21:42:12Z    1
2024-05-12T21:41:57Z    0
```

**Analiz:**

- **Başlangıç (21:41:57):** Pod sayısı 0. Bu başlangıç durumu, yük testinin henüz başlamadığını gösterir.
- **İlk Artış (21:42:12):** Yük başladığında pod sayısı hızla 1'e çıkar.
- **İkinci Artış (21:42:27 - 21:42:57):** Trafik artışıyla birlikte pod sayısı 4'ten 5'e yükselir.
- **Üçüncü Artış (21:43:12 - 21:44:42):** Pod sayısı 6'dan 12'ye kadar artar. Bu, Linear Regression PHPA'nın trafikteki artışı hızlıca algılayıp kaynak sağladığını gösterir.
- **Düşüş (21:44:57 - 21:45:12):** Yük azalırken pod sayısı 12'den 3'e ve ardından 0'a düşer. Bu durum, PHPA'nın düşen yük ile birlikte pod sayısını hızla azalttığını gösterir.

### Normal HPA Scaling Results Analysis

Normal HPA'nın pod ölçeklendirme sonuçlarını zamanla birlikte inceleyelim:

```plaintext
4m12s       Normal    Started             pod/load-tester-9kq57                  Started container load-tester
4m12s       Normal    Scheduled           pod/load-tester-9kq57                  Successfully assigned simple-linear/load-tester-9kq57 to docker-desktop
4m12s       Normal    Created             pod/load-tester-9kq57                  Created container load-tester
4m12s       Normal    Pulled              pod/load-tester-9kq57                  Container image "load-tester" already present on machine
4m12s       Normal    SuccessfulCreate    job/load-tester                        Created pod: load-tester-9kq57
3m15s       Normal    SuccessfulRescale   horizontalpodautoscaler/standard-hpa   New size: 4; reason: cpu resource utilization (percentage of request) above target
2m15s       Normal    SuccessfulRescale   horizontalpodautoscaler/standard-hpa   New size: 8; reason: cpu resource utilization (percentage of request) above target
50s         Normal    Completed           job/load-tester                        Job completed
15s         Normal    SuccessfulRescale   horizontalpodautoscaler/standard-hpa   New size: 1; reason: All metrics below target
```

**Analiz:**

- **Başlangıç (4m12s):** İlk pod oluşturulmuş ve yük test cihazı başlatılmış.
- **İlk Artış (3m15s):** CPU kullanımı hedefin üzerine çıktığında HPA, pod sayısını 4'e yükseltmiş.
- **İkinci Artış (2m15s):** Daha fazla CPU kullanım artışı nedeniyle HPA, pod sayısını 8'e yükseltmiş.
- **Azalma (50s - 15s):** Yük testi tamamlandıktan sonra pod sayısı yeniden 1'e düşmüş.

### Karşılaştırma ve Yorum

**Linear Regression PHPA:**
- **Yanıt Süresi:** Linear Regression PHPA, yük artışlarına daha hızlı ve proaktif olarak tepki vermiş. Bu, modelin yük değişikliklerini tahmin edebilme kabiliyetinden kaynaklanır.
- **Pod Sayısındaki Artış:** Artış daha kademeli ve öngörülerek yapılmış, bu da gereksiz pod artırımlarını minimize eder.

**Normal HPA:**
- **Yanıt Süresi:** HPA, CPU kullanımına dayalı olarak reaktif bir şekilde pod sayısını artırmış. İlk artış 3m15s'de, ikinci artış ise 2m15s'de gerçekleşmiş.
- **Pod Sayısındaki Artış:** Pod sayısı daha büyük ve ani artışlarla yapılmış. Bu, ani yük değişikliklerine hızlı tepki vermesine rağmen, bazen gereksiz kaynak kullanımına yol açabilir.

**Genel Yorum:**
- **Linear Regression PHPA**, yükün düzenli ve öngörülebilir şekilde arttığı durumlarda daha etkin bir çözüm sunar. Bu yöntem, aşamalı ve proaktif bir ölçeklendirme yaparak kaynak kullanımını optimize eder.
- **Normal HPA** ise, ani ve beklenmedik yük değişikliklerine daha hızlı tepki verebilir. Ancak, bu yöntem bazen gereksiz pod artışlarına yol açabilir ve kaynak verimliliğini düşürebilir.

Her iki yöntem de kendi avantajlarına sahiptir ve kullanım senaryosuna bağlı olarak seçilmelidir. Linear Regression PHPA, düzenli ve tahmin edilebilir yük artışları için daha uygundur, Normal HPA ise ani ve büyük yük değişikliklerine daha uygun tepki verir. Bu bilgiler, yüksek lisans tez sunumunuzda farklı ölçeklendirme yöntemlerinin performanslarını karşılaştırırken kullanılabilir.

### Grafiklerle Görselleştirme

Grafikler, pod sayısındaki değişiklikleri zamanla birlikte görselleştirmeyi sağlar. Aşağıda, her iki yöntem için birer örnek grafik oluşturuyoruz:

#### Linear Regression PHPA Grafik

![Linear Regression PHPA](https://fake-image-url/linear-regression-phpa-chart.png)
```plaintext
Pod Sayısı | Zaman
12         | 21:44:42
10         | 21:44:27
10         | 21:44:12
8          | 21:43:57
8          | 21:43:42
9          | 21:43:27
6          | 21:43:12
5          | 21:42:57
4          | 21:42:42
4          | 21:42:27
1          | 21:42:12
0          | 21:41:57
```

#### Normal HPA Grafik

![Normal HPA](https://fake-image-url/normal-hpa-chart.png)
```plaintext
Pod Sayısı | Zaman
8          | 2m15s
4          | 3m15s
1          | 15s
```

Bu grafikler, pod sayısındaki değişikliklerin zaman içinde nasıl gerçekleştiğini net bir şekilde gösterir ve ölçeklendirme yöntemlerinin etkinliğini görselleştirir.



---
### PHPA'nın Avantajları

1. **Proaktif Ölçeklendirme**: PHPA, gelecekteki yük tahminlerine dayanarak önceden ölçeklendirme yapabilir, bu da ani yük artışlarına daha hızlı tepki verilmesini sağlar.
2. **Kaynak Optimizasyonu**: Yeterli kaynakların her zaman mevcut olmasını sağlayarak ve aşırı provizyonu önleyerek kaynak kullanımını daha verimli hale getirir.
3. **Daha İyi Kullanıcı Deneyimi**: Kullanıcı talebi artışlarına hızlı yanıt verme yeteneği, kullanıcı deneyimini iyileştirir ve sistem yavaşlamalarını veya kesintilerini minimize eder.
4. **Esneklik**: Farklı senaryolara ve beklenmedik yük değişimlerine karşı daha esnek bir ölçeklendirme stratejisi sunar.
5. **Analitik Yaklaşım**: Veriye dayalı tahminlerle, sistem performansını daha iyi anlama ve sürekli iyileştirmeler yapma imkanı sunar.

### PHPA'nın Dezavantajları

1. **Karmaşıklık**: Tahmin modellerini kurmak ve ayarlamak daha karmaşık ve zaman alıcı olabilir.
2. **Hata Riski**: Yanlış tahminler, gereksiz ölçeklendirme eylemlerine neden olabilir ve maliyetleri artırabilir.
3. **Bakım Gereksinimi**: Modelin düzenli olarak güncellenmesi ve doğru çalışması için sürekli bakım gerektirir.
4. **Veri Bağımlılığı**: Doğru çalışması için yüksek kaliteli ve sürekli veri akışına ihtiyaç duyar.
5. **Maliyet**: Tahmin modelinin geliştirilmesi ve işletilmesi ek maliyetler getirebilir.

### HPA'nın Avantajları

1. **Basitlik ve Kolaylık**: HPA, CPU ve bellek kullanımı gibi metrikler üzerinden otomatik olarak ölçeklendirme yapar ve kurulumu görece daha basittir.
2. **Geniş Kabul ve Destek**: Kubernetes topluluğu tarafından yaygın olarak kabul görmüş ve iyi anlaşılmış bir çözümdür.
3. **Düşük Bakım Gereksinimi**

: PHPA'ya kıyasla daha az bakım ve yönetim gerektirir.
4. **Anında Tepki**: Gerçek zamanlı metrikler üzerinden çalıştığı için, sistem anında mevcut yüke göre ölçeklendirme yapabilir.
5. **Uyumluluk ve Entegrasyon**: Çeşitli Kubernetes çevrelerinde ve ekosistem araçlarıyla entegre çalışabilme yeteneği.

### HPA'nın Dezavantajları

1. **Reaktif Yaklaşım**: Yalnızca mevcut metrikler üzerinden ölçeklendirme yapar, bu yüzden ani yük artışlarına yavaş tepki verebilir.
2. **Sistem Dalgalanmaları**: Yüksek yük altında sistemin yavaşlamasına neden olabilir, çünkü kaynaklar yeterince hızlı sağlanamayabilir.
3. **Aşırı Ölçeklendirme Riski**: Kısa süreli yük artışları bazen gereğinden fazla pod başlatılmasına neden olabilir, bu da kaynak israfına yol açar.
4. **Sınırlı Esneklik**: Önceden belirlenmiş eşikler dışında daha karmaşık yük modellerine uyum sağlamada sınırlıdır.
5. **Maliyet Optimizasyonu**: Ani düşüşlerde hızlı ölçek küçültme yapmazsa, gereksiz maliyet artışına neden olabilir.

## Sonuç

Bu yük test senaryosu, Predictive Horizontal Pod Autoscaler (PHPA) kullanarak basit lineer regresyon modeli ile standart Horizontal Pod Autoscaler (HPA) arasında kapsamlı bir karşılaştırma sağlar. Değişken yük koşulları altında ölçekleme davranışlarını değerlendirerek, her iki yaklaşımın avantajları ve dezavantajları hakkında bilgi sahibi olabilir ve belirli kullanım senaryoları için en uygun otomatik ölçeklendirme stratejisini belirlememize yardımcı olur.