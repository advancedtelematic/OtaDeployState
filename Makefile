.PHONY: build
build:
	swift build

generate-xcode:
	swift package generate-xcodeproj

open-xcode:
	open OtaDeployState.xcodeproj

docker-build:
	docker build -t advancedtelematic/ota-deploy-state .

docker-push:
	docker push advancedtelematic/ota-deploy-state

docker-run:
	docker run \
		--rm \
		-it \
		--net=host \
		advancedtelematic/ota-deploy-state ./.build/debug/OtaDeployState

docker-run-interactive:
	docker run \
		-it \
		--net=host \
		--rm \
		--privileged --cap-add sys_ptrace \
		advancedtelematic/ota-deploy-state bash

kube-apply:
	kubectl apply -f ./deploy/deploy.yaml
