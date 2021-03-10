include ${PWD}/environments/${ENV}.env

VARIABLES =	-var=environment=${ENV} \
			-var=project_name=${PROJECT_NAME} \
			-var=region=${REGION} \
			-var=zone=${ZONE} \
			-var=start_up_script=${START_UP_SCRIPT} \
			-var=service_account=${SERVICE_ACCOUNT} \

all:


up: init plan apply


init:
	terraform init \
    -backend-config=bucket=${PROJECT_NAME}-tfstate \
    -backend-config=prefix="backend" \
    -backend-config=credentials="terraform-sa-key.json"

plan:
	terraform plan ${VARIABLES}

apply:
	terraform apply ${VARIABLES}

destroy:
	terraform destroy ${VARIABLES} \

.PHONY = all init plan apply destroy up down import az_up az_down