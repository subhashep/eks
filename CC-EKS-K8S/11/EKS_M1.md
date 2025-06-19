# 🧪 Lab: ALB Ingress Setup & Pod-to-Pod Network Policy Enforcement on EKS

---

## 🚦 **Lab Goals**

* Deploy and expose an app using AWS ALB Ingress Controller
* Create, test, and enforce pod-to-pod network policies (Kubernetes NetworkPolicy)

---

## 0️⃣ **Set Up Your Variables**

```bash
export CLUSTER_NAME="ep33-eks-02"
export AWS_REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export LBC_VERSION="v2.7.1"
export APP_NAMESPACE="app-demo"
```

---

## 1️⃣ **Prerequisite: Ensure ALB Ingress Controller Is Installed**

> If you’ve done the Load Balancer Controller lab, you can skip this. Otherwise, use those steps to set up the controller first.

---

## 2️⃣ **Create a Namespace for Your Demo Application**

```bash
kubectl create namespace $APP_NAMESPACE
```

---

## 3️⃣ **Deploy a Sample Application**

Let’s deploy two apps—**frontend** and **backend**—in the same namespace.

```bash
# Deploy backend (nginx)
kubectl -n $APP_NAMESPACE create deployment backend --image=nginx

# Expose backend as a ClusterIP service (internal-only)
kubectl -n $APP_NAMESPACE expose deployment backend --port=80

# Deploy frontend (nginx)
kubectl -n $APP_NAMESPACE create deployment frontend --image=nginx

# Expose frontend as a service (for ALB)
kubectl -n $APP_NAMESPACE expose deployment frontend --port=80
```

---

## 4️⃣ **Create an Ingress Resource for the Frontend**

Here’s a minimal Ingress manifest for the ALB controller.

```yaml
cat <<EOF | kubectl apply -n $APP_NAMESPACE -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: frontend
              port:
                number: 80
EOF
```

> The ALB controller will provision an AWS ALB and direct external traffic to your frontend service.

---

## 5️⃣ **Wait for ALB to Be Provisioned and Test External Access**

```bash
# Wait a few minutes, then get the ALB DNS name:
export ALB_DNS=$(kubectl get ingress frontend-ingress -n $APP_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Your app is accessible at: http://${ALB_DNS}"
```

> Open the DNS name in your browser. You should see the default NGINX page from the frontend deployment.

---

## 6️⃣ **Apply a Strict Pod-to-Pod Network Policy**

Let’s enforce that **only the frontend pods can talk to the backend pods**, and nothing else (default deny for all other sources).

```yaml
cat <<EOF | kubectl apply -n $APP_NAMESPACE -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
EOF
```

> This policy:
>
> * Selects all pods labeled `app=backend`
> * Only allows ingress (incoming) connections from pods with label `app=frontend` on TCP port 80

---

## 7️⃣ **Test the Network Policy Enforcement**

### 7.1 **Launch a Test Pod (not frontend or backend)**

```bash
kubectl -n $APP_NAMESPACE run testpod --rm -it --image=busybox:1.28 --labels="app=test" --restart=Never -- sh
```

* Inside the pod, run:

  ```sh
  wget --spider --timeout=2 backend
  ```
* **Expected:** Connection should **fail**—NetworkPolicy denies access.

Type `exit` to leave the shell.

### 7.2 **Test from Frontend Pod (should be allowed)**

```bash
FRONTEND_POD=$(kubectl -n $APP_NAMESPACE get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')

kubectl -n $APP_NAMESPACE exec -it $FRONTEND_POD -- sh
```

* Inside the pod, run:

  ```sh
  wget --spider --timeout=2 backend
  ```
* **Expected:** Connection should **succeed**.

Type `exit` to leave the shell.

---

## 8️⃣ **Cleanup**

```bash
kubectl delete ns $APP_NAMESPACE
```

---

## 📝 **Quick Recap Table**

| Step | What You Do                              | Why                                  |
| ---- | ---------------------------------------- | ------------------------------------ |
| 0    | Set variables                            | Workshop-friendly, easy updates      |
| 1    | Prereq: ALB controller ready             | Needed for ALB-based Ingress         |
| 2    | Create namespace                         | Keeps resources organized            |
| 3    | Deploy frontend/backend                  | Simulates real microservices         |
| 4    | Add Ingress                              | ALB exposes your app to the world    |
| 5    | Get ALB DNS and test                     | Proves external access via ALB       |
| 6    | Apply NetworkPolicy                      | Enforces strict pod-to-pod comms     |
| 7    | Test policy from allowed and denied pods | Shows how policies work in real life |
| 8    | Cleanup                                  | Good housekeeping                    |

---

## 💡 **Tips**

* For NetworkPolicies to take effect, your cluster must have a compatible CNI/network plugin (AWS VPC CNI now supports basic policies as of recent releases).
* You can extend the NetworkPolicy to allow or deny by namespace, IP, or label.
* Check controller and CNI pod logs for troubleshooting ALB or policy issues.

---

**You now have a real-world pattern for combining secure Ingress and microservice isolation!**
