# 💥 DockSec Suite

**One-command Docker image security scanner**  
Runs: **Trivy + Dockle + Falco (runtime)**  
Author: AppsecJay

---

## 🚀 Overview

DockSec Suite is a **portable, interactive Docker/container security toolkit** that:

- Pulls Docker images (from local or registry)
- Runs **Trivy** for vulnerabilities
- Runs **Dockle** for Docker CIS best practices
- Runs **Falco** for basic runtime monitoring (via Falco container)
- Generates a **combined CSV** report for all images
- Produces **per-image JSON/TXT** outputs
- Cleans up images locally when done

Useful for:

- Security assessments of public images
- Pre-production checks before using images in corporate environments
- DevSecOps pipelines
- Red Team / Blue Team validation

---

## ✅ Features

- 🐳 Supports any Docker image (public or local)
- 🔎 Trivy: CVEs, vulnerable packages, versions, links
- 🛡 Dockle: CIS-DI checks & bad practices
- 👀 Falco: runtime behaviour monitor via privileged container
- 📊 Combined CSV for all images
- 🧹 Local image cleanup after scan
- 🔁 Supports:
  - one image
  - multiple images
  - file-based list

---

## 📦 Requirements

- **Docker**
- **Trivy**
- **Dockle**
- **jq**
- Linux environment (tested with Kali/Debian/Ubuntu)

Example installation (Debian/Ubuntu/Kali style):

```bash
sudo apt update
sudo apt install -y docker.io jq

# Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# Dockle (one example; use your preferred method)
sudo snap install dockle || echo "Or install dockle via GitHub releases: https://github.com/goodwithtech/dockle"

# Ensure Docker is running
sudo systemctl enable --now docker

# example runing script:
└─# ./docksec.sh                 
==============================================
           DOCKSEC - FULL SECURITY SCAN
==============================================

How do you want to provide Docker images?
  1) Enter ONE image manually
  2) Enter MULTIPLE images manually
  3) Provide a FILE with one image per line

Select option (1/2/3): 1
Enter Docker image (e.g. python:3.12): python:3.12
[+] Starting Falco runtime monitor container...
[+] Falco started.

==============================================
          PROCESSING IMAGE: python:3.12
==============================================
[+] Pulling image from registry...
3.12: Pulling from library/python
53c88f1dfeb7: Pull complete 
eae668646f44: Pull complete 
ff2e6e687b6c: Pull complete 
7c40a3faff76: Pull complete 
ef75e1766b83: Pull complete 
858443e1534f: Pull complete 
f88c3859cc57: Pull complete 
Digest: sha256:2b075cba87fcf51f14e6be18f83f209fb2013d72362ec874aed7d01933253e8b
Status: Downloaded newer image for python:3.12
docker.io/library/python:3.12
[+] Running Trivy...
2025-11-20T02:19:46-05:00       INFO    [vulndb] Need to update DB
2025-11-20T02:19:46-05:00       INFO    [vulndb] Downloading vulnerability DB...
2025-11-20T02:19:46-05:00       INFO    [vulndb] Downloading artifact...        repo="mirror.gcr.io/aquasec/trivy-db:2"
75.42 MiB / 75.42 MiB [------------------------------------------------------------------------------------------------------------------------------------] 100.00% 13.29 MiB p/s 5.9s
2025-11-20T02:19:54-05:00       INFO    [vulndb] Artifact successfully downloaded       repo="mirror.gcr.io/aquasec/trivy-db:2"
2025-11-20T02:19:54-05:00       INFO    [vuln] Vulnerability scanning is enabled
2025-11-20T02:19:54-05:00       INFO    Detected OS     family="debian" version="13.2"
2025-11-20T02:19:54-05:00       INFO    [debian] Detecting vulnerabilities...   os_version="13" pkg_num=469
2025-11-20T02:19:54-05:00       INFO    Number of language-specific files       num=1
2025-11-20T02:19:54-05:00       INFO    [python-pkg] Detecting vulnerabilities...
2025-11-20T02:19:54-05:00       WARN    Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/v0.67/docs/scanner/vulnerability#severity-selection for details.
[+] Adding Trivy results to combined CSV...
[+] Running Dockle...
[+] Starting short-lived container for Falco runtime check...
[+] Removing image locally to save disk...
[+] Stopping Falco and saving logs...

==============================================
           DOCKSEC SCAN COMPLETED
==============================================
Combined CSV report : reports/combined/docksec_all_images.csv
Per-image Trivy JSON: reports/per-image/trivy_*.json
Per-image Dockle txt: reports/per-image/dockle_*.txt
Falco runtime log   : reports/falco_runtime.log

All images processed and local copies removed.
==============================================


