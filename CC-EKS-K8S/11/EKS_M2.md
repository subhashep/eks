# 🧪 **Lab: Upgrading an Amazon EKS Cluster to a Specific Version (Control Plane, Nodegroup, Addons)**

---

## **Lab Objectives**

* Understand EKS version upgrades and why they’re needed
* Upgrade the EKS control plane **to a specific version**
* Upgrade nodegroups safely to the same target version
* Upgrade key EKS addons (CNI, CoreDNS, kube-proxy)
* Validate your upgrade at every stage

---

## **0️⃣ Prerequisites**

* Your cluster is deployed using `ep33-eks-02.yaml`
* `eksctl`, `kubectl`, and `aws` CLI are installed and configured
* You have AWS permissions to update clusters/nodegroups

---

## **1️⃣ Planning and Pre-Checks**

### **What is an EKS Upgrade?**

Kubernetes versions are updated frequently. AWS only supports the last 4 versions at a time.
You must upgrade clusters regularly to avoid falling out of support and missing important updates.

### **Pre-Check Your Cluster**

```bash
eksctl get cluster --region ${AWS_REGION}
eksctl get nodegroup --cluster ep33-eks-02 --region ${AWS_REGION}
```

* This tells you your current Kubernetes and nodegroup versions.
* Review the [EKS supported versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) for your region.

---

## **2️⃣ Upgrading the EKS Control Plane to a Specific Version**

### **Why upgrade the control plane first?**

The control plane is the “brain” of Kubernetes (API, scheduler, etc).
It must be upgraded **before** any node groups.

### **Upgrade Command**

To upgrade to a specific version (replace `<TARGET_VERSION>` with the desired version, e.g. `1.29`):

```bash
eksctl upgrade cluster \
  --name ep33-eks-02 \
  --region ${AWS_REGION} \
  --version <TARGET_VERSION>
```

* Example: To upgrade to Kubernetes 1.29:

  ```bash
  eksctl upgrade cluster --name ep33-eks-02 --region ${AWS_REGION} --version 1.29
  ```
* You **must upgrade one minor version at a time** (e.g., 1.28 → 1.29, then 1.29 → 1.30).

---

## **3️⃣ Upgrade Managed Node Groups to a Specific Version**

### **Why?**

Node groups are your Kubernetes “workers” (EC2s) and must match or closely follow the control plane’s version.

### **How to Upgrade**

```bash
eksctl get nodegroup --cluster ep33-eks-02 --region ${AWS_REGION} -o yaml
eksctl upgrade nodegroup \
  --cluster ep33-eks-02 \
  --name ep33-ng-02 \
  --region ${AWS_REGION} \
  --kubernetes-version <TARGET_VERSION> \
  
```

* Replace `<TARGET_VERSION>` with the same version you used for the control plane (e.g., `1.29`).

---

## **4️⃣ Upgrade EKS Addons**

EKS Addons like `vpc-cni`, `coredns`, and `kube-proxy` must match the new Kubernetes version.

**How to Upgrade Addons**
Absolutely! Here is your **corrected and enhanced EKS Upgrade Lab (Markdown, copy-paste ready)** with proper instructions for **finding and using the correct addon version strings** for AWS CLI upgrades.
**Key improvement:** No longer use the K8s version (like `1.29`) as the addon version; always fetch the actual compatible version string!

---

# 🧪 EKS Upgrade Lab: Control Plane, Nodegroups, and Addons (2025 Edition, Corrected)

---

## 🎯 **Lab Objectives**

* Safely upgrade EKS clusters, nodegroups, and managed addons
* Find the correct versions for each component
* Use best-practice scripting and troubleshooting

---

## 0️⃣ **Pre-check Cluster State**

```bash
eksctl get cluster --region ${AWS_REGION}
eksctl get nodegroup --cluster ep33-eks-02 --region ${AWS_REGION}
kubectl get nodes -o wide
aws eks list-addons --cluster-name ep33-eks-02 --region ${AWS_REGION}
```

---

## 1️⃣ **Plan the Upgrade Path**

* **Can only upgrade one minor version at a time (e.g., 1.28 → 1.29).**
* Control plane → nodegroup → addons (in that order).
* Addon versions are **not** K8s versions—**must discover them first!**

---

## 2️⃣ **Upgrade Control Plane**

```bash
eksctl upgrade cluster \
  --name ep33-eks-02 \
  --region ${AWS_REGION} \
  --version <TARGET_VERSION>
```

* Replace `<TARGET_VERSION>` with the next minor version.

---

## 3️⃣ **Upgrade Nodegroup(s)**

```bash
eksctl get nodegroup --cluster ep33-eks-02 --region ${AWS_REGION} -o yaml | grep version
eksctl upgrade nodegroup \
  --cluster ep33-eks-02 \
  --name ep33-ng-02 \
  --region ${AWS_REGION} \
  --kubernetes-version <TARGET_VERSION>
```

* **No `--approve` flag.**

---

## 4️⃣ **Upgrade Managed Addons (AWS CLI)**

### **a. List Addons**

```bash
aws eks list-addons --cluster-name ep33-eks-02 --region ${AWS_REGION}
```

### **b. Discover the Correct Addon Version for Your Cluster**

For each addon (replace `<ADDON-NAME>` and `<K8S_VERSION>`):

```bash
aws eks describe-addon-versions \
  --addon-name <ADDON-NAME> \
  --kubernetes-version <K8S_VERSION> \
  --region ${AWS_REGION}
```

