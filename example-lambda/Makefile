PHONY: help
.phony: help

#####################################################################
###   BAMBOO VARIABLES & DEFAULTS
#####################################################################

ifndef AWS_PROFILE
AWS_PROFILE := default
endif

ifdef bamboo_AWS_ACCESS_KEY_ID
export AWS_ACCESS_KEY_ID := $(bamboo_AWS_ACCESS_KEY_ID)
else
export AWS_ACCESS_KEY_ID := $(shell aws configure get aws_access_key_id --profile $(AWS_PROFILE))
export bamboo_AWS_ACCESS_KEY_ID := $(AWS_ACCESS_KEY_ID)
endif

ifdef bamboo_AWS_SECRET_ACCESS_KEY_PASSWORD
export AWS_SECRET_ACCESS_KEY := $(bamboo_AWS_SECRET_ACCESS_KEY_PASSWORD)
else
export AWS_SECRET_ACCESS_KEY := $(shell aws configure get aws_secret_access_key --profile $(AWS_PROFILE))
export bamboo_AWS_SECRET_ACCESS_KEY_PASSWORD := $(AWS_SECRET_ACCESS_KEY)
endif

ifdef bamboo_AWS_SESSION_TOKEN
export AWS_SESSION_TOKEN := $(bamboo_AWS_SESSION_TOKEN)
else
export AWS_SESSION_TOKEN := $(shell aws configure get aws_session_token --profile $(AWS_PROFILE))
export bamboo_AWS_SESSION_TOKEN := $(AWS_SESSION_TOKEN)
endif


#####################################################################
###   DOCKER IMAGES TO USE
#####################################################################

TERRAGRUNT_REPO := krzysztofszyperepam/docker-terragrunt
TERRAGRUNT_FMT_REPO := krzysztofszyperepam/docker-terragrunt-fmt


#####################################################################
###   OTHER VARIABLES
#####################################################################

CURRENT_DIR := $(shell pwd)
CURRENT_DIR_SED := $(shell echo $(CURRENT_DIR) | sed 's|\/|\\/|g')


#####################################################################
###   ACTIONS RUN MANUALLY
#####################################################################

help:
	@echo " "
	@echo " Terragrunt orchestrator"
	@echo " "
	@echo " Usage:                make [DEPLOY_ENVIRONMENT=<account_name>.<environment>] [STACK=<stack>] <action> [AWS_PROFILE=<profile_name>]"
	@echo " "
	@echo " Available options for <action> are:"
	@echo "     validate          Validates templates in all subdirectories"
	@echo "     plan              Runs 'terragrunt plan-all' in all subdirectories"
	@echo "     plan-destroy      Runs 'terragrunt plan-all -destroy' in all subdirectories"
	@echo "     apply             Runs 'terragrunt apply-all' in all subdirectories"
	@echo "     output            Runs 'terragrunt output-all' in all subdirectories"
	@echo "     destroy           Runs 'terragrunt apply-all -destroy' in all subdirectories"
	@echo " "

pre-commit: clean format

check:
	$(MAKE) plan -s STACK=$(STACK)


#####################################################################
###   AUTOMATION ACTIONS
#####################################################################

build: clean set-vars
	$(info ===>   Running build in $(STACK))
	$(MAKE) -s format-check
	$(MAKE) -s set-automation validate STACK=$$sub_env
	$(MAKE) -s clean

deploy: clean set-vars
	$(info ===>   Running deploy in $(STACK))
ifeq ($(IMPORT_RESOURCES),true)
	$(MAKE) -s import STACK=$(STACK)
else
	$(MAKE) -s set-automation refresh STACK=$(STACK)
	$(MAKE) -s set-automation plan STACK=$(STACK)
	$(MAKE) -s set-automation apply STACK=$(STACK)
endif


#####################################################################
###   TERRAGRUNT/TERRAFORM ACTIONS
#####################################################################

plan:
	$(MAKE) -s docker-tg TG_ACTION="plan-all --terragrunt-ignore-dependency-order" \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
		TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)

plan-destroy:
	$(MAKE) -s docker-tg TG_ACTION="plan-all -destroy" \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
        TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)

apply:
	$(MAKE) -s docker-tg TG_ACTION="apply-all" \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
		TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)

destroy:
	$(MAKE) -s docker-tg TG_ACTION="destroy-all" \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
		TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)

refresh:
	$(MAKE) -s docker-tg TG_ACTION=refresh \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
		TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)

output:
	$(MAKE) -s docker-tg TG_ACTION=output-all \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
		TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)

validate:
	$(MAKE) -s docker-tg TG_ACTION=validate-all \
		TF_IN_AUTOMATION=$(TF_IN_AUTOMATION) \
		TG_NON_INTERACTIVE=$(TG_NON_INTERACTIVE)


