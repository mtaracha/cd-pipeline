#!/bin/bash

# Login to ECR
eval $(aws ecr get-login --region eu-west-1)

REGISTRY_URL=${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com
JOB_NAME=$(echo ${JOB_NAME} | sed 's/.*\///')

# Functions section
function get_tag()
{
  local JOB_NAME=$1
  local CLUSTER=$2
  echo ${JOB_NAME} ${CLUSTER}
  IF_SERVICE_EXISTS=$(aws ecs describe-services --service ${JOB_NAME} --cluster ${CLUSTER} | jq -r .failures[].reason)
  ECR_IMAGES_COUNT=$(aws ecr list-images --repository-name ${JOB_NAME} --registry-id ${AWS_ACCOUNT_ID} --region eu-west-1 | jq '.[] | length')

  echo "Condition check ${IF_SERVICE_EXISTS} on ${JOB_NAME}"

  # Choose the tag
  if [ "$IF_SERVICE_EXISTS" = "MISSING" ] || [ "$ECR_IMAGES_COUNT" = "0" ]
  then
     # Service doesn't exist so tagging from 1
     BUILD_NUMBER="1"
     VERSION=master.$BUILD_NUMBER
  else
     TAG_NUMBER_CURRENT=$(aws ecs wait services-stable --services ${JOB_NAME} --cluster ${CLUSTER} && aws ecs describe-services --service ${JOB_NAME} \
                          --cluster ${CLUSTER} --region eu-west-1 | jq -r .services[].taskDefinition | sed 's/.*task-definition.*://')
     TAG_NUMBER_NEW=$((TAG_NUMBER_CURRENT+1))
     BUILD_NUMBER=${TAG_NUMBER_NEW}

     # If the service exist choose the tag based on BRANCH
     if [ "$BRANCH" ]
     then
         BRANCH=$(echo $BRANCH | sed 's:/:-:g')
         VERSION=$BRANCH.$TAG_NUMBER_NEW
     else
         VERSION=master.$TAG_NUMBER_NEW
     fi
  fi
}

get_tag ${JOB_NAME} ${CLUSTER} || exit 1
echo "Version: ${VERSION}"
# Used by Inject env plugin for chained builds
echo VERSION=${VERSION} > build.properties
echo JOB_NAME=${JOB_NAME} >> build.properties
# The new tag name to create in the Docker registry
IMAGE_TAG=${VERSION}

# Build Docker image
docker build --no-cache=true --build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -t $REGISTRY_URL/${JOB_NAME} . || exit 1

# Tag the newly built Docker image (latest) with explicit version tag
docker tag $REGISTRY_URL/${JOB_NAME}:latest $REGISTRY_URL/${JOB_NAME}:$IMAGE_TAG || exit 1
docker tag $REGISTRY_URL/${JOB_NAME}:latest $REGISTRY_URL/${JOB_NAME}:$ENV-latest || exit 1

# Push both tags to the registry
docker push $REGISTRY_URL/${JOB_NAME} && echo "${JOB_NAME}:$IMAGE_TAG was successfully uploaded to ECR" || exit 1

# Remove the version tagged image and just leave the 'latest'.
# This helps avoid many old tags piling up.
docker rmi $REGISTRY_URL/${JOB_NAME}:$IMAGE_TAG
