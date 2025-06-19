# 🧪 Lab: CI/CD Pipeline with GitOps using ArgoCD on Amazon EKS (Public UI, Code-Server/Cloud Lab Edition)

---

## 🎯 **Lab Objectives**

* Understand GitOps concepts
* Install and access ArgoCD with a public UI (no port-forward)
* Deploy and auto-sync a sample app using GitOps workflow
* Securely open access using Security Group updates
* Visualize and validate the end-to-end workflow

---

## 📋 **Prerequisites**

* EKS cluster (v1.28+), `kubectl`, `helm`, and `aws` CLI set up
* Access to EC2/Cloud instance and Security Group permissions
* A GitHub account (for GitOps repo; can use public sample)

---

## 🧩 **High-Level Flow**

```
[GitHub Repo] <---> [ArgoCD on EKS (public UI)] <---> [You (Web Browser)]
                                          |
                                [EKS Cluster applies all changes]
```

---

## 1️⃣ **Set Environment Variables**

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=ep33-eks-02
export ARGOCD_PORT=8084   # Change if you wish
```

---

## 2️⃣ **Install ArgoCD in EKS**

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd
```

> Wait until all pods in `argocd` namespace are `Running`.

---

## 3️⃣ **Expose ArgoCD UI via LoadBalancer Service**

Patch the service to be public and on your chosen port:

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer","ports": [{"port": '"${ARGOCD_PORT}"',"targetPort": 8080,"protocol": "TCP","name": "http-web"}]}}'
```

> **Note:** If you want to use a different port (e.g., 8086), change `ARGOCD_PORT` above.

Check the service:

```bash
kubectl get svc argocd-server -n argocd --watch
```

* **Copy the EXTERNAL-IP** or DNS (it will look like `ae5a...elb.amazonaws.com`).

---

## 4️⃣ **Update EC2/EKS Security Group for ArgoCD UI Access**

**a. Find the correct Security Group attached to your worker nodes/cluster:**

* In the AWS EC2 console, find the Security Group used by your nodegroup (look for group attached to EC2 worker nodes).

**b. Add an Ingress Rule:**

* Type: **Custom TCP**
* Port: **8084** (or whatever you chose)
* Source: **Your public IP** or `0.0.0.0/0` (for demo; restrict for security)
* Description: `Allow ArgoCD UI public access`

**Example (AWS CLI, for `sg-abc123` SG):**

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-abc123 \
  --protocol tcp \
  --port 8084 \
  --cidr 0.0.0.0/0
```

> **(For best security, use your own IP address, not `0.0.0.0/0` in production!)**

---

## 5️⃣ **Access ArgoCD UI Remotely**

* Go to: `https://<EXTERNAL-IP-or-DNS>:8084` in your browser
* **Ignore browser SSL warnings (self-signed cert) for now.**

---

## 6️⃣ **Get Initial ArgoCD Admin Password**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

* Username: `admin`
* Password: (the value above)

---

## 7️⃣ **Fork/Clone the Sample App GitHub Repo**

You can use the official demo app or fork it for yourself:

* [https://github.com/argoproj/argocd-example-apps](https://github.com/argoproj/argocd-example-apps)

**Note the HTTPS repo URL.**

---

## 8️⃣ **Register a New App with ArgoCD**

**Via UI:**

* Log in to ArgoCD UI (`https://<EXTERNAL-IP-or-DNS>:8084`)
* Click “NEW APP”

  * Application Name: `guestbook`
  * Project: `default`
  * Sync Policy: `Manual` (or `Auto Sync` if you want)
  * Repository URL: your fork or the example repo URL
  * Revision: `HEAD`
  * Path: `guestbook`
  * Cluster URL: `https://kubernetes.default.svc`
  * Namespace: `default`
* Click “Create”

**Or CLI (if you want):**

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

---

## 9️⃣ **Sync Your App**

* In the UI, click `Sync` for `guestbook`
* Or via CLI: `argocd app sync guestbook`

---

## 🔟 **Test the Deployment**

```bash
kubectl get pods,svc -n default
```

* You should see the `guestbook` pods and service running.

---

## 1️⃣1️⃣ **Visual Workflow**

```
[GitHub]  <----> [ArgoCD (UI on ELB:8084)] <----> [You]
                        |
                [EKS Cluster]
```

* ArgoCD UI is public (on your chosen port)
* All changes in Git are auto/applied to EKS!

---

## 1️⃣2️⃣ **Test GitOps!**

* Change something in your `guestbook` manifest in GitHub (e.g., replica count).
* Commit/push.
* In ArgoCD UI, click “Refresh” or wait for Auto Sync.
* See the cluster update itself!

---

## 1️⃣3️⃣ **Cleanup (Optional)**

```bash
kubectl delete ns argocd
kubectl delete deployment guestbook -n default
```

* Optionally, remove the SG ingress rule for 8084.

---

## 📝 **Troubleshooting Table**

| Problem                    | Solution                                    |
| -------------------------- | ------------------------------------------- |
| No EXTERNAL-IP             | Node SG or subnet config may block LB       |
| Can’t access UI            | SG ingress missing for port 8084            |
| SSL browser warning        | Accept/Ignore (self-signed, for demo)       |
| ArgoCD admin password fail | Copy/paste again, or reset via `kubectl`    |
| App not syncing            | Check repo URL/path, retry sync, check logs |

---

## 🧠 **Key Takeaways**

* No `localhost` or port-forwarding—fully cloud-accessible
* Security Group ingress is essential for public access
* ArgoCD brings **self-healing, declarative CI/CD** to your EKS apps!

---
