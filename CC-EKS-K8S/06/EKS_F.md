
# 🟦 Lab: CoreDNS Administration & Custom DNS on EKS

> This lab teaches you how to check, modify, and troubleshoot CoreDNS, and how to add custom DNS entries

---

## **0️⃣ Set Up Your Environment**

```bash
export CLUSTER_NAME="ep33-eks-02"   # Change as needed
export AWS_REGION="us-east-1"
```

---

## **1️⃣ Update Your kubeconfig**

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
```

---

## **2️⃣ Check CoreDNS Health**

```bash
kubectl -n kube-system get deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
```

---

## **3️⃣ Back Up Current CoreDNS ConfigMap**

```bash
kubectl -n kube-system get configmap coredns -o yaml > coredns-backup-$(date +%F-%H%M).yaml
```

---

## **4️⃣ Edit CoreDNS ConfigMap for Custom DNS**

```bash
kubectl -n kube-system edit configmap coredns
```

**Insert this sample block into your `Corefile:` below the default `.:53 { ... }` block:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }

    lab.internal:53 {
        forward . 8.8.8.8
    }
```

*This means CoreDNS will forward all queries ending with `.lab.internal` to 8.8.8.8.*

---

## **5️⃣ Restart CoreDNS Pods**

```bash
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

---

## **6️⃣ Create a Service With a Custom DNS Name**

Suppose you want a Service to be addressable as `ep33.lab.internal`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ep33-custom-service
  namespace: default
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
EOF
```

> **Note:**
> This makes a service called `ep33-custom-service.default.svc.cluster.local`.
> To use a custom DNS name like `ep33.lab.internal`, you need to create an **A record** in an upstream DNS (e.g., in Route 53 or the forwarded DNS, if it’s authoritative for `.lab.internal`), or use the `hosts` plugin in CoreDNS.

---

### **Optionally Add a Hosts Entry in CoreDNS**

To hard-code a DNS record (for demo):

```yaml
    lab.internal:53 {
        hosts {
            10.100.38.184 ep33.lab.internal
            fallthrough
        }
        forward . 8.8.8.8
    }
```

* Replace `10.1.2.3` with the actual ClusterIP of your service:

  ```bash
  kubectl get svc ep33-custom-service
  ```

---

## **7️⃣ Test Your DNS Entry**

```bash
kubectl run dns-lab --rm -it --image=busybox:1.29 --restart=Never -- nslookup ep33.lab.internal
```

* **Expected output:**
  Should return the IP address you mapped (e.g., `10.1.2.3`).

---

## **8️⃣ Roll Back If Needed**

```bash
kubectl -n kube-system replace -f coredns-backup-YYYY-MM-DD-HHMM.yaml
kubectl -n kube-system rollout restart deployment coredns
```

---

## **9️⃣ Quick Summary Table**

| Step | Action                              | Why?                                       |
| ---- | ----------------------------------- | ------------------------------------------ |
| 1    | Update kubeconfig                   | Use correct cluster                        |
| 2    | Check CoreDNS health                | Ensure DNS is working                      |
| 3    | Back up ConfigMap                   | Safe rollback                              |
| 4    | Edit ConfigMap (add `lab.internal`) | Add custom DNS                             |
| 5    | Restart CoreDNS                     | Apply changes                              |
| 6    | Add Service, get IP                 | Something to resolve via custom DNS        |
| 7    | Test custom DNS                     | Prove it works inside the cluster          |
| 8    | Roll back if needed                 | Restore service in production environments |

---

## 💡 **Tips for Training**

* Practice adding/removing the `lab.internal` block and test live with `nslookup`.
* You can use the `hosts` plugin for demo; for production, use a proper DNS authority for `.lab.internal`.
* Always document the changes made to CoreDNS.

---
