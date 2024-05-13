# Basit Holt-Winters PHPA

Bu belge, Docker Desktop'ın Kubernetes ortamında Holt-Winters tahmin yöntemi kullanarak Predictive Horizontal Pod Autoscaler (PHPA) kurulumunu adım adım açıklamaktadır. Docker Desktop, yerel makinenizde bir Kubernetes kümesini kolayca kurup çalıştırmanıza olanak tanır, bu da geliştirme ve test senaryoları için idealdir.

## Ön Koşullar
1. **Docker Desktop ile Kubernetes**: Docker Desktop'ın yüklü olduğundan ve ayarlarında Kubernetes'in etkinleştirildiğinden emin olun.
2. **kubectl**: Yüklü olmalı ve Docker Desktop Kubernetes kümenizle iletişim kuracak şekilde yapılandırılmalıdır.
3. **Helm**: Kubernetes uygulamalarını yönetmek için Helm yükleyin.
4. **jq**: JSON verilerini işlemek için `jq` yükleyin.
5. **Docker**: Yük testi görüntüsünü oluşturmak için Docker yüklenmelidir.

## Kurulum Adımları

### Adım 1: Docker Desktop'ta Kubernetes'i Etkinleştirme
- Docker Desktop'ı açın.
- Tercihler > Kubernetes'e gidin.
- "Kubernetes'i Etkinleştir" seçeneğini işaretleyin ve "Uygula ve Yeniden Başlat" düğmesine tıklayın.

### Adım 2: Predictive Horizontal Pod Autoscaler Operatörünü Yükleme
İlk olarak, PHPA operatörünü yüklemeniz gerekmektedir. Bu işlem genellikle Helm aracılığıyla yapılır:

```bash
helm repo add predictive-horizontal-pod-autoscaler https://predictive-horizontal-pod-autoscaler.github.io/helm/
helm repo update
helm install phpa predictive-horizontal-pod-autoscaler/predictive-horizontal-pod-autoscaler
```

### Adım 3: Yönetilecek Uygulamayı Dağıtma
`php-apache` dağıtımı için bir `deployment.yaml` dosyası oluşturun:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: k8s.gcr.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m
          limits:
            cpu: 500m
```

- **apiVersion**: Kubernetes API versiyonu.
- **kind**: Bu kaynağın türü, bu durumda bir `Deployment`.
- **metadata**: Deployment için isim ve diğer tanımlayıcı bilgiler.
- **spec**: Deployment özelliklerini içerir.
  - **replicas**: Başlangıçta kaç pod'un çalıştırılacağı.
  - **selector**: Bu deployment tarafından yönetilen pod'ları etiketlere göre nasıl seçeceği.
  - **template**: Yaratılacak pod'ların şablonu.
    - **metadata**: Pod için etiketler.
    - **spec**: Pod içinde çalışacak konteynerler ve ayarlar.
      - **containers**: Çalıştırılacak konteynerler listesi.
        - **name**: Konteyner ismi.
        - **image**: Konteynerin kullanacağı imaj.
        - **ports**: Konteynerin açık olacak portları.
        - **resources**: Konteyner için ayrılacak kaynak miktarları.

Bu dağıtımı uygulayın:

```bash
kubectl apply -f deployment.yaml
```

### Adım 4: PHPA Yapılandırmasını Uygulama
PHPA yapılandırması için bir `phpa.yaml` dosyası oluşturun:

```yaml
apiVersion: jamiethompson.me/v1alpha1
kind: PredictiveHorizontalPodAutoscaler
metadata:
  name: simple-holt-winters
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
    name: simple-holt-winters
    holtWinters:
      alpha: 0.9
      beta: 0.9
      gamma: 0.9
      seasonalPeriods: 6
      storedSeasons: 4
      trend: additive
      seasonal: additive
```
- **apiVersion**: PHPA API versiyonu.
- **kind**: Bu kaynağın türü, bu durumda bir `PredictiveHorizontalPodAutoscaler`.
- **metadata**: PHPA için isim ve diğer tanımlayıcı bilgiler.
- **spec**: PHPA özelliklerini içerir.
  - **scaleTargetRef**: Ölçeklendirilecek kaynağı belirtir.
  - **minReplicas** ve **maxReplicas**: Minimum ve maksimum replica sayıları.
  - **syncPeriod**: Otoscaler'ın ne kadar sıklıkla çalışacağı (milisaniye).
  - **behavior**: Ölçekleme davranışlarını tanımlar.
  - **metrics**: Kullanılacak metrikleri tanımlar.
  - **models**: Uygulanacak tahmin modellerini içerir.
  
Bu PHPA yapılandırmasını uygulayın:

```bash
kubectl apply -f phpa.yaml
```

### Adım 5: Yük Test Cihazını Oluşturma ve Dağıtma
Yük test cihazı için Dockerfile

 bulunan dizine gidin ve görüntüyü oluşturun:

```bash
docker build -t load-tester .
```

Görüntüyü Docker Desktop'ın Kubernetes'ine aktarın:

```bash
docker save load-tester | kubectl apply -n kube-system -f -
```

`load/load.yaml` kullanarak yük test cihazı dağıtımını uygulayın:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-tester
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-tester
  template:
    metadata:
      labels:
        app: load-tester
    spec:
      containers:
      - name: load-tester
        image: load-tester
        env:
        - name: TARGET_URL
          value: "http://php-apache.default.svc.cluster.local"
```

Yük test cihazı dağıtımını uygulayın:

```bash
kubectl apply -f load/load.yaml
```

### Adım 6: PHPA Logları ve Performansını İzleme
Otoscaler'in çalışmasını izlemek ve yüke göre kaç replika ayarladığını görmek için:

```bash
kubectl logs -l name=predictive-horizontal-pod-autoscaler -f
```

Bu kurulum, Docker Desktop tarafından sağlanan yerel Kubernetes ortamında Holt-Winters tahmini kullanarak PHPA ile tahmini ölçeklendirme yapmanızı sağlar. Parametreleri ve yapılandırmaları, belirli gereksinimlerinize veya deneylerinize göre ayarlayın.