# 🔧 Upgrading Existing `kubectl` and `eksctl` in Code-Server (Amazon Linux)

This guide ensures that **older versions** of `kubectl` and `eksctl` are properly **replaced with the latest stable releases** compatible with Amazon EKS.

---

## 📌 Prerequisites

* You're logged into the code-server IDE as `ec2-user`.
* You have `sudo` access.
* Internet access is enabled.

---

## ⬆️ Step 1: Upgrade `kubectl` (Official Amazon EKS Version)

### 🔹 Remove older version (if exists):

```bash
sudo rm -f /usr/local/bin/kubectl
```

> This avoids version conflicts or stale binary issues.

### 🔹 Download the EKS-recommended `kubectl`:

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2025-05-01/bin/linux/amd64/kubectl
```

> Change `amd64` to `arm64` if you're using an ARM-based system.

### 🔹 Set permissions and move to path:

```bash
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### 🔹 Validate version:

```bash
kubectl version --client
```

---

## ⬆️ Step 2: Upgrade `eksctl` (Latest GitHub Release)

### 🔹 Remove older version (if exists):

```bash
sudo rm -f /usr/local/bin/eksctl
```

### 🔹 Set architecture and platform:

```bash
ARCH=amd64    # Use 'arm64' or 'armv6' for ARM
PLATFORM=$(uname -s)_$ARCH
```

### 🔹 Download the latest release:

```bash
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
```

### 🔹 (Optional) Verify checksum:

```bash
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
```

### 🔹 Extract, move, and clean up:

```bash
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/
rm eksctl_$PLATFORM.tar.gz
```

### 🔹 Confirm the version:

```bash
eksctl version
```

---

## ✅ Final Verification

```bash
which kubectl
which eksctl
kubectl version --client
eksctl version
```

---

