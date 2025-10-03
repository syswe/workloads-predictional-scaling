# Simple GBDT Example

This example shows a Predictive Horizontal Pod Autoscaler (PHPA) using a Gradient Boosted Decision Trees model.

Usage mirrors the simple-linear example:

1. Deploy the sample app:

```bash
kubectl apply -f deployment.yaml
```

2. Deploy the PHPA with the GBDT model:

```bash
kubectl apply -f phpa.yaml
```

3. Watch operator logs:

```bash
kubectl logs -l name=predictive-horizontal-pod-autoscaler -f
```

4. Generate load and observe scaling.

The model configuration is under `spec.models[0].gbdt` with `lookAhead` (ms), `historySize`, and `lags`.
