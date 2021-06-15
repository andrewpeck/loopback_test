init:
	git submodule update --init --recursive

create:
	Hog/CreateProject.sh loopback

build:
	Hog/LaunchWorkflow.sh loopback
