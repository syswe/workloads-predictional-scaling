[![Build](https://github.com/syswe/predictive-horizontal-pod-autoscaler/workflows/main/badge.svg)](https://github.com/syswe/predictive-horizontal-pod-autoscaler/actions)
[![go.dev](https://img.shields.io/badge/go.dev-reference-007d9c?logo=go&logoColor=white&style=flat)](https://pkg.go.dev/github.com/syswe/predictive-horizontal-pod-autoscaler)
[![Go Report Card](https://goreportcard.com/badge/github.com/syswe/predictive-horizontal-pod-autoscaler)](https://goreportcard.com/report/github.com/syswe/predictive-horizontal-pod-autoscaler)
[![Documentation Status](https://readthedocs.org/projects/predictive-horizontal-pod-autoscaler/badge/?version=latest)](https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest)
[![License](https://img.shields.io/:license-apache-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

# Predictive Horizontal Pod Autoscaler (PHPA)

`syswe/predictive-horizontal-pod-autoscaler` extends the native Kubernetes Horizontal Pod Autoscaler (HPA) with
predictive models so that workloads can scale **before** demand spikes occur. The operator evaluates the standard HPA
calculation, applies statistical or machine-learning models over replica history, and then writes back the desired
replica count.

## Why PHPA?

- Proactive scaling for workloads with recurring traffic patterns or bursty demand.
- Multiple ready-to-use predictive models covering classical time series and gradient boosting techniques.
- Operator-based installation that works on any cluster where HPAs are supported (managed Kubernetes, bare metal,
  **k3d**, etc.).
- Extensible hooks for shipping your own Python (or other language) models through the Custom Models interface.

## Architecture Overview

- **CRD**: `PredictiveHorizontalPodAutoscaler` in the `syswe.me` API group keeps configuration close to familiar HPA
  manifests while exposing model configuration, hook definitions, and per-model options.
- **Controller**: Built with Kubebuilder and `controller-runtime`. Reconciliation pulls Kubernetes metrics via
  `syswe/k8shorizmetrics`, evaluates desired replicas, and invokes the configured predictive models.
- **Model runners**: Each model implements the `prediction.ModelPredict` interface. Native Go implementations and
  external Python scripts coexist, enabling offline training followed by lightweight in-cluster inference.
- **Hooks**: Optional `runtimeTuningFetchHook` or scaling event hooks can call external services (HTTP/webhook) to push
  additional context into the models.

## Built-in Models

| Type | Description | Best for |
| ---- | ----------- | -------- |
| `Linear` | Ordinary least squares regression over recent replicas. | Simple trends and gentle slopes. |
| `HoltWinters` | Triple exponential smoothing with configurable seasonality and trend components. | Strong seasonal and cyclical patterns. |
| `GBDT` | Gradient Boosted Decision Trees using scikit-learn with configurable lags/lookahead. | Non-linear dynamics with structured historical data. |
| `CatBoost` | CatBoost regressor optimised for categorical/time features with fast inference. | Fast, accurate predictions with little manual feature tuning. |
| `VAR` | Vector Auto Regression capturing multi-variable interactions across lags. | Multivariate time series (e.g., replica + external signals). |
| `XGBoost` | XGBoost regressor variant with iterative horizon forecasting. | Highly expressive gradient boosting where GPU/CPU resources are available. |

Sample snippet configuring multiple models:

```yaml
apiVersion: syswe.me/v1alpha1
kind: PredictiveHorizontalPodAutoscaler
metadata:
  name: sample-workload
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
  models:
    - type: HoltWinters
      name: seasonal-fit
      perSyncPeriod: 1
      holtWinters:
        alpha: 0.9
        beta: 0.1
        gamma: 0.4
        seasonalPeriods: 6
        storedSeasons: 4
    - type: GBDT
      name: gbdt-fast
      gbdt:
        lookAhead: 10000
        historySize: 30
        lags: 6
    - type: CatBoost
      name: catboost-default
      catboost:
        lookAhead: 15000
        historySize: 40
```

See [`docs/user-guide/models.md`](docs/user-guide/models.md) for every configuration knob and advanced tuning advice.

## Installation

Install the operator using Helm (replace `vX.Y.Z` with the desired release tag):

```bash
VERSION=vX.Y.Z
HELM_CHART=predictive-horizontal-pod-autoscaler-operator
helm install ${HELM_CHART} \
  https://github.com/syswe/predictive-horizontal-pod-autoscaler/releases/download/${VERSION}/predictive-horizontal-pod-autoscaler-${VERSION}.tgz
```

The chart installs the CRD, RBAC, deployment, and optional validating/mutating webhooks that ensure configuration
consistency.

For a pure manifest-based install, apply the resources under [`helm/templates/cluster`](helm/templates/cluster/)
after templating or adapting them to your environment.

## Quick Start

1. Ensure a metrics server is available in the cluster (`kubectl get apiservice v1beta1.metrics.k8s.io`).
2. Deploy an example workload and PHPA definition from [`examples/`](examples/) – e.g. `examples/simple-gbdt/` pairs a
   synthetic traffic generator with a GBDT model.
3. Inspect the resulting scaling decisions with `kubectl describe phpa sample-workload` and watch replica counts on the
   target deployment.
4. Tune `lookAhead`, `historySize`, or per-model options as you analyse your traffic profile.

Detailed walkthroughs live in the [docs wiki](docs/wiki/) and the [custom models guide](docs/user-guide/custom-models.md).

## Repository Layout

- `api/` – CRD Go types and generated DeepCopy/Webhook code.
- `internal/controllers/` – Reconciler logic and integration with the prediction engine.
- `internal/prediction/` – Model implementations (`linear`, `holtwinters`, `gbdt`, `catboost`, `varmodel`, `xgboost`).
- `algorithms/` – Offline training scripts for Python-based models.
- `helm/` & `deploy/` – Helm chart templates and raw manifests for operator deployment.
- `docs/` – MkDocs sources for the documentation site.
- `scripts/` – Utility tooling for benchmarking, stopping local setups, etc.

## Development

Requirements:

- [Go](https://golang.org/doc/install) **1.20+**
- [Python](https://www.python.org/downloads/) **3.8.x** with `pip`
- [Helm](https://helm.sh/) **3.9.x**

Install Python dependencies for the bundled algorithms:

```bash
pip install -r requirements-dev.txt
```

Key `make` targets:

- `make run` – Run the operator locally against your kubeconfig context.
- `make docker` – Build the PHPA container image.
- `make lint` / `make format` – Static analysis and formatting checks.
- `make test` – Execute Go unit tests.
- `make doc` – Serve the documentation locally at <https://localhost:8000>.
- `make coverage` – Produce and open coverage reports.

When contributing, ensure new models include validation, unit tests, and docs updates describing configuration and
deployment considerations.

## License

This project is licensed under the [Apache 2.0 License](LICENSE).
