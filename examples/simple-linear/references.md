# Basit Lineer PHPA

Bu örnek, lineer regresyon modeli kullanarak Predictive Horizontal Pod Autoscaler (PHPA) kurulumunu göstermektedir.

## Gereksinimler

Bu örneği kurmak ve burada listelenen adımları takip etmek için ihtiyacınız olanlar:

- [kubectl](https://kubernetes.io/docs/tasks/tools/).
- kubectl'in yapılandırıldığı bir Kubernetes kümesi - yerel testler için k3d veya Docker-Desktop iyi bir seçenektir.
- PHPA operatörünü yüklemek için [helm](https://helm.sh/docs/intro/install/).
- Bazı JSON çıktılarını formatlamak için [jq](https://stedolan.github.io/jq/).

## Kullanım

Bu örneği kümenize dağıtmak istiyorsanız, önce Predictive Horizontal Pod Autoscaler Operatörünü yüklemelisiniz, operatörü yüklemek için kurulum dokümanını takip edin.

Bu örnek, Predictional Horizontal Pod Autoscaler üzerine kurgulanmıştır.

1. `php-apache` adlı uygulamayı/dağıtımı yönetmek için bu komutu çalıştırın:

```bash
kubectl apply -f deployment.yaml
```

2. Daha önce oluşturulan dağıtımı gösteren autoscaler'ı başlatmak için bu komutu çalıştırın:

```bash
kubectl apply -f phpa.yaml
```

3. Otoscaler'in çalıştığını ve ürettiği günlük çıktısını görmek için bu komutu çalıştırın:

```bash
kubectl logs -l name=predictive-horizontal-pod-autoscaler -f
```

4. Yükü artırmak için bu komutu çalıştırın:

```bash
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

5. Replica sayısının arttığını izleyin.
6. Otoscaler tarafından saklanan ve takip edilen replica geçmişini görmek için bu komutu çalıştırın:

```bash
kubectl get configmap predictive-horizontal-pod-autoscaler-simple-linear-data -o=json | jq -r '.data.data | fromjson | .modelHistories["simple-linear"].replicaHistory[] | .time,.replicas'
```

Yük arttıkça, PHPA podların ortalama CPU kullanımının %50'nin üzerine çıktığını tespit edecek ve bu değeri düşürmeye çalışmak için daha fazla pod sağlayacaktır. Replica sayısı değiştikçe, PHPA yapılan replica değişikliklerinin geçmişini saklayacak ve otoscaler her çalıştığında bu verileri lineer regresyon modeline besleyecektir. Bu, otoscaler'in çalıştığı anda hesaplanan ham replica sayısı ve modelin replica sayısı geçmişine dayanarak hesapladığı tahmini değer olmak üzere iki değer sonucu verir. Kaynak daha sonra bu iki değerden daha büyük olanına göre ölçeklendirilecektir (maksimum değeri seçmenin dışında başka seçenekler de vardır, daha fazla bilgi için [decisionType yapılandırma seçeneğine](https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest/reference/configuration/#decisiontype) bakınız).

Bu tahmini ölçeklendirmenin nasıl göründüğünü gösteren bir grafik örneğinde ham hesaplanan replica sayılarının ve tahmin edilen replica sayılarının karşılaştırıldığı, ham hesaplanan replica sayısının ani bir şekilde düştüğü ve lineer regresyonun hesaplanan geçmişe dayanarak daha pürüzsüz bir şekilde ölçek azaltma yaklaşımı aldığı replica sayısının azaldığını gösterir.

## Açıklama

Bu örnek, otoscaler'i tanımlamak için aşağıdaki YAML'i kullanır:

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

- `scaleTargetRef` otoscaler'in ölçeklendirmek için hedef aldığı kaynağı belirtir.
- `minReplicas` ve `maxReplicas` otoscaler'in kaynağı ölçeklendirebileceği minimum ve maksimum replica sayılarını belirtir.
- `syncPeriod` otoscaler'in ne sıklıkla çalışacağını milisaniye cinsinden belirtir, bu otoscaler her 10000 milisaniyede (10 saniye) bir çalışacaktır.
- `behavior.scaleDown.stabilizationWindowSeconds` bir otoscaler'in ne kadar hızlı ölçek küçültebileceğini yönetir, varsayılan olarak geçmişte tanımlanan son zaman dilimi içinde meydana gelen en yüksek değerlendirmeyi seçer. Bu durumu engellemek için aşağı ölçekleme stabilizasyonunu `0` olarak ayarladık.
- `metrics` PHPA'nın ölçeklendirme yaparken kullanması gereken metrikleri tanımlar, bu örnekte her podun ortalama CPU kullanımını %50 seviyesinde tutmaya çalışır.
- `models` elde edilen replica sayısına uygulanan istatistiksel modelleri içerir, bu örnekte sadece geçmişteki 6 replica sayısını saklayan (`historySize: 6`) ve bu verileri kullanarak 10000 milisaniye (10 saniye) sonra replica sayısının ne olacağını tahmin eden bir lineer regresyon modeli bulunmaktadır (`lookAhead: 10000`).