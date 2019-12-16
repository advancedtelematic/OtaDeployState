.PHONY: build

VERSION=0.4.0

build:
	swift build

generate-xcode:
	swift package generate-xcodeproj

open-xcode:
	open OtaDeployState.xcodeproj

docker-build:
	docker build -t advancedtelematic/ota-deploy-state:$(VERSION) .

docker-push:
	docker push advancedtelematic/ota-deploy-state:$(VERSION)

docker-run:
	docker run \
		--rm \
		-it \
		--net=host \
		-v /usr/local/etc/ota-deploy-state:/usr/local/etc/ota-deploy-state \
		advancedtelematic/ota-deploy-state:$(VERSION)

docker-run-interactive:
	docker run \
		-it \
		--net=host \
		--rm \
		-v /usr/local/etc/ota-deploy-state:/usr/local/etc/ota-deploy-state \
		--privileged --cap-add sys_ptrace \
		advancedtelematic/ota-deploy-state bash

kube-apply:
	kubectl apply -f ./deploy/deploy.yaml

start-dev-vault:
	docker run --rm \
		-p 8200:8200 \
		--cap-add=IPC_LOCK \
		-v $(CURDIR)/vault.json:/tmp/vault.json vault:0.6.5 server -config=/tmp

restart-kube-vault:
	kubectl delete -f deploy/vault.yaml
	kubectl apply -f deploy/vault.yaml
	kubectl delete secret --selector 'createdBy=OtaDeployState'

restart-ota-deploy-state:
	kubectl delete -f ./deploy/generic-secrets.yaml || true
	kubectl delete -f ./deploy/configmap.yaml || true
	kubectl delete -f ./deploy/deploy.yaml || true
	kubectl delete secret --selector 'createdBy=OtaDeployState' || true
	kubectl apply -f ./deploy/generic-secrets.yaml
	kubectl apply -f ./deploy/configmap.yaml
	kubectl apply -f ./deploy/deploy.yaml
