pipeline {
    agent any

    environment {
        HELM_VERSION = '3.12.0'
        NAMESPACE = 'devops-demo'
        SLACK_TOKEN_ID = 'slack-token-id'
        DOCKER_IMAGE_NAME = 'nodejs-devops-app'
        DOCKER_HUB_USR = 'mouradouammou'  // Votre username Docker Hub

        ARGOCD_APP_NAME = 'nodejs-devops-app'
        ARGOCD_NAMESPACE = 'argocd'
        GIT_REPO_URL = 'git@github.com:MouradOuammou/nodejs-devops-app.git'  // Changé en SSH
        GIT_BRANCH = 'main'

        DEPLOY_TIMEOUT = 600 // secondes
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
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
                    usernameVariable: 'DOCKER_HUB_USR_CRED',
                    passwordVariable: 'DOCKER_HUB_PSW'
                )]) {
                    script {
                        sh '''
                            echo "$DOCKER_HUB_PSW" | docker login -u "$DOCKER_HUB_USR_CRED" --password-stdin
                            docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
                            docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:latest
                            docker push ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }

        stage('Update Helm Values') {
            steps {
                script {
                    sh '''
                        # Configuration Git avec vos informations
                        git config user.name "Mourad Ouammou"
                        git config user.email "mouradouammou8@gmail.com"

                        # Nettoyer le répertoire temporaire
                        rm -rf temp-repo

                        # Cloner avec SSH (utilise automatiquement mouradkey)
                        git clone ${GIT_REPO_URL} temp-repo
                        cd temp-repo

                        # Installer yq si nécessaire
                        YQ_BIN="$HOME/yq"
                        if [ ! -x "$YQ_BIN" ]; then
                            echo "Installing yq in $HOME..."
                            wget -qO "$YQ_BIN" https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64
                            chmod +x "$YQ_BIN"
                        fi
                        export PATH="$HOME:$PATH"

                        # Mettre à jour les valeurs Helm
                        yq e -i ".image.repository = \\"${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}\\"" helm/${DOCKER_IMAGE_NAME}/values.yaml
                        yq e -i ".image.tag = \\"${BUILD_NUMBER}\\"" helm/${DOCKER_IMAGE_NAME}/values.yaml

                        # Vérifier s'il y a des changements avant de commiter
                        if ! git diff --quiet helm/${DOCKER_IMAGE_NAME}/values.yaml; then
                            git add helm/${DOCKER_IMAGE_NAME}/values.yaml
                            git commit -m "🚀 Update image ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"
                            git push origin ${GIT_BRANCH}
                            echo "Helm values updated successfully"
                        else
                            echo "No changes in Helm values"
                        fi
                    '''
                }
            }
        }

        stage('Trigger ArgoCD Sync') {
            steps {
                script {
                    sh '''
                        # Installer ArgoCD CLI si nécessaire
                        ARGOCD_BIN="$HOME/argocd"
                        if [ ! -x "$ARGOCD_BIN" ]; then
                            echo "Installing ArgoCD CLI..."
                            curl -sSL -o "$ARGOCD_BIN" https://github.com/argoproj/argo-cd/releases/download/v2.12.6/argocd-linux-amd64
                            chmod +x "$ARGOCD_BIN"
                        fi
                        export PATH="$HOME:$PATH"

                        # Synchroniser l'application ArgoCD
                        echo "Triggering ArgoCD sync for ${ARGOCD_APP_NAME}..."
                        # argocd app sync ${ARGOCD_APP_NAME} --namespace ${ARGOCD_NAMESPACE}
                        # argocd app wait ${ARGOCD_APP_NAME} --namespace ${ARGOCD_NAMESPACE} --health --timeout ${DEPLOY_TIMEOUT}
                        
                        # Commenté pour l'instant - décommentez quand ArgoCD sera configuré
                        echo "ArgoCD sync would be triggered here"
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                // Nettoyage des ressources
                sh '''
                    rm -rf temp-repo || true
                    docker rmi ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} || true
                '''
                cleanWs()
            }
        }

        success {
            script {
                try {
                    slackSend(
                        channel: '#nouveau-canal',
                        color: 'good',
                        message: """✅ *Pipeline SUCCESS*
Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Image: ${DOCKER_HUB_USR}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
ArgoCD App: ${ARGOCD_APP_NAME}
Namespace: ${NAMESPACE}
Duration: ${currentBuild.durationString}
Build URL: ${env.BUILD_URL}""",
                        tokenCredentialId: "${SLACK_TOKEN_ID}"
                    )
                } catch (Exception e) {
                    echo "Slack notification failed: ${e.getMessage()}"
                }
            }
        }

        failure {
            script {
                try {
                    slackSend(
                        channel: '#nouveau-canal',
                        color: 'danger',
                        message: """❌ *Pipeline FAILED*
Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Stage: ${env.STAGE_NAME}
Duration: ${currentBuild.durationString}
Console: ${env.BUILD_URL}console""",
                        tokenCredentialId: "${SLACK_TOKEN_ID}"
                    )
                } catch (Exception e) {
                    echo "Slack notification failed: ${e.getMessage()}"
                }
            }
        }
    }
}