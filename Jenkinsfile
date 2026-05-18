pipeline {
    agent any
    
    environment {
        // Dynamic image tag using Git short commit hash
        IMAGE_NAME    = "my-app"
        REGISTRY_USER = "your-dockerhub-username"
        GIT_COMMIT_HEX= sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        IMAGE_TAG     = "${GIT_COMMIT_HEX}-${BUILD_NUMBER}"
        FULL_IMAGE    = "${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
        
        // Define Docker Credentials ID configured in Jenkins Credentials Manager
        DOCKER_CREDS  = 'docker-hub-credentials-id'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        ansiColor('xterm')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Pulling code from Git Repository...'
                checkout scm
            }
        }

        stage('Docker Linting & Validation') {
            steps {
                echo 'Checking Dockerfile structure...'
                // Ensures your Dockerfile doesn't contain critical formatting mistakes
                sh "docker run --rm -i hadolint/hadolint < Dockerfile"
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building production image: ${FULL_IMAGE}"
                // Uses --no-cache dynamically if needed or leverages layer caching
                sh "docker build --target production -t ${FULL_IMAGE} ."
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                echo 'Scanning Docker Image for Vulnerabilities using Trivy...'
                // Fails the pipeline if HIGH or CRITICAL vulnerabilities are found
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH,CRITICAL --exit-code 1 ${FULL_IMAGE}"
            }
        }

        stage('Push to Registry') {
            steps {
                echo 'Logging into Docker Hub and Pushing Image...'
                // Securely injects credentials without exposing passwords in logs
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin"
                    sh "docker push ${FULL_IMAGE}"
                    // Also tag and push as 'latest' for production convenience
                    sh "docker tag ${FULL_IMAGE} ${REGISTRY_USER}/${IMAGE_NAME}:latest"
                    sh "docker push ${REGISTRY_USER}/${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Deploy Sandbox / Smoke Test') {
            steps {
                echo 'Spawning container instance for runtime verification...'
                // Run container detached, wait, and test the health check endpoint
                sh "docker run -d --name test_runtime -p 3000:3000 ${FULL_IMAGE}"
                sleep 5
                sh "curl --fail http://localhost:3000/health || (docker logs test_runtime && exit 1)"
            }
        }
    }

    post {
        always {
            echo 'Cleaning up workspace and temporary runtime containers...'
            sh "docker stop test_runtime || true"
            sh "docker rm test_runtime || true"
        }
        success {
            echo "Pipeline completed successfully! Image ${FULL_IMAGE} is ready for deployment. 🎉"
        }
        failure {
            echo "Pipeline failed. Cleaning dangling Docker layers to free space..."
            sh "docker image prune -f"
        }
    }
}
