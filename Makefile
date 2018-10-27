.PHONY: build
build:
	swift build

generate-xcode:
	swift package generate-xcodeproj

open-xcode:
	open OtaDeployState.xcodeproj

docker-build:
	docker build -t ota-deploy-state .

docker-run-interactive:
	docker run --net=host --privileged --rm --cap-add sys_ptrace -it ota-deploy-state bash
