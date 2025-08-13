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
    string(name: 'REGISTRY_NODEPORT', defaultValue: '30050', description: 'NodePort exposed by registry service')
    booleanParam(name: 'RESOLVE_MINIKUBE_IP', defaultValue: true, description: 'Auto-detect Minikube IP for registry host')
    string(name: 'REGISTRY_HOST_OVERRIDE', defaultValue: '', description: 'Optional full registry host:port to use (takes precedence)')
  }

  environment {
    KUBE_NAMESPACE = 'apps'
    REGISTRY_HOST  = 'registry.infra.svc.cluster.local:5000' // placeholder; will be replaced
  }

  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Resolve Registry Host') {
      steps {
        container('helm') {
          script {
            if (params.REGISTRY_HOST_OVERRIDE?.trim()) {
              env.REGISTRY_HOST = params.REGISTRY_HOST_OVERRIDE.trim()
              echo "Using explicit REGISTRY_HOST_OVERRIDE: ${env.REGISTRY_HOST}"
            } else if (params.RESOLVE_MINIKUBE_IP) {
              def ip = sh(script: 'minikube ip 2>/dev/null || true', returnStdout: true).trim()
              if(!ip) {
                ip = sh(script: 'kubectl get node -o jsonpath="{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}"', returnStdout: true).trim()
              }
              if(!ip) { error 'Could not resolve Minikube IP and no override provided.' }
              env.REGISTRY_HOST = ip + ':' + params.REGISTRY_NODEPORT
              echo "Resolved registry host (NodeIP:NodePort): ${env.REGISTRY_HOST}"
            } else {
              echo "WARNING: Using default internal DNS registry host ${env.REGISTRY_HOST} (may fail for image pulls). Provide REGISTRY_HOST_OVERRIDE or enable RESOLVE_MINIKUBE_IP." 
            }
          }
        }
      }
    }

    stage('Mirror Base Image') {
      steps {
        container('kaniko') {
          script {
            if (!params.MIRRORED_BASE_IMAGE?.trim()) {
              error 'MIRRORED_BASE_IMAGE parameter is empty'
            }
            echo "Mirroring ${params.UPSTREAM_BASE_IMAGE} -> ${env.REGISTRY_HOST}/${params.MIRRORED_BASE_IMAGE} (insecure)"
          }
          sh """
cat > Dockerfile.mirror <<'EOF'
FROM ${params.UPSTREAM_BASE_IMAGE}
LABEL mirror.from=${params.UPSTREAM_BASE_IMAGE}
EOF
/kaniko/executor \
  --context=${WORKSPACE} \
  --dockerfile=${WORKSPACE}/Dockerfile.mirror \
  --destination=${REGISTRY_HOST}/${params.MIRRORED_BASE_IMAGE} \
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
        container('maven') {
          sh 'mvn -B -DskipTests package'
          writeFile file: 'Dockerfile', text: """
FROM ${REGISTRY_HOST}/${params.MIRRORED_BASE_IMAGE}
WORKDIR /app
COPY target/*SNAPSHOT.jar app.jar
EXPOSE 8080 8081
ENTRYPOINT [\"java\",\"-jar\",\"/app/app.jar\"]
"""
          echo "Generated Dockerfile using base image ${REGISTRY_HOST}/${params.MIRRORED_BASE_IMAGE}";
        }
      }
    }

    stage('Build Image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
/kaniko/executor \
  --context=${WORKSPACE} \
  --dockerfile=${WORKSPACE}/Dockerfile \
  --destination=${REGISTRY_HOST}/${APP_NAME}:latest \
  --insecure --insecure-pull
'''
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
          sh 'echo PWD=$(pwd) WORKSPACE=${WORKSPACE} && ls -1 ${WORKSPACE} || true'
          sh 'helm upgrade --install ' + params.APP_NAME + ' ' + '${CHART_DIR}' + ' -n ' + KUBE_NAMESPACE + ' ' + \
             '--set app.name=' + params.APP_NAME + ' --set image.repository=' + '${REGISTRY_HOST}/' + params.APP_NAME + ' --set image.tag=latest --set image.pullPolicy=IfNotPresent'
          echo "Deployed image ${REGISTRY_HOST}/${params.APP_NAME}:latest"
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
