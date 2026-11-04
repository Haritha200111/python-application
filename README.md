
# Python API – Jenkins CI/CD Demo

A small FastAPI application for learning a practical Jenkins pipeline:
checkout → preflight → install dependencies → test → Docker build → deploy → health check.

## 1. Local requirements

- Python 3.10+
- pip
- Docker Desktop (for the Docker test)

## 2. Run locally on Windows PowerShell

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
python -m pytest -v
uvicorn app.main:app --reload
```

Open:
- API: http://127.0.0.1:8000/
- Health: http://127.0.0.1:8000/health
- API docs: http://127.0.0.1:8000/docs

## 3. Run with Docker locally

```powershell
docker build -t python-api:local .
docker run --rm -p 8000:8000 --name python-api-local python-api:local
```

In another terminal:

```powershell
Invoke-RestMethod http://localhost:8000/health
```

## 4. Push to GitHub

Create an empty GitHub repository named `python-api`.

```powershell
git init
git add .
git commit -m "Initial FastAPI application"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/python-api.git
git push -u origin main
```

Replace `YOUR-USERNAME` with your GitHub username.

## 5. Configure Jenkins

Install the Jenkins GitHub plugin, then create a Pipeline job named
`python-api-cicd`.

Under Pipeline:
- Definition: Pipeline script from SCM
- SCM: Git
- Repository URL: your GitHub repository URL
- Credentials: select a Jenkins credential if the repository is private
- Branch specifier: `*/main`
- Script Path: `Jenkinsfile`

The Jenkinsfile enables the `githubPush()` trigger. In the job's build triggers,
enable **GitHub hook trigger for GITScm polling** if it is not enabled by the
Jenkinsfile. In GitHub, add a repository webhook pointing to
`https://<your-jenkins-url>/github-webhook/`, set the content type to
`application/json`, and subscribe to push events. Ensure Jenkins is reachable
from GitHub.

Run **Build Now** once to verify the job and webhook configuration. The webhook
starts builds on pushes; Jenkins still uses Git SCM to retrieve the repository
and check out the `Jenkinsfile` and application source.

## 6. Jenkins agent requirements

The Jenkinsfile targets a node labelled `python-agent`. That node must provide:
- Git
- Python 3 and venv support
- pip
- Docker CLI
- Access to a Docker daemon
- Network access to the deployed application's health endpoint

The controller does not need these tools if a separate agent provides them.

Important: access to the Docker socket is highly privileged. Only use it with a trusted local learning agent. If the agent is in a separate container/network namespace, `127.0.0.1:8000` in the health-check stage may not reach the Docker host's published port; adjust the URL or run the check from a host-reachable location.

## 7. Pipeline stages

1. Checkout – fetch source from Git.
2. Preflight – verify tools and Docker daemon access.
3. Install Dependencies – create a virtual environment and install test dependencies.
4. Unit Tests – run pytest.
5. Build Docker Image – build a versioned image using the Jenkins build number.
6. Deploy Locally – replace the demo container.
7. Health Check – call `/health`.

This is a local learning deployment, not a production deployment strategy. Production systems normally add a registry, immutable image digests, controlled environments, secrets management and rollback.
