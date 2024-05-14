### Predictive Horizontal Pod Autoscaler (PHPA) Kullanarak Dinamik Holt-Winters

## Dinamik Holt-Winters PHPA İçin Yük Testi ve Karşılaştırma

### Giriş

Bu belge, Dinamik Holt-Winters Predictive Horizontal Pod Autoscaler (PHPA) kullanarak gerçekleştirilen yük test senaryosunun detaylı açıklamasını sağlar ve bunu standart Horizontal Pod Autoscaler (HPA) ile karşılaştırır. Amacımız, PHPA'nın performansını ve ölçeklendirme davranışını değişken yük koşulları altında değerlendirmektir.

### Test Kurulumu

#### Yük Test Edici İçin Dockerfile

Yük test edici ortamını kurmak için bir `Dockerfile` oluşturun:

```Dockerfile
FROM alpine:3.6

RUN apk add --no-cache wget coreutils

COPY load_tester.sh /load_tester.sh

RUN chmod +x /load_tester.sh

CMD [ "/bin/sh", "/load_tester.sh" ]
```

#### Yük Test Edici Betiği

### Test Senaryosu: Dinamik Yük Artışı ve Azalışı

Bu test senaryosu, dinamik yük artışı ve azalışını simüle eden bir yük test betiği (`load_tester.sh`) kullanarak, Predictive Horizontal Pod Autoscaler (PHPA) ve standart Horizontal Pod Autoscaler (HPA) performansını değerlendirmektedir. Test senaryosu, belirli bir süre boyunca değişken bir yük oluşturur ve bu yükü uygulamaya göndererek ölçeklendirme davranışlarını gözlemler.

#### Test Betiği: `load_tester.sh`

Aşağıda, test betiği `load_tester.sh`'nin detaylı açıklaması bulunmaktadır:

```sh
#!/bin/sh
increment=1            # Her döngü arasında 1 dakika bekleme süresi.
total_duration=10      # Toplam test süresi 10 dakika.
start_time=$(date +%s) # Başlangıç zamanını kaydet.

# Dinamik yük artışı ve azalışı simülasyonu
i=0
while true; do
    # Geçen süreyi hesapla
    current_time=$(date +%s)
    elapsed=$(((current_time - start_time) / 60)) # Dakika cinsinden geçen süre

    if [ $elapsed -ge $total_duration ]; then
        echo "Test süresi doldu: Toplam süre ${elapsed} dakika."
        break
    fi

    # Yük hesaplaması: Testin başında ve sonunda yüksek, ortada düşük
    if [ $elapsed -lt 3 ];then
        count=40 # İlk 3 dakikada yüksek yük
    elif [ $elapsed -lt 7 ]; then
        count=10 # 4 dakika boyunca yükü düşük tut
    else
        count=40 # Son 3 dakikada yüksek yük
    fi

    echo "${elapsed} dakika: Gönderilen paralel istek sayısı: $count"
    j=1
    while [ $j -le $count ]; do
        timeout 60 wget -q -O- http://php-apache &
        j=$(expr $j + 1)
    done
    wait
    sleep $increment
done
```

#### Betiğin Çalışma Mantığı

1. **Başlangıç Ayarları**:
    - `increment=1`: Her döngü arasında 1 dakika bekleme süresi.
    - `total_duration=10`: Toplam test süresi 10 dakika.
    - `start_time=$(date +%s)`: Testin başlangıç zamanını kaydeder.

2. **Döngü Başlangıcı**:
    - `i=0`: Döngü sayacı başlatılır.
    - `while true; do`: Sonsuz döngü başlatılır. Bu döngü, test süresi dolana kadar çalışır.

3. **Geçen Süre Hesaplama**:
    - `current_time=$(date +%s)`: Şu anki zaman kaydedilir.
    - `elapsed=$(((current_time - start_time) / 60))`: Başlangıç zamanından itibaren geçen süre dakika cinsinden hesaplanır.

