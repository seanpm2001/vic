# Copyright 2016-2017 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL=/bin/bash

GO ?= go
GOVERSION ?= go1.8
OS := $(shell uname | awk '{print tolower($$0)}')
ifeq (vagrant, $(filter vagrant,$(USER) $(SUDO_USER)))
	# assuming we are in a shared directory where host arch is different from the guest
	BIN_ARCH := -$(OS)
endif
REV :=$(shell git rev-parse --short=8 HEAD)

BASE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BASE_PKG := github.com/vmware/vic/

BIN ?= bin
IGNORE := $(shell mkdir -p $(BIN))

export GOPATH ?= $(shell echo $(CURDIR) | sed -e 's,/src/.*,,')
SWAGGER ?= $(GOPATH)/bin/swagger$(BIN_ARCH)
GOIMPORTS ?= $(GOPATH)/bin/goimports$(BIN_ARCH)
GOLINT ?= $(GOPATH)/bin/golint$(BIN_ARCH)
GVT ?= $(GOPATH)/bin/gvt$(BIN_ARCH)
GOVC ?= $(GOPATH)/bin/govc$(BIN_ARCH)
GAS ?= $(GOPATH)/bin/gas$(BIN_ARCH)
MISSPELL ?= $(GOPATH)/bin/misspell$(BIN_ARCH)
DOCKER_BUILD := $(BASE_DIR)/infra/build-image/docker-iso-build.sh

.PHONY: all tools clean test check distro \
	goversion goimports gopath govet gofmt misspell gas golint \
	isos tethers apiservers copyright

.DEFAULT_GOAL := all

# allow deferred godeps calls
.SECONDEXPANSION:

include infra/util/gsml/gmsl

ifeq ($(ENABLE_RACE_DETECTOR),true)
	RACE := -race
else
	RACE :=
endif

# Generate Go package dependency set, skipping if the only targets specified are clean and/or distclean
# Caches dependencies to speed repeated calls
define godeps
	$(call assert,$(call gmsl_compatible,1 1 7), Wrong GMSL version) \
	$(if $(filter-out push push-portlayer push-docker push-vic-init push-vicadmin focused-test test check clean distclean mrrobot mark sincemark local-ci-test .DEFAULT,$(MAKECMDGOALS)), \
		$(if $(call defined,dep_cache,$(dir $1)),,$(info Generating dependency set for $(dir $1))) \
		$(or \
			$(if $(call defined,dep_cache,$(dir $1)), $(debug Using cached Go dependencies) $(wildcard $1) $(call get,dep_cache,$(dir $1))),
			$(call set,dep_cache,$(dir $1),$(shell $(BASE_DIR)/infra/scripts/go-deps.sh $(dir $1) $(MAKEFLAGS))),
			$(debug Cached Go dependency for $(dir $1): $(call get,dep_cache,$(dir $1))),
			$(wildcard $1) $(call get,dep_cache,$(dir $1))
		) \
	)
endef

ifeq ($(DISABLE_DEPENDENCY_TRACKING), true)
define godeps
endef
endif

LDFLAGS := $(shell BUILD_NUMBER=${BUILD_NUMBER} $(BASE_DIR)/infra/scripts/version-linker-flags.sh)

# target aliases - environment variable definition
docker-engine-api := $(BIN)/docker-engine-server
docker-engine-api-test := $(BIN)/docker-engine-server-test
admiralapi-client := lib/config/dynamic/admiral/client/admiral_client.go
portlayerapi := $(BIN)/port-layer-server
portlayerapi-test := $(BIN)/port-layer-server-test
portlayerapi-client := lib/apiservers/portlayer/client/port_layer_client.go
portlayerapi-server := lib/apiservers/portlayer/restapi/server.go
serviceapi := $(BIN)/vic-machine-server
serviceapi-server := lib/apiservers/service/restapi/server.go

imagec := $(BIN)/imagec
vicadmin := $(BIN)/vicadmin
rpctool := $(BIN)/rpctool
vic-machine-linux := $(BIN)/vic-machine-linux
vic-machine-windows := $(BIN)/vic-machine-windows.exe
vic-machine-darwin := $(BIN)/vic-machine-darwin
vic-init := $(BIN)/vic-init
vic-init-test := $(BIN)/vic-init-test
# NOT BUILT WITH make all TARGET
# vic-dns variants to create standalone DNS service.
vic-dns-linux := $(BIN)/vic-dns-linux
vic-dns-windows := $(BIN)/vic-dns-windows.exe
vic-dns-darwin := $(BIN)/vic-dns-darwin
archive := $(BIN)/unpack
gandalf := $(BIN)/gandalf

tether-linux := $(BIN)/tether-linux

appliance := $(BIN)/appliance.iso
appliance-staging := $(BIN)/.appliance-staging.tgz
bootstrap := $(BIN)/bootstrap.iso
bootstrap-custom := $(BIN)/bootstrap-$(REPO).iso
bootstrap-staging := $(BIN)/.bootstrap-staging.tgz
bootstrap-staging-custom := $(BIN)/.bootstrap-staging-$(REPO).tgz
iso-base := $(BIN)/.iso-base-photon-2.0.tgz
iso-base-custom := $(BIN)/.iso-base-$(REPO).tgz

# target aliases - target mapping
docker-engine-api: $(docker-engine-api)
docker-engine-api-test: $(docker-engine-api-test)
portlayerapi: $(portlayerapi)
portlayerapi-test: $(portlayerapi-test)
portlayerapi-client: $(portlayerapi-client)
portlayerapi-server: $(portlayerapi-server)
serviceapi: $(serviceapi)
serviceapi-server: $(serviceapi-server)
admiralapi-client: $(admiralapi-client)

imagec: $(imagec)
vicadmin: $(vicadmin)
rpctool: $(rpctool)
vic-init: $(vic-init)
vic-init-test: $(vic-init-test)

tether-linux: $(tether-linux)

appliance: $(appliance)
appliance-staging: $(appliance-staging)
bootstrap: $(bootstrap)
bootstrap-custom: $(bootstrap-custom)
bootstrap-staging: $(bootstrap-staging)
bootstrap-staging-custom: $(bootstrap-staging-custom)
iso-base: $(iso-base)
iso-base-custom: $(iso-base-custom)

vic-machine: $(vic-machine-linux) $(vic-machine-windows) $(vic-machine-darwin)
vic-machine-linux: $(vic-machine-linux)
vic-machine-windows: $(vic-machine-windows)
vic-machine-darwin: $(vic-machine-darwin)

# NOT BUILT WITH make all TARGET
# vic-dns variants to create standalone DNS service.
vic-dns: $(vic-dns-linux) $(vic-dns-windows) $(vic-dns-darwin)
gandalf: $(gandalf)

swagger: $(SWAGGER)
goimports: $(GOIMPORTS)
gas: $(GAS)
misspell: $(MISSPELL)

# convenience targets
all: components tethers isos vic-machine imagec
tools: $(GOIMPORTS) $(GVT) $(GOLINT) $(SWAGGER) $(GAS) $(MISSPELL) goversion
check: goversion goimports gofmt misspell govet golint copyright whitespace gas
apiservers: $(portlayerapi) $(docker-engine-api) $(serviceapi)
components: check apiservers $(vicadmin) $(rpctool)
isos: $(appliance) $(bootstrap)
tethers: $(tether-linux)

most: $(portlayerapi) $(docker-engine-api) $(vicadmin) $(tether-linux) $(appliance) $(bootstrap) $(vic-machine-linux) $(serviceapi)

# utility targets
goversion:
	@echo checking go version...
	@( $(GO) version | grep -q $(GOVERSION) ) || ( echo "Please install $(GOVERSION) (found: $$($(GO) version))" && exit 1 )

$(GOIMPORTS): vendor/manifest
	@echo building $(GOIMPORTS)...
	@$(GO) build $(RACE) -o $(GOIMPORTS) ./vendor/golang.org/x/tools/cmd/goimports

$(GVT): vendor/manifest
	@echo building $(GVT)...
	@$(GO) build $(RACE) -o $(GVT) ./vendor/github.com/FiloSottile/gvt

$(GOLINT): vendor/manifest
	@echo building $(GOLINT)...
	@$(GO) build $(RACE) -o $(GOLINT) ./vendor/github.com/golang/lint/golint

$(SWAGGER): vendor/manifest
	@echo building $(SWAGGER)...
	@$(GO) build $(RACE) -o $(SWAGGER) ./vendor/github.com/go-swagger/go-swagger/cmd/swagger

$(GOVC): vendor/manifest
	@echo building $(GOVC)...
	@$(GO) build $(RACE) -o $(GOVC) ./vendor/github.com/vmware/govmomi/govc

$(GAS): vendor/manifest
	@echo building $(GAS)...
	@echo "Skip..."

$(MISSPELL): vendor/manifest
	@echo building $(MISSPELL)...
	@$(GO) build $(RACE) -o $(MISSPELL) ./vendor/github.com/client9/misspell/cmd/misspell

copyright:
	@echo "checking copyright in header..."
	@infra/scripts/header-check.sh

whitespace:
	@echo "checking whitespace..."
	@infra/scripts/whitespace-check.sh

# exit 1 if golint complains about anything other than comments
golintf = $(GOLINT) $(1) | sh -c "! grep -v 'lib/apiservers/portlayer/restapi/operations'" | sh -c "! grep -v 'lib/config/dynamic/admiral/client'" | sh -c "! grep -v 'should have comment'" | sh -c "! grep -v 'comment on exported'" | sh -c "! grep -v 'by other packages, and that stutters'" | sh -c "! grep -v 'error strings should not be capitalized'"

golint: $(GOLINT)
	@echo checking go lint...
	@$(call golintf,github.com/vmware/vic/cmd/...)
	@$(call golintf,github.com/vmware/vic/pkg/...)
	@$(call golintf,github.com/vmware/vic/lib/...)

# For use by external tools such as emacs or for example:
# GOPATH=$(make gopath) go get ...
gopath:
	@echo -n $(GOPATH)

goimports: $(GOIMPORTS)
	@echo checking go imports...
	@! if test -e swagger-gen.log; then $(GOIMPORTS) -local github.com/vmware -d $$(\
		 comm -23 <(find . -type f -name '*.go' -not -path "./vendor/*" | sort) \
		          <(grep creating swagger-gen.log | awk '{print $$6 $$4};' | sed -e "s-\"\(.*\)\"-\./\1-g" | sed "s-\"\"-/-g" | sort)) \
		 | egrep -v '^$$'; else $(GOIMPORTS) -local github.com/vmware -d $$(find . -type f -name '*.go' -not -path "./vendor/*") | egrep -v "^$$"; fi

gofmt:
	@echo checking gofmt...
	@! gofmt -d -e -s $$(find . -mindepth 1 -maxdepth 1 -type d -not -name vendor) 2>&1 | egrep -v '^$$'

misspell: $(MISSPELL)
	@echo checking misspell...
	@infra/scripts/misspell.sh

govet:
	@echo checking go vet...
# 	one day we will enable shadow check
# 	@$(GO) tool vet -all -shadow -lostcancel -tests $$(find . -mindepth 1 -maxdepth 1 -type d -not -name vendor)

gas: $(GAS)
	@echo checking security problems

vendor: $(GVT)
	@echo restoring vendor
	$(GVT) restore

TEST_DIRS=github.com/vmware/vic/cmd
TEST_DIRS+=github.com/vmware/vic/lib
TEST_DIRS+=github.com/vmware/vic/pkg

TEST_JOBS := $(addprefix test-job-,$(TEST_DIRS))

# since drone cannot tell us how log it took
mark:
	@echo touching /started to mark beginning of the time
	@touch /started
sincemark:
	@echo seconds passed since we start
	@stat -c %Y /started | echo `expr $$(date +%s) - $$(cat)`

install-govmomi:
# manually install govmomi so the huge types package doesn't break cover
	$(GO) install ./vendor/github.com/vmware/govmomi

test: install-govmomi $(portlayerapi-client) $(portlayerapi-server) $(serviceapi-server) $(admiralapi-client) $(TEST_JOBS)

push:
	$(BASE_DIR)/infra/scripts/replace-running-components.sh

push-portlayer:
	$(BASE_DIR)/infra/scripts/replace-running-components.sh port-layer-server

push-docker:
	$(BASE_DIR)/infra/scripts/replace-running-components.sh docker-engine-server

push-vic-init:
	$(BASE_DIR)/infra/scripts/replace-running-components.sh vic-init

push-vicadmin:
	$(BASE_DIR)/infra/scripts/replace-running-components.sh vicadmin

local-ci-test:
	@echo running CI tests locally...
	infra/scripts/local-ci.sh

