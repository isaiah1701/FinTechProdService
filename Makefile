CLUSTER_NAME ?= bank-platform
IMAGE ?= bank-account-service:local
CHART ?= k8s/helm/bank-account-service
APP_CONTAINER ?= bank-account-service-smoke
APP_PORT ?= 18080

.PHONY: local-up local-db-up local-down test docker-build docker-run docker-stop kind-create kind-load kind-secret kind-deploy helm-lint helm-template terraform-fmt terraform-validate

local-up:
	docker compose -f local/docker-compose.yml up -d

local-db-up:
	test -n "$(BANK_POSTGRES_OWNER_PASSWORD)"
	test -n "$(BANK_ACCOUNT_APP_PASSWORD)"
	BANK_GRAFANA_ADMIN_PASSWORD=$${BANK_GRAFANA_ADMIN_PASSWORD:-unused-local} \
		docker compose -f local/docker-compose.yml up -d postgres

local-down:
	docker compose -f local/docker-compose.yml down

test:
	PYTHONPATH=app/src pytest app/tests

docker-build:
	docker build -t $(IMAGE) -f app/Dockerfile .

docker-run:
	test -n "$(DATABASE_URL)"
	docker rm -f $(APP_CONTAINER) >/dev/null 2>&1 || true
	docker run -d --name $(APP_CONTAINER) \
		--add-host=host.docker.internal:host-gateway \
		-p $(APP_PORT):8080 \
		-e DATABASE_URL="$(DATABASE_URL)" \
		$(IMAGE)

docker-stop:
	docker rm -f $(APP_CONTAINER) >/dev/null 2>&1 || true

kind-create:
	kind create cluster --name $(CLUSTER_NAME)

kind-load:
	kind load docker-image $(IMAGE) --name $(CLUSTER_NAME)

kind-secret:
	test -n "$(DATABASE_URL)"
	kubectl create secret generic bank-account-service-db \
		--from-literal=DATABASE_URL="$(DATABASE_URL)" \
		--dry-run=client -o yaml | kubectl apply -f -

kind-deploy:
	helm upgrade --install bank-account-service $(CHART) \
		--set image.repository=bank-account-service \
		--set image.tag=local \
		--set image.pullPolicy=Never

helm-lint:
	helm lint $(CHART)

helm-template:
	helm template bank-account-service $(CHART)

terraform-fmt:
	cd infra/terraform && terraform fmt -recursive

terraform-validate:
	cd infra/terraform && terraform init -backend=false && terraform fmt -check -recursive && terraform validate
