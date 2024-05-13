# Kurulum

Predictive Horizontal Pod Autoscaler Operatörünü (PHPA operatörü) kümenize yükledikten sonra Predictive Horizontal Pod Autoscalers (PHPAs) kurabilirsiniz.

PHPA operatörü Helm kullanılarak kurulabilir, operatörü kümenize küme çapında yüklemek için bu komutu çalıştırın:

```bash
VERSION=v0.13.2
HELM_CHART=predictive-horizontal-pod-autoscaler-operator
helm install ${HELM_CHART} https://github.com/jthomperoo/predictive-horizontal-pod-autoscaler/releases/download/${VERSION}/predictive-horizontal-pod-autoscaler-${VERSION}.tgz
```

Bunu yaptıktan sonra, kümenize PHPAs yükleyebilirsiniz. Dağıtabileceğiniz PHPAs için [örneklere](https://github.com/jthomperoo/predictive-horizontal-pod-autoscaler/tree/master/examples) göz atın veya [başlangıç kılavuzunu](./getting-started.md) izleyin.