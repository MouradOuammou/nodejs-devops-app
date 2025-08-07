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

        stage('Pre-Deploy Cleanup') {
            steps {
                script {
                    echo "Cleaning up existing resources..."
                    sh '''
                        # Vérifier la connexion Kubernetes
                        echo "Testing Kubernetes connection..."
                        kubectl cluster-info
                        kubectl get nodes
                        
                        # Créer le namespace s'il n'existe pas
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

                        # Supprimer toutes les ressources liées à l'ancienne release
                        echo "Removing existing Helm release and related resources..."
                        helm uninstall ${DOCKER_IMAGE_NAME} -n ${NAMESPACE} || true

                        # Attendre que les ressources soient supprimées
                        sleep 10

                        # Force cleanup des ressources restantes
                        kubectl delete all,pdb,configmap,secret,ingress,networkpolicy -l app.kubernetes.io/instance=${DOCKER_IMAGE_NAME} -n ${NAMESPACE} --ignore-not-found=true || true
                        kubectl delete pdb ${DOCKER_IMAGE_NAME} -n ${NAMESPACE} --ignore-not-found=true || true

                        # Attendre le nettoyage complet
                        sleep 5

                        echo "Cleanup completed"
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'DOCKER_HUB_USR', passwordVariable: 'DOCKER_HUB_PSW')]) {
                    script {
                        echo "Deploying to Kubernetes..."
                        sh '''
                            # Vérifier que le chart Helm existe
                            if [ ! -d "./helm/${DOCKER_IMAGE_NAME}" ]; then
                                echo "Error: Helm chart directory not found at ./helm/${DOCKER_IMAGE_NAME}"
                                exit 1
                            fi

                            # Déployer avec Helm (installation fraîche après cleanup)
                            echo "Installing with Helm..."
                            helm install ${DOCKER_IMAGE_NAME} ./helm/${DOCKER_IMAGE_NAME} \
                                --set image.repository=$DOCKER_HUB_USR/${DOCKER_IMAGE_NAME} \
                                --set image.tag=${BUILD_NUMBER} \
                                --namespace ${NAMESPACE} \
                                --create-namespace \
                                --wait \
                                --timeout=10m

                            # Vérifier le déploiement
                            echo "Checking deployment status..."
                            kubectl get pods -n ${NAMESPACE}
                            kubectl get services -n ${NAMESPACE}
                            kubectl get pdb -n ${NAMESPACE} || true
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
                        message: ":white_check_mark: *SUCCESS* - Job '${env.JOB_NAME}' [${env.BUILD_NUMBER}]\n:rocket: Application deployed successfully!\n:link: ${env.BUILD_URL}",
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
                        docker rmi ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} || true
                        docker system prune -f
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
                =================================
                """
            }
        }
    }
}