pipeline {
  agent any

  environment {
    AWS_REGION = 'us-east-1'
    ECR_REGISTRY = '757370076744.dkr.ecr.us-east-1.amazonaws.com'
    REPO_NAME = 'demo-app'
    IMAGE_TAG = "v1.${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout Code') {
      steps {
        git branch: 'main', url: 'https://github.com/singammanisha65/ecs-demo-app'
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''
          echo "Building Docker image..."
          docker build -t $REPO_NAME:$IMAGE_TAG .
        '''
      }
    }

    stage('Login to ECR') {
      steps {
        sh '''
          echo "Logging in to ECR..."
          aws ecr get-login-password --region $AWS_REGION | \
          docker login --username AWS --password-stdin $ECR_REGISTRY
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          docker tag $REPO_NAME:$IMAGE_TAG $ECR_REGISTRY/$REPO_NAME:$IMAGE_TAG
          docker push $ECR_REGISTRY/$REPO_NAME:$IMAGE_TAG
        '''
      }
    }

    stage('Deploy to ECS') {
      steps {
        sh '''
          echo "Updating ECS service..."
          aws ecs update-service \
            --cluster dev-ecs-cluster \
            --service dev-service \
            --force-new-deployment
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Deployment successful!"
    }
    failure {
      echo "❌ Deployment failed."
    }
  }
}
