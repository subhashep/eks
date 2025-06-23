# 🟢 Observability Lab 2: Prometheus Metrics and Fluent Bit Logs Visualization in Grafana

> **Goal:**
> Visualize Kubernetes cluster metrics and logs using **Prometheus** and **Grafana**.
> Prometheus scrapes metrics from K8s objects; Fluent Bit ships logs; Grafana visualizes both.
> You’ll see **live podinfo metrics** and **application logs** in one pane!

---

## **0. Prerequisites**

* Lab 1 completed: Logs from K8s → CloudWatch via Fluent Bit and IRSA.
* EKS cluster running and `kubectl`/`helm`/`aws` CLIs installed.
* Cluster nodes can reach the Internet (for Helm chart downloads).

---

## **1. Deploy Prometheus Using Helm**

> We'll use [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) for all-in-one Prometheus, Alertmanager, and Grafana (plus CRDs).

```sh
kubectl create ns monitoring || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword='admin123' \
  --set grafana.service.type=NodePort
```

*Wait for pods:*

```sh
kubectl get pods -n monitoring
```

---

## **2. Expose Grafana UI**

> To access Grafana, port-forward to localhost.
> (Change port as needed.)

```sh
kubectl -n monitoring port-forward svc/kube-prom-stack-grafana 3000:80
```

* Open: [http://localhost:3000](http://localhost:3000)
* **Login:** user: `admin` / password: `admin123`

---

## **3. Validate Prometheus Metrics**

> You should see:
>
> * Cluster-wide CPU/memory/disk/network dashboards (default)
> * `podinfo` app metrics (search for “podinfo” in dashboards or explore Prometheus targets)

---

## **4. \[Optional] Configure CloudWatch Logs as Grafana Data Source**

> To view **K8s logs (from Fluent Bit)** in Grafana, add CloudWatch as a data source.

1. **IAM Permissions for Grafana:**

   * If using AWS Managed Grafana, assign the necessary CloudWatch ReadOnly policy.
   * If running Grafana inside EKS:
     Use [IRSA](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/#eks-irsa) for Grafana’s service account or just paste AWS keys in the Grafana UI (not recommended for prod).

2. **Add CloudWatch Data Source in Grafana:**

   * Go to **Configuration > Data Sources > Add data source**.
   * Select **CloudWatch**.
   * Enter **Region** (e.g., `us-east-1`), authentication method, etc.

3. **Create a Dashboard/Panel:**

   * Use “Logs” query type.
   * Select `/aws/containerinsights/$CLUSTER_NAME/application` as the log group.
   * Search/filter for `podinfo` or any other logs!

---

## **5. End-to-End Demo: Visualize Both Logs and Metrics**

* **Grafana “Explore” Panel**:
  Use Prometheus for metrics (e.g., `up{namespace="demo"}`), CloudWatch for logs.
* **Dashboards**:

  * Node health, cluster performance (Prometheus)
  * Application logs (CloudWatch via Fluent Bit)
  * Combine both in custom dashboards

---

## **6. \[Optional] Enable/Explore Container Insights Metrics in CloudWatch**

> In addition to Prometheus, Container Insights metrics are visible in the CloudWatch console
> (covered in Lab 1, but you can **import CloudWatch dashboards into Grafana** for a unified view).

---

## **7. Clean Up**

```sh
helm uninstall kube-prom-stack -n monitoring
kubectl delete ns monitoring
```

> (Delete CloudWatch Grafana data source manually, if needed.)

---

## **Architecture Diagram (Text Version)**

```
[K8s Pods: podinfo/demo, etc.]
         |
         |---(stdout logs)---> [Fluent Bit DaemonSet] ---IRSA---> [CloudWatch Logs]
         |
         |---(Prometheus metrics endpoints)---> [Prometheus Operator]
                                             |
                                [Prometheus metrics DB]---> [Grafana Dashboard UI]
                                             |                        |
                                  [CloudWatch Logs Data Source]<------|
```

---

## **References**

* [Kube Prometheus Stack (Helm)](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* [Grafana CloudWatch Data Source](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/)
* [AWS Container Insights Docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights.html)
* [IRSA for Grafana](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/#eks-irsa)

---

### **What did you achieve?**

* Cluster metrics (Prometheus) and logs (Fluent Bit → CloudWatch) visualized together in Grafana
* No secrets in pods (IRSA best practices)
* K8s observability for modern production

---
