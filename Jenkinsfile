pipeline {
    agent any
    
    environment {
        DOCKER_HUB = credentials('docker-hub')
        KUBECONFIG = credentials('kubeconfig')
        HELM_VERSION = '3.12.0'
        NAMESPACE = 'devops-demo'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t nodejs-devops-app:${BUILD_NUMBER} .'
            }
        }
        
        stage('Test') {
            steps {
                sh 'docker run --rm nodejs-devops-app:${BUILD_NUMBER} npm test'
            }
        }
        
        stage('Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-cred', passwordVariable: 'DOCKER_HUB_PSW', usernameVariable: 'DOCKER_HUB_USR')]) {
                    sh """
                    docker login -u ${DOCKER_HUB_USR} -p ${DOCKER_HUB_PSW}
                    docker tag nodejs-devops-app:${BUILD_NUMBER} ${DOCKER_HUB_USR}/nodejs-devops-app:${BUILD_NUMBER}
                    docker push ${DOCKER_HUB_USR}/nodejs-devops-app:${BUILD_NUMBER}
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh """
                kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                helm upgrade --install nodejs-devops-app ./helm/nodejs-devops-app \
                    --set image.repository=${DOCKER_HUB_USR}/nodejs-devops-app \
                    --set image.tag=${BUILD_NUMBER} \
                    --namespace ${NAMESPACE} \
                    --atomic \
                    --wait
                """
            }
        }
    }
    
    post {
        success {
            slackSend(color: "good", message: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
        failure {
            slackSend(color: "danger", message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
        always {
            cleanWs()
        }
    }
}