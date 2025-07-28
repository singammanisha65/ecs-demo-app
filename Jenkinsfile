pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"
    ECR_REPO   = "757370076744.dkr.ecr.us-east-1.amazonaws.com/demo-app"
    IMAGE_TAG  = "v${env.BUILD_NUMBER}"
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
        echo "Building Docker image with tag ${env.IMAGE_TAG}..."
        sh "docker build -t demo-app:${env.IMAGE_TAG} ."
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
          docker tag demo-app:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
          docker push ${ECR_REPO}:${IMAGE_TAG}
        '''
      }
    }

    stage('Deploy to ECS') {
      steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

            # Get current task definition and update image tag
            TASK_DEF_JSON=$(aws ecs describe-task-definition --task-definition dev-task --region $AWS_REGION)

            FAMILY=$(echo $TASK_DEF_JSON | jq -r '.taskDefinition.family')
            EXEC_ROLE=$(echo $TASK_DEF_JSON | jq -r '.taskDefinition.executionRoleArn')
            NET_MODE=$(echo $TASK_DEF_JSON | jq -r '.taskDefinition.networkMode')
            COMPAT=$(echo $TASK_DEF_JSON | jq -r '.taskDefinition.requiresCompatibilities[0]')
            CPU=$(echo $TASK_DEF_JSON | jq -r '.taskDefinition.cpu')
            MEMORY=$(echo $TASK_DEF_JSON | jq -r '.taskDefinition.memory')

            CONTAINER_DEF=$(echo $TASK_DEF_JSON | jq --arg IMAGE "${ECR_REPO}:${IMAGE_TAG}" '.taskDefinition.containerDefinitions | map(.image = $IMAGE)')

            aws ecs register-task-definition \
              --family $FAMILY \
              --execution-role-arn $EXEC_ROLE \
              --network-mode $NET_MODE \
              --requires-compatibilities $COMPAT \
              --cpu $CPU \
              --memory $MEMORY \
              --container-definitions "$CONTAINER_DEF"

            echo "Triggering ECS deployment..."
            aws ecs update-service \
              --cluster dev-ecs-cluster \
              --service dev-service \
              --force-new-deployment \
              --region $AWS_REGION
          '''
        }

      }
    }
  }
}
