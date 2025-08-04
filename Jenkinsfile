pipeline {
  agent any

  environment {
    AWS_REGION        = "us-east-1"
    BUILD_TAG         = "v${BUILD_NUMBER}"
    ECR_URI           = "757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:${BUILD_TAG}"
    LOG_GROUP         = "/ecs/demo-app"
    TASK_FAMILY       = "dev-task"
    CLUSTER_NAME      = "dev-ecs-cluster"
    SERVICE_NAME      = "dev-service"
    EXECUTION_ROLE_ARN = "arn:aws:iam::757370076744:role/dev-ecsTaskExecutionRole-v2"
  }

  stages {
    stage('Checkout Code') {
      steps {
        git branch: 'main',
            credentialsId: 'aws-credentials',
            url: 'https://github.com/singammanisha65/ecs-demo-app.git'
      }
    }

    stage('Build Docker Image') {
      steps {
        echo '📦 Building Docker image...'
        sh 'docker build -t demo-app:${BUILD_TAG} .'
      }
    }

    stage('Login to ECR') {
      steps {
        echo '🔐 Logging into AWS ECR...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin 757370076744.dkr.ecr.us-east-1.amazonaws.com
          '''
        }
      }
    }

    stage('Push to ECR') {
      steps {
        echo '🚀 Pushing image to ECR...'
        sh '''
          docker tag demo-app:${BUILD_TAG} $ECR_URI
          docker push $ECR_URI
        '''
      }
    }

    stage('Register New Task Definition') {
      steps {
        echo '📄 Registering ECS Task Definition...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
              --family $TASK_FAMILY \
              --requires-compatibilities FARGATE \
              --network-mode awsvpc \
              --cpu 256 \
              --memory 512 \
              --execution-role-arn $EXECUTION_ROLE_ARN \
              --container-definitions '[{"name":"app","image":"'$ECR_URI'","essential":true,"portMappings":[{"containerPort":80,"protocol":"tcp"}],"environment":[{"name":"DB_HOST","value":"dev-rds.cy9cqcygodlh.us-east-1.rds.amazonaws.com:3306"},{"name":"DB_USER","value":"admin"},{"name":"DB_PASS","value":"StrongPassword123!"}],"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"'$LOG_GROUP'","awslogs-region":"'$AWS_REGION'","awslogs-stream-prefix":"ecs"}}}]' \
              --region $AWS_REGION \
              --query 'taskDefinition.taskDefinitionArn' \
              --output text)

            echo "New Task Definition ARN: $TASK_DEFINITION_ARN"
            echo "$TASK_DEFINITION_ARN" > task_definition_arn.txt
          '''
        }
      }
    }

    stage('Update ECS Service') {
      steps {
        echo '🔁 Triggering ECS Service deployment...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            TASK_DEFINITION_ARN=$(cat task_definition_arn.txt)
            echo "Updating service with Task Definition: $TASK_DEFINITION_ARN"

            aws ecs update-service \
              --cluster $CLUSTER_NAME \
              --service $SERVICE_NAME \
              --task-definition "$TASK_DEFINITION_ARN" \
              --force-new-deployment \
              --region $AWS_REGION

            echo "✅ Deployment initiated! ECS will continue deploying in the background."
          '''
        }
      }
    }

    stage('Apply Auto-Scaling Policy') {
      steps {
        echo '📊 Applying Auto-scaling policy...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            aws application-autoscaling deregister-scalable-target \
              --service-namespace ecs \
              --scalable-dimension ecs:service:DesiredCount \
              --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
              --region $AWS_REGION || true

            aws application-autoscaling register-scalable-target \
              --service-namespace ecs \
              --scalable-dimension ecs:service:DesiredCount \
              --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
              --min-capacity 1 \
              --max-capacity 3 \
              --region $AWS_REGION

            aws application-autoscaling delete-scaling-policy \
              --service-namespace ecs \
              --scalable-dimension ecs:service:DesiredCount \
              --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
              --policy-name cpu-utilization-policy \
              --region $AWS_REGION || true

            aws application-autoscaling put-scaling-policy \
              --service-namespace ecs \
              --scalable-dimension ecs:service:DesiredCount \
              --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
              --policy-name cpu-utilization-policy \
              --policy-type TargetTrackingScaling \
              --target-tracking-scaling-policy-configuration '{"TargetValue": 50.0, "PredefinedMetricSpecification": {"PredefinedMetricType": "ECSServiceAverageCPUUtilization"}, "ScaleInCooldown": 60, "ScaleOutCooldown": 60}' \
              --region $AWS_REGION
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline completed successfully!'
      echo '📍 Deployment is continuing in the background. Check ECS Console for progress.'
    }
    failure {
      echo '❌ Pipeline failed.'
    }
    cleanup {
      sh 'rm -f task_definition_arn.txt'
    }
  }
}
