pipeline {
    agent any

    environment {
        HELM_VERSION = '3.12.0'
        NAMESPACE = 'devops-demo'
        SLACK_TOKEN_ID = 'slack-token-id'
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
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
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub',
                        usernameVariable: 'DOCKER_HUB_USR',
                        passwordVariable: 'DOCKER_HUB_PSW'
                    )
                ]) {
                    sh """
                        echo \$DOCKER_HUB_PSW | docker login -u \$DOCKER_HUB_USR --password-stdin
                        docker tag nodejs-devops-app:\${BUILD_NUMBER} \$DOCKER_HUB_USR/nodejs-devops-app:\${BUILD_NUMBER}
                        docker push \$DOCKER_HUB_USR/nodejs-devops-app:\${BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub', 
                        usernameVariable: 'DOCKER_HUB_USR', 
                        passwordVariable: 'DOCKER_HUB_PSW'
                    )
                ]) {
                    sh '''
                        # Vérifier que kubectl fonctionne
                        kubectl version --client
                        kubectl cluster-info
                        
                        # Créer le namespace
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Si vous utilisez Helm
                        if [ -d "./helm/nodejs-devops-app" ]; then
                            echo "Deploying with Helm..."
                            helm upgrade --install nodejs-devops-app ./helm/nodejs-devops-app \
                                --set image.repository=$DOCKER_HUB_USR/nodejs-devops-app \
                                --set image.tag=${BUILD_NUMBER} \
                                --namespace ${NAMESPACE} \
                                --create-namespace \
                                --atomic \
                                --wait
                        else
                            echo "Deploying with kubectl..."
                            # Remplacer les placeholders dans les manifests k8s
                            sed -i "s|IMAGE_PLACEHOLDER|$DOCKER_HUB_USR/nodejs-devops-app:${BUILD_NUMBER}|g" k8s/*.yaml
                            kubectl apply -f k8s/ -n ${NAMESPACE}
                            kubectl rollout status deployment/nodejs-devops-app -n ${NAMESPACE} --timeout=300s
                        fi
                        
                        # Vérifier le déploiement
                        kubectl get pods -n ${NAMESPACE}
                        kubectl get services -n ${NAMESPACE}
                    '''
                }
            }
        }
    }

    post {
        success {
            slackSend(
                channel: '#nouveau-canal', 
                color: "good",
                message: " SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' deployed successfully!\n🔗 Build URL: ${env.BUILD_URL}",
                tokenCredentialId: "${SLACK_TOKEN_ID}"
            )
        }
        failure {
            slackSend(
                channel: '#nouveau-canal',
                color: "danger",
                message: " FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' failed!\n🔗 Build URL: ${env.BUILD_URL}\n📋 Check logs for details.",
                tokenCredentialId: "${SLACK_TOKEN_ID}"
            )
        }
        always {
            sh '''
                docker rmi nodejs-devops-app:${BUILD_NUMBER} || true
                docker system prune -f || true
            '''
            cleanWs()
        }
    }
}