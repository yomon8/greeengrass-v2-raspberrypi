#############################################
# Parameters
#############################################
DEVICE_NAME := my-ggv2-device
AWS_PROFILE ?= default
AWS_REGION ?= ap-northeast-1
GREENGRASS_VERSION := 2.9.3
COMPONENT_NAME := com.example.greengrassv2
COMPONENT_VERSION := 1.0.0
TARGET_IOT_TOPIC := $(COMPONENT_NAME)/topic
S3_BUCKET :=
DEVICE_IP :=

#############################################
# Constants
#############################################
CONFIG_DIR := greengrass-config

#############################################
# Terraform
#############################################
TF_VERSION := 1.3.7
TF_DIR := terraform
TF_CMD := docker run -it --rm \
    -v ${HOME}/.aws:/root/.aws:ro \
    -v ${PWD}:/work \
    -w /work \
    hashicorp/terraform:$(TF_VERSION)

TF_STATE_PREFIX ?= tfstate
TF_BACKEND_ARGS := -backend-config "bucket=$(S3_BUCKET)" \
					-backend-config "profile=$(AWS_PROFILE)" \
					-backend-config "region=$(AWS_REGION)" \
					-backend-config "key=$(TF_STATE_PREFIX)/$(DEVICE_NAME).tfstate"
TF_ARGS := -var "device_name=$(DEVICE_NAME)" \
			-var "region=$(AWS_REGION)" \
			-var "profile=$(AWS_PROFILE)" \
			-var "bucket=$(S3_BUCKET)" \
			-var "config_dir=$(CONFIG_DIR)" \
			-var "component_name=$(COMPONENT_NAME)" \
			-var "component_version=$(COMPONENT_VERSION)" \
			-var "target_iot_topic=$(TARGET_IOT_TOPIC)" \
			-var "greengrass_version=$(GREENGRASS_VERSION)"

.PHONY: tf-init
tf-init: 
ifndef S3_BUCKET
	$(error S3_BUCKET is not set)
endif
	$(TF_CMD) -chdir=$(TF_DIR) init -reconfigure $(TF_BACKEND_ARGS) $(TF_ARGS) 

.PHONY: tf-apply
tf-apply: tf-init
	$(TF_CMD) -chdir=$(TF_DIR) apply $(TF_ARGS) 

.PHONY: tf-destroy
tf-destroy: tf-init
	$(TF_CMD) -chdir=$(TF_DIR) destroy $(TF_ARGS) 

#############################################
# Ansible
#############################################
ANSIBLE_VERSION := 7.2.0
ANSIBLE_DOCKER_DIR := ansible/docker
ANSIBLE_IMAGE := $(DEVICE_NAME)-ansible
ANSIBLE_CONFIG ?= ansible.cfg
ANSIBLE_DIR ?= ${PWD}/ansible
ANSIBLE_PLAYBOOK := greengrassv2.yml

.PHONY: ansible-build
ansible-build:
	DOCKER_BUILDKIT=1 docker build \
	--build-arg ANSIBLE_VERSION=${ANSIBLE_VERSION} \
	-t ${ANSIBLE_IMAGE} ${ANSIBLE_DOCKER_DIR}

.PHONY: ansible-run
ansible-apply: ansible-build
ifndef DEVICE_IP
	$(error DEVICE_IP is not set)
endif
	docker run -it --rm -v $(ANSIBLE_DIR):/ansible \
		-w /ansible \
		-v ${PWD}/$(CONFIG_DIR):/ansible/roles/greengrass-settings/files \
		-v ${HOME}/.ssh:/root/.ssh:ro \
		-e ANSIBLE_CONFIG=${ANSIBLE_CONFIG} \
		${ANSIBLE_IMAGE} -i ${DEVICE_IP}, ${ANSIBLE_PLAYBOOK} \
		-e aws_region=$(AWS_REGION)

#############################################
# Greengrass
#############################################

COMPONENT_DIR := $(CONFIG_DIR)/component
RECIPE_DIR := $(COMPONENT_DIR)/recipe

.PHONY: greengrass-component
greengrass-component:
	aws greengrassv2 --profile $(AWS_PROFILE) --region $(AWS_REGION) \
		create-component-version \
		--inline-recipe fileb://./$(RECIPE_DIR)/$(COMPONENT_NAME)_$(COMPONENT_VERSION).yaml

.PHONY: greengrass-component-delete
greengrass-component-delete:
	$(eval account_id := `aws sts get-caller-identity --profile $(AWS_PROFILE) --query 'Account' --output text`)
	aws greengrassv2 --profile $(AWS_PROFILE) --region $(AWS_REGION) \
		delete-component \
		--arn arn:aws:greengrass:$(AWS_REGION):$(account_id):components:$(COMPONENT_NAME):versions:$(COMPONENT_VERSION)

.PHONY: greengrass-deploy
greengrass-deploy:
	$(eval account_id := `aws sts get-caller-identity --profile $(AWS_PROFILE) --query 'Account' --output text`)
	aws greengrassv2 --profile $(AWS_PROFILE) --region $(AWS_REGION) \
	create-deployment \
	--target-arn "arn:aws:iot:$(AWS_REGION):$(account_id):thing/$(DEVICE_NAME)" \
	--components file://./${COMPONENT_DIR}/$(COMPONENT_NAME).json