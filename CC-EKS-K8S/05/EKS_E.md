# 🟦 EKS Lab: Dynamic Kubernetes Dashboard Access from Code-Server

---

## 1️⃣ **Install jq (if not already installed)**

```bash
sudo yum -y install jq || sudo apt-get -y install jq
```

---

## 2️⃣ **Deploy the Official Kubernetes Dashboard**

```bash
# You can use the latest version or stick to v2.7.0
export DASHBOARD_VERSION="v2.7.0"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml
```

---

## 3️⃣ **Find the Dashboard Namespace and Service Name**

This will **automatically discover** the dashboard namespace and service name (and HTTPS port):

```bash
# Find the namespace where the dashboard is deployed (usually "kubernetes-dashboard")
DASHBOARD_NS=$(kubectl get svc --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.name | test("dashboard")) | .metadata.namespace' | head -n 1)

# Find the service name for the dashboard (should include "dashboard")
DASHBOARD_SVC=$(kubectl -n "$DASHBOARD_NS" get svc -o json | \
  jq -r '.items[] | select(.metadata.name | test("dashboard")) | .metadata.name' | head -n 1)

# Get the service port name for HTTPS (usually "https" or "https-dashboard")
PORT_NAME=$(kubectl -n "$DASHBOARD_NS" get svc "$DASHBOARD_SVC" -o json | \
  jq -r '.spec.ports[] | select(.port==443) | .name')

# Build the dashboard URL
DASHBOARD_URL="/api/v1/namespaces/${DASHBOARD_NS}/services/https:${DASHBOARD_SVC}:/${PORT_NAME:+proxy/}"

echo "Dashboard proxy path is: $DASHBOARD_URL"
```

* Typical output:

  ```
  Dashboard proxy path is: /api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
  ```

---

## 4️⃣ **Start the Dashboard Proxy (after killing old ones if any)**

```bash
# Kill old proxies if any
pkill -f "kubectl proxy"

# Start a new proxy
kubectl proxy --address=0.0.0.0 --port=8080 --disable-filter=true &
```

---

## 5️⃣ **Access the Dashboard in Browser**

1. In code-server, look for the forwarded port (`8080`) and use your environment’s base URL, e.g.:

   ```
   https://<your-code-server-base>/proxy/8080
   ```
2. Append the dashboard proxy path discovered above.
   **Full URL:**

   ```
   https://<your-code-server-base>/proxy/8080<dashboard_proxy_path>
   ```

   For example:

   ```
   https://d2uo4qwv8g03sd.cloudfront.net/proxy/8080/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
   ```

---

## 6️⃣ **Authenticate with EKS Token**

```bash
aws eks get-token --cluster-name <your-cluster-name> | jq -r '.status.token'
```

* Copy the output.
* Paste into the "Enter Token" field in the dashboard.

---

## 7️⃣ **Delete / Clean Up**

```bash
# Kill the proxy process
pkill -f 'kubectl proxy'

# Delete the dashboard
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml

unset DASHBOARD_VERSION
```

---

## **Optional: One-liner to Print the Full Dashboard URL**

```bash
PROXY_BASE_URL="https://<your-code-server-base>/proxy/8080"
DASHBOARD_NS=$(kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.metadata.name | test("dashboard")) | .metadata.namespace' | head -n 1)
DASHBOARD_SVC=$(kubectl -n "$DASHBOARD_NS" get svc -o json | jq -r '.items[] | select(.metadata.name | test("dashboard")) | .metadata.name' | head -n 1)
DASHBOARD_URL="/api/v1/namespaces/${DASHBOARD_NS}/services/https:${DASHBOARD_SVC}:/proxy/"
echo "Access your dashboard at:"
echo "${PROXY_BASE_URL}${DASHBOARD_URL}"
```

Replace `<your-code-server-base>` with your actual code-server hostname.

---

## **Summary Table (Step-by-Step)**

| Step | Command / Action       | Description                                    |
| ---- | ---------------------- | ---------------------------------------------- |
| 1    | Install jq             | For JSON parsing                               |
| 2    | Deploy Dashboard       | Installs dashboard                             |
| 3    | Discover Dashboard URL | Auto-generates the dashboard proxy URL         |
| 4    | Start Proxy            | Opens up access on port 8080                   |
| 5    | Build Browser URL      | Combine your base/proxy URL and dashboard path |
| 6    | Auth                   | Use EKS token for dashboard login              |
| 7    | Clean up               | Remove dashboard & kill proxy                  |

---

This approach is **robust, dynamic, and reproducible**—you never need to hardcode the namespace or service again!
