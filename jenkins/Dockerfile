FROM jenkins/jenkins:lts-jdk21

ARG TRIVY_VERSION=0.76.1
ARG SONAR_SCANNER_VERSION=8.1.0.6389

USER root

# Base tooling, Python (unit tests) and the Docker CLI.
# The CLI talks to the HOST daemon through the mounted /var/run/docker.sock.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg unzip python3 python3-venv \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && . /etc/os-release \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

# Trivy: download the release tarball and verify its SHA-256 before installing.
# The tarball also ships contrib/*.tpl (HTML report template used by the Jenkinsfile).
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) arch="Linux-64bit" ;; \
      arm64) arch="Linux-ARM64" ;; \
      *) echo "Unsupported architecture" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}"; \
    file="trivy_${TRIVY_VERSION}_${arch}.tar.gz"; \
    curl -fsSLo /tmp/trivy.tgz "${base}/${file}"; \
    curl -fsSLo /tmp/trivy.sums "${base}/trivy_${TRIVY_VERSION}_checksums.txt"; \
    expected="$(awk -v f="${file}" '$2 == f {print $1}' /tmp/trivy.sums)"; \
    test -n "${expected}"; \
    echo "${expected}  /tmp/trivy.tgz" | sha256sum -c -; \
    mkdir -p /opt/trivy; \
    tar -xzf /tmp/trivy.tgz -C /opt/trivy; \
    ln -s /opt/trivy/trivy /usr/local/bin/trivy; \
    rm -f /tmp/trivy.tgz /tmp/trivy.sums

# SonarScanner CLI (generic build, uses the JDK already present in this image).
RUN set -eux; \
    curl -fsSLo /tmp/scanner.zip "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip"; \
    top="$(unzip -Z1 /tmp/scanner.zip | head -n 1 | cut -d/ -f1)"; \
    unzip -q /tmp/scanner.zip -d /opt; \
    mv "/opt/${top}" /opt/sonar-scanner; \
    ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner; \
    rm -f /tmp/scanner.zip

# Persistent Trivy vulnerability-DB cache (mounted as the trivy_cache volume).
ENV TRIVY_CACHE_DIR=/var/trivy-cache \
    TRIVY_NO_PROGRESS=true
RUN mkdir -p /var/trivy-cache && chown jenkins:jenkins /var/trivy-cache

USER jenkins

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=5 \
  CMD curl -fsS http://localhost:8080/login -o /dev/null || exit 1
