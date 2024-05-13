# Metrikler

Hangi metriklerin kullanılacağını belirlemek için `MetricSpecs` kullanılır, bunlar HPAs'in anahtar bir parçasıdır ve şu şekilde görünür:

```yaml
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 50
```

Bu spesifikasyonları Predictive HPA'ya göndermek için, PHPA'ya metrik listesini içeren çok satırlı bir dize ile `metrics` adında bir yapılandırma seçeneği ekleyin. Örneğin:

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 50
```

Bu, mevcut Kubernetes HPA metrik yapılandırmalarını Predictive Horizontal Pod Autoscaler'a aktarmanıza olanak tanır. K8s HPA metrik spesifikasyonlarına eşdeğerdir; bunlar [bu HPA
rehberinde](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#autoscaling-on-multiple-metrics-and-custom-metrics) gösterilmiştir.
Bir dizi olduğundan birden fazla değeri tutabilir.

Desteklenen metriklerin tam listesi için [Horizontal Pod Autoscaler dokümantasyonuna](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) bakın (Predictive Horizontal Pod Autoscaler işlevsel olarak eşdeğer olmayı amaçlamaktadır).