focused-test:
# test only those packages that have changes
	infra/scripts/focused-test.sh $(REMOTE)

$(TEST_JOBS): test-job-%:
	@echo Running unit tests
	# test everything but vendor
ifdef DRONE
	@echo Generating coverage data
	@$(TIME) infra/scripts/coverage.sh $*
else
	@echo Generating local html coverage report
	@$(TIME) infra/scripts/coverage.sh --html $*
endif

$(vic-init): $$(call godeps,cmd/vic-init/*.go)
	@echo building vic-init
	@CGO_ENABLED=1 GOOS=linux GOARCH=amd64 $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -tags netgo -installsuffix netgo -o ./$@ ./$(dir $<)

$(vic-init-test): $$(call godeps,cmd/vic-init/*.go)
	@echo building vic-init-test
	@CGO_ENABLED=1 GOOS=linux GOARCH=amd64 $(GO) test -c -coverpkg github.com/vmware/vic/lib/...,github.com/vmware/vic/pkg/... -outputdir /tmp -coverprofile init.cov -o ./$@ ./$(dir $<)

$(tether-linux): $$(call godeps,cmd/tether/*.go)
	@echo building tether-linux
	@CGO_ENABLED=1 GOOS=linux GOARCH=amd64 $(TIME) $(GO) build $(RACE) -tags netgo -installsuffix netgo -ldflags '$(LDFLAGS) -extldflags "-static"' -o ./$@ ./$(dir $<)

$(rpctool): $$(call godeps,cmd/rpctool/*.go)
ifeq ($(OS),linux)
	@echo building rpctool
	@GOARCH=amd64 GOOS=linux $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)
else
	@echo skipping rpctool, cannot cross compile cgo
endif

$(vicadmin): $$(call godeps,cmd/vicadmin/*.go)
	@echo building vicadmin
	@GOARCH=amd64 GOOS=linux $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(archive): $$(call godeps,cmd/archive/*.go)
	@echo building archive
	@GOARCH=amd64 GOOS=linux CGO_ENABLED=0 $(TIME) $(GO) build $(RACE) -a -ldflags '-extldflags "-static"' -o ./$@ ./$(dir $<)

$(imagec): $(call godeps,cmd/imagec/*.go) $(portlayerapi-client)
	@echo building imagec...
	@$(TIME) $(GO) build $(RACE)  $(ldflags) -o ./$@ ./$(dir $<)

$(docker-engine-api): $(portlayerapi-client) $(admiralapi-client) $$(call godeps,cmd/docker/*.go)
ifeq ($(OS),linux)
	@echo building docker-engine-api server...
	@$(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o $@ ./cmd/docker
else
	@echo skipping docker-engine-api server, cannot build on non-linux
endif

$(docker-engine-api-test): $$(call godeps,cmd/docker/*.go) $(portlayerapi-client)
ifeq ($(OS),linux)
	@echo building docker-engine-api server for test...
	@$(TIME) $(GO) test -c -coverpkg github.com/vmware/vic/lib/...,github.com/vmware/vic/pkg/... -outputdir /tmp -coverprofile docker-engine-api.cov -o $@ ./cmd/docker
else
	@echo skipping docker-engine-api server for test, cannot build on non-linux
endif


# Common portlayer dependencies between client and server
PORTLAYER_DEPS ?= lib/apiservers/portlayer/swagger.json \
				  lib/apiservers/portlayer/restapi/configure_port_layer.go \
				  lib/apiservers/portlayer/restapi/options/*.go

$(admiralapi-client): lib/config/dynamic/admiral/swagger.json $(SWAGGER)
	@echo regenerating swagger models and operations for Admiral API client...
	@$(SWAGGER) generate client -A Admiral --target lib/config/dynamic/admiral \
	    -f lib/config/dynamic/admiral/swagger.json \
	    --tags /projects \
	    --tags /resources/compute \
	    --tags /config/registries \
	    -O GetResourcesCompute \
	    -O GetProjects \
	    -O GetConfigRegistriesID \
	    -M "com:vmware:photon:controller:model:resources:ComputeService:ComputeState" \
	    -M "com:vmware:xenon:common:ServiceDocumentQueryResult" \
	    -M "com:vmware:admiral:service:common:RegistryService:RegistryState" \
	    -M "com:vmware:xenon:common:ServiceDocumentQueryResult:ContinuousResult" \
	    -M "com:vmware:xenon:common:ServiceErrorResponse" \
	    2>>swagger-gen.log
	@echo done regenerating swagger models and operations for Admiral API client...

$(portlayerapi-client): $(PORTLAYER_DEPS) $(SWAGGER)
	@echo regenerating swagger models and operations for Portlayer API client...
	@$(SWAGGER) generate client -A PortLayer --target lib/apiservers/portlayer -f lib/apiservers/portlayer/swagger.json 2>>swagger-gen.log
	@echo done regenerating swagger models and operations for Portlayer API client...

$(portlayerapi-server): $(PORTLAYER_DEPS) $(SWAGGER)
	@echo regenerating swagger models and operations for Portlayer API server...
	@$(SWAGGER) generate server --exclude-main -A PortLayer --target lib/apiservers/portlayer -f lib/apiservers/portlayer/swagger.json 2>>swagger-gen.log
	@echo done regenerating swagger models and operations for Portlayer API server...

$(portlayerapi): $(portlayerapi-server) $(portlayerapi-client) $$(call godeps,cmd/port-layer-server/*.go)
	@echo building Portlayer API server...
	@$(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o $@ ./cmd/port-layer-server

$(portlayerapi-test): $$(call godeps,cmd/port-layer-server/*.go) $(portlayerapi-server) $(portlayerapi-client)
	@echo building Portlayer API server for test...
	@$(TIME) $(GO) test -c -coverpkg github.com/vmware/vic/lib/...,github.com/vmware/vic/pkg/... -coverprofile port-layer-server.cov -outputdir /tmp -o $@ ./cmd/port-layer-server

# Common service dependencies between client and server
SERVICE_DEPS ?= lib/apiservers/service/swagger.json \
				  lib/apiservers/service/restapi/configure_vic_machine.go \
				  lib/apiservers/service/restapi/handlers/*.go

$(serviceapi-server): $(SERVICE_DEPS) $(SWAGGER)
	@echo regenerating swagger models and operations for vic-machine-as-a-service API server...
	@$(SWAGGER) generate server --exclude-main --target lib/apiservers/service -f lib/apiservers/service/swagger.json 2>>service-swagger-gen.log
	@echo done regenerating swagger models and operations for vic-machine-as-a-service API server...

$(serviceapi): $$(call godeps,cmd/vic-machine-server/*.go) $(serviceapi-server)
	@echo building vic-machine-as-a-service API server...
	@$(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o $@ ./cmd/vic-machine-server


# ISO Targets
$(iso-base): isos/base.sh isos/base/repos/photon-2.0/*.repo isos/base/isolinux/** isos/base/xorriso-options.cfg
	@echo "building iso-base image (photon-2.0)"
	@$(TIME) $(DOCKER_BUILD) $< -r photon-2.0 -c $(BIN)/.yum-cache-photon-2.0.tgz -p $@

$(iso-base-custom): isos/base.sh isos/base/repos/$(REPO)/*.repo isos/base/isolinux/** isos/base/xorriso-options.cfg
	@echo "building custom iso-base image ($(REPO))"
	@$(TIME) $(DOCKER_BUILD) -d $(REPO) $< -r $(REPO) -c $(BIN)/.yum-cache-$(REPO).tgz -p $@

# main appliance target - depends on all top level component targets
$(appliance): isos/appliance.sh isos/appliance/* isos/vicadmin/** $(appliance-staging) $(vicadmin) $(vic-init) $(portlayerapi) $(docker-engine-api) $(archive)
	@echo building VCH appliance ISO
	@$(TIME) $(DOCKER_BUILD) $< -p $(appliance-staging) -b $(BIN)

# appliance staging - allows for caching of package install
$(appliance-staging): isos/appliance-staging.sh $(iso-base)
	@echo staging for VCH appliance
	@$(TIME) $(DOCKER_BUILD) $< -c $(BIN)/.yum-cache-photon-2.0.tgz -p $(iso-base) -o $@

# main bootstrap target
$(bootstrap): isos/bootstrap.sh $(tether-linux) $(archive) $(bootstrap-staging) isos/bootstrap/*
	@echo "Making bootstrap iso"
	@$(TIME) $(DOCKER_BUILD) $< -p $(bootstrap-staging) -b $(BIN)

# uses iso-base-custom to allow for custom kernels
$(bootstrap-custom): isos/bootstrap.sh $(tether-linux) $(archive) $(bootstrap-staging-custom) isos/bootstrap/*
	@echo "Making custom bootstrap iso"
	@$(TIME) $(DOCKER_BUILD) -d $(REPO) $< -p $(bootstrap-staging-custom) -b $(BIN) -o $(notdir $@)

$(bootstrap-staging): isos/bootstrap-staging.sh $(iso-base) isos/base/repos/photon-2.0/*
	@echo staging for bootstrap
	@$(TIME) $(DOCKER_BUILD) $< -c $(BIN)/.yum-cache-photon-2.0.tgz -p $(iso-base) -o $@

$(bootstrap-staging-custom): isos/bootstrap-staging.sh $(iso-base-custom) isos/base/repos/$(REPO)/*
	@echo custom staging for bootstrap
	@$(TIME) $(DOCKER_BUILD) -d $(REPO) $< -c $(BIN)/.yum-cache-$(REPO).tgz -p $(iso-base-custom) -o $@

# vic-machine targets
$(vic-machine-linux): $$(call godeps,cmd/vic-machine/*.go)
	@echo building vic-machine linux...
	@GOARCH=amd64 GOOS=linux $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(vic-machine-windows): $$(call godeps,cmd/vic-machine/*.go)
	@echo building vic-machine windows...
	@GOARCH=amd64 GOOS=windows $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(vic-machine-darwin): $$(call godeps,cmd/vic-machine/*.go)
	@echo building vic-machine darwin...
	@GOARCH=amd64 GOOS=darwin $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(vic-dns-linux): $$(call godeps,cmd/vic-dns/*.go)
	@echo building vic-dns linux...
	@GOARCH=amd64 GOOS=linux $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(vic-dns-windows): $$(call godeps,cmd/vic-dns/*.go)
	@echo building vic-dns windows...
	@GOARCH=amd64 GOOS=windows $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(vic-dns-darwin): $$(call godeps,cmd/vic-dns/*.go)
	@echo building vic-dns darwin...
	@GOARCH=amd64 GOOS=darwin $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

$(gandalf):  $$(call godeps,cmd/gandalf/*.go)
	@echo building gandalf...
	@GOARCH=amd64 GOOS=linux $(TIME) $(GO) build $(RACE) -ldflags "$(LDFLAGS)" -o ./$@ ./$(dir $<)

distro: all
	@tar czvf $(REV).tar.gz bin/*.iso bin/vic-machine-* --exclude=bin/vic-machine-server

mrrobot:
	@rm -rf *.xml *.html *.log *.zip VCH-0-*

clean: cleandeps
	@echo removing binaries
	@rm -rf $(BIN)/*
	@echo removing Go object files
	@$(GO) clean

	@echo removing swagger generated files...
	@rm -f ./lib/apiservers/portlayer/restapi/doc.go
	@rm -f ./lib/apiservers/portlayer/restapi/embedded_spec.go
	@rm -f ./lib/apiservers/portlayer/restapi/server.go
	@rm -rf ./lib/apiservers/portlayer/client/
	@rm -rf ./lib/apiservers/portlayer/cmd/
	@rm -rf ./lib/apiservers/portlayer/models/
	@rm -rf ./lib/apiservers/portlayer/restapi/operations/
	@rm -rf ./lib/config/dynamic/admiral/client
	@rm -rf ./lib/config/dynamic/admiral/models
	@rm -rf ./lib/config/dynamic/admiral/operations

	@rm -f ./lib/apiservers/service/restapi/doc.go
	@rm -f ./lib/apiservers/service/restapi/embedded_spec.go
	@rm -f ./lib/apiservers/service/restapi/server.go
	@rm -rf ./lib/apiservers/service/restapi/cmd/
	@rm -rf ./lib/apiservers/service/restapi/models/
	@rm -rf ./lib/apiservers/service/restapi/operations/

	@rm -f *.log
	@rm -f *.pem

# removes the yum cache as well as the generated binaries
distclean: clean
	@echo removing binaries
	@rm -rf $(BIN)

cleandeps:
	@echo removing dependency cache
	@rm -rf .godeps_cache
