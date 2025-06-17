# 🧪 EKS Workshop – Managing Your Code-Server IDE

Welcome to the EKS Workshop! This note guides you through the **daily usage of your Cloud IDE** (code-server) so you can focus on learning EKS without worrying about infrastructure management.

---

## 📄 Overview

Each participant creates an **IDE instance using CloudFormation**, which provides:

* A web-based code-server IDE
* Access via CloudFront
* IAM-powered EC2 with full developer permissions

To **optimize costs and reduce idle time**, follow these three steps:

---

## 🛠️ Day 1: Launch Your IDE Environment

1. **Launch CloudFormation Stack**
   Use the template: `epsh-code-server-CFN.yaml`

   > 💡 This will:
   >
   > * Launch an EC2 instance (IDE)
   > * Configure code-server and Caddy
   > * Set up CloudFront for secure access
   > * Auto-generate the login password via Secrets Manager

2. **Access Your IDE**

   Find these from the **CloudFormation stack outputs**:

   * ✅ `IdeUrl`: Your IDE URL (via CloudFront)
   * 🔐 `IdePasswordSecret`: Link to your password secret in Secrets Manager

---

## ⏸️ End of Each Day: Stop Your IDE

1. Go to the **EC2 Console**
2. Locate your IDE instance (identified by the tag `type=eksworkshop-ide`)
3. Select the instance and click **Stop**

> 💸 Stopping saves AWS cost by halting compute charges.

---

## ▶️ Start of Each Day: Resume IDE with CLI Script

Use the provided shell script to:

* Start your EC2 IDE instance
* Update the CloudFront distribution origin to the new DNS

### 🔧 Before Running the Script

Open the file `restart-code-server-ec2-and-update-cloudfront.sh`
Update these **two variables** at the top:

```bash
INSTANCE_ID="your-ec2-instance-id"        # e.g. i-0abc123456789def0
DIST_ID="your-cloudfront-distribution-id" # e.g. E1A2B3C4D5E6F7
```

You can find both in the **CloudFormation Outputs** or EC2/CloudFront consoles.

### ▶️ To Run:

```bash
bash restart-code-server-ec2-and-update-cloudfront.sh
```

⏳ Wait 3–5 minutes and access the **same IDE URL** you used earlier.

---

## ❌ Final Day: Delete the Stack

⚠️ On the **last day of the workshop**, go to the **CloudFormation Console** and delete the stack named:

```
epsh-code-server
```

> ⚠️ This will **terminate your IDE EC2 instance**, delete the CloudFront distribution, Secrets Manager password, and all related resources.

---

## 📌 Recap: What You Need to Do Each Day

| Day          | Action                                                |
| ------------ | ----------------------------------------------------- |
| Day 1        | Launch `epsh-code-server-CFN.yaml` via CloudFormation |
| End of Day   | Stop your EC2 IDE instance                            |
| Start of Day | Run the restart CLI script (update 2 parameters)      |
| Final Day    | Delete the CloudFormation stack                       |

---

Happy EKS Learning! 🚀
Let your IDE work for you — not the other way around.

---
