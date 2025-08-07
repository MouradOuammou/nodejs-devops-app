pipeline {
    agent any

    environment {
        HELM_VERSION = '3.12.0'
        NAMESPACE = 'devops-demo'
        SLACK_TOKEN_ID = 'slack-token-id'
        DOCKER_IMAGE_NAME = 'nodejs-devops-app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                script {
                    echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker build -t ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ."
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    echo "Running tests..."
                    sh "docker run --rm ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} npm test"
                }
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
                    script {
                        echo "Pushing image to Docker Hub..."
                        sh '''
                            echo "$DOCKER_HUB_PSW" | docker login -u "$DOCKER_HUB_USR" --password-stdin
                            docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} $DOCKER_HUB_USR/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
                            docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} $DOCKER_HUB_USR/${DOCKER_IMAGE_NAME}:latest
                            docker push $DOCKER_HUB_USR/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
                            docker push $DOCKER_HUB_USR/${DOCKER_IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }

        stage('Clean Deploy') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'DOCKER_HUB_USR', passwordVariable: 'DOCKER_HUB_PSW')]) {
                    script {
                        echo "Clean deployment to Kubernetes..."
                        sh '''
                            # Vérification rapide de Kubernetes
                            kubectl get nodes --no-headers | head -1
                            
                            # Vérifier que le chart Helm existe
                            if [ ! -d "./helm/${DOCKER_IMAGE_NAME}" ]; then
                                echo "Error: Helm chart directory not found at ./helm/${DOCKER_IMAGE_NAME}"
                                exit 1
                            fi

                            # Force cleanup - supprimer tout proprement
                            echo "Force cleaning existing resources..."
                            kubectl delete namespace ${NAMESPACE} --ignore-not-found=true || true
                            
                            # Attendre que le namespace soit complètement supprimé
                            echo "Waiting for namespace cleanup..."
                            sleep 10
                            
                            # Recréer le namespace proprement
                            kubectl create namespace ${NAMESPACE}
                            
                            # Déploiement avec Helm install (installation fraîche)
                            echo "Fresh deployment with Helm..."
                            helm install ${DOCKER_IMAGE_NAME} ./helm/${DOCKER_IMAGE_NAME} \
                                --set image.repository=$DOCKER_HUB_USR/${DOCKER_IMAGE_NAME} \
                                --set image.tag=${BUILD_NUMBER} \
                                --namespace ${NAMESPACE} \
                                --wait \
                                --timeout=5m

                            # Vérification du déploiement
                            echo "Deployment successful! Checking status..."
                            kubectl get pods -n ${NAMESPACE}
                            kubectl get services -n ${NAMESPACE}
                            
                            # Afficher l'URL d'accès (pour minikube)
                            echo "=== APPLICATION ACCESS ==="
                            minikube service ${DOCKER_IMAGE_NAME} -n ${NAMESPACE} --url || echo "Service URL not available"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                try {
                    slackSend(
                        channel: '#nouveau-canal', 
                        color: "good",
                        message: ":white_check_mark: *SUCCESS* - Job '${env.JOB_NAME}' [${env.BUILD_NUMBER}]\n:rocket: Application deployed successfully to Kubernetes!\n:link: ${env.BUILD_URL}",
                        tokenCredentialId: "${SLACK_TOKEN_ID}"
                    )
                    echo "Slack notification sent successfully"
                } catch (Exception e) {
                    echo "Warning: Slack notification failed - ${e.getMessage()}"
                }
            }
        }

        failure {
            script {
                try {
                    slackSend(
                        channel: '#nouveau-canal',
                        color: "danger",
                        message: ":x: *FAILED* - Job '${env.JOB_NAME}' [${env.BUILD_NUMBER}]\n:warning: Pipeline failed\n:link: ${env.BUILD_URL}console",
                        tokenCredentialId: "${SLACK_TOKEN_ID}"
                    )
                    echo "Slack failure notification sent successfully"
                } catch (Exception e) {
                    echo "Warning: Slack notification failed - ${e.getMessage()}"
                }
            }
        }

        always {
            script {
                try {
                    sh '''
                        # Cleanup Docker images
                        docker rmi ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} || true
                        docker system prune -f --volumes || true
                    '''
                } catch (Exception e) {
                    echo "Warning: Failed to clean up Docker images - ${e.getMessage()}"
                }
            }

            cleanWs()

            script {
                echo """
                =================================
                BUILD SUMMARY
                =================================
                Job: ${env.JOB_NAME}
                Build: ${env.BUILD_NUMBER}
                Status: ${currentBuild.currentResult}
                Duration: ${currentBuild.durationString}
                Image: ${env.DOCKER_HUB_USR}/${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}
                Namespace: ${env.NAMESPACE}
                =================================
                """
            }
        }
    }
}