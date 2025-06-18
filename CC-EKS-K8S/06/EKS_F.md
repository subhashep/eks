# 🟦Lab: CoreDNS Administration and Troubleshooting on EKS

> **Lab Overview:**
> This hands-on lab guides you through checking and modifying CoreDNS—the internal DNS service for Kubernetes clusters—using practical, real-world admin scenarios.
>
> **Key Skills:**
>
> * Diagnosing DNS issues
> * Customizing cluster DNS
> * Safely rolling back changes
>
> **Requirements:**
>
> * EKS admin access
> * `kubectl` and `aws` CLI installed
> * `jq` installed for parsing JSON (one-time install)

---

## 0️⃣ **Set Cluster Variables**

*Why:* So the lab works for any EKS cluster—just change these two values to match your setup.

```bash
export CLUSTER_NAME="ep33-eks-02"   # Set your EKS cluster name here
export AWS_REGION="us-east-1"       # Set your AWS region here
```

* **Tip:** Share these two lines with your participants and tell them to change them as needed!

---

## 1️⃣ **Update Your kubeconfig**

*Why:* This command ensures that `kubectl` is connected to your chosen EKS cluster. If you don’t do this, your commands will go to the wrong cluster (or none at all).

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
```

* **What this does:** Downloads credentials and config for the EKS cluster and adds them to your local config, so `kubectl` commands know where to go.

---

## 2️⃣ **Check CoreDNS Deployment Health**

*Why:* CoreDNS is the DNS server for your Kubernetes cluster. It must be running correctly or DNS inside your cluster will not work.

```bash
kubectl -n kube-system get deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
```

* **What you’ll see:**

  * The number of running/ready CoreDNS pods.
  * Their status (should be “Running”).
  * Their node location.

---

## 3️⃣ **Check CoreDNS Logs (Troubleshooting)**

*Why:* If DNS is not working inside your cluster, checking logs is a fast way to spot errors.

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=50
```

* **Look for:** Errors like `no upstreams available` or `SERVFAIL`.

---

## 4️⃣ **Test In-Cluster DNS Resolution**

*Why:* You want to verify that DNS is working for your apps inside the cluster, not just for Kubernetes components.

### 4.1 **Test Cluster Internal DNS**

```bash
kubectl run dns-test --rm -it --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default
```

* **What this does:** Starts a temporary Linux pod and runs a DNS lookup for the Kubernetes default service.
* **What you should see:** The DNS name should resolve to a cluster IP.

### 4.2 **Test External DNS**

```bash
kubectl run dns-ext --rm -it --image=busybox:1.28 --restart=Never -- nslookup google.com
```

* **What this does:** Starts another temporary pod and checks if it can resolve `google.com` using CoreDNS, which should forward to an outside DNS server.
* **Why:** This checks that pods can reach the outside world using DNS.

---

## 5️⃣ **Edit CoreDNS ConfigMap for Custom DNS Entry**

*Why:* Sometimes you want to customize DNS for your apps—maybe to forward a certain domain to a special DNS server.

```bash
kubectl -n kube-system edit configmap coredns
```

* **What happens:** Opens the CoreDNS config in your editor (usually `vi`).

* **What to do:**

  * **Add this section before the final closing brace (`}`):**

    ```
    lab.internal:53 {
        forward . 8.8.8.8
    }
    ```
  * This tells CoreDNS: “For any request ending with `.lab.internal`, forward the query to Google DNS (8.8.8.8)”.

* **How to save:** Press `Esc`, then type `:wq` and press `Enter` (in `vi`).

---

## 6️⃣ **Reload CoreDNS Deployment**

*Why:* For config changes to take effect, you need to restart the CoreDNS pods. This is called a “rollout restart”.

```bash
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

* **What happens:** New pods are started with the updated configuration.
* **Wait for:** All pods to show “Running” and “Ready”.

---

## 7️⃣ **Test Your Custom DNS Entry**

*Why:* Make sure your CoreDNS change actually works.

```bash
kubectl run dns-lab --rm -it --image=busybox:1.28 --restart=Never -- nslookup test.lab.internal
```

* **Expected:** The DNS query should be forwarded to 8.8.8.8 (may or may not resolve if 8.8.8.8 doesn’t know the answer, but you shouldn’t see an immediate error like “SERVFAIL”).

---

## 8️⃣ **Roll Back CoreDNS Config If Needed**

*Why:* If you made a mistake or broke DNS for your cluster, it’s important to restore the working config.

**Backup before editing:**

```bash
kubectl -n kube-system get configmap coredns -o yaml > coredns-backup.yaml
```

**To restore from backup:**

```bash
kubectl -n kube-system replace -f coredns-backup.yaml
kubectl -n kube-system rollout restart deployment coredns
```

**Or:**
Edit the configmap again and remove the custom block, then repeat the rollout restart.

---

## 9️⃣ **Explore CoreDNS Metrics (Optional Advanced Step)**

*Why:* CoreDNS exposes useful metrics (like request counts, errors, cache hits). This helps with debugging and monitoring DNS health.

```bash
kubectl -n kube-system port-forward deployment/coredns 9153:9153
```

* Then, on your local machine, open [http://localhost:9153/metrics](http://localhost:9153/metrics) in your browser.
* **What you see:** Prometheus-format metrics for CoreDNS.

---

# ✅ **Summary Table**

| Step | Action               | Why this matters                                        |
| ---- | -------------------- | ------------------------------------------------------- |
| 0    | Set Variables        | Lets you easily share and reuse these steps with others |
| 1    | Update kubeconfig    | Makes sure you’re connected to the correct cluster      |
| 2    | Check CoreDNS health | Ensures DNS is working cluster-wide                     |
| 3    | Check logs           | Fastest way to spot DNS problems                        |
| 4    | Test DNS in pod      | Proves if cluster DNS is working for your apps          |
| 5    | Edit CoreDNS config  | Enables custom DNS routing (a common admin job)         |
| 6    | Restart CoreDNS      | Required for config changes to take effect              |
| 7    | Test your changes    | Never change DNS without confirming it works            |
| 8    | Roll back config     | Always know how to undo a change in production          |
| 9    | Metrics (optional)   | For advanced monitoring and troubleshooting             |

---

## 💡 **Extra Tips**

* **Always backup configs** before editing.
* **Don’t leave test pods running** (`--rm` flag cleans up automatically).
* **Document any changes** for your team.

---
