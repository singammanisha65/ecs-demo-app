pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"
    IMAGE_NAME = "demo-app"
    IMAGE_TAG  = "v1.4"
    ECR_URI    = "757370076744.dkr.ecr.us-east-1.amazonaws.com/${IMAGE_NAME}:${IMAGE_TAG}"
    TASK_FAMILY = "dev-task"
    CLUSTER_NAME = "dev-ecs-cluster"
    SERVICE_NAME = "dev-service"
    EXECUTION_ROLE_ARN = "arn:aws:iam::757370076744:role/dev-ecsTaskExecutionRole-v2"
    LOG_GROUP = "/ecs/demo-app"
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
        echo "📦 Building Docker image..."
        sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'
      }
    }

    stage('Login to ECR') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin 757370076744.dkr.ecr.us-east-1.amazonaws.com
          '''
        }
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}
          docker push ${ECR_URI}
        '''
      }
    }

    stage('Register New Task Definition') {
      steps {
        echo "📄 Registering new ECS task definition..."
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

            aws ecs register-task-definition \
              --family ${TASK_FAMILY} \
              --requires-compatibilities FARGATE \
              --network-mode awsvpc \
              --cpu 256 \
              --memory 512 \
              --execution-role-arn ${EXECUTION_ROLE_ARN} \
              --container-definitions '[
                {
                  "name": "app",
                  "image": "${ECR_URI}",
                  "essential": true,
                  "portMappings": [
                    { "containerPort": 80, "protocol": "tcp" }
                  ],
                  "environment": [
                    { "name": "DB_HOST", "value": "dev-rds.cy9cqcygodlh.us-east-1.rds.amazonaws.com:3306" },
                    { "name": "DB_USER", "value": "admin" },
                    { "name": "DB_PASS", "value": "StrongPassword123!" }
                  ],
                  "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                      "awslogs-group": "${LOG_GROUP}",
                      "awslogs-region": "${AWS_REGION}",
                      "awslogs-stream-prefix": "ecs"
                    }
                  }
                }
              ]' \
              --region $AWS_REGION
          '''
        }
      }
    }

    stage('Update ECS Service') {
      steps {
        echo "🚀 Deploying to ECS..."
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

            aws ecs update-service \
              --cluster ${CLUSTER_NAME} \
              --service ${SERVICE_NAME} \
              --force-new-deployment \
              --region $AWS_REGION
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Deployment to ECS complete!"
    }
    failure {
      echo "❌ Deployment failed."
    }
  }
}
