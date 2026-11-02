# Lab notes

Fill this in while you work and commit it. Each section lists the evidence worth capturing; save screenshots in `docs/screenshots/` using the file names below and they will render here.

## 0. Environment

```bash
lsb_release -d && uname -r && nproc && free -h | head -n 2
docker --version && docker compose version
```

| Item | Value |
|------|-------|
| Host OS | |
| CPU / RAM | |
| Date | |

## 1. Stack up

Evidence: output of `./scripts/verify-stack.sh` and `docker compose ps`.

![stack](screenshots/01-verify-stack.png)

Notes / problems hit:

## 2. SonarQube setup

Evidence: first login, token creation, empty project list.

![sonarqube](screenshots/02-sonarqube-token.png)

## 3. Jenkins setup

Evidence: credentials page (`sonar-token`), SonarQube server config, pipeline job config.

![jenkins-config](screenshots/03-jenkins-config.png)

## 4. First green run

Evidence: Stage View, console output of the Trivy stages, SonarQube dashboard, `curl` of the deployed app.

![stage-view](screenshots/04-stage-view.png)
![sonar-dashboard](screenshots/05-sonar-dashboard.png)
![trivy-report](screenshots/06-trivy-report.png)

```bash
curl -s http://localhost:5000/health
```

## 5. Failure experiments

| Experiment | Stage that failed | Finding | Screenshot |
|------------|-------------------|---------|------------|
| Flask 2.2.4 | Trivy fs | | `07-trivy-fail.png` |
| `eval()` in a route | SonarQube / ruff | | `08-sonar-fail.png` |
| Root container | Trivy fs (misconfig) | | |

## 6. GitHub Actions

Evidence: green run of `CI`, the job graph, uploaded `trivy-reports` artifact, Security -> Code scanning (public repos).

![actions](screenshots/09-actions-run.png)

## 7. What I learned

-

## 8. Improvements / next steps

-