4. **Test Süresinin Kontrolü**:
    - `if [ $elapsed -ge $total_duration ]; then`: Geçen süre toplam test süresine eşit veya daha fazla ise:
        - Test süresinin dolduğu ve toplam sürenin ne kadar olduğu yazdırılır.
        - `break`: Döngüden çıkılır.

5. **Yük Hesaplaması**:
    - `if [ $elapsed -lt 3 ]; then`: Eğer geçen süre 3 dakikadan az ise:
        - `count=40`: İlk 3 dakika boyunca yüksek yük (40 paralel istek).
    - `elif [ $elapsed -lt 7 ]; then`: Eğer geçen süre 7 dakikadan az ise:
        - `count=10`: 4 dakika boyunca düşük yük (10 paralel istek).
    - `else`: Eğer geçen süre 7 dakika veya daha fazla ise:
        - `count=40`: Son 3 dakika boyunca yüksek yük (40 paralel istek).

6. **Paralel İstek Gönderme**:
    - `echo "${elapsed} dakika: Gönderilen paralel istek sayısı: $count"`: Mevcut dakikayı ve gönderilen paralel istek sayısını yazdırır.
    - `j=1`: İç döngü sayacı başlatılır.
    - `while [ $j -le $count ]; do`: `count` değeri kadar paralel istek gönderilir.
        - `timeout 60 wget -q -O- http://php-apache &`: `wget` komutuyla `php-apache` servisine 60 saniye boyunca paralel istek gönderilir.
        - `j=$(expr $j + 1)`: İç döngü sayacı artırılır.
    - `wait`: Tüm paralel isteklerin tamamlanmasını bekler.
    - `sleep $increment`: Bir sonraki döngüye geçmeden önce 1 dakika bekler.

7. **Döngü Sayacının Artırılması**:
    - Döngü sayacı artırılır ve süreç tekrarlanır.

Bu betik, belirlenen süre boyunca değişken yük koşullarını simüle ederek, PHPA ve HPA'nın bu yük değişimlerine nasıl tepki verdiğini gözlemlemeyi sağlar. Testin başında ve sonunda yüksek yük, ortasında ise düşük yük uygulanarak, autoscaler'ların bu değişimlere nasıl uyum sağladığı incelenir.

#### Yük Test Edici İçin Kubernetes Job

Yük test ediciyi çalıştırmak için bir Kubernetes job tanımlayın `load_job.yaml`:

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
  backoffLimit: 0  # Ensures the job does not retry on failure
```

### Tuning API Kurulumu

#### Tuning API İçin Dockerfile

Tuning API için bir `Dockerfile` oluşturun:

```Dockerfile
FROM python:3.8-slim
# We copy just the requirements.txt first to leverage Docker cache
COPY ./requirements.txt /app/requirements.txt
WORKDIR /app
# Install dependencies
RUN pip install -r requirements.txt
# Copy in source files
COPY . /app
ENTRYPOINT [ "python" ]
CMD [ "api.py" ]
```

#### Tuning API Betiği

Tuning API'yi tanımlamak için bir `api.py` dosyası oluşturun:

```python
from flask import Flask, request
import json

app = Flask(__name__)

ALPHA_VALUE = 0.9
BETA_VALUE = 0.9
GAMMA_VALUE = 0.9

@app.route("/holt_winters")
def metric():
    app.logger.info('Received context: %s', request.data)

    return json.dumps({
        "alpha": ALPHA_VALUE,
        "beta": BETA_VALUE,
        "gamma": GAMMA_VALUE,
    })

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
```

#### Tuning API İçin Gereksinimler Dosyası

Tuning API için bağımlılıkları belirtmek üzere bir `requirements.txt` dosyası oluşturun:

```
Flask==2.3.2
```

#### Tuning API İçin Kubernetes Deployment

Tuning API'yi Kubernetes üzerinde dağıtmak için bir `tuning.yaml` dosyası oluşturun:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: tuning
  name: tuning
spec:
  replicas: 1
  selector:
    matchLabels:
      run: tuning
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        run: tuning
    spec:
      containers:
      - image: tuning
        imagePullPolicy: IfNotPresent
        name: tuning
        ports:
        - containerPort: 5000
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
  name: tuning
spec:
  ports:
  - port: 80
    protocol

: TCP
    targetPort: 5000
  selector:
    run: tuning
  sessionAffinity: None
  type: ClusterIP
```

