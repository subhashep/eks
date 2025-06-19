# 🧪 Modern Lab: AWS Load Balancer Controller Deployment on EKS

---

## 0️⃣ **Set Up Your Environment Variables**

```bash
# Set these to your actual values before starting!
export CLUSTER_NAME="ep33-eks-02"
export AWS_REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export LBC_VERSION="v2.7.1"  # Use latest stable at time of lab; check: https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases
```

---

## 1️⃣ **Verify Helm and eksctl**

```bash
helm version --short
eksctl version
```

> Ensure both tools are installed and working.

---

## 2️⃣ **Create IAM OIDC Provider for the Cluster**

```bash
eksctl utils associate-iam-oidc-provider \
    --region ${AWS_REGION} \
    --cluster ${CLUSTER_NAME} \
    --approve
```

> OIDC enables Kubernetes service accounts to assume IAM roles securely.

---

## 3️⃣ **Create IAM Policy for the Controller**

```bash
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name EPSH-AWS-ELB-ControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  --region $AWS_REGION
```

> The policy grants the controller the required permissions.

---

## 4️⃣ **Create IAM Role & ServiceAccount for Controller**

```bash
eksctl create iamserviceaccount \
  --cluster ${CLUSTER_NAME} \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/EPSH-AWS-ELB-ControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

> This creates a Kubernetes service account and links it to the IAM role/policy above.

---

## 5️⃣ **Install the TargetGroupBinding CRDs**

```bash
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
kubectl get crd | grep targetgroupbindings
```

> These CRDs are required for ALB/NLB integration.

---

## 6️⃣ **Add the EKS Helm Repo and Deploy the Controller**

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.tag="${LBC_VERSION}"

kubectl -n kube-system rollout status deployment aws-load-balancer-controller
```

> Installs the controller using the IAM-linked ServiceAccount.

---

## 7️⃣ **Deploy and Test a Sample Application (2048 Game)**

```bash
kubectl create namespace game-2048

curl -s https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/examples/2048/2048_full.yaml |
  kubectl apply -n game-2048 -f -
```

> This deploys the 2048 game, plus a sample Ingress resource for ALB.

---

## 8️⃣ **Verify the Ingress and ALB Provisioning**

```bash
kubectl get ingress -n game-2048

# Wait 2–3 minutes for ALB creation
export GAME_2048=$(kubectl get ingress/ingress-2048 -n game-2048 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access the 2048 game at: http://${GAME_2048}"
```

> After a few minutes, your ALB hostname should be active!

---

## 9️⃣ **(Optional) Inspect TargetGroupBindings**

```bash
kubectl -n game-2048 get targetgroupbindings -o yaml
```

---

## 🔁 **CLEANUP: Remove All Resources When Done**

```bash
curl -s https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/examples/2048/2048_full.yaml | kubectl delete -n game-2048 -f -
helm uninstall aws-load-balancer-controller -n kube-system

eksctl delete iamserviceaccount \
    --cluster ${CLUSTER_NAME} \
    --name aws-load-balancer-controller \
    --namespace kube-system \
    --wait

aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/EPSH-AWS-ELB-ControllerIAMPolicy

kubectl delete ns game-2048

kubectl delete crd targetgroupbindings.elbv2.k8s.aws
```

---

## 📝 **Quick Explanation Table**

| Step | What / Why?                                                  |
| ---- | ------------------------------------------------------------ |
| 0    | Set variables for re-use, workshop portability               |
| 1    | Confirm helm/eksctl are working                              |
| 2    | OIDC provider: enables IRSA (IAM Roles for Service Accounts) |
| 3    | Create/load AWS IAM policy for controller                    |
| 4    | Make IAM ServiceAccount (maps k8s SA to AWS IAM)             |
| 5    | Install TargetGroupBinding CRDs                              |
| 6    | Helm install the controller (uses ServiceAccount + policy)   |
| 7    | Deploy/test app and Ingress (proves ALB controller works)    |
| 8    | Confirm ALB creation, grab its hostname                      |
| 9    | Cleanup all, save costs and avoid resource sprawl            |

---

## 💡 **Extra Tips**

* Always check [controller release notes](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases) for the latest version and features.
* For multi-team/production use, consider using [IRSA best practices](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).
* Use `kubectl -n kube-system logs deployment/aws-load-balancer-controller` to troubleshoot controller issues.

---
