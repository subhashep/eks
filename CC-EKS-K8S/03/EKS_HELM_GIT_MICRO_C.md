# 🚀 EKS Microservices Lab (Helm, GitHub, Ingress-NGINX, 2025)

---

## **Lab Goals**

* Provision a fully functional EKS cluster
* Install and configure kubectl, Helm, Git
* Prepare all environment variables for all sessions
* **Deploy a microservices app via Helm from GitHub, with no unnecessary Helm dependencies**
* **Use ONE cluster-wide Ingress-NGINX controller**
* Expose the app with a standard Kubernetes Ingress
* **Troubleshoot and understand all moving parts**
* **Fully clean up all resources**

---

## 1️⃣ Environment Setup (Persistent Variables)

**Why?** Ensures all scripts and CLI commands work in any terminal.

```bash
export MY_ID=ep33
export AWS_REGION=us-east-1
export AZ1=us-east-1a
export AZ2=us-east-1b
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat <<EOF > ~/.envvars
export MY_ID=${MY_ID}
export AWS_REGION=${AWS_REGION}
export AZ1=${AZ1}
export AZ2=${AZ2}
export ACCOUNT_ID=${ACCOUNT_ID}
EOF

grep -qxF 'source ~/.envvars' ~/.bash_profile || echo 'source ~/.envvars' >> ~/.bash_profile
grep -qxF 'source ~/.envvars' ~/.bashrc || echo 'source ~/.envvars' >> ~/.bashrc
source ~/.envvars

aws configure set default.region ${AWS_REGION}
```

---

## 2️⃣ Create EKS Cluster and Node Group

```bash
eksctl create cluster --name=ep33-eks-01 \
  --region=${AWS_REGION} \
  --zones=${AZ1},${AZ2} \
  --without-nodegroup

eksctl create nodegroup --cluster=ep33-eks-01 \
  --region=${AWS_REGION} \
  --name=ep33-ng-01 \
  --node-type=t3.medium \
  --nodes=2 \
  --node-volume-size=20 \
  --ssh-access \
  --ssh-public-key=ep33-eks \
  --managed \
  --external-dns-access
```

---

## 3️⃣ Install kubectl, Git, Helm

```bash
if ! git --version &>/dev/null; then
  sudo yum install -y git || sudo apt-get install -y git
fi
if ! helm version &>/dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
```

Test:

```bash
kubectl version --client
helm version
git --version
```

---

## 4️⃣ Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region $AWS_REGION --name ep33-eks-01
kubectl get nodes
```

* **You should see two nodes with `STATUS: Ready`.**

---

## 5️⃣ Install Ingress-NGINX Controller (Cluster-wide)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

Check the external LoadBalancer:

```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller --watch
```

* The **EXTERNAL-IP** (or DNS) must appear.
  *If not, see Troubleshooting below!*

---

## 6️⃣ Clone and Prepare Microservices App

```bash
git clone https://github.com/microservices-demo/microservices-demo.git
cd microservices-demo/deploy/kubernetes/helm-chart
```

---

## 7️⃣ **\[CRITICAL!] Clean Up Helm Chart Dependencies**

### Before running any Helm commands:

**A. Edit `Chart.yaml`**

* Open `Chart.yaml` in your chart directory.
* **Remove any section like:**

  ```yaml
  dependencies:
    - name: nginx-ingress
      version: ...
      repository: "https://helm.nginx.com/stable"
  ```
* Save and close the file.

**B. Remove legacy files**

```bash
rm -f requirements.yaml
rm -rf charts/
rm -f requirements.lock Chart.lock

```

**C. Build dependencies (should say nothing to build):**

```bash
helm dependency build
```

* You should see `No requirements found in Chart.yaml, updating dependencies...`

---

## 8️⃣ Deploy Microservices App with Helm

```bash
helm install sock-shop . --namespace sock-shop --create-namespace
kubectl get pods -n sock-shop
kubectl get svc -n sock-shop
```

---

## 9️⃣ Expose the App via Standard Ingress

Create a file `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sock-shop
  namespace: sock-shop
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  ingressClassName: nginx
  rules:
    - host: <ELB-DNS-NAME>
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: front-end    # Your app’s Service name
                port:
                  number: 80
```

* Replace `<ELB-DNS-NAME>` with the **DNS name from the Ingress-NGINX controller service**.

Apply it:

```bash
kubectl apply -f ingress.yaml
```

---

## 🔟 Test the Application

* Open the **ELB DNS name** in your browser.
* If using a custom hostname, add a line to `/etc/hosts`:

  ```bash
  echo "<EXTERNAL-IP> sockshop.ep33.workshop.com" | sudo tee -a /etc/hosts
  ```
* You should see your app’s UI.
* If you see `404 Not Found nginx`, **check your Ingress, Service, and Pod names/namespaces**.

---

## 🧹 **Final Full Cleanup**

**Remove everything you created (to avoid AWS costs):**

```bash
helm uninstall sock-shop -n sock-shop
kubectl delete ns sock-shop

