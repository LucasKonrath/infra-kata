pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
    - name: maven
      image: maven:3.9-eclipse-temurin-21
      command: ['cat']
      tty: true
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: ['sh','-c']
      args: ['sleep 3600']
      tty: true
    - name: helm
      # Switched image to include kubectl
      image: dtzar/helm-kubectl:3.14.0
      command: ['cat']
      tty: true
"""
    }
  }

  parameters {
    string(name: 'APP_NAME', defaultValue: 'sample-app', description: 'App / Helm release name')
    string(name: 'UPSTREAM_BASE_IMAGE', defaultValue: 'docker.io/library/eclipse-temurin:21-jre', description: 'Upstream public base image to mirror')
    string(name: 'MIRRORED_BASE_IMAGE', defaultValue: 'base/eclipse-temurin:21-jre', description: 'Internal mirrored base image path (suffix after registry host)')
    string(name: 'CHART_PATH', defaultValue: 'charts/app', description: 'Relative path to Helm chart within repo (searched if missing)')
    string(name: 'REGISTRY_HOST_OVERRIDE', defaultValue: '', description: 'Optional manual registry host:port override (takes precedence)')
    string(name: 'REGISTRY_NODEPORT', defaultValue: '32000', description: 'NodePort exposing the Minikube addon registry (must match infra)')
  }

  environment {
    KUBE_NAMESPACE = 'apps'
    // IMAGE_TAG will be computed dynamically
  }

  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Compute Image Tag') {
      steps {
        container('maven') { // any container with git available (mounted workspace)
          script {
            def sha = sh(script: 'git rev-parse --short=12 HEAD 2>/dev/null || echo none', returnStdout: true).trim()
            if (sha == 'none' || !sha) {
              sha = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()
            }
            env.IMAGE_TAG = sha + '-b' + env.BUILD_NUMBER
            echo "Computed IMAGE_TAG=${env.IMAGE_TAG}"
          }
        }
      }
    }

    stage('Resolve Registry Host') {
      steps {
        container('helm') {
          script {
            echo '--- Resolving registry host (debug) ---'
            sh 'kubectl -n kube-system get svc registry -o wide || true'
            sh 'kubectl get nodes -o wide || true'

            echo "DEBUG: Param REGISTRY_HOST_OVERRIDE='${params.REGISTRY_HOST_OVERRIDE}'"
            echo "DEBUG: Env VAR REGISTRY_HOST_OVERRIDE='${env.REGISTRY_HOST_OVERRIDE ?: ''}'"
            echo "DEBUG: Initial env.REGISTRY_HOST='${env.REGISTRY_HOST ?: '(null)'}'"

            def effectiveOverride = params.REGISTRY_HOST_OVERRIDE?.trim()
            if (!effectiveOverride) { effectiveOverride = env.REGISTRY_HOST_OVERRIDE?.trim() }
            echo "DEBUG: effectiveOverride='${effectiveOverride ?: ''}'"
            if (effectiveOverride) {
              effectiveOverride = effectiveOverride.replaceFirst(/^https?:\/\//,'')
              env.REGISTRY_HOST = effectiveOverride
              echo "Applied explicit override. env.REGISTRY_HOST=${env.REGISTRY_HOST}"
            } else {
              def tryCmd = { label, cmd ->
                def out = sh(script: cmd, returnStdout: true).trim()
                echo "Attempt ${label}: '${out}'"
                return out
              }
              def nodeIp = tryCmd('minikube ip', 'minikube ip 2>/dev/null || true')
              if (!nodeIp) { nodeIp = tryCmd('jsonpath internalIP', "kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}' 2>/dev/null || true") }
              if (!nodeIp) { nodeIp = tryCmd('wide column 6', '''kubectl get nodes -o wide 2>/dev/null | awk 'NR==2 {print $6}' || true''') }
              if (nodeIp) {
                env.REGISTRY_HOST = nodeIp + ':' + params.REGISTRY_NODEPORT
                echo "Auto-resolved registry host: ${env.REGISTRY_HOST}"
              } else {
                error 'Registry host could not be auto-resolved and no override provided.'
              }
            }
            if (!env.REGISTRY_HOST?.trim()) {
              error "Registry host not set after resolution logic (effectiveOverride='${effectiveOverride ?: ''}')."
            }
            echo "Final REGISTRY_HOST: ${env.REGISTRY_HOST}"
          }
        }
      }
    }

    stage('Mirror Base Image') {
      steps {
        echo "DEBUG: Using REGISTRY_HOST in mirror stage = ${env.REGISTRY_HOST}"
        container('kaniko') {
          sh """