### Test Adımları

1. **Yük Test Ediciyi Kurun ve Dağıtın**:
   - Docker imajını oluşturun:
     ```bash
     docker build -t load-tester .
     ```
   - Kubernetes job'ını uygulayın:
     ```bash
     kubectl apply -f load_job.yaml
     ```

2. **Tuning API'yi Kurun ve Dağıtın**:
   - Tuning API için Docker imajını oluşturun:
     ```bash
     docker build -t tuning .
     ```
   - Tuning API için Kubernetes deployment'ını uygulayın:
     ```bash
     kubectl apply -f tuning.yaml
     ```

3. **Ölçeklendirmeyi İzleyin**:
   - PHPA'nın ölçeklendirme davranışını izlemek için şu komutu kullanın:
     ```bash
     kubectl get configmap predictive-horizontal-pod-autoscaler-dynamic-holt-winters-data -o=json | jq -r '.data.data | fromjson | .modelHistories["HoltWintersPrediction"].replicaHistory[] | .time,.replicas'
     ```

### PHPA ve HPA'yı Karşılaştırma

PHPA'nın Dinamik Holt-Winters modeline karşı standart HPA'nın ölçeklendirme davranışını, zaman içinde replika sayısını analiz ederek karşılaştırın. Sonuçları aşağıdaki grafikte görebilirsiniz:

![Holt Winters PHPA vs Normal HPA](../../src/holt-winters-phpa-vs-hpa.png)

### Dynamic Holt-Winters PHPA Ölçeklendirme Sonuçları

Dynamic Holt-Winters PHPA'nın ölçeklendirme sonuçları:

```plaintext
2024-05-12T22:50:51Z    0
2024-05-12T22:50:31Z    2
2024-05-12T22:50:11Z    12
2024-05-12T22:49:51Z    15
2024-05-12T22:49:31Z    14
2024-05-12T22:49:11Z    14
2024-05-12T22:48:51Z    15
2024-05-12T22:48:31Z    14
2024-05-12T22:48:11Z    14
2024-05-12T22:47:51Z    14
2024-05-12T22:47:31Z    13
2024-05-12T22:47:11Z    7
2024-05-12T22:46:51Z    6
2024-05-12T22:46:31Z    10
2024-05-12T22:46:11Z    6
2024-05-12T22:45:51Z    7
2024-05-12T22:45:31Z    8
2024-05-12T22:45:11Z    6
2024-05-12T22:44:51Z    6
2024-05-12T22:44:31Z    6
2024-05-12T22:44:11Z    7
2024-05-12T22:43:51Z    6
2024-05-12T22:43:31Z    7
2024-05-12T22:43:11Z    14
2024-05-12T22:42:51Z    14
2024-05-12T22:42:31Z    12
2024-05-12T22:42:11Z    10
2024-05-12T22:41:51Z    12
2024-05-12T22:41:31Z    13
2024-05-12T22:41:11Z    11
2024-05-12T22:40:51Z    5
2024-05-12T22:40:31Z    5
2024-05-12T22:40:11Z    0
```

### Normal HPA Ölçeklendirme Sonuçları

Normal HPA'nın ölçeklendirme sonuçları:

