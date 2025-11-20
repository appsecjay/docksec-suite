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

