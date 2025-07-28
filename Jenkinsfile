pipeline {
  agent any

  // No automatic triggers - manual only for production
  
  environment {
    AWS_REGION        = "us-east-1"
    BUILD_TAG         = "prod-v${BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    ECR_URI           = "757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:${BUILD_TAG}"
    LOG_GROUP         = "/ecs/prod-demo-app"
    TASK_FAMILY       = "prod-task"
    CLUSTER_NAME      = "prod-ecs-cluster"
    SERVICE_NAME      = "prod-service"
    EXECUTION_ROLE_ARN = "arn:aws:iam::757370076744:role/prod-ecsTaskExecutionRole-v2"
  }

  stages {
    stage('Production Approval') {
      steps {
        script {
          def deploymentApproval = input(
            message: '🚨 Deploy to PRODUCTION? This action affects live users!',
            ok: 'Deploy to Production',
            parameters: [
              choice(name: 'CONFIRM_DEPLOYMENT', choices: ['No', 'Yes'], description: 'Confirm production deployment')
            ],
            submitterParameter: 'APPROVER'
          )
          
          if (deploymentApproval.CONFIRM_DEPLOYMENT != 'Yes') {
            error('Production deployment cancelled by user')
          }
          
          echo "✅ Production deployment approved by: ${APPROVER}"
        }
      }
    }

    stage('Pre-Production Validation') {
      steps {
        echo '🔍 Running pre-production checks...'
        echo "Deploying from branch: ${env.GIT_BRANCH}"
        echo "Build tag: ${BUILD_TAG}"
        echo "Approved by: ${APPROVER}"
      }
    }

    stage('Checkout Code') {
      steps {
        git branch: 'production',
            credentialsId: 'aws-credentials',
            url: 'https://github.com/singammanisha65/ecs-demo-app.git'
      }
    }

    stage('Build Docker Image') {
      steps {
        echo '📦 Building Docker image for production...'
        sh '''
          # Build with no cache to ensure fresh build
          docker build --no-cache -t demo-app:${BUILD_TAG} .
          echo "✅ Built production image: demo-app:${BUILD_TAG}"
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
        echo '🚀 Pushing production image to ECR...'
        sh '''
          docker tag demo-app:${BUILD_TAG} $ECR_URI
          docker push $ECR_URI
          echo "✅ Pushed: $ECR_URI"
          
          # Also tag as latest for production
          docker tag demo-app:${BUILD_TAG} 757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:prod-latest
          docker push 757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app:prod-latest
        '''
      }
    }

    stage('Register New Task Definition') {
      steps {
        echo '📄 Registering ECS Task Definition for production...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            echo "🔄 Registering production task definition with image: $ECR_URI"

            TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
              --family $TASK_FAMILY \
              --requires-compatibilities FARGATE \
              --network-mode awsvpc \
              --cpu 512 \
              --memory 1024 \
              --execution-role-arn $EXECUTION_ROLE_ARN \
              --container-definitions '[{"name":"app","image":"'$ECR_URI'","essential":true,"portMappings":[{"containerPort":80,"protocol":"tcp"}],"environment":[{"name":"DB_HOST","value":"prod-rds.cy9cqcygodlh.us-east-1.rds.amazonaws.com:3306"},{"name":"DB_USER","value":"admin"},{"name":"DB_PASS","value":"ProductionPassword123!"}],"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"'$LOG_GROUP'","awslogs-region":"'$AWS_REGION'","awslogs-stream-prefix":"ecs"}}}]' \
              --region $AWS_REGION \
              --query 'taskDefinition.taskDefinitionArn' \
              --output text)

            echo "✅ Production Task Definition: $TASK_DEFINITION_ARN"
            echo "$TASK_DEFINITION_ARN" > task_definition_arn.txt
          '''
        }
      }
    }

    stage('Update ECS Service') {
      steps {
        echo '🔁 Updating production ECS Service...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

            TASK_DEFINITION_ARN=$(cat task_definition_arn.txt)
            echo "🚀 Updating production service with Task Definition: $TASK_DEFINITION_ARN"

            aws ecs update-service \
              --cluster $CLUSTER_NAME \
              --service $SERVICE_NAME \
              --task-definition "$TASK_DEFINITION_ARN" \
              --force-new-deployment \
              --region $AWS_REGION

            echo "✅ Production service update initiated!"
            
            # Wait and check status
            echo "⏳ Waiting 30 seconds for service to start updating..."
            sleep 30
            
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

    stage('Verify Production Deployment') {
      steps {
        echo '✅ Verifying production deployment...'
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
        echo '📊 Applying Auto-scaling policy for production...'
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
              --min-capacity 2 \
              --max-capacity 5 \
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
              --target-tracking-scaling-policy-configuration '{"TargetValue": 70.0, "PredefinedMetricSpecification": {"PredefinedMetricType": "ECSServiceAverageCPUUtilization"}, "ScaleInCooldown": 300, "ScaleOutCooldown": 300}' \
              --region $AWS_REGION
          '''
        }
      }
    }

    stage('Post-Production Verification') {
      steps {
        echo '✅ Running post-deployment verification...'
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
            
            echo "Waiting 30 seconds for service to stabilize..."
            sleep 30
            
            # Get ALB DNS name for production
            ALB_DNS=$(aws elbv2 describe-load-balancers \
              --names prod-alb \
              --region $AWS_REGION \
              --query 'LoadBalancers[0].DNSName' \
              --output text)
              
            echo "🌐 Production URL: http://$ALB_DNS/"
            echo "Production deployment verification completed"
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ Production deployment completed successfully!'
      echo "🏷️ Deployed image: ${ECR_URI}"
      echo "👤 Deployed by: ${APPROVER}"
      echo "🌐 Production URL: http://prod-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com/"
    }
    failure {
      echo '❌ Production deployment failed - immediate attention required!'
      echo "👤 Attempted by: ${APPROVER}"
    }
    cleanup {
      sh 'rm -f task_definition_arn.txt'
    }
  }
}