```plaintext
13m         Normal    SuccessfulCreate         job/load-tester                        Created pod: load-tester-nhn2p
13m         Normal    Scheduled                pod/load-tester-nhn2p                  Successfully assigned dynamic-holt-winters/load-tester-nhn2p to docker-desktop
13m         Normal    Created                  pod/load-tester-nhn2p                  Created container load-tester
13m         Normal    Started                  pod/load-tester-nhn2p                  Started container load-tester
13m         Normal    Pulled                   pod/load-tester-nhn2p                  Container image "load-tester" already present on machine
12m         Normal    SuccessfulRescale        horizontalpodautoscaler/standard-hpa   New size: 5; reason: cpu resource utilization (percentage of request) above target
12m         Normal    Scheduled                pod/php-apache-5d54745f55-gxjhb        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-gxjhb to docker-desktop
12m         Normal    Scheduled                pod/php-apache-5d54745f55-24dnx        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-24dnx to docker-desktop
12m         Normal    Pulling                  pod/php-apache-5d54745f55-xjdqv        Pulling image "k8s.gcr.io/hpa-example"
12m         Normal    Scheduled                pod/php-apache-5d54745f55-xjdqv        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-xjdqv to docker-desktop
12m         Normal    Scheduled                pod/php-apache-5d54745f55-7znn8        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-7znn8 to docker-desktop
12m         Normal    Pulling                  pod/php-apache-5d54745f55-7znn8        Pulling image "k8s.gcr.io/hpa-example"
12m         Normal    Pulling                  pod/php-apache-5d54745f55-gxjhb        Pulling image "k8s.gcr.io/hpa-example"
12m         Normal    Pulling                  pod/php-apache-5d54745f55-24dnx        Pulling image "k8s.gcr.io/hpa-example"
11m         Normal    Started                  pod/php-apache-5d54745f55-xjdqv        Started container php-apache
11m         Normal    Created                  pod/php-apache-5d54745f55-xjdqv        Created container php-apache
11m         Normal    Pulled                   pod/php-apache-5d54745f55-xjdqv        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.306s (1.306s including waiting)
11m         Normal    Created                  pod/php-apache-5d54745f55-24dnx        Created container php-apache
11m         Normal    Pulled                   pod/php-apache-5d54745f55-24dnx        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.276s (2.582s including waiting)
11m         Normal    Started                  pod/php-apache-5d54745f55-24dnx        Started container php-apache
11m         Normal    Started                  pod/php-apache-5d54745f55-gxjhb        Started container php-apache
11m         Normal    Pulled                   pod/php-apache-5d54745f55-gxjhb        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.167s (3.748s including waiting)
11m         Normal    Created                  pod/php-apache-5d54745f55-gxjhb        Created container php-apache
11m         Normal    Pulled                   pod/php-apache-5d54745f55-7znn8        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.1s (4.846s including waiting)
11m         Normal    Created                  pod/php-apache-5d54745f55-7znn8        Created container php-apache
11m         Normal    Started                  pod/php-apache-5d54745f55-7znn8        Started container php-apache
5m          Normal    SuccessfulRescale        horizontalpodautoscaler/standard-hpa   New size: 10; reason: cpu resource utilization (percentage of request) above target
11m         Normal    Scheduled                pod/php-apache-5d54745f55-mbh4k        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-mbh4k to docker-desktop
11m         Normal    Pulling                  pod/php-apache-5d54745f55-mbh4k        Pulling image "k8s.gcr.io/hpa-example"
11m         Normal    Scheduled                pod/php-apache-5d54745f55-vh289        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-vh289 to docker-desktop
11m         Normal    Pulling                  pod/php-apache-5d54745f55-psdch        Pulling image "k8s.gcr.io/hpa-example"
11m         Normal    Scheduled                pod/php-apache-5d54745f55-q6mpl        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-q6mpl to docker-desktop
11m         Normal    Scheduled                pod/php-apache-5d54745f55-psdch        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-psdch to docker-desktop
11m         Normal    Scheduled                pod/php-apache-5d54745f55-dd74s        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-dd74s to docker-desktop
11m         Normal    Pulling                  pod/php-apache-5d54745f55-dd74s        Pulling image "k8s.gcr.io/hpa-example"
11m         Normal    Pulling                  pod/php-apache-5d54745f55-q6mpl        Pulling image "k8s.gcr.io/hpa-example"
11m         Normal    Pulling                  pod/php-apache-5d547

45f55-vh289        Pulling image "k8s.gcr.io/hpa-example"
10m         Normal    Pulled                   pod/php-apache-5d54745f55-vh289        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.155s (1.155s including waiting)
10m         Normal    Started                  pod/php-apache-5d54745f55-vh289        Started container php-apache
10m         Normal    Created                  pod/php-apache-5d54745f55-vh289        Created container php-apache
10m         Normal    Pulled                   pod/php-apache-5d54745f55-psdch        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.15s (2.305s including waiting)
10m         Normal    Created                  pod/php-apache-5d54745f55-psdch        Created container php-apache
10m         Normal    Started                  pod/php-apache-5d54745f55-psdch        Started container php-apache
10m         Normal    Pulled                   pod/php-apache-5d54745f55-q6mpl        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.218s (3.524s including waiting)
10m         Normal    Created                  pod/php-apache-5d54745f55-q6mpl        Created container php-apache
10m         Normal    Started                  pod/php-apache-5d54745f55-q6mpl        Started container php-apache
10m         Normal    Created                  pod/php-apache-5d54745f55-mbh4k        Created container php-apache
10m         Normal    Pulled                   pod/php-apache-5d54745f55-mbh4k        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.239s (4.763s including waiting)
10m         Normal    Started                  pod/php-apache-5d54745f55-mbh4k        Started container php-apache
10m         Normal    Started                  pod/php-apache-5d54745f55-dd74s        Started container php-apache
10m         Normal    Pulled                   pod/php-apache-5d54745f55-dd74s        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.188s (5.951s including waiting)
10m         Normal    Created                  pod/php-apache-5d54745f55-dd74s        Created container php-apache
9m          Normal    Killing                  pod/php-apache-5d54745f55-vh289        Stopping container php-apache
9m          Normal    SuccessfulRescale        horizontalpodautoscaler/standard-hpa   New size: 7; reason: All metrics below target
9m          Normal    Killing                  pod/php-apache-5d54745f55-mbh4k        Stopping container php-apache
9m          Normal    Killing                  pod/php-apache-5d54745f55-psdch        Stopping container php-apache
8m          Normal    Killing                  pod/php-apache-5d54745f55-24dnx        Stopping container php-apache
8m          Normal    SuccessfulRescale        horizontalpodautoscaler/standard-hpa   New size: 6; reason: All metrics below target
5m          Normal    Pulling                  pod/php-apache-5d54745f55-4mv5x        Pulling image "k8s.gcr.io/hpa-example"
5m          Normal    Scheduled                pod/php-apache-5d54745f55-p694k        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-p694k to docker-desktop
5m          Normal    Pulling                  pod/php-apache-5d54745f55-p694k        Pulling image "k8s.gcr.io/hpa-example"
5m          Normal    Scheduled                pod/php-apache-5d54745f55-4mv5x        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-4mv5x to docker-desktop
5m          Normal    Scheduled                pod/php-apache-5d54745f55-vm8kz        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-vm8kz to docker-desktop
5m          Normal    Pulling                  pod/php-apache-5d54745f55-wfjbq        Pulling image "k8s.gcr.io/hpa-example"
5m          Normal    Scheduled                pod/php-apache-5d54745f55-wfjbq        Successfully assigned dynamic-holt-winters/php-apache-5d54745f55-wfjbq to docker-desktop
5m          Normal    Pulling                  pod/php-apache-5d54745f55-vm8kz        Pulling image "k8s.gcr.io/hpa-example"
4m59s       Normal    Pulled                   pod/php-apache-5d54745f55-4mv5x        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.296s (1.296s including waiting)
4m59s       Normal    Created                  pod/php-apache-5d54745f55-4mv5x        Created container php-apache
4m59s       Normal    Started                  pod/php-apache-5d54745f55-4mv5x        Started container php-apache
4m57s       Normal    Started                  pod/php-apache-5d54745f55-p694k        Started container php-apache
4m57s       Normal    Created                  pod/php-apache-5d54745f55-p694k        Created container php-apache
4m57s       Normal    Pulled                   pod/php-apache-5d54745f55-p694k        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.254s (2.55s including waiting)
4m56s       Normal    Started                  pod/php-apache-5d54745f55-vm8kz        Started container php-apache
4m56s       Normal    Created                  pod/php-apache-5d54745f55-vm8kz        Created container php-apache
4m56s       Normal    Pulled                   pod/php-apache-5d54745f55-vm8kz        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.183s (3.734s including waiting)
4m55s       Normal    Created                  pod/php-apache-5d54745f55-wfjbq        Created container php-apache
4m55s       Normal    Started                  pod/php-apache-5d54745f55-wfjbq        Started container php-apache
4m55s       Normal    Pulled                   pod/php-apache-5d54745f55-wfjbq        Successfully pulled image "k8s.gcr.io/hpa-example" in 1.133s (4.868s including waiting)
3m11s       Normal    Completed                job/load-tester                        Job completed
2m          Normal    Killing                  pod/php-apache-5d54745f55-xjdqv        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-p694k        Stopping container php-apache
2m          Normal    SuccessfulRescale        horizontalpodautoscaler/standard-hpa   New size: 1; reason: All metrics below target
2m          Normal    Killing                  pod/php-apache-5d54745f55-q6mpl        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-wfjbq        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-4mv5x        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-dd74s        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-7znn8        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-gxjhb        Stopping container php-apache
2m          Normal    Killing                  pod/php-apache-5d54745f55-vm8kz        Stopping container php-apache
```

