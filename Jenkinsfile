pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '5'))
    }

    // Parameters appear in "Build with Parameters" after the first run.
    parameters {
        string(name: 'TRIVY_SEVERITY', defaultValue: 'HIGH,CRITICAL',
               description: 'Trivy fails the build on findings with these severities')
        booleanParam(name: 'DEPLOY', defaultValue: true,
                     description: 'Deploy the container on this host after every gate passes')
    }

    environment {
        APP_NAME       = 'devsecops-demo'
        IMAGE          = "devsecops-demo:${env.BUILD_NUMBER}"
        APP_PORT       = '5000'
        DOCKER_NETWORK = 'devsecops'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                sh 'mkdir -p reports'
            }
        }

        stage('Lint & unit tests') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --quiet --upgrade pip
                    pip install --quiet -r requirements-dev.txt
                    ruff check .
                    pytest --junitxml=reports/junit.xml \
                           --cov --cov-report=xml:coverage.xml --cov-report=term
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        // Code quality + SAST. The scanner blocks until SonarQube has computed the
        // quality gate and exits non-zero if the gate fails (no webhook needed).
        stage('SonarQube: analysis + quality gate') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.host.url="$SONAR_HOST_URL" \
                          -Dsonar.token="$SONAR_AUTH_TOKEN" \
                          -Dsonar.qualitygate.wait=true \
                          -Dsonar.qualitygate.timeout=300
                    '''
                }
            }
        }

        // Dependencies (requirements.txt), hard-coded secrets and Dockerfile misconfigurations.
        stage('Trivy: filesystem scan') {
            steps {
                sh '''
                    SKIP="**/.venv,**/reports,**/.scannerwork,**/.pytest_cache,**/.ruff_cache"
                    # 1) report (never fails)
                    trivy fs --scanners vuln,secret,misconfig --severity "$TRIVY_SEVERITY" \
                        --ignore-unfixed --skip-dirs "$SKIP" \
                        --format json --output reports/trivy-fs.json .
                    # 2) gate (fails the build)
                    trivy fs --scanners vuln,secret,misconfig --severity "$TRIVY_SEVERITY" \
                        --ignore-unfixed --skip-dirs "$SKIP" --exit-code 1 .
                '''
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --pull -t "$IMAGE" -t "$APP_NAME:latest" .'
            }
        }

        // OS packages + Python libraries inside the image we are about to ship.
        stage('Trivy: image scan') {
            steps {
                sh '''
                    # 1) reports (never fail)
                    trivy image --severity "$TRIVY_SEVERITY" --ignore-unfixed \
                        --format template --template "@/opt/trivy/contrib/html.tpl" \
                        --output reports/trivy-image.html "$IMAGE"
                    trivy image --severity "$TRIVY_SEVERITY" --ignore-unfixed \
                        --format json --output reports/trivy-image.json "$IMAGE"
                    # 2) gate (fails the build)
                    trivy image --severity "$TRIVY_SEVERITY" --ignore-unfixed --exit-code 1 "$IMAGE"
                '''
            }
        }

        // "Deployment host" = this same server: the container is started through the host Docker socket.
        stage('Deploy (this host)') {
            when { expression { return params.DEPLOY } }
            steps {
                sh '''
                    docker network inspect "$DOCKER_NETWORK" >/dev/null
                    docker rm -f "$APP_NAME" >/dev/null 2>&1 || true
                    docker run -d --name "$APP_NAME" --restart unless-stopped \
                        --network "$DOCKER_NETWORK" -p "$APP_PORT:5000" "$IMAGE"

                    # Smoke test from inside the Docker network (Jenkins is not on the host's localhost).
                    for i in $(seq 1 20); do
                        if curl -fsS "http://$APP_NAME:5000/health"; then
                            echo
                            echo "Deployed $IMAGE -> http://localhost:$APP_PORT"
                            break
                        fi
                        if [ "$i" -eq 20 ]; then
                            docker logs "$APP_NAME"
                            exit 1
                        fi
                        sleep 2
                    done

                    # Housekeeping: keep the 3 newest build images.
                    docker images "$APP_NAME" --format '{{.Tag}}' | grep -E '^[0-9]+$' \
                        | sort -rn | tail -n +4 \
                        | xargs -r -I{} docker rmi "$APP_NAME:{}" || true
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**, coverage.xml', allowEmptyArchive: true
        }
        success {
            echo "Pipeline passed: tests, SonarQube quality gate and Trivy scans are green."
        }
        failure {
            echo "Pipeline failed: check which gate stopped it (tests, SonarQube or Trivy)."
        }
    }
}
