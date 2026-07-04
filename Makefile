CLUSTER_NAME ?= mal-platform
IMAGE ?= mal-account-service:local
CHART ?= k8s/helm/mal-account-service

.PHONY: local-up local-down test docker-build kind-create kind-load kind-secret kind-deploy helm-lint helm-template terraform-fmt terraform-validate

local-up:
	docker compose -f local/docker-compose.yml up -d

local-down:
	docker compose -f local/docker-compose.yml down

test:
	PYTHONPATH=app/src pytest app/tests

docker-build:
	docker build -t $(IMAGE) -f app/Dockerfile .

kind-create:
	kind create cluster --name $(CLUSTER_NAME)

kind-load:
	kind load docker-image $(IMAGE) --name $(CLUSTER_NAME)

kind-secret:
	test -n "$(DATABASE_URL)"
	kubectl create secret generic mal-account-service-db \
		--from-literal=DATABASE_URL="$(DATABASE_URL)" \
		--dry-run=client -o yaml | kubectl apply -f -

kind-deploy:
	helm upgrade --install mal-account-service $(CHART) \
		--set image.repository=mal-account-service \
		--set image.tag=local \
		--set image.pullPolicy=Never

helm-lint:
	helm lint $(CHART)

helm-template:
	helm template mal-account-service $(CHART)

terraform-fmt:
	cd infra/terraform && terraform fmt -recursive

terraform-validate:
	cd infra/terraform && terraform init -backend=false && terraform fmt -check -recursive && terraform validate