### Analysis and Comparison

#### Dynamic Holt-Winters PHPA

- **Başlangıç (22:40:11):** Başlangıçta pod sayısı 0.
- **İlk Artış (22:41:11 - 22:42:51):** Pod sayısı hızla 14'e çıkar.
- **Yüksek Trafik (22:43:11 - 22:50:11):** Pod sayısı yüksek seviyede kalır, 14 ila 15 arasında.
- **Yük Azalışı (22:50:31 - 22:50:51):** Pod sayısı tekrar azalır ve 0'a düşer.

#### Normal HPA

- **Başlangıç ve Yük Artışı (13m - 12m):** Pod say

ısı 5'e çıkar.
- **Daha Fazla Yük Artışı (12m - 11m):** Pod sayısı 10'a yükselir.
- **Yük Azalışı (9m - 2m):** Pod sayısı kademeli olarak azalır ve 1'e düşer.

### Karşılaştırma ve Yorum

**Dynamic Holt-Winters PHPA:**
- **Yanıt Süresi:** Dynamic Holt-Winters PHPA, yük artışlarına hızlı ve proaktif tepki veriyor.
- **Pod Sayısındaki Artış:** Daha hızlı ve öngörülerek yapılmış, bu da modelin mevsimsel değişikliklere iyi yanıt verdiğini gösteriyor.
- **Yüksek Trafik:** Pod sayısı yük altında sabit yüksek seviyede tutuluyor.

