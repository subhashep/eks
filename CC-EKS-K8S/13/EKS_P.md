Absolutely! Here’s your **updated, step-by-step, classroom-ready lab** for deploying **Fluent Bit** via Helm (the best practice for Kubernetes 1.29+), integrating with **CloudWatch Logs**, and visualizing application and cluster metrics/logs using **Prometheus**, **Grafana**, and **CloudWatch Insights**. All explanations are beginner-to-intermediate, with pointers to key concepts and AWS best practices.

---

# 🧪 EKS Observability Lab: Fluent Bit via Helm, Prometheus, Grafana, CloudWatch Insights

---

## 🎯 **Learning Goals**

* Deploy a microservice app with observable logs and metrics (using podinfo)
* Collect logs from all pods and nodes with Fluent Bit (Helm)
* Route logs to AWS CloudWatch Logs
* Scrape and visualize metrics with Prometheus and Grafana
* Explore and analyze logs with CloudWatch Logs Insights
* Learn AWS’s hybrid (open + managed) observability approach for EKS

---

## 1️⃣ **Deploy Demo App for Metrics & Logs**

### a. **Namespace & App Deployment**

```bash
kubectl create ns demo
kubectl apply -n demo -f https://raw.githubusercontent.com/stefanprodan/podinfo/master/kustomize/deployment.yaml
```

* *Deploys `podinfo`, a real app emitting Prometheus metrics and structured logs.*

### b. **Expose App with LoadBalancer**

```bash
kubectl expose deployment podinfo --type=LoadBalancer --name=podinfo-ui -n demo --port=9898 --target-port=9898
kubectl get svc -n demo podinfo-ui
```

* *Open `http://<EXTERNAL-IP>:9898` in your browser. Click around to generate activity (and logs).*

---

## 2️⃣ **Install Fluent Bit via Helm (Log Forwarding)**

### a. **Add Fluent Bit Helm Repo & Update**

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

### b. **Create Namespace for Logging**

```bash
kubectl create ns logging
```

### c. **Install Fluent Bit (Basic, All Defaults)**

```bash
helm install fluent-bit fluent/fluent-bit --namespace=logging
```

*This installs Fluent Bit as a DaemonSet—one pod on every node to collect all logs.*

---

### 🧑‍🔬 **AWS Integration Tips:**

* **CloudWatch Output:** To send logs to CloudWatch, Fluent Bit needs to be configured with the CloudWatch output plugin, an IRSA-enabled ServiceAccount, and correct log group/region.
* **For a fully AWS-integrated setup (optional, advanced):**

  * [See Fluent Bit Helm Chart values for CloudWatch](https://github.com/fluent/helm-charts/blob/main/charts/fluent-bit/values.yaml)
  * Provide a values.yaml with CloudWatch details and service account.
  * Example install (with log group and region):

    ```bash
    helm install fluent-bit fluent/fluent-bit \
      --namespace=logging \
      --set backend.type=cloudwatch \
      --set backend.cloudwatch.region=${AWS_REGION} \
      --set backend.cloudwatch.log_group_name=/eks/fluentbit/logs
    ```

---

## 3️⃣ **Install Prometheus & Grafana (Metrics Collection & Visualization)**

### a. **Add Helm Repo & Install**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

### b. **Expose Prometheus and Grafana UIs**

```bash
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus

kubectl patch svc prometheus-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc -n monitoring prometheus-grafana
```

* **Prometheus UI:** `http://<EXTERNAL-IP>:9090`
* **Grafana UI:** `http://<EXTERNAL-IP>:80` or `:3000`

### c. **Get Grafana Admin Password**

```bash
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

* Username: `admin`
* Password: *(above)*

---

## 4️⃣ **Explore Logs in AWS CloudWatch**

### a. **Find Your Log Group**

* Go to AWS Console → **CloudWatch → Log groups**
* Look for log groups like `/eks/fluentbit/logs`, `/aws/containerinsights/<cluster>/application`, or similar

### b. **Search Logs**

* Click into a log group and use **Log Insights** to run queries, e.g.:

  ```sql
  fields @timestamp, @message
  | filter kubernetes.namespace_name="demo"
  | sort @timestamp desc
  | limit 20
  ```
* **You can filter by pod, namespace, log level, etc.**

---

## 5️⃣ **View Metrics in Grafana & Prometheus**

* **Grafana:** Use default Kubernetes dashboards or create a panel for podinfo metrics.
* **Prometheus:** Explore `/metrics` endpoint or custom queries (e.g., `http_requests_total`, `process_cpu_seconds_total`, etc.)

---

## 6️⃣ **(Optional, Advanced) Enable Container Insights**

If you want full AWS-native metrics, enable **Container Insights** for EKS via AWS CLI:

```bash
aws eks update-cluster-config \
  --name ${CLUSTER_NAME} \
  --region ${AWS_REGION} \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

* This sends detailed pod, node, and cluster metrics/logs to CloudWatch.

---

## 7️⃣ **Lab Cleanup**

```bash
kubectl delete ns demo
kubectl delete ns logging
kubectl delete ns monitoring
helm uninstall fluent-bit --namespace=logging
helm uninstall prometheus --namespace=monitoring
```

*Delete any log groups from CloudWatch if you wish (in the Console).*

---

## 📘 **Key Concepts and Explanations**

* **Fluent Bit** is a lightweight log shipper, running as a DaemonSet to collect and forward all logs (by default to stdout, can be configured for CloudWatch, Elasticsearch, etc.).
* **Helm** is the cloud-native “package manager” for Kubernetes; it handles all resources and dependencies.
* **Prometheus** scrapes application and cluster metrics, storing time-series data for monitoring and alerting.
* **Grafana** visualizes metrics from Prometheus, with flexible dashboards.
* **CloudWatch Logs/Insights** provide AWS-native log storage, querying, alerting, and long-term retention.
* **Podinfo** is a real microservice, useful for demoing metrics/logs collection and dashboarding.

---

## 🗺️ **Textual Visualization**

```
[Podinfo App] --logs--> [Fluent Bit DaemonSet] --logs--> [CloudWatch Logs/Insights]
     |                                              
  (Prometheus Scraper)                            
     |                                              
[Prometheus DB] --metrics--> [Grafana Dashboards]
```

---

## 📝 **Troubleshooting Table**

| Issue                  | Solution                                     |
| ---------------------- | -------------------------------------------- |
| No EXTERNAL-IP         | Check SG, subnet tags, node status           |
| Logs not in CloudWatch | Check Fluent Bit backend, IAM permissions    |
| Metrics missing        | Check Prometheus targets, pod labels         |
| Grafana login fail     | Use admin / password from secret (see above) |

---

**You can copy-paste this entire lab into a handout or LMS for practical, real-world EKS observability exercises!**
Let me know if you want a custom Helm values.yaml, sample CloudWatch queries, or more!
