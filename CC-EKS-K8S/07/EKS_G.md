# 🧪 Lab: EKS Networking – CNI, Pod Networking, and CoreDNS Service Resolution

---

## 🚩 **What Will You Learn?**

* What is `kubeconfig`? Why do we need it?
* How to connect your terminal to an EKS cluster
* What is the CNI (Container Network Interface) in Kubernetes/EKS?
* How to check that your cluster networking is working
* How DNS and service discovery works with CoreDNS

---

## 0️⃣ **Set Up Your Cluster Info**

> **Why?**
> You may have multiple clusters or be working with classmates—this step makes all commands portable.

```bash
export CLUSTER_NAME="ep33-eks-02"      # Change to your EKS cluster name
export AWS_REGION="us-east-1"          # Change to your AWS region
```

---

## 1️⃣ **What is kubeconfig and Why Do You Need It?**

> **kubeconfig** is a configuration file that tells `kubectl` how to connect to your cluster—what address to use, which user, and how to authenticate (with AWS, a token is used).
>
> * By default, the file is stored at `~/.kube/config`.
> * If you don’t set up kubeconfig, `kubectl` won’t know which cluster to connect to and will error out.

---

## 2️⃣ **Connect Your Terminal to EKS**

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
```

> **What does this command do?**
> It fetches the cluster's API endpoint, authentication info, and updates your kubeconfig file so that all your `kubectl` commands go to your EKS cluster.

---

## 3️⃣ **What is the EKS CNI Plugin and Why Does It Matter?**

> * **CNI** stands for **Container Network Interface**—it’s how Kubernetes gives network access to pods.
> * In EKS, the `aws-node` pods (one per worker node) provide networking using AWS VPC CNI.
> * This means: **every pod gets its own VPC IP address**!

---

### 3.1 **Check That the CNI Is Working**

```bash
kubectl -n kube-system get daemonset aws-node
```

> * **DaemonSet:** A special kind of deployment that ensures a pod runs on every node.
> * **aws-node:** The EKS CNI plugin.
> * The output shows how many pods are running; this number should match your node count.

---

### 3.2 **Check CNI Logs for Errors**

```bash
kubectl -n kube-system logs -l k8s-app=aws-node --tail=20
```

> * Look for errors or warnings in the output.
> * Healthy logs mean your pod networking is likely OK.

---

### 3.3 **See Pod Networking in Action**

```bash
kubectl get nodes -o wide
kubectl get pods -o wide --all-namespaces
```

> * Each pod should have an IP in your VPC subnet.
> * These are **real network IPs**, not fake or overlay addresses!

---

## 4️⃣ **Test Pod-to-Pod Networking**

> This confirms that your CNI is set up correctly—pods can communicate like VMs on the same subnet.

### 4.1 **Deploy Two Test Pods**

```bash
kubectl run test-a --image=busybox:1.28 --restart=Never -- sleep 3600
kubectl run test-b --image=busybox:1.28 --restart=Never -- sleep 3600
```

* These pods just sleep for 1 hour, so they stay alive for testing.

### 4.2 **Find Their IPs**

```bash
kubectl get pod test-a -o wide
kubectl get pod test-b -o wide
```

* Write down the `IP` field for `test-b`.

### 4.3 **Ping Between Pods**

```bash
kubectl exec test-a -- ping -c 4 192.168.20.178
```

> **Expected:**
> The ping should succeed. This means your CNI plugin is routing packets between pods correctly.

---

## 5️⃣ **What is CoreDNS and Why Does It Matter?**

> * **CoreDNS** is the DNS server inside your Kubernetes cluster.
> * It lets pods/services find each other by name (e.g., `nginx-service`), not just by IP.
> * It’s critical for service discovery in Kubernetes.

---

### 5.1 **Deploy an Example Application and Service**

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --name=nginx-service
```

* **Deployment:** Runs your app (nginx) in pods.
* **Service:** Creates a stable network endpoint (`nginx-service`) for accessing those pods.

---

### 5.2 **Test DNS Service Resolution**

```bash
kubectl run dns-tester --rm -it --image=busybox:1.28 --restart=Never -- sh
```

* This gives you a shell inside a test pod.

From inside the test pod, run:

```sh
nslookup nginx-service
wget --spider --timeout=2 nginx-service
```

* **nslookup:** Should return a ClusterIP address.
* **wget:** Should connect successfully to the service on port 80.

Type `exit` to leave the shell.

---

## 6️⃣ **Cleanup – Always Remove Test Resources**

```bash
kubectl delete deployment nginx
kubectl delete service nginx-service
kubectl delete pod test-a test-b
```

---

## 📝 **Lab Recap Table**

| Step | Action/Command                            | Why You’re Doing This                                   |
| ---- | ----------------------------------------- | ------------------------------------------------------- |
| 0    | Set cluster variables                     | For easy sharing/copy-paste and multi-user labs         |
| 1    | Learn about kubeconfig                    | Understand how `kubectl` connects to your cluster       |
| 2    | aws eks update-kubeconfig                 | Make sure your commands go to the correct EKS cluster   |
| 3    | Explore the CNI (aws-node DaemonSet/logs) | Verify pod networking is working as designed            |
| 4    | Test pod-to-pod communication             | Ensure all pods can reach each other in the VPC         |
| 5    | Learn/test CoreDNS                        | Verify DNS/service discovery works inside your cluster  |
| 6    | Cleanup                                   | Good practice; don’t leave unused pods/services running |

---

## 💡 **Key Takeaways**

* **kubeconfig** is like an address book + keychain for `kubectl`—it tells your CLI how to find and log in to your cluster.
* **CNI (aws-node DaemonSet)** enables real VPC networking for all pods—EKS’s “secret sauce.”
* **CoreDNS** lets Kubernetes services and pods find each other by name—no IP memorization needed!
* **Always clean up your test resources**—this saves cloud costs and keeps your cluster tidy.

---
