ifeq '$(findstring ;,$(PATH))' ';'
    detected_OS := windows
	detected_arch := amd64
else
    detected_OS := $(shell uname | tr '[:upper:]' '[:lower:]' 2> /dev/null || echo Unknown)
    detected_OS := $(patsubst CYGWIN%,Cygwin,$(detected_OS))
    detected_OS := $(patsubst MSYS%,MSYS,$(detected_OS))
    detected_OS := $(patsubst MINGW%,MSYS,$(detected_OS))
	detected_arch := $(shell dpkg --print-architecture 2>/dev/null || amd64)
endif

APP=$(shell basename $(shell git remote get-url origin))
REGISTRY=sbazanov
VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)

get:
	go install

lint:
	golint

test:
	go test -v

format:
	gofmt -s -w ./

build:
	@printf "$GDetected OS/ARCH: $R$(detected_OS)/$(detected_arch)$D\n"
	CGO_ENABLED=0 GOOS=$(detected_OS) GOARCH=$(detected_arch) go build -v -o kbot -ldflags "-X="github.com/${REGISTRY}/kbot/cmd.appVersion=${VERSION}

image:
	docker build . -t ${REGISTRY}/${APP}:${VERSION}-$(detected_arch)

linux:
	@printf "$GTarget OS/ARCH: $Rlinux/$(detected_arch)$D\n"
	CGO_ENABLED=0 GOOS=linux GOARCH=$(detected_arch) go build -v -o kbot -ldflags "-X="github.com/${REGISTRY}/kbot/cmd.appVersion=${VERSION}
	docker build name=linux -t ${REGISTRY}/${APP}:${VERSION}-linux-$(detected_arch) .

windows:
	@printf "$GTarget OS/ARCH: $Rwindows/$(detected_arch)$D\n"
	CGO_ENABLED=0 GOOS=windows GOARCH=$(detected_arch) go build -v -o kbot -ldflags "-X="github.com/${REGISTRY}/kbot/cmd.appVersion=${VERSION}
	docker build name=windows -t ${REGISTRY}/${APP}:${VERSION}-windows-$(detected_arch) .

darwin:
	@printf "$GTarget OS/ARCH: $Rdarwin/$(detected_arch)$D\n"
	CGO_ENABLED=0 GOOS=darwin GOARCH=$(detected_arch) go build -v -o kbot -ldflags "-X="github.com/${REGISTRY}/kbot/cmd.appVersion=${VERSION}
	docker build name=darwin -t ${REGISTRY}/${APP}:${VERSION}-darwin-$(detected_arch) .

arm:
	@printf "$GTarget OS/ARCH: $R$(detected_OS)/arm$D\n"
	CGO_ENABLED=0 GOOS=$(detected_OS) GOARCH=arm go build -v -o kbot -ldflags "-X="github.com/${REGISTRY}/kbot/cmd.appVersion=${VERSION}
	docker build name=arm -t ${REGISTRY}/${APP}:${VERSION}-$(detected_OS)-arm .

push:
	docker push ${REGISTRY}/${APP}:${VERSION}-$(detected_arch)

dive: image
	IMG1=$$(docker images -q | head -n 1); \
	CI=true docker run -ti --rm -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive --ci --lowestEfficiency=0.99 $${IMG1}; \
	IMG2=$$(docker images -q | sed -n 2p); \
	docker rmi $${IMG1}; \
	docker rmi $${IMG2}

clean:
	@rm -rf kbot; \
	IMG1=$$(docker images -q | head -n 1); \
	if [ -n "$${IMG1}" ]; then  docker rmi -f $${IMG1}; else printf "$RImage not found$D\n"; fi