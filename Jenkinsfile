pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'python-api'
        CONTAINER_NAME = 'python-api'
        APP_PORT = '8000'
        DOCKER_NETWORK = 'ci-network'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    echo "Branch: ${BRANCH_NAME}"
                    echo "Commit:"
                    git rev-parse --short HEAD
                '''
            }
        }

        stage('Preflight') {
            steps {
                sh '''
                    set -eu

                    git --version
                    python3 --version
                    python3 -m pip --version
                    docker --version
                    docker info

                    echo "Checking Docker network..."
                    docker network inspect "${DOCKER_NETWORK}"
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    set -eu

                    python3 -m venv .venv

                    .venv/bin/python -m pip install --upgrade pip

                    .venv/bin/python -m pip install -r requirements-dev.txt
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    set -eu

                    .venv/bin/python -m pytest -v
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    env.IMAGE_TAG = sh(
                        script: '''
                            BRANCH_TAG=$(printf '%s' "${BRANCH_NAME}" | tr '/' '-')
                            COMMIT_SHA=$(git rev-parse --short=12 HEAD)

                            echo "${BRANCH_TAG}-${BUILD_NUMBER}-${COMMIT_SHA}"
                        ''',
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    set -eu

                    echo "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"

                    docker build --pull \
                        -t "${IMAGE_NAME}:${IMAGE_TAG}" .
                '''
            }
        }

        stage('Deploy Locally') {
            when {
                branch 'main'
            }

            steps {
                sh '''
                    set -eu

                    echo "Deploying main branch..."

                    echo "Removing previous application container..."
                    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

                    echo "Starting new application container..."

                    docker run -d \
                        --name "${CONTAINER_NAME}" \
                        --restart unless-stopped \
                        --network "${DOCKER_NETWORK}" \
                        -p "${APP_PORT}:8000" \
                        "${IMAGE_NAME}:${IMAGE_TAG}"

                    docker ps --filter "name=${CONTAINER_NAME}"
                '''
            }
        }

        stage('Health Check') {
            when {
                branch 'main'
            }

            steps {
                sh '''
                    set -eu

                    python3 - <<'PY'
import time
import urllib.request

url = "http://python-api:8000/health"

for attempt in range(1, 16):
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            body = response.read().decode()

            if response.status == 200 and '"healthy"' in body:
                print(f"Application is healthy: {body}")
                break

            print(f"Unexpected response: {response.status}, {body}")

    except Exception as exc:
        print(f"Health check attempt {attempt}/15 failed: {exc}")

    time.sleep(2)
else:
    raise SystemExit("Application did not become healthy")
PY
                '''
            }
        }
    }

    post {
        success {
            echo "CI/CD pipeline completed successfully for ${BRANCH_NAME}"
            echo "Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
            
            script {
                if (env.BRANCH_NAME == 'main') {
                    echo "Application URL: http://localhost:${APP_PORT}"
                } else {
                    echo "Deployment skipped for non-main branch."
                }
            }
        }

        failure {
            echo "Pipeline failed for ${BRANCH_NAME}."
            echo "Review stage logs and container logs."

            script {
                if (env.BRANCH_NAME == 'main') {
                    sh 'docker logs "${CONTAINER_NAME}" || true'
                }
            }
        }

        always {
            echo "Pipeline execution completed."
        }
    }
}
