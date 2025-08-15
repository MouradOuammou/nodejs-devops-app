pipeline {
    agent any

    environment {
        HELM_VERSION = '3.12.0'
        NAMESPACE = 'devops-demo'
        SLACK_TOKEN_ID = 'slack-token-id'
        DOCKER_IMAGE_NAME = 'nodejs-devops-app'
        
        // ArgoCD Configuration
        ARGOCD_APP_NAME = 'nodejs-devops-app'
        ARGOCD_NAMESPACE = 'argocd'
        GIT_REPO_URL = 'https://github.com/MouradOuammou/nodejs-devops-app.git'
        GIT_BRANCH = 'main'
        
        DEPLOY_TIMEOUT = 600 // secondes
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ."
                }
            }
        }

        stage('Test Image') {
            steps {
                script {
                    sh "docker run --rm ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} npm test"
                }
            }
        }

        stage('Push to Registry') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub',
                    usernameVariable: 'DOCKER_HUB_USR',
                    passwordVariable: 'DOCKER_HUB_PSW'
                )]) {
                    script {
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

        stage('Update Helm Values') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-token',
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    script {
                        sh '''
                           git config user.name "Mourad Ouammou"
git config user.email "mourad.ouammou@example.com"

                            git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/MouradOuammou/nodejs-devops-app.git temp-repo
                            cd temp-repo

                            # Update image in Helm values.yaml using yq
                            yq e -i ".image.repository = \"${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}\"" helm/${DOCKER_IMAGE_NAME}/values.yaml
                            yq e -i ".image.tag = \"${BUILD_NUMBER}\"" helm/${DOCKER_IMAGE_NAME}/values.yaml

                            git add helm/${DOCKER_IMAGE_NAME}/values.yaml
                            git commit -m "🚀 Update image ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"
                            git push origin ${GIT_BRANCH}
                        '''
                    }
                }
            }
        }

        stage('Trigger ArgoCD Sync') {
            steps {
                script {
                    sh '''
                        # Sync application via ArgoCD CLI
                        argocd app sync ${ARGOCD_APP_NAME} --namespace ${ARGOCD_NAMESPACE}
                        argocd app wait ${ARGOCD_APP_NAME} --namespace ${ARGOCD_NAMESPACE} --health --timeout ${DEPLOY_TIMEOUT}
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                slackSend(
                    channel: '#nouveau-canal', 
                    color: "good",
                    message: ":white_check_mark: Pipeline SUCCESS - ${JOB_NAME} #${BUILD_NUMBER}\nImage: ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}\nArgoCD App: ${ARGOCD_APP_NAME}\nNamespace: ${NAMESPACE}\nBuild URL: ${BUILD_URL}",
                    tokenCredentialId: "${SLACK_TOKEN_ID}"
                )
            }
        }

        failure {
            script {
                slackSend(
                    channel: '#nouveau-canal',
                    color: "danger",
                    message: ":x: Pipeline FAILED - ${JOB_NAME} #${BUILD_NUMBER}\nStage: ${STAGE_NAME}\nBuild URL: ${BUILD_URL}console",
                    tokenCredentialId: "${SLACK_TOKEN_ID}"
                )
            }
        }

        always {
            script {
                sh '''
                    # Cleanup
                    rm -rf temp-repo || true
                    docker rmi ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} || true
                '''
                cleanWs()
            }
        }
    }
}
