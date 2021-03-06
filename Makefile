EPOCH_TEST_COMMIT ?= 7fc874e05e74faa81e7c423b6514fc5c474c6b34
PROJECT := github.com/kubernetes-incubator/ocid
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
GIT_BRANCH_CLEAN := $(shell echo $(GIT_BRANCH) | sed -e "s/[^[:alnum:]]/-/g")
OCID_IMAGE := ocid_dev$(if $(GIT_BRANCH_CLEAN),:$(GIT_BRANCH_CLEAN))
OCID_LINK := ${CURDIR}/vendor/src/github.com/kubernetes-incubator/ocid
OCID_LINK_DIR := ${CURDIR}/vendor/src/github.com/kubernetes-incubator
OCID_INSTANCE := ocid_dev
SYSTEM_GOPATH := ${GOPATH}
export GOPATH := ${CURDIR}/vendor

default: help

help:
	@echo "Usage: make <target>"
	@echo
	@echo " * 'binaries' - Build ocid, conmon and ocic"
	@echo " * 'integration' - Execute integration tests"
	@echo " * 'clean' - Clean artifacts"
	@echo " * 'lint' - Execute the source code linter"

lint: ${OCID_LINK}
	@echo "checking lint"
	@./.tool/lint

${OCID_LINK}:
	mkdir -p ${OCID_LINK_DIR}
	ln -sfn ${CURDIR} ${OCID_LINK}

conmon:
	make -C $@

ocid: ${OCID_LINK}
	go build -o ocid ./cmd/server/

ocic: ${OCID_LINK}
	go build -o ocic ./cmd/client/

clean:
	rm -f ocic ocid
	rm -f ${OCID_LINK}
	rm -f conmon/conmon.o conmon/conmon

ocidimage:
	docker build -t ${OCID_IMAGE} .

dbuild: ocidimage
	docker run --name=${OCID_INSTANCE} --privileged ${OCID_IMAGE} make binaries
	docker cp ${OCID_INSTANCE}:/go/src/github.com/kubernetes-incubator/ocid/ocid .
	docker cp ${OCID_INSTANCE}:/go/src/github.com/kubernetes-incubator/ocid/ocic .
	docker cp ${OCID_INSTANCE}:/go/src/github.com/kubernetes-incubator/ocid/conmon/conmon ./conmon/conmon
	docker rm ${OCID_INSTANCE}

integration: ocidimage
	docker run -e TESTFLAGS -t --privileged --rm -v ${CURDIR}:/go/src/${PROJECT} ${OCID_IMAGE} make localintegration

localintegration: binaries
	./test/test_runner.sh ${TESTFLAGS}

binaries: ${OCID_LINK} ocid ocic conmon

.PHONY: .gitvalidation
# When this is running in travis, it will only check the travis commit range
.gitvalidation:
	@which git-validation > /dev/null 2>/dev/null || (echo "ERROR: git-validation not found. Consider 'make install.tools' target" && false)
ifeq ($(TRAVIS),true)
	git-validation -q -run DCO,short-subject
else
	git-validation -v -run DCO,short-subject -range $(EPOCH_TEST_COMMIT)..HEAD
endif

.PHONY: install.tools

install.tools: .install.gitvalidation .install.gometalinter

.install.gitvalidation:
	GOPATH=${SYSTEM_GOPATH} go get github.com/vbatts/git-validation

.install.gometalinter:
	GOPATH=${SYSTEM_GOPATH} go get github.com/alecthomas/gometalinter
	GOPATH=${SYSTEM_GOPATH} gometalinter --install

.PHONY: \
	binaries \
	conmon \
	ocid \
	ocic \
	clean \
	lint