helm uninstall nginx-ingress -n ingress-nginx
kubectl delete ns ingress-nginx

```

---

## 🦉 **Troubleshooting Table**

| Problem               | Fix/Check                                                             |
| --------------------- | --------------------------------------------------------------------- |
| No EXTERNAL-IP        | Public subnets must be tagged `kubernetes.io/role/elb=1` and have IGW |
| Helm dependency error | Remove all dependencies from Chart.yaml; delete charts/ dir           |
| CRD errors on install | Ensure you use only standard K8s Ingress (no NGINX Inc CRDs)          |
| 404 Not Found nginx   | Ingress or Service misconfiguration, typo, or wrong namespace         |
| Service not reachable | App pods not running, service misnamed                                |

---

## 📝 **Key Explanations for Participants**

* **Ingress-NGINX Controller** is cluster-wide. Only install it ONCE.
* **Microservices Helm charts** should deploy Deployments, Services, ConfigMaps, and a **standard Ingress**. They should NOT depend on, or install, ingress controllers.
* **`EXTERNAL-IP`** of LoadBalancer service is the public entry point for your app.
* **No CRDs required** unless you’re teaching advanced NGINX Inc features (out of scope here).
* **Final cleanup is a must** to avoid surprise AWS charges.

---

Absolutely! Here are **two diagrams** (with expert-level explanations):

1. **Lab Workflow/Flowchart:** Visualizes the step-by-step process students follow.
2. **EKS Microservices Architecture:** Shows how all components interact in AWS.

---

## 1️⃣ **Lab Workflow Diagram: Amazon EKS Microservices Deployment**

**Flow:**

1. Set environment variables
2. Create EKS cluster
3. Create node group
4. Install tools (kubectl, Helm, Git)
5. Install Ingress-NGINX controller
6. Clone microservices repo from GitHub
7. Clean Helm chart dependencies
8. Deploy app with Helm
9. Create and apply Ingress
10. Access app via ELB
11. Cleanup

---

### **\[Diagram 1: Lab Workflow]**

```plaintext
+---------------------+
| Set Env Variables   |
+---------+-----------+
          |
          v
+---------------------+
| Create EKS Cluster  |
+---------+-----------+
          |
          v
+---------------------+
| Create Node Group   |
+---------+-----------+
          |
          v
+-------------------------------+
| Install kubectl, Helm, Git    |
+---------+-----------+---------+
          |
          v
+------------------------------+
| Install Ingress-NGINX        |
| Controller (cluster-wide)    |
+---------+-----------+--------+
          |
          v
+-------------------------------+
| Clone Microservices Repo       |
+---------+-----------+---------+
          |
          v
+-----------------------------+
| Clean Helm Chart (Remove    |
| Dependencies, Lockfiles)    |
+---------+-----------+-------+
          |
          v
+---------------------+
| Deploy App with Helm|
+---------+-----------+
          |
          v
+-----------------------------+
| Create & Apply Ingress      |
+---------+-----------+-------+
          |
          v
+-----------------------------+
| Access App via ELB DNS      |
+---------+-----------+-------+
          |
          v
+-----------------------------+
| Full Cleanup                |
+-----------------------------+
```

---

## 2️⃣ **EKS Microservices Architecture Diagram**

### **\[Diagram 2: EKS Microservices Architecture]**

```
                           +-------------------------------+
                           |        AWS VPC (Cluster)      |
                           |                               |
+---------+                |   +------------------------+   |                +-------------+
|  User   |  <--(HTTP)-->  |   |   Ingress-NGINX        |   |  <--(Pods)-->  | Sock Shop   |
+---------+   (Browser)    |   |   Controller (Service  |   |    ClusterIP   | Microservices|
                           |   |   type: LoadBalancer)  |   |    Services    +-------------+
                           |   +---------+--------------+   |      ^           (Deployments,
                           |             |                  |      |           Pods,
                           |     +-------v---------+        |      |           DBs, etc.)
                           |     | AWS ELB/NLB     |        |      |
                           |     | (EXTERNAL-IP)   |        |      |
                           |     +-----------------+        |      |
                           |                               |      |
                           +-------------------------------+      |
                                  ^        ^                     |
                                  |        |                     |
                      Internet <--+        +---------------------+
                                      AWS IAM, K8s API, etc.

```

---

### **Explanation:**

* **User** accesses the app via the ELB DNS (EXTERNAL-IP).
* **ELB/NLB** is provisioned by the Ingress-NGINX Controller’s LoadBalancer Service.
* **Ingress-NGINX Controller** receives incoming HTTP/HTTPS requests, looks up matching Ingress rules, and forwards to the correct **ClusterIP Service**.
* **ClusterIP Services** load-balance traffic to the correct **Pods** (microservices, DBs).
* All of this is deployed inside the EKS-managed **AWS VPC**.

---


