pipeline {
  agent any
  options { timestamps() }
  environment {
    APP_NAME = credentials('APP_NAME') ?: env.JOB_NAME
    KUBE_NAMESPACE = 'apps'
    CHART_PATH = 'charts/app'
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Build & Test') {
      steps {
        sh 'mvn -B -Dmaven.test.failure.ignore=false test'
      }
      post {
        always { junit '**/target/surefire-reports/*.xml' }
      }
    }
    stage('Package (Optional)') {
      when { expression { fileExists('pom.xml') } }
      steps {
        sh 'mvn -B package -DskipTests'
      }
    }
    stage('Deploy') {
      steps {
        script {
          sh "helm upgrade --install ${env.APP_NAME} ${CHART_PATH} -n ${KUBE_NAMESPACE} --create-namespace --set app.name=${env.APP_NAME}"
        }
      }
    }
  }
  post {
    failure { echo 'Pipeline failed.' }
    success { echo 'Deployment successful.' }
  }
}
