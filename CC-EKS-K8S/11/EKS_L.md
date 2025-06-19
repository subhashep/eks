# 🧪 Lab: Add Secondary CIDRs to EKS VPC and Enable Custom CNI Networking

---

## 🛠️ **Preparation: Set Your Cluster Variables**

```bash
# Set these to your cluster's actual name and region
export CLUSTER_NAME="ep33-eks-02"
export AWS_REGION="us-east-1"
export VPC_TAG="eksctl-${CLUSTER_NAME}-cluster/VPC"
```

---

## 1️⃣ **Find Your EKS VPC**

> **Why?**
> Your EKS cluster runs in a VPC (Virtual Private Cloud). You must find the right VPC before adding new network ranges.

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=$VPC_TAG \
  --region $AWS_REGION \
  --query 'Vpcs[].VpcId' \
  --output text)

echo "Your VPC is: $VPC_ID"
```

---

## 2️⃣ **Add a Secondary CIDR Block**

> **Why?**
> Adding a secondary CIDR block expands the IP address pool for your pods/services (for large or multi-AZ clusters).

**IMPORTANT:**

* Ensure your secondary CIDR **does not overlap** with any existing VPC CIDR or other networks in your AWS environment.
* You may want to check AWS [VPC CIDR block restrictions](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#vpc-cidr-blocks).

```bash
aws ec2 associate-vpc-cidr-block \
  --vpc-id $VPC_ID \
  --cidr-block 100.64.0.0/16 \
  --region $AWS_REGION
```

---

## 3️⃣ **Find Your Node AZs (Availability Zones)**

> **Why?**
> Subnets must be created in the same AZs as your EKS worker nodes to support multi-AZ scheduling and resilience.

```bash
# Get AZs where EKS worker nodes are running
POD_AZS=($(aws ec2 describe-instances \
  --region $AWS_REGION \
  --filters "Name=tag-key,Values=eks:cluster-name" "Name=tag-value,Values=$CLUSTER_NAME" \
  --query 'Reservations[*].Instances[*].Placement.AvailabilityZone' \
  --output text | sort | uniq))

echo "Node AZs: ${POD_AZS[@]}"
```

---

## 4️⃣ **Create Subnets in the New CIDR for Each AZ**

> **Why?**
> Kubernetes expects a subnet in every AZ where it runs pods, for IP assignment.

```bash
# Adjust CIDR ranges as needed for your VPC design!
CGNAT_SNET1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 100.64.0.0/19 \
  --availability-zone ${POD_AZS[0]} \
  --region $AWS_REGION \
  --query 'Subnet.SubnetId' --output text)

CGNAT_SNET2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 100.64.32.0/19 \
  --availability-zone ${POD_AZS[1]} \
  --region $AWS_REGION \
  --query 'Subnet.SubnetId' --output text)

echo "Created subnets: $CGNAT_SNET1 $CGNAT_SNET2"
```

---

## 5️⃣ **Associate New Subnets with Route Table**

> **Why?**
> Pods in these subnets need a route to the internet (usually through a NAT Gateway).

```bash
# Find a route table associated with an existing EKS subnet (update CIDR as needed)
SNET1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=eksctl-${CLUSTER_NAME}* Name=cidr-block,Values=192.168.0.0/19 --region $AWS_REGION --query 'Subnets[].SubnetId' --output text)

RTASSOC_ID=$(aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=$SNET1 --region $AWS_REGION --query 'RouteTables[].RouteTableId' --output text)

# Associate both new subnets with this route table
aws ec2 associate-route-table --route-table-id $RTASSOC_ID --subnet-id $CGNAT_SNET1 --region $AWS_REGION
aws ec2 associate-route-table --route-table-id $RTASSOC_ID --subnet-id $CGNAT_SNET2 --region $AWS_REGION

echo "Associated new subnets with route table $RTASSOC_ID"
```

---

## 6️⃣ **Validate VPC CNI Plugin Version**

> **Why?**
> Only recent CNI versions fully support custom networking with secondary CIDRs.

```bash
kubectl -n kube-system describe daemonset aws-node | grep Image
```

* Check AWS docs for the latest supported CNI version.
* [See CNI release notes](https://github.com/aws/amazon-vpc-cni-k8s/releases)

---

## 7️⃣ **Enable Custom Networking in the CNI**

> **Why?**
> This environment variable tells the CNI to support secondary subnets and custom networking.

```bash
kubectl set env ds aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
kubectl -n kube-system describe daemonset aws-node | grep -A5 Environment
```

---

## 8️⃣ **Rolling Cluster Update: Replace Worker Nodes**

> **Why?**
> New nodes will come up with the new network config, so pods can be assigned IPs from your new subnets.

⚠️ **SAFETY NOTE:**

* **Do not run this in production without careful planning.**
* This will terminate ALL worker nodes and their running pods (they will be replaced if your cluster autoscaling is set up).

```bash
INSTANCE_IDS=($(aws ec2 describe-instances \
  --region $AWS_REGION \
  --filters "Name=tag-key,Values=eks:cluster-name" "Name=tag-value,Values=$CLUSTER_NAME" \
  --query 'Reservations[*].Instances[*].InstanceId' --output text))

for i in "${INSTANCE_IDS[@]}"
do
    echo "Terminating EC2 instance $i ..."
    aws ec2 terminate-instances --instance-ids $i --region $AWS_REGION
done
```

* Watch your node group (or Managed Node Group) bring up replacements.
* Use `kubectl get nodes` to see new nodes.

---

## 9️⃣ **Validate Pod IP Assignment from New Subnets**

> **Why?**
> Pods should now get IPs from your new subnets if you have more pods than the old subnets can handle.

```bash
kubectl get pods -o wide --all-namespaces
# Check if any pod IPs are now in 100.64.x.x range (your new CIDR)
```

---

## 🧹 **Cleanup**

> If this was a test, remember to remove unused subnets, route associations, and secondary CIDR blocks to avoid AWS charges.

---

## 📝 **Lab Recap Table**

| Step | Action                  | Why You Do This                          |
| ---- | ----------------------- | ---------------------------------------- |
| 1    | Find VPC                | You must target the correct VPC          |
| 2    | Add secondary CIDR      | Expands your cluster’s address space     |
| 3    | Get node AZs            | So new subnets match where nodes are     |
| 4    | Create new subnets      | For pods in each AZ to get IPs           |
| 5    | Associate route table   | New pods need internet/NAT access        |
| 6    | Check CNI version       | Must be new enough for custom networking |
| 7    | Set CNI env var         | Enables custom/secondary CIDR support    |
| 8    | Terminate/recycle nodes | Replace old nodes to get new config      |
| 9    | Validate pod IPs        | See if new subnets are being used        |
| 10   | Cleanup                 | Don’t waste AWS resources/money          |

---

## 💡 **Extra Tips**

* **Always back up any critical config before running destructive actions.**
* **You can use Managed Node Groups for safer rolling updates.**
* For production, consider draining nodes instead of abrupt termination (`kubectl drain <node>`).
* **Never overlap CIDR ranges!**

---
