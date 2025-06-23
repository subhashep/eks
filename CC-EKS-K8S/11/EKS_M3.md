# **Amazon EKS Add-on Upgrade: Expert Guide**

---

## **1. Why Upgrade EKS Add-ons?**

EKS add-ons are core Kubernetes operational components, such as:

* **VPC CNI** (`vpc-cni`)
* **CoreDNS**
* **kube-proxy**
* **Amazon EBS CSI Driver**
* **Amazon EFS CSI Driver**
* **metrics-server** (if installed as an add-on)
* Others (as released by AWS)

**Reasons to upgrade:**

* **Security:** Add-ons regularly receive security patches for discovered vulnerabilities.
* **Compatibility:** New Kubernetes versions require compatible versions of add-ons.
* **Performance:** Upgrades can bring significant performance improvements and bug fixes.
* **New Features:** Latest add-ons introduce features and configuration options critical for modern workloads.
* **AWS Recommendations:** AWS may require minimum versions for support or for new EKS features to work.

---

## **2. Pre-upgrade Considerations**

### **A. Read Release Notes**

* **AWS Release Notes:** Check the [official add-on documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html) and release notes for your cluster version and add-on type.
* **Kubernetes Upstream Notes:** Review [upstream project releases](https://github.com/aws/amazon-vpc-cni-k8s/releases), especially for CNI, CoreDNS, kube-proxy, etc.

### **B. Compatibility Matrix**

* Confirm **compatibility** between your Kubernetes version and the add-on version.
* Certain add-ons require cluster upgrade before (or after) upgrading the add-on.

### **C. Backup**

* Take **etcd backup** or a backup of cluster state, especially for production clusters.
* Back up current add-on configurations if you have customizations.

### **D. Disruption Awareness**

* Some upgrades will briefly disrupt core services (e.g., DNS via CoreDNS).
* Check **pod disruption budgets** and plan for maintenance windows for mission-critical clusters.

### **E. IAM Permissions**

* Ensure your user/role has permission to update EKS add-ons and (if needed) IAM roles for service accounts.

### **F. Custom Configuration**

* If you have customized add-on manifests, ensure those configs are compatible with the new add-on version.
* Record all custom ConfigMap/Deployment changes.

### **G. Test on Non-Production First**

* Always test add-on upgrades in a **dev/staging cluster** before rolling out to production.

---

## **3. Common Side-effects or Risks**

* **Pod Evictions & Restarts:** Some add-ons (like CoreDNS, VPC CNI) will cause pods to restart or evict briefly.
* **Service Interruption:** DNS lookups may fail momentarily, or new pods may not schedule until CNI is ready.
* **Loss of Customization:** If managed by EKS add-ons, any direct edits to manifests may be overwritten.
* **Incompatibility:** Upgrading add-ons before the control plane/Kubernetes version may break features.
* **Rollbacks May Be Tricky:** Some add-ons don’t easily support rolling back to older versions.

---

## **4. How to Upgrade EKS Add-ons**

### **4.1 Upgrading Add-ons via AWS CLI**

#### **A. List Installed Add-ons and Versions**

```sh
aws eks list-addons --cluster-name <CLUSTER_NAME> --region <REGION>
aws eks describe-addon --cluster-name <CLUSTER_NAME> --addon-name <ADDON_NAME> --region <REGION>
```

#### **B. List Available Versions**

```sh
aws eks describe-addon-versions --addon-name <ADDON_NAME> --kubernetes-version <K8S_VERSION> --region <REGION>
```

#### **C. Upgrade an Add-on**

> Replace `<CLUSTER_NAME>`, `<ADDON_NAME>`, `<REGION>`, `<NEW_VERSION>` as appropriate.

```sh
aws eks update-addon \
  --cluster-name <CLUSTER_NAME> \
  --addon-name <ADDON_NAME> \
  --addon-version <NEW_VERSION> \
  --region <REGION>
```

* You can omit `--addon-version` to upgrade to the latest compatible version.

#### **D. Monitor Upgrade Progress**

```sh
aws eks describe-addon \
  --cluster-name <CLUSTER_NAME> \
  --addon-name <ADDON_NAME> \
  --region <REGION" | jq
```

Look for `status: "ACTIVE"` and the new version.

#### **E. Examples**

Upgrade CoreDNS to the latest version:

```sh
aws eks update-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name coredns \
  --region $REGION
```

Upgrade VPC CNI to a specific version:

```sh
aws eks update-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name vpc-cni \
  --addon-version v1.15.3-eksbuild.1 \
  --region $REGION
```

#### **F. Special: Self-managed Add-ons (kubectl/Helm)**

If you are **not** using EKS-managed add-ons (you installed with Helm or kubectl), you must upgrade those manually.
E.g., for metrics-server:

```sh
helm repo update
helm upgrade --namespace kube-system metrics-server metrics-server/metrics-server
```

---

### **4.2 Upgrading Add-ons via AWS Console**

1. **Navigate to the EKS Console**
   [EKS Console Link](https://console.aws.amazon.com/eks/home)

2. **Select Your Cluster**
   Click your cluster name.

3. **Go to the “Add-ons” Tab**

4. **Review Add-on Status and Available Upgrades**

   * Each add-on will show its current version and “Update available” if a new version is present.

5. **Initiate the Upgrade**

   * Click the “Update” button next to the add-on you wish to upgrade.
   * Select the desired version.
   * Click “Update add-on”.

6. **Monitor the Upgrade**

   * Console will show status and logs.
   * Once status shows “Active” and version is updated, the upgrade is complete.

---

## **5. Post-upgrade Validation & Rollback**

### **A. Validation**

* **Check pod status:**

  ```sh
  kubectl get pods -A
  ```
* **Check add-on version:**

  ```sh
  aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name <ADDON_NAME> --region $REGION
  ```
* **Validate application functionality** and network/DNS resolution.

### **B. Rollback (If Needed)**

* Use the same `aws eks update-addon` command, specifying the previous (known good) version.
* Note: Rollbacks are not always supported or may cause downtime; always check documentation.

---

## **6. Pro Tips & Best Practices**

* **Automate version checks** for add-ons using scripts or AWS Health notifications.
* **Upgrade add-ons before cluster version upgrades** unless AWS documentation says otherwise.
* **Keep infrastructure-as-code (e.g., eksctl, Terraform) in sync** with your actual add-on versions.
* **Monitor after upgrade:**
  Use `kubectl logs`, Prometheus, and application health checks to catch regressions early.
* **Set PodDisruptionBudget** and **use multiple replicas** for critical add-on pods (like CoreDNS).
* **Document every upgrade** and keep a changelog.

---

## **References**

* [EKS Add-ons documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
* [AWS EKS Add-on Release Notes](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html)
* [eksctl Add-on Management](https://eksctl.io/usage/add-ons/)

---

Here’s how you can **expertly manage EKS add-on upgrades in a repeatable, operationally robust way**.
Let’s supplement the guide above with **real-world automation, practical examples, and readiness checks.**

---

# **EKS Add-on Upgrade: Ops Runbook & Automation**

---

## **A. Scripted Version Check (All Add-ons)**

```sh
# List all add-ons for your cluster and their current version
aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$REGION" \
  | jq -r '.addons[]' \
  | xargs -I{} aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$REGION" --addon-name {} \
  | jq -r '"\(.addon.addonName): \(.addon.addonVersion)"'
```

---

## **B. List All Available Add-on Versions**

```sh
# For each add-on, list available versions (replace as needed)
for ADDON in vpc-cni coredns kube-proxy; do
  echo "Versions for $ADDON:"
  aws eks describe-addon-versions --addon-name "$ADDON" --kubernetes-version "$K8S_VERSION" --region "$REGION" \
    | jq -r '.addons[0].addonVersions[].addonVersion'
  echo ""
done
```

---

## **C. Pre-upgrade Checks**

* Make sure you have a kubeconfig context pointing to the right cluster:

  ```sh
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
  ```
* Verify critical workloads have **PodDisruptionBudget** and **multiple replicas** (especially CoreDNS).

---

## **D. Upgrade (with CLI, Automated Example)**

Upgrade all add-ons to latest compatible:

```sh
for ADDON in vpc-cni coredns kube-proxy; do
  aws eks update-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name "$ADDON" \
    --region "$REGION"
done
```

Or specify an explicit version if you want to control the rollout:

```sh
aws eks update-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name coredns \
  --addon-version v1.11.1-eksbuild.2 \
  --region "$REGION"
```

---

## **E. Monitor and Validate**

```sh
# Watch system pod status
kubectl get pods -A -w

# Check events for issues
kubectl get events -A | grep -i "coredns\|kube-proxy\|vpc-cni"
```

---

## **F. Rollback Example**

```sh
aws eks update-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name coredns \
  --addon-version <PREVIOUS_VERSION> \
  --region "$REGION"
```

*Always note the original version before upgrading!*

---

## **G. Console Steps (Quick Summary)**

1. Go to **EKS console** → **Your cluster** → **Add-ons** tab.
2. Review add-ons. If “Update available” is shown, select “Update”.
3. Pick a version (or accept the latest) and apply.
4. Watch for “Active” status on completion.

---

## **H. Safety Reminders**

* **Never upgrade everything at once on prod.** Start with dev, then prod (one add-on at a time).
* Watch logs, check for regressions.
* Back up/record all custom manifests.
* Tag your IaC (eksctl/Terraform) repos with add-on versions post-upgrade.

---

## **I. Upgrade Add-ons Managed Outside EKS (e.g., metrics-server via Helm)**

```sh
# Example for metrics-server
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system
```

* For all custom add-ons, review Helm chart documentation for breaking changes before upgrade.

---

## **J. Links to Track**

* [EKS Add-ons and Compatibility](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
* [Add-on version history](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html)
* [eksctl Add-on Automation](https://eksctl.io/usage/add-ons/)

---

