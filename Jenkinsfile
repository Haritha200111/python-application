
pipeline {
    agent {
        // Agent must provide Git, Python 3, pip, Docker CLI and Docker daemon access.
        label 'python-agent'
    }

    triggers {
        githubPush()
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'python-api'
        CONTAINER_NAME = 'python-api'
        APP_PORT = '8000'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git rev-parse --short HEAD'
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
                sh '''
                    set -eu
                    docker build --pull                       -t "${IMAGE_NAME}:${BUILD_NUMBER}"                       -t "${IMAGE_NAME}:latest" .
                '''
            }
        }

        stage('Deploy Locally') {
            steps {
                sh '''
                    set -eu
                    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
                    docker run -d                       --name "${CONTAINER_NAME}"                       --restart unless-stopped                       -p "${APP_PORT}:8000"                       "${IMAGE_NAME}:${BUILD_NUMBER}"
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    set -eu
                    python3 - <<'PY'
import time
import urllib.request

url = "http://127.0.0.1:8000/health"
for attempt in range(1, 16):
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            body = response.read().decode()
            if response.status == 200 and '"healthy"' in body:
                print(f"Application is healthy: {body}")
                break
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
            echo 'CI/CD pipeline completed successfully.'
            echo 'Application URL: http://localhost:8000'
        }
        failure {
            echo 'Pipeline failed. Review stage logs and container logs.'
            sh 'docker logs "${CONTAINER_NAME}" || true'
        }
    }
}
