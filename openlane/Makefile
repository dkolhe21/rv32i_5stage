# Custom Makefile for OpenLane Physical Design

export OPENLANE_RUN_TAG = $(shell date '+%y_%m_%d_%H_%M')
OPENLANE_TAG ?= 2023.07.19-1
OPENLANE_IMAGE_NAME ?= efabless/openlane:$(OPENLANE_TAG)

designs = $(shell find * -maxdepth 0 -type d)

ROOTLESS ?= 0
USER_ARGS = -u $$(id -u $$USER):$$(id -g $$USER)
ifeq ($(ROOTLESS), 1)
	USER_ARGS =
endif

docker_mounts = \
	-v $$(realpath $(PWD)/..):$$(realpath $(PWD)/..) \
	-v $(PDK_ROOT):$(PDK_ROOT) \
	-v $(OPENLANE_ROOT):/openlane

docker_env = \
	-e PDK_ROOT=$(PDK_ROOT) \
	-e PDK=$(PDK) \
	-e OPENLANE_RUN_TAG=$(OPENLANE_RUN_TAG)

docker_startup_mode = $(shell test -t 0 && echo "-it" || echo "--rm" )
docker_run = \
	docker run $(docker_startup_mode) \
	$(USER_ARGS) \
	$(docker_mounts) \
	$(docker_env)

.PHONY: $(designs)
$(designs) : % : ./%/config.tcl
	mkdir -p ./$*/runs/$(OPENLANE_RUN_TAG) 
	rm -rf ./$*/runs/$*
	ln -s $$(realpath ./$*/runs/$(OPENLANE_RUN_TAG)) ./$*/runs/$*
	$(docker_run) \
		$(OPENLANE_IMAGE_NAME) sh -c "flow.tcl -design $$(realpath ./$*) -save_path $$(realpath ..) -save -tag $(OPENLANE_RUN_TAG) -overwrite"
	@mkdir -p ../signoff/$*/
	@cp ./$*/runs/$*/OPENLANE_VERSION ../signoff/$*/ 2>/dev/null || true
	@cp ./$*/runs/$*/PDK_SOURCES ../signoff/$*/ 2>/dev/null || true
	@cp ./$*/runs/$*/reports/*.csv ../signoff/$*/ 2>/dev/null || true

list:
	@echo $(designs)
