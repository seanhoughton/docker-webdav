ifeq ($(OS),Windows_NT)
	detected_OS := Windows
	export PWD?=$(shell echo %CD%)
else
	detected_OS := $(shell uname -s)
endif

export IMAGENAME=jtilander/webdav
export TAG?=test

image:
	docker build -t $(IMAGENAME):$(TAG) .
	docker images $(IMAGENAME):$(TAG)

run:
	docker run --rm -v $(PWD)/tmp:/data -p 8181:80 $(IMAGENAME):$(TAG)

clean:
	-docker run --rm -v $(PWD):/data alpine:3.7 rm -rf /data/tmp