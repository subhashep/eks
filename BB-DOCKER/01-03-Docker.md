# 🧪 Module 1 - Lab 3: Customizing Tomcat with JSP and Pushing to ECR

**Focus:**

* Pulling the official `tomcat` image
* Creating a custom JSP page that displays timezone-based current dates
* Building a custom image called `TimeCat`
* Tagging and pushing the image to **Amazon ECR**

**Environment:**  
- EC2 instance with Docker and `code-server` running  
- IAM Role: Admin access with ECR permissions

---

## 🎯 Lab Objectives

- Pull the official Tomcat Docker image
- Create a JSP page to display current time in US, Europe, and India
- Build a custom Docker image called `TimeCat`
- Push the `TimeCat` image to Amazon ECR

---

## ✅ Pre-Lab Setup

Ensure Docker is running:

```bash
sudo service docker start
docker version
````

Install the AWS CLI **if not** already available:

```bash
sudo yum install -y awscli
aws configure   # Configure with IAM user credentials
```

---

## 🐳 Step: Pull the Official Tomcat Image

```bash
docker pull tomcat:10.1
```

---

## 📁 Step: Prepare Your Project Structure

```bash
mkdir -p ~/lab3-timecat/webapps/ROOT
cd ~/lab3-timecat
```

### Create `webapps/ROOT/time.jsp`:

```jsp
<%@ page import="java.util.*, java.text.*" %>
<html>
<head><title>TimeCat JSP</title></head>
<body>
  <h2>Current Times by Region</h2>
  <ul>
    <%
      SimpleDateFormat sdf = new SimpleDateFormat("EEE, d MMM yyyy HH:mm:ss z");
      String[] zones = {"America/New_York", "Europe/London", "Asia/Kolkata"};
      for (String zone : zones) {
        sdf.setTimeZone(TimeZone.getTimeZone(zone));
        out.println("<li>" + zone + ": " + sdf.format(new Date()) + "</li>");
      }
    %>
  </ul>
</body>
</html>
```

---

## 🐳 Step: Create the Dockerfile

Create a file named `Dockerfile` in the `~/lab3-timecat/` directory:

```Dockerfile
FROM tomcat:10.1
COPY webapps/ /usr/local/tomcat/webapps/
```

---

## 🔨 Step: Build the Custom Image

```bash
docker build -t timecat:1.0 .
```

Verify the image:

```bash
docker images
```

---

## 🧪 Step: Test Locally

```bash
docker run --rm -d -p 8082:8080 --name timecat-container timecat:1.0
```

Access: curl http://localhost:8082/time.jsp

---

## 🛳️ Step: Push to Amazon ECR

### Create an ECR Repository (if not done)

```bash
aws ecr create-repository --repository-name ep33-repo --region <YOUR_REGION_ID>
```

Replace `<YOUR_REGION_ID>` with your actual region, e.g. `<YOUR_REGION_ID>`.

---

### Authenticate Docker with ECR

```bash
aws ecr get-login-password --region <YOUR_REGION_ID> | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.<YOUR_REGION_ID>.amazonaws.com
```

---

### Tag the Local Image

```bash
docker tag timecat:1.0 <ACCOUNT_ID>.dkr.ecr.<YOUR_REGION_ID>.amazonaws.com/ep33-repo:1.0
```

---

### Push to ECR

```bash
docker push <ACCOUNT_ID>.dkr.ecr.<YOUR_REGION_ID>.amazonaws.com/ep33-repo:1.0
```

---

### ✅ 1. **List all ECR repositories in `<YOUR_REGION_ID>`**

```bash
aws ecr describe-repositories --region <YOUR_REGION_ID>
```

To list **just names**:

```bash
aws ecr describe-repositories \
  --region <YOUR_REGION_ID> \
  --query "repositories[].repositoryName" \
  --output table
```

---

### ✅ 2. **Get details of one repository: `ep33-repo`**

```bash
aws ecr describe-repositories \
  --repository-names ep33-repo \
  --region <YOUR_REGION_ID>
```

---

### ✅ 3. **Get details of all images in `ep33-repo`**

```bash
aws ecr list-images \
  --repository-name ep33-repo \
  --region <YOUR_REGION_ID>
```

To get more detail (e.g., image size, pushedAt, tags):

```bash
aws ecr describe-images \
  --repository-name ep33-repo \
  --region <YOUR_REGION_ID>
```
---

### ✅ 4. **Get details of the image `timecat:latest` in `ep33-repo`**

```bash
aws ecr describe-images \
  --repository-name ep33-repo \
  --image-ids imageTag=latest \
  --region <YOUR_REGION_ID>
```

To be specific to the `timecat` image, just ensure the correct tag is used (e.g., `imageTag=timecat` or `latest` if that's how you tagged it).

---

## 🧹 Step: Cleanup

```bash
docker stop timecat-container
docker rm timecat-container
docker rmi timecat:1.0
docker rmi tomcat:10.1
```

---

## 📝 Lab Validation Checklist

* [ ] JSP page shows correct times for US, Europe, and India
* [ ] Custom image `TimeCat` built successfully
* [ ] Image pushed to ECR
* [ ] Local container works on port 8082

---

## 📘 Key Concepts Reinforced

| Concept                | Demonstrated In                      |
| ---------------------- | ------------------------------------ |
| Image layering         | `Dockerfile` builds on top of Tomcat |
| Java-based web dynamic | `time.jsp` using `SimpleDateFormat`  |
| ECR push flow          | `tag`, `login`, `push` to ECR        |
| Cleanup discipline     | Remove local containers/images       |

---
