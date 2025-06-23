**StatefulSets** in the first place!

---

## **1. Key Differences Recap**

* **ReplicaSet/Deployment**: Pods are **identical**, stateless, can be created/destroyed anywhere/anytime, and typically use ephemeral storage. Names/identities change. No *stable* storage unless you mount a shared volume (which defeats true isolation).
* **StatefulSet**: Pods have **stable, unique identities**, *sticky* persistent volumes, and **ordered**, graceful rolling updates/deletes. Pod names and their associated storage stay the same, even if the pod is deleted and recreated.

---

## **2. Stateful Example: StatefulSet with Persistent Data**

Imagine a **PostgreSQL database cluster** managed as a StatefulSet:

* **Each pod** is `pg-0`, `pg-1`, etc.
* Each gets its **own PersistentVolumeClaim** (`pg-data-pg-0`, `pg-data-pg-1`).
* When a pod restarts (crash or reschedule), Kubernetes always mounts **the same persistent volume** back to `pg-0`, ensuring all data remains.

---

### **Hands-on Demo: See the Stability of State**

#### **A. Define a StatefulSet with Persistent Storage**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: demo-db
spec:
  serviceName: "demo-db"
  replicas: 2
  selector:
    matchLabels:
      app: demo-db
  template:
    metadata:
      labels:
        app: demo-db
    spec:
      containers:
      - name: db
        image: postgres:14
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pgdata
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

* Creates `demo-db-0` and `demo-db-1`, **each with their own volume**.

#### **B. Prove State Survives Pod Restart/Reschedule**

1. **Write some data to demo-db-0** (connect via `kubectl exec` and add a row).
2. **Delete demo-db-0**:

   ```sh
   kubectl delete pod demo-db-0
   ```
3. **Kubernetes automatically recreates demo-db-0**—**attaching the same volume** (`pgdata-demo-db-0`).
4. **Reconnect and verify**: The database row you created is **still there**.

   * **Pod name** and **PVC name** are stable and reused.

#### **C. Even If the Node Fails**

* If the node running `demo-db-0` is deleted, Kubernetes will reschedule the pod elsewhere **and re-attach the correct EBS volume** (on AWS), ensuring data isn’t lost.

---

## **3. Real-World StatefulSet Use Cases**

* **Databases**: MySQL, PostgreSQL, MongoDB, Cassandra, etc.
* **Distributed caches**: Redis (in cluster mode)
* **Kafka/Zookeeper clusters**
* Any app requiring **stable network identity** and **persistent storage**

---

## **4. Why Not Use Deployments for Databases?**

* Deployments offer **no guarantee** of attaching the *same* storage or keeping the *same* network identity for a pod.
* Data loss or split-brain scenarios can occur if two pods point to the same PVC or try to claim different volumes.

---

## **5. Summary Table**

|              | Deployment/ReplicaSet | StatefulSet               |
| ------------ | --------------------- | ------------------------- |
| Pod Names    | random                | stable (`app-0`, `app-1`) |
| Storage      | shared/ephemeral      | stable per-pod PVC        |
| Pod Identity | not sticky            | sticky                    |
| Use Case     | stateless apps        | databases, stateful apps  |

---

## **Quick Visualization**

```
[Pod: demo-db-0] ---> [PVC: pgdata-demo-db-0] ---> [EBS: demo-db-0-data]  (always same mapping!)
```

Even if you delete `demo-db-0`, it **comes back with all data** intact.

---


* Deploy a **StatefulSet** of 2 pods running NGINX with *per-pod persistent storage*
* Write a file to one pod’s volume
* Delete/restart the pod
* Show the file/data is preserved and unique to the pod, even after the pod is recreated

---

# 📝 **Kubernetes StatefulSet Statefulness Demo**

## **Step 1: Create a StorageClass and PersistentVolume (if needed)**

> *Skip this if your cloud provider offers dynamic provisioning (EKS, GKE, etc. do this automatically). For Minikube:*

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-manual
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

*But in cloud, you can proceed directly!*

---

## **Step 2: Deploy the StatefulSet**

```yaml
# statefulset-demo.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: demo-nginx
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: demo-nginx
  template:
    metadata:
      labels:
        app: demo-nginx
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: nginx:alpine
        command: ["sh", "-c", "while true; do sleep 3600; done"]
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

```sh
kubectl apply -f statefulset-demo.yaml
kubectl get pods -l app=demo-nginx
```

---

## **Step 3: Write a Unique File to Each Pod’s Storage**

```sh
kubectl exec demo-nginx-0 -- sh -c 'echo Hello from pod 0 > /usr/share/nginx/html/hello.txt'
kubectl exec demo-nginx-1 -- sh -c 'echo Hello from pod 1 > /usr/share/nginx/html/hello.txt'
```

Verify:

```sh
kubectl exec demo-nginx-0 -- cat /usr/share/nginx/html/hello.txt
kubectl exec demo-nginx-1 -- cat /usr/share/nginx/html/hello.txt
```

---

## **Step 4: Delete One Pod and Watch It Recreate**

```sh
kubectl delete pod demo-nginx-0
kubectl get pods -l app=demo-nginx   # Wait for demo-nginx-0 to restart
kubectl exec demo-nginx-0 -- cat /usr/share/nginx/html/hello.txt
```

You will see:

```
Hello from pod 0
```

**Data is preserved—pod’s identity and volume are sticky!**

---

## **Step 5: List the PersistentVolumeClaims**

```sh
kubectl get pvc
```

Output:

```
www-demo-nginx-0
www-demo-nginx-1
```

Each pod gets its own PVC!

---

## **Step 6: Scale Up/Down and See More PVCs**

```sh
kubectl scale statefulset demo-nginx --replicas=3
kubectl get pvc
kubectl exec demo-nginx-2 -- sh -c 'echo Hello from pod 2 > /usr/share/nginx/html/hello.txt'
kubectl exec demo-nginx-2 -- cat /usr/share/nginx/html/hello.txt
```

> Scale down and then up again—`demo-nginx-2` will come back with the same PVC, preserving data.

---

## **What Does This Prove?**

* **Stable Identity:** Pod names and PVCs stick.
* **Stateful Storage:** Each pod always gets its *own data*, even if restarted.
* **Perfect for Databases:** This is exactly how you’d run PostgreSQL, MySQL, MongoDB, Redis Cluster, Kafka, etc. in K8s.

---
