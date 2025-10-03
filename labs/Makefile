LAB_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(LAB_ROOT)/..)

NAMESPACE ?= phpa-lab
OPERATOR_NAMESPACE ?= phpa-system
RUN_DURATION ?= 240
SAMPLING_INTERVAL ?= 5
PYTHON ?= python3

.PHONY: bootstrap offline online report destroy clean

bootstrap:
	@echo "[labs] Kurulum başlıyor (namespace=$(NAMESPACE), operator-ns=$(OPERATOR_NAMESPACE))"
	NAMESPACE=$(NAMESPACE) OPERATOR_NAMESPACE=$(OPERATOR_NAMESPACE) \
		$(LAB_ROOT)/scripts/bootstrap.sh

offline:
	@echo "[labs] Offline benchmark çalışıyor"
	PYTHON=$(PYTHON) $(LAB_ROOT)/scripts/run_offline_benchmark.sh

online:
	@echo "[labs] Online deneyler çalışıyor"
	NAMESPACE=$(NAMESPACE) RUN_DURATION=$(RUN_DURATION) SAMPLING_INTERVAL=$(SAMPLING_INTERVAL) \
		$(LAB_ROOT)/scripts/run_online_benchmark.sh

report:
	@echo "[labs] Rapor üretiliyor"
	PYTHON=$(PYTHON) $(LAB_ROOT)/scripts/generate_report.py

# Operatör, namespace ve oluşturulan dosyaları temizler
 destroy:
	@echo "[labs] Kaynaklar temizleniyor"
	NAMESPACE=$(NAMESPACE) OPERATOR_NAMESPACE=$(OPERATOR_NAMESPACE) \
		$(LAB_ROOT)/scripts/destroy.sh

clean:
	@echo "[labs] Çıktılar temizleniyor"
	rm -rf $(LAB_ROOT)/output/offline/* $(LAB_ROOT)/output/online/* $(LAB_ROOT)/output/report.md || true