**Normal HPA:**
- **Yanıt Süresi:** Normal HPA, CPU kullanımına dayalı olarak reaktif bir şekilde pod sayısını artırmış.
- **Pod Sayısındaki Artış:** Ani artışlarla yapılmış, yük azaldıkça pod sayısı kademeli olarak düşürülmüş.
- **Yüksek Trafik:** Pod sayısı yüksek trafikte hızlı bir şekilde artırılmış, ancak azalmalar da hızlı gerçekleşmiş.

**Genel Yorum:**
- **Dynamic Holt-Winters PHPA**, mevsimsel ve dinamik trafik desenlerinde daha etkili bir çözüm sunar. Bu yöntem, trafikteki ani değişikliklere daha proaktif ve tahmin edici bir yaklaşım sergiler.
- **Normal HPA** ise, CPU kullanımına dayalı olarak ani yük artışlarına hızlı tepki verir. Ancak, yük azalması durumunda gereksiz pod azaltmalarına neden olabilir.

---

### Holt-Winters Predictional Horizontal Autoscaler (PHPA) Avantajlar:

1. **Daha İyi Tahminleme**: Dynamic Holt-Winters modeli, trend ve mevsimsellik gibi zaman serisi özelliklerini dikkate alır, bu da yük değişimlerini daha doğru tahmin etmeye yardımcı olur.
2. **Önceden Ölçeklendirme**: Beklenen yük artışlarına karşı önceden ölçeklendirme yaparak, kaynakların zamanında hazır olmasını sağlar, böylece kullanıcı deneyimi iyileştirilir.
3. **Kaynak Kullanımı Optimizasyonu**: Gelecek yük tahminlerine dayalı ölçeklendirme, kaynak israfını azaltır ve maliyet optimizasyonuna katkıda bulunur.
4. **Yük Dalgalanmalarına Uyum**: PHPA, yük dalgalanmalarını öğrenerek ve tahmin ederek ani yük değişimlerine daha hızlı ve etkin yanıt verir.
5. **Esneklik**: Farklı yük senaryolarına ve iş yükü paternlerine esnek bir şekilde adapte olabilir, bu da çeşitli uygulama türleri için uygun hale getirir.

