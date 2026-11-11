
$ErrorActionPreference = "Stop"

Write-Host "Starting Kubernetes bootstrap..." -ForegroundColor Cyan

# 1. Verify Kubernetes context
$context = kubectl config current-context

if ($context -ne "docker-desktop") {
    throw "Expected docker-desktop context. Current context: $context"
}

# 2. Verify cluster
kubectl get nodes

# 3. Apply RBAC resources
kubectl apply -f ./k8s/rbac/bootstrap.yaml

# 4. Generate ServiceAccount token
$token = (
    kubectl create token jenkins-deployer `
        -n jenkins `
        --duration=24h
).Trim()

if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Unable to generate ServiceAccount token"
}

# 5. Read cluster CA from Windows kubeconfig
$config = kubectl config view --raw --minify -o json |
    ConvertFrom-Json

$caData = $config.clusters[0].cluster.'certificate-authority-data'

if ([string]::IsNullOrWhiteSpace($caData)) {
    throw "Kubernetes CA certificate data not found."
}

# 6. Generate Jenkins kubeconfig
# The TLS server name remains 127.0.0.1 because
# that is the original, certificate-verified endpoint.
$kubeconfig = @"
apiVersion: v1
kind: Config
clusters:
  - name: docker-desktop
    cluster:
      server: https://host.docker.internal:53004
      certificate-authority-data: $caData
      tls-server-name: 127.0.0.1

users:
  - name: jenkins-deployer
    user:
      token: $token

contexts:
  - name: jenkins-context
    context:
      cluster: docker-desktop
      user: jenkins-deployer
      namespace: python-app

current-context: jenkins-context
"@

# 7. Save kubeconfig without printing credentials
$outputPath = Join-Path (Get-Location) "jenkins-kubeconfig.yaml"

[System.IO.File]::WriteAllText(
    $outputPath,
    $kubeconfig,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "Kubernetes bootstrap completed." -ForegroundColor Green
Write-Host "Generated kubeconfig: $outputPath"
Write-Host "Token validity requested: 24 hours"
