pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"
    ECR_REPO   = "757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app"
    IMAGE_TAG  = "v1.4"
    CLUSTER    = "dev-ecs-cluster"
    SERVICE    = "dev-service"
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
        echo 'Building Docker image...'
        sh 'docker build -t demo-app:${IMAGE_TAG} .'
      }
    }

    stage('Login to ECR') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
          '''
        }
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          docker tag demo-app:${IMAGE_TAG} $ECR_REPO:${IMAGE_TAG}
          docker push $ECR_REPO:${IMAGE_TAG}
        '''
      }
    }

    stage('Deploy to ECS') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

            aws ecs update-service \
              --cluster $CLUSTER \
              --service $SERVICE \
              --force-new-deployment \
              --region $AWS_REGION
          '''
        }
      }
    }

    stage('Apply Auto-Scaling Policy') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

            aws application-autoscaling register-scalable-target \
              --service-namespace ecs \
              --resource-id service/$CLUSTER/$SERVICE \
              --scalable-dimension ecs:service:DesiredCount \
              --min-capacity 1 \
              --max-capacity 3 \
              --region $AWS_REGION

            aws application-autoscaling put-scaling-policy \
              --policy-name cpu-scaling-policy \
              --service-namespace ecs \
              --scalable-dimension ecs:service:DesiredCount \
              --resource-id service/$CLUSTER/$SERVICE \
              --policy-type TargetTrackingScaling \
              --target-tracking-scaling-policy-configuration '{
                "TargetValue": 60.0,
                "PredefinedMetricSpecification": {
                  "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
                },
                "ScaleInCooldown": 60,
                "ScaleOutCooldown": 60
              }' \
              --region $AWS_REGION
          '''
        }
      }
    }
  }

  post {
    failure {
      echo '❌ Deployment failed.'
    }
    success {
      echo '✅ Deployment succeeded.'
    }
  }
}