* `<K8S_VERSION>` is your EKS cluster version, e.g., `1.29`.
* Look for `"addonVersion": "..."` in the output; **use the most recent/stable version**.

**Sample one-liner to fetch the latest:**

```bash
aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version 1.29 --region ${AWS_REGION} \
  | grep addonVersion | head -1 | cut -d '"' -f4
```

---

### **c. Upgrade the Addon with the Correct Version String**

```bash
aws eks update-addon \
  --cluster-name ep33-eks-02 \
  --addon-name <ADDON-NAME> \
  --addon-version <LATEST_VERSION_STRING> \
  --region ${AWS_REGION}
```

**Example:**

```bash
aws eks update-addon \
  --cluster-name ep33-eks-02 \
  --addon-name vpc-cni \
  --addon-version v1.19.6-eksbuild.1 \
  --region ${AWS_REGION}
```

*(repeat for coredns, kube-proxy, metrics-server as appropriate)*

---

### **d. Validate Addon Status**

```bash
aws eks describe-addon --cluster-name ep33-eks-02 --addon-name <ADDON-NAME> --region ${AWS_REGION}
```

* Should show latest version and status ACTIVE.

---

## 5️⃣ **Validate All Upgrades**

```bash
kubectl get nodes -o wide
eksctl get cluster --region ${AWS_REGION}
eksctl get nodegroup --cluster ep33-eks-02 --region ${AWS_REGION} -o yaml | grep version
aws eks list-addons --cluster-name ep33-eks-02 --region ${AWS_REGION}
```

---

## 6️⃣ **Automated Bash Script Example (Addons Only)**

```bash
for addon in vpc-cni coredns kube-proxy metrics-server; do
  latest=$(aws eks describe-addon-versions --addon-name $addon --kubernetes-version 1.29 --region ${AWS_REGION} \
    | grep addonVersion | head -1 | cut -d '"' -f4)
  echo "Upgrading $addon to $latest"
  aws eks update-addon --cluster-name ep33-eks-02 --addon-name $addon --addon-version $latest --region ${AWS_REGION}
done
```

*Replace `1.29` with your actual K8s version if different.*

---

## 7️⃣ **Troubleshooting Table**

| Problem                                    | Solution                                    |
| ------------------------------------------ | ------------------------------------------- |
| `Addon version specified is not supported` | Use real addon version string (see Step 4b) |
| `Cannot skip versions`                     | Upgrade one minor version at a time         |
| Nodegroup version missing                  | Use `-o yaml`/`describe`                    |
| Addon upgrade not supported in eksctl      | Use AWS CLI method above                    |

---

## 8️⃣ **Textual Upgrade Flow**

```
[PRE-CHECK] → [CONTROL PLANE UPGRADE] → [NODEGROUP UPGRADE] → [ADDON UPGRADE (using actual version strings)] → [VALIDATION]
```

---

## 📝 **Key Reminders**

* **Never use the K8s version as the addon version.** Always fetch real version strings!
* **Upgrade one minor version at a time**—for both control plane and nodegroups.
* **Order always matters:** Control plane → nodegroups → addons.

---

**This version of the lab is ready to distribute and avoids ALL common pitfalls. If you need a PDF/Word or want to add actual command outputs for illustration, just ask!**

```bash
eksctl get addon --cluster ep33-eks-02 --region ${AWS_REGION}

eksctl upgrade addon --name vpc-cni --cluster ep33-eks-02 --region ${AWS_REGION} --approve
eksctl upgrade addon --name coredns --cluster ep33-eks-02 --region ${AWS_REGION} --approve
eksctl upgrade addon --name kube-proxy --cluster ep33-eks-02 --region ${AWS_REGION} --approve
```

* Run `eksctl get addon ...` to check status after each upgrade.

---

## **5️⃣ Validation**

**Check Everything!**

```bash
kubectl get nodes
kubectl get pods --all-namespaces
eksctl get addon --cluster ep33-eks-02 --region ${AWS_REGION}
```

* **Nodes should all show the new version.**
* **Pods should be Running and healthy.**
* **All addons should show the latest compatible version.**

---

## **6️⃣ Troubleshooting Tips**

* If a nodegroup upgrade fails, re-run the upgrade or create a new nodegroup.
* Control plane upgrades **cannot** be rolled back—if you run into issues, you must restore from backup or re-create the cluster.
* Always test your applications after upgrading!
* Check [AWS EKS Upgrade docs](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html) for any version-specific notes.

---

## **7️⃣ Cleanup (Optional)**

If you’re running this as a lab, you can clean up everything to avoid AWS charges:

```bash
eksctl delete cluster --name ep33-eks-02 --region ${AWS_REGION}
```

---

# **Summary Flow**

1. **Pre-check:** Know your current cluster and nodegroup versions.
2. **Upgrade control plane:**
   `eksctl upgrade cluster --name ep33-eks-02 --region ${AWS_REGION} --version <TARGET_VERSION>`
3. **Upgrade nodegroups:**
   `eksctl upgrade nodegroup --cluster ep33-eks-02 --name ep33-ng-02 --region ${AWS_REGION} --kubernetes-version <TARGET_VERSION> --approve`
4. **Upgrade all addons:**
   `eksctl upgrade addon ...`
5. **Validate:** Check nodes, pods, and addons.
6. **Troubleshoot or clean up** as needed.

---

**Tip:**
Repeat the upgrade steps for each minor version, one at a time, until you reach your desired version.

---
