pipeline {
  agent any

  triggers {
    githubPush()  // Auto-trigger on staging branch push
  }

  environment {
    AWS_REGION        = "us-east-1"
    BUILD_TAG         = "staging-v${BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"  // Include git commit for uniqueness
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
        echo "Commit: ${env.GIT_COMMIT}"
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
        sh '''
          # Build with no cache to ensure fresh build
          docker build --no-cache -t demo-app:${BUILD_TAG} .
          echo "✅ Built image: demo-app:${BUILD_TAG}"
        '''
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
          echo "✅ Pushed: $ECR_URI"
          
          # Also tag as latest for this environment
          docker tag demo-app:${BUILD_TAG} 757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:staging-latest
          docker push 757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:staging-latest
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

            echo "🔄 Registering new task definition with image: $ECR_URI"

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

            echo "✅ New Task Definition: $TASK_DEFINITION_ARN"
            echo "$TASK_DEFINITION_ARN" > task_definition_arn.txt
          '''
        }
      }
    }

    stage('Update ECS Service with Latest') {
      steps {
        echo '🔁 Forcing ECS service to use latest task definition...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            TASK_DEFINITION_ARN=$(cat task_definition_arn.txt)
            echo "🚀 Updating service with latest task definition: $TASK_DEFINITION_ARN"

            # Update service with specific task definition
            aws ecs update-service \
              --cluster $CLUSTER_NAME \
              --service $SERVICE_NAME \
              --task-definition "$TASK_DEFINITION_ARN" \
              --force-new-deployment \
              --region $AWS_REGION

            echo "✅ Service update initiated with latest image!"
            
            # Wait a bit and verify the update
            echo "⏳ Waiting 30 seconds for service to start updating..."
            sleep 30
            
            # Check deployment status
            aws ecs describe-services \
              --cluster $CLUSTER_NAME \
              --services $SERVICE_NAME \
              --region $AWS_REGION \
              --query 'services[0].deployments[0].{Status:status,TaskDefinition:taskDefinition,RunningCount:runningCount,PendingCount:pendingCount}' \
              --output table
          '''
        }
      }
    }

    stage('Verify Latest Deployment') {
      steps {
        echo '✅ Verifying latest image is deployed...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            echo "🔍 Checking running tasks for latest image..."
            
            # Get running tasks
            TASK_ARNS=$(aws ecs list-tasks \
              --cluster $CLUSTER_NAME \
              --service-name $SERVICE_NAME \
              --desired-status RUNNING \
              --region $AWS_REGION \
              --query 'taskArns' \
              --output text)

            if [ ! -z "$TASK_ARNS" ]; then
              echo "📋 Current running tasks:"
              aws ecs describe-tasks \
                --cluster $CLUSTER_NAME \
                --tasks $TASK_ARNS \
                --region $AWS_REGION \
                --query 'tasks[*].{TaskArn:taskArn,TaskDefinition:taskDefinitionArn,LastStatus:lastStatus}' \
                --output table
            else
              echo "⚠️ No running tasks found yet - deployment may still be in progress"
            fi
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
      echo '✅ Staging deployment completed with latest code!'
      echo "🏷️ Deployed image: ${ECR_URI}"
      echo "🌐 Staging URL: Check ECS console for ALB DNS name"
    }
    failure {
      echo '❌ Staging deployment failed.'
    }
    cleanup {
      sh 'rm -f task_definition_arn.txt'
    }
  }
}
