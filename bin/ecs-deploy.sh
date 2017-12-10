TASK_FAMILY=${JOB_NAME}
SERVICE=${JOB_NAME}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
ENV=${ENV}
CLUSTER=${CLUSTER}
DOCKER_IMAGE=${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/${SERVICE}:${ENV}-latest
LATEST_TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition ${TASK_FAMILY})

echo $LATEST_TASK_DEFINITION \
     | jq '{containerDefinitions: .taskDefinition.containerDefinitions, volumes: .taskDefinition.volumes}' \
     | jq '.containerDefinitions[0].image='\"${DOCKER_IMAGE}\" \
     > ${TASK_FAMILY}.json || exit 1

echo "Create new task definition revision"
aws ecs register-task-definition --family ${TASK_FAMILY} --cli-input-json file://${TASK_FAMILY}.json || exit 1
echo "Update ECS Service"
aws ecs update-service --service ${SERVICE} --task-definition ${TASK_FAMILY} --cluster ${CLUSTER} || exit 1
# Below commands are moved to antoher circleci step
#echo "Wait for service to be stable..."
#aws ecs wait services-stable --services ${SERVICE} --cluster ${CLUSTER} 		 || exit 1
