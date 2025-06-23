# 🟢 Observability Lab 1: Kubernetes Logs to CloudWatch with Fluent Bit & IRSA

> **Goal:**
> Ship all Kubernetes workload logs (e.g., `podinfo` demo app) to AWS CloudWatch Logs, using the AWS-recommended Fluent Bit DaemonSet, with secure IAM Roles for Service Accounts (IRSA), and enable Container Insights.

---

## **0. Prerequisites**

* EKS Cluster (`ep33-eks-02` as example) and `kubectl`/`aws` CLI access
* [ ] OIDC provider enabled for the cluster (default with modern EKS)
* [ ] Node IAM role must not block STS or CloudWatch permissions
* [ ] AWS CLI default profile with admin rights (for IAM setup)
* [ ] Helm (for optional app deploys)

---

## **1. Deploy a Demo App (podinfo)**

```sh
kubectl create ns demo || true
helm repo add stefanprodan https://stefanprodan.github.io/podinfo
helm upgrade --install podinfo stefanprodan/podinfo -n demo
```

*This will emit logs—visible to Fluent Bit.*

---

## **2. Setup Environment Variables for Automation**

```sh
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION=us-east-1
export CLUSTER_NAME=ep33-eks-02
export NAMESPACE=amazon-cloudwatch
export SA_NAME=fluent-bit
export POLICY_NAME=fluent-bit-cloudwatch-policy
export IRSA_ROLE_NAME=fluent-bit-irsa-role
export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
```

---

## **3. Create Namespace and Service Account**

```sh
kubectl create namespace $NAMESPACE || true
kubectl create serviceaccount $SA_NAME -n $NAMESPACE || true
```

---

## **4. Create the Fluent Bit CloudWatch Policy**

**Save to file:**

```sh
cat > fluent-bit-cloudwatch-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:CreateLogGroup"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

**Create policy:**

```sh
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://fluent-bit-cloudwatch-policy.json 2>/dev/null || echo "Policy likely already exists."
export POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"
```

---

## **5. Create IRSA Trust Policy**

**Save to file:**

```sh
cat > fluent-bit-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER:sub": "system:serviceaccount:$NAMESPACE:$SA_NAME"
        }
      }
    }
  ]
}
EOF
```

---

## **6. Create IAM Role for Service Account (IRSA)**

```sh
aws iam create-role \
  --role-name $IRSA_ROLE_NAME \
  --assume-role-policy-document file://fluent-bit-trust.json 2>/dev/null || echo "Role likely already exists."
aws iam attach-role-policy \
  --role-name $IRSA_ROLE_NAME \
  --policy-arn $POLICY_ARN
export ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$IRSA_ROLE_NAME"
```

---

## **7. Annotate Service Account for IRSA**

```sh
kubectl annotate serviceaccount $SA_NAME \
  -n $NAMESPACE \
  eks.amazonaws.com/role-arn=$ROLE_ARN \
  --overwrite
```

---

## **8. Deploy Fluent Bit DaemonSet for CloudWatch**

> AWS provides a fully working manifest. This DaemonSet will:
>
> * Collect all `/var/log/containers/*` logs
> * Send to CloudWatch under `/aws/containerinsights/<cluster>/application`

```sh
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

---

## **9. Validate Deployment**

* **Pod status:**

  ```sh
  kubectl get pods -n $NAMESPACE -l k8s-app=fluent-bit
  ```

* **Check logs (should see log shipping, no AccessDenied or auth errors):**

  ```sh
  kubectl logs -n $NAMESPACE -l k8s-app=fluent-bit --tail=50
  ```

* **AWS Console:**
  Go to **CloudWatch > Log Groups**
  You should see `/aws/containerinsights/$CLUSTER_NAME/application` (and `host`, `dataplane`).

* **Check for podinfo logs:**
  In the CloudWatch log group, search for "podinfo" or visit `/aws/containerinsights/$CLUSTER_NAME/application` and confirm demo logs are being received.

---

## **10. Enable (Optional) Container Insights Metrics**

If not already enabled:

```sh
aws eks update-cluster-config \
  --name $CLUSTER_NAME \
  --region $REGION \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

(You may also use the EKS Console to enable Insights.)

---

## **11. \[Optional] Clean Up**

To remove everything:

```sh
kubectl delete ns demo
kubectl delete ns $NAMESPACE
aws iam detach-role-policy --role-name $IRSA_ROLE_NAME --policy-arn $POLICY_ARN
aws iam delete-role --role-name $IRSA_ROLE_NAME
aws iam delete-policy --policy-arn $POLICY_ARN
```

---

## **Summary Table**

| Step | Action            | Command/File                        |
| ---- | ----------------- | ----------------------------------- |
| 1    | Deploy demo app   | `helm install podinfo ...`          |
| 2    | Set env vars      | see above                           |
| 3    | Namespace/SA      | `kubectl create ...`                |
| 4    | Policy            | `aws iam create-policy ...`         |
| 5    | Trust Policy      | `fluent-bit-trust.json`             |
| 6    | IRSA Role         | `aws iam create-role ...`           |
| 7    | Annotate SA       | `kubectl annotate ...`              |
| 8    | Deploy Fluent Bit | `kubectl apply -f ...`              |
| 9    | Validate          | `kubectl get pods ...` / CloudWatch |
| 10   | Enable Insights   | optional CLI                        |
| 11   | Clean Up          | see above                           |

---

## **References & Notes**

* [AWS: Fluent Bit for Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html)
* [AWS: EKS IRSA Guide](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---