### Holt-Winters Predictional Horizontal Autoscaler (PHPA) Dezavantajlar:

1. **Karmaşıklık**: Modelin kurulumu ve ayarı, standart HPA'ya göre daha karmaşık ve teknik bilgi gerektirir.
2. **Yanlış Tahminler**: Model parametrelerinin yanlış ayarlanması, tahmin hatalarına ve istenmeyen ölçeklendirme eylemlerine yol açabilir.
3. **Bakım Gereksinimi**: Modelin doğru çalışmaya devam etmesi için düzenli bakım ve inceleme gereklidir.
4. **Veriye Duyarlılık**: Yeterli ve kaliteli veri gerektirir; veri eksikliği veya kalitesiz veri model performansını olumsuz etkileyebilir.
5. **Maliyet**: İleri düzey modelleme ve sürekli veri analizi, işletme maliyetlerini artırabilir.

### Normal Horizontal Pod Autoscaler (HPA)

### Avantajlar:

1. **Kurulum Kolaylığı**: HPA, Kubernetes'in yerleşik bir özelliği olarak gelir ve basit metriklerle kolayca kurulabilir ve yönetilebilir.
2. **Düşük Bakım**: Bir kez kurulduktan sonra, az bakım gerektirir ve genellikle otomatik olarak çalışır.
3. **Anında Tepki**: Gerçek zamanlı metriklerle çalışır ve kaynak kullanımı belirli bir eşiği aştığında hızlı bir şekilde ölçeklendirme yapar.
4. **Geniş Kabul ve Destek**: Kubernetes kullanıcıları arasında geniş bir kabul görmüştür ve çeşitli araçlar ve topluluk desteği ile desteklenmektedir.
5. **Basit ve Güvenilir**: Yapılandırması kolaydır ve çoğu kullanım senaryosu için güvenilir sonuçlar sunar.

### Dezavantajlar:

1. **Reaktif Yaklaşım**: Yalnızca mevcut yük üzerine tepki verir, bu yüzden yük artışlarına proaktif bir yanıt veremez.
2. **Esneklik Eksikliği**: Mevsimsellik veya trend gibi daha karmaşık yük desenlerini anlamakta ve buna göre ölçeklendirmede yetersiz kalabilir.
3. **Ani Yük Değişimlerine Yavaş Yanıt**: Ani yük artışları durumunda, kaynaklar yeterince hızlı sağlanamayabilir, bu da performans sorunlarına yol açabilir.
4. **Kaynak İsrafı**: Kısa süreli yük artışları, gereksiz yere fazla sayıda pod başlatılmasına neden olabilir.
5. **Detaylı İzleme ve Tahmin Yok**: HPA, basit CPU ve bellek kullanımı gibi temel metriklerle çalışır ve daha detaylı kullanım veya tahmin yetenekleri sunmaz.


### Sonuç

Bu test senaryosu, Dynamic Holt-Winters PHPA'nın değişken yük koşullarına nasıl uyum sağladığını ve standart HPA ile karşılaştırıldığında performansını göstermektedir. Her iki yaklaşımın avantajlarını ve dezavantajlarını anlayarak, uygulama ihtiyaçlarınıza en uygun otomatik ölçeklendirme yöntemini seçebilirsiniz.