ifneq (,$(wildcard ./.env))
    include .env
    export
endif

PROFILE=tekton-test
TEKTON_PIPELINE_URL=https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
TEKTON_TRIGGER_URL=https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
TEKTON_INTERCEPTORS_URL=https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

_has_%:
	@command -v $* >/dev/null 2>&1 || { echo >&2 "This script need $* to be installed."; exit 1; }

# Tekton Pipeline
.PHONY: install_tekton_pipeline
install_tekton_pipeline: _has_kubectl
	curl -fsSL $(TEKTON_PIPELINE_URL) | sed 's|gcr\.io|m.daocloud\.io/gcr\.io|g' | kubectl apply -f -

# Tekton Trigger
.PHONY: install_tekton_trigger
install_tekton_trigger: _has_kubectl
	curl -fsSL $(TEKTON_TRIGGER_URL) | sed 's|gcr\.io|m.daocloud\.io/gcr\.io|g' | kubectl apply -f -
	curl -fsSL $(TEKTON_INTERCEPTORS_URL) | sed 's|gcr\.io|m.daocloud\.io/gcr\.io|g' | kubectl apply -f -

# Tekton profile
.PHONY: install_tekton
install_tekton:
	$(MAKE) install_tekton_pipeline
	$(MAKE) install_tekton_trigger

.PHONY: install_catalog
install_catalog:
	kubectl apply -f task/ko/0.1/ko.yaml
	kubectl apply -f pipeline/clone-kaniko/0.1/clone-kaniko.yaml
	kubectl apply -f pipeline/clone-ko/0.1/clone-ko.yaml

.PHONY: test
test: _has_minikube
	-@minikube status -p tekton-test >/dev/null 2>&1 && minikube delete -p $(PROFILE)
	@minikube start -p $(PROFILE) --driver=docker --container-runtime='containerd'\
	 && $(MAKE) install_tekton\
	 || minikube delete -p $(PROFILE)
	@printf "\n****************\nTest yaml now:\n\n"
	$(MAKE) install_catalog
	@minikube delete -p $(PROFILE) >/dev/null 2>&1