cat > Dockerfile.mirror <<'EOF'
FROM ${params.UPSTREAM_BASE_IMAGE}
LABEL mirror.from=${params.UPSTREAM_BASE_IMAGE}
EOF
/kaniko/executor \
  --context=${WORKSPACE} \
  --dockerfile=${WORKSPACE}/Dockerfile.mirror \
  --destination=${env.REGISTRY_HOST}/${params.MIRRORED_BASE_IMAGE} \
  --insecure --insecure-pull
"""
        }
      }
    }

    stage('Build & Test') {
      steps { container('maven') { sh 'mvn -B test' } }
    }

    stage('Package & Dockerfile') {
      steps {
        echo "DEBUG: Using REGISTRY_HOST in package stage = ${env.REGISTRY_HOST}"
        container('maven') {
          sh 'mvn -B -DskipTests package'
          writeFile file: 'Dockerfile', text: """
FROM ${env.REGISTRY_HOST}/${params.MIRRORED_BASE_IMAGE}
WORKDIR /app
COPY target/*SNAPSHOT.jar app.jar
EXPOSE 8080 8081
ENTRYPOINT [\"java\",\"-jar\",\"/app/app.jar\"]
"""
        }
      }
    }

    stage('Build Image (Kaniko)') {
      steps {
        echo "DEBUG: Using REGISTRY_HOST in build image stage = ${env.REGISTRY_HOST} and IMAGE_TAG=${env.IMAGE_TAG}"
        container('kaniko') {
          sh "/kaniko/executor --context=${WORKSPACE} --dockerfile=${WORKSPACE}/Dockerfile --destination=${env.REGISTRY_HOST}/${params.APP_NAME}:${env.IMAGE_TAG} --destination=${env.REGISTRY_HOST}/${params.APP_NAME}:latest --insecure --insecure-pull"
        }
      }
    }

    stage('Resolve Chart') {
      steps {
        container('helm') {
          script {
            def defaultPath = "${WORKSPACE}/${params.CHART_PATH}"
            if (fileExists(defaultPath)) {
              env.CHART_DIR = defaultPath
            } else {
              def found = sh(script: "find ${WORKSPACE} -maxdepth 5 -type f -name Chart\\.yaml -print | head -1 || true", returnStdout: true).trim()
              if (found) {
                env.CHART_DIR = sh(script: "dirname ${found}", returnStdout: true).trim()
              } else {
                error "Helm chart not found at ${defaultPath}; provide CHART_PATH param or add chart to repo"
              }
            }
            echo "Using Helm chart directory: ${env.CHART_DIR}"
          }
        }
      }
    }

    stage('Verify Namespace') {
      steps {
        container('helm') {
          sh 'echo "(Non-blocking) Checking namespace access..."'
          sh 'kubectl get ns ${KUBE_NAMESPACE} 2>&1 || echo "Namespace check skipped / insufficient RBAC, continuing."'
        }
      }
    }

    stage('Deploy (Helm)') {
      steps {
        container('helm') {
          script {
            def imageRepo = "${env.REGISTRY_HOST}/${params.APP_NAME}"
            def tag = env.IMAGE_TAG ?: 'latest'
            echo "DEBUG: Preparing Helm deploy with imageRepo=${imageRepo} tag=${tag} chartDir=${env.CHART_DIR}"
            sh """
#!/bin/bash -e
set -o pipefail
echo "DEBUG: Deploy stage using imageRepo='${imageRepo}' TAG='${tag}' REGISTRY_HOST='${env.REGISTRY_HOST}' CHART_DIR='${env.CHART_DIR}'"
helm upgrade --install ${params.APP_NAME} ${env.CHART_DIR} -n ${env.KUBE_NAMESPACE} \
  --set app.name=${params.APP_NAME} \
  --set image.repository=${imageRepo} \
  --set image.tag=${tag} \
  --set image.pullPolicy=IfNotPresent
"""
          }
        }
      }
    }
  }

  post {
    success { echo 'Deployment successful.' }
    failure { echo 'Pipeline failed.' }
    always  { echo "Result: ${currentBuild.currentResult}" }
  }
}
