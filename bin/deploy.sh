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


cd terraform
# fails if terraform/terraform.tfvars is missing
mkdir -p build
terraform plan -out build/${ENVIRONMENT}.out
cd ..


echo "Proceed? [yes/no]"
read -r proceed
if [[ "$proceed" != "yes" ]]
then
  exit 0
fi


# TODO can we make this work with build/env.out?
# provision ECR repo for docker image
cd terraform
DOCKER_IMAGE=$(terraform apply -auto-approve -target aws_ecr_repository.app |grep "ecr_repository_url" |tail -n 1 |awk '{print $3}' |tr -d '"')
cd ..


# build + publish image
cd app
sudo docker build --tag "${DOCKER_IMAGE}:${ENVIRONMENT}" --file Dockerfile.lambda .

aws ecr get-login-password \
  --region ${AWS_REGION} \
| sudo docker login \
  --username AWS \
  --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

sudo docker push "${DOCKER_IMAGE}:${ENVIRONMENT}"
cd ..


# provision all infra
cd terraform
terraform apply -auto-approve build/${ENVIRONMENT}.out | grep app_backend_api_gateway_endpoint
cd ..
