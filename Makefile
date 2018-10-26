docker-build:
	docker build -t ota-deploy-state .

docker-run-interactive:
	docker run --net=host --privileged --rm --cap-add sys_ptrace -it ota-deploy-state bash
