#!/usr/bin/env bash
[[ "$TRACE" ]] && set -x
set -eu -o pipefail

AWS_REGION=us-east-1
AWS_ACCOUNT_ID=
ENVIRONMENT=dev


# `terraform plan` does this
#pushd terraform
#terraform validate
#popd


pushd terraform
# fails if terraform/terraform.tfvars is missing
mkdir -p build
terraform plan -out build/${ENVIRONMENT}.out
popd


echo "Proceed? [yes/no]"
read -r proceed
if [[ "$proceed" != "yes" ]]
then
  exit 0
fi


# provision ECR repo for docker image
pushd terraform
DOCKER_IMAGE=$(terraform apply -auto-approve -target aws_ecr_repository.app |grep "ecr_repository_url" |awk '{print $3}' |tr -d \")
popd


# build + publish image
pushd app
sudo docker build --tag "${DOCKER_IMAGE}:${ENVIRONMENT}" --file Dockerfile.lambda .

aws ecr get-login-password \
  --region ${AWS_REGION} \
| sudo docker login \
  --username AWS \
  --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

sudo docker push "${DOCKER_IMAGE}:${ENVIRONMENT}"
popd


# provision all infra
pushd terraform
terraform apply -auto-approve build/${ENVIRONMENT}.out | grep app_backend_api_gateway_endpoint
popd
