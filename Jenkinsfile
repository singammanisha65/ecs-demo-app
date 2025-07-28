pipeline {
  agent any

  triggers {
    githubPush()  // Auto-trigger on staging branch push
  }

  environment {
    AWS_REGION        = "us-east-1"
    BUILD_TAG         = "staging-v${BUILD_NUMBER}"
    ECR_URI           = "757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:${BUILD_TAG}"
    LOG_GROUP         = "/ecs/staging-demo-app"
    TASK_FAMILY       = "staging-task"
    CLUSTER_NAME      = "staging-ecs-cluster"
    SERVICE_NAME      = "staging-service"
    EXECUTION_ROLE_ARN = "arn:aws:iam::757370076744:role/staging-ecsTaskExecutionRole-v2"
  }

  stages {
    stage('Staging Environment Check') {
      steps {
        echo '🔍 Deploying to STAGING environment...'
        echo "Branch: ${env.GIT_BRANCH}"
        echo "Build: ${BUILD_TAG}"
      }
    }

    stage('Checkout Code') {
      steps {
        git branch: 'staging',
            credentialsId: 'aws-credentials',
            url: 'https://github.com/singammanisha65/ecs-demo-app.git'
      }
    }

    stage('Build Docker Image') {
      steps {
        echo '📦 Building Docker image for staging...'
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
        echo '🚀 Pushing staging image to ECR...'
        sh '''
          docker tag demo-app:${BUILD_TAG} $ECR_URI
          docker push $ECR_URI
        '''
      }
    }

    stage('Register New Task Definition') {
      steps {
        echo '📄 Registering ECS Task Definition for staging...'
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
              --container-definitions '[{"name":"app","image":"'$ECR_URI'","essential":true,"portMappings":[{"containerPort":80,"protocol":"tcp"}],"environment":[{"name":"DB_HOST","value":"staging-rds.cy9cqcygodlh.us-east-1.rds.amazonaws.com:3306"},{"name":"DB_USER","value":"admin"},{"name":"DB_PASS","value":"StagingPassword123!"}],"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"'$LOG_GROUP'","awslogs-region":"'$AWS_REGION'","awslogs-stream-prefix":"ecs"}}}]' \
              --region $AWS_REGION \
              --query 'taskDefinition.taskDefinitionArn' \
              --output text)

            echo "Staging Task Definition ARN: $TASK_DEFINITION_ARN"
            echo "$TASK_DEFINITION_ARN" > task_definition_arn.txt
          '''
        }
      }
    }

    stage('Update ECS Service') {
      steps {
        echo '🔁 Updating staging ECS Service...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            TASK_DEFINITION_ARN=$(cat task_definition_arn.txt)
            echo "Updating staging service with Task Definition: $TASK_DEFINITION_ARN"

            aws ecs update-service \
              --cluster $CLUSTER_NAME \
              --service $SERVICE_NAME \
              --task-definition "$TASK_DEFINITION_ARN" \
              --force-new-deployment \
              --region $AWS_REGION

            echo "✅ Staging deployment initiated!"
          '''
        }
      }
    }

    stage('Apply Auto-Scaling Policy') {
      steps {
        echo '📊 Applying Auto-scaling policy for staging...'
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
      echo '✅ Staging deployment completed successfully!'
      echo "🌐 Staging URL: http://staging-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com/"
    }
    failure {
      echo '❌ Staging deployment failed.'
    }
    cleanup {
      sh 'rm -f task_definition_arn.txt'
    }
  }
}