#####################################################################
###   MAIN ACTIONS
#####################################################################

set-automation:
	$(eval TF_IN_AUTOMATION = true)
	$(eval TG_NON_INTERACTIVE = --terragrunt-non-interactive)

set-env:
	@echo "STACK=$(STACK)" > .env.list
	@echo "DOCKER_DIR=$(DOCKER_DIR)" >> .env.list
	@echo "TF_VAR_docker_dir=$(DOCKER_DIR)" >> .env.list
	@env | grep -e "^bamboo_" >> .env.list || true
ifneq ($(TF_IN_AUTOMATION),)
	@echo TF_IN_AUTOMATION="$(TF_IN_AUTOMATION)" >> .env.list
endif
ifneq ($(TG_NON_INTERACTIVE),)
	@echo TG_NON_INTERACTIVE="$(TG_NON_INTERACTIVE)" >> .env.list
endif

set-docker-dir:
ifeq ($(shell grep -E "(Microsoft|WSL)" /proc/version),)
	$(eval DOCKER_DIR = $(shell pwd))
	$(info ===>   Detected non-Windows system. Setting DOCKER_DIR to: $(DOCKER_DIR))
else
	$(eval MOUNT_DIR = $(shell df | grep 'C:' | awk '{print $$6}' | sed 's|\/|\\/|g'))
	$(eval DOCKER_DIR = $(shell echo $(shell pwd) | sed 's|$(MOUNT_DIR)|C:|'))
	$(info ===>   Detected Windows system. Setting DOCKER_DIR to: $(DOCKER_DIR))
endif

set-vars:
	$(eval COMMON_VARS = TF_VAR_tg_dir="$(CURRENT_DIR)")
	$(eval GLOBAL_VARS = $(shell python utils/hcl-to-env-vars/hcl-to-env-vars.py variables/global))
#	$(eval ACCOUNT_VARS = $(shell python utils/hcl-to-env-vars/hcl-to-env-vars.py variables/$(ACCOUNT_SHORT)))
#	$(eval ENVIRONMENT_VARS = $(shell python utils/hcl-to-env-vars/hcl-to-env-vars.py variables/$(ACCOUNT_SHORT)-$(ENVIRONMENT)))
	$(eval SET_VARS = export $(COMMON_VARS) $(GLOBAL_VARS) $(ACCOUNT_VARS) $(ENVIRONMENT_VARS))
ifneq ($(TF_IN_AUTOMATION),)
	@$(SET_VARS) && echo "===>   Setting Terraform/Terragrunt variables:" && printenv | grep -e "^TF_" -e "^TG_" -e "^STACK" -e "^DOCKER"| sort
else
	@$(SET_VARS)
endif

format:
	$(info ===>   Formatting HCL files)
	$(MAKE) -s docker-fmt-run FMT_COMMAND="-recursive -write=true; terraform fmt -recursive -write=true"

format-check:
	$(info ===>   Listing HCL files to improve)
	$(MAKE) -s docker-fmt-run FMT_COMMAND="-recursive -write=false -list=true; terraform fmt -recursive -write=false -list=true"

clean:
	$(info ===>   Cleaning Terragrunt cache directories)
	@find . -type d -name ".terragrunt-cache" | xargs rm -rf
	@find . -type d -name "dist" | xargs rm -rf
	@find . -type f -name ".env.list" | xargs rm -f


#####################################################################
###   DOCKERIZED ACTIONS
#####################################################################

docker-tg: clean set-docker-dir set-env
ifeq ($(TG_ACTION),)
	$(error Terragrunt action not specified. Use for example: make check)
else
	$(eval TG_COMMAND = terragrunt $(TG_ACTION) --terragrunt-working-dir $(STACK) $(TG_NON_INTERACTIVE))
	docker run --rm \
		--env-file ./.env.list \
		--volume $(DOCKER_DIR):/data \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--interactive \
		--tty \
    	$(TERRAGRUNT_REPO) \
    	make docker-tg-run TG_COMMAND="$(TG_COMMAND)"
endif

docker-tg-run: set-vars
ifeq ($(TG_COMMAND),)
	$(error Command to run not specified. To adjust automatically use for example: make check)
else
	$(info ===>   Running: $(TG_COMMAND))
	terraform --version && terragrunt --version && $(SET_VARS) && $(TG_COMMAND) && make -s clean
endif

docker-fmt-run: set-docker-dir
ifeq ($(FMT_COMMAND),)
	$(error Format action not specified. Use for example: make format-check)
else
	$(info ===>   Running: $(FMT_COMMAND))
	docker run --rm \
    		--volume $(DOCKER_DIR):/data \
    		$(TERRAGRUNT_FMT_REPO) \
    		$(FMT_COMMAND)
endif