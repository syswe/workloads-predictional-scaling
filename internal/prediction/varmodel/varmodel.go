package varmodel

import (
    "encoding/json"
    "errors"
    "sort"
    "strconv"

    syswev1alpha1 "github.com/syswe/predictive-horizontal-pod-autoscaler/api/v1alpha1"
)

const (
    defaultTimeout = 30000
)

const algorithmPath = "algorithms/var/var.py"

type parameters struct {
    LookAhead      int                                           `json:"lookAhead"`
    Lags           int                                           `json:"lags"`
    ReplicaHistory []syswev1alpha1.TimestampedReplicas `json:"replicaHistory"`
}

// AlgorithmRunner defines an algorithm runner, allowing algorithms to be run
type AlgorithmRunner interface {
    RunAlgorithmWithValue(algorithmPath string, value string, timeout int) (string, error)
}

// Predict provides logic for using VAR to make a prediction
type Predict struct {
    Runner AlgorithmRunner
}

// GetPrediction uses VAR to predict what the replica count should be based on historical evaluations
func (p *Predict) GetPrediction(model *syswev1alpha1.Model, replicaHistory []syswev1alpha1.TimestampedReplicas) (int32, error) {
    if model.VAR == nil {
        return 0, errors.New("no VAR configuration provided for model")
    }

    if len(replicaHistory) == 0 {
        return 0, errors.New("no evaluations provided for VAR model")
    }

    if len(replicaHistory) <= model.VAR.Lags {
        return replicaHistory[len(replicaHistory)-1].Replicas, nil
    }

    params, err := json.Marshal(parameters{
        LookAhead:      model.VAR.LookAhead,
        Lags:           model.VAR.Lags,
        ReplicaHistory: replicaHistory,
    })
    if err != nil {
        panic(err)
    }

    timeout := defaultTimeout
    if model.CalculationTimeout != nil {
        timeout = *model.CalculationTimeout
    }

    value, err := p.Runner.RunAlgorithmWithValue(algorithmPath, string(params), timeout)
    if err != nil {
        return 0, err
    }

    prediction, err := strconv.Atoi(value)
    if err != nil {
        return 0, err
    }

    return int32(prediction), nil
}

// PruneHistory trims history to HistorySize most recent points
func (p *Predict) PruneHistory(model *syswev1alpha1.Model, replicaHistory []syswev1alpha1.TimestampedReplicas) ([]syswev1alpha1.TimestampedReplicas, error) {
    if model.VAR == nil {
        return nil, errors.New("no VAR configuration provided for model")
    }

    if len(replicaHistory) <= model.VAR.HistorySize {
        return replicaHistory, nil
    }

    sort.Slice(replicaHistory, func(i, j int) bool {
        return !replicaHistory[i].Time.Before(replicaHistory[j].Time)
    })

    for i := len(replicaHistory) - 1; i >= model.VAR.HistorySize; i-- {
        replicaHistory = append(replicaHistory[:i], replicaHistory[i+1:]...)
    }

    return replicaHistory, nil
}

// GetType returns the model type
func (p *Predict) GetType() string {
    return syswev1alpha1.TypeVAR
}

