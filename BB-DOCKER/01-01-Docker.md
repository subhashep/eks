## 🧪 Module 1 - Lab 1: Getting Started with Docker (Level 1)

**Environment:**

* EC2 instance (Amazon Linux 2) with Docker and `code-server` running
* IAM Role: Admin Access (not required for local Docker, but assumed for later labs)

---

### 🎯 Lab Objectives

By the end of this lab, learners will:

* Pull and run a basic Docker container
* Understand container lifecycle: start, stop, restart, remove
* Use Docker with TTY and shell access
* Work with container ports and networks

---

### ✅ Check if Docker installed

* Docker must be installed and running on the EC2 instance

```bash
sudo docker --version

```

---

### ✅ Pre-requisites

* Run the following to ensure Docker is installed:

```bash
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -aG docker ec2-user
newgrp docker
docker version
```

---

## 🚀 Step-by-Step Lab Instructions

---

### 🧱 Step: Pull the NGINX Docker Image

```bash
docker pull nginx
```

**Explanation:**
Downloads the latest `nginx` image from Docker Hub and stores it locally.

---

To list all Docker images stored **locally** on your EC2 instance, use:

```bash
docker images
```

### 🔍 Explanation:

| Column       | Description                        |
| ------------ | ---------------------------------- |
| `REPOSITORY` | Image name (e.g., `nginx`)         |
| `TAG`        | Image version tag (e.g., `latest`) |
| `IMAGE ID`   | Unique ID of the image             |
| `CREATED`    | When the image was created         |
| `SIZE`       | Size of the image on disk          |

---

### 🛠 Example Output:

```bash
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    4bb46517cac3   2 weeks ago    142MB
```

---

### 🚦 Step: Run a Container from the Image

```bash
docker run --name mynginx -d -p 8080:80 nginx
```

**Explanation:**

* `--name mynginx`: Assigns a name to the container
* `-d`: Detached mode (runs in background)
* `-p 8080:80`: Maps host port 8080 to container port 80
* `nginx`: Image name

* Access
>> On code-server terminal:

```bash

curl localhost:8080

```
>> Access via browser:

>>> Modify EC2 Security Group:
>>>> Add rule: All traffic from Anywhere 0.0.0.0/0 (very dangerous! use it only in a training lab for a quick check. Should remove once done) 
>>>> In broser `http://<your-ec2-public-ip>:8080`
>>>> Once done, go back to Security Group and remove the newly added rule 0.0.0.0/0

---

### 🧰 Step: List Running and All Containers

```bash
docker ps             # List running containers
docker ps -a          # List all containers (running + exited)
```

---

### 🌐 Step: Docker Network and Port Details

```bash
docker inspect mynginx
```

Look for:

* `"IPAddress"` under `"NetworkSettings"`
* `"Ports"` mapping details

To list all Docker networks:

```bash
docker network ls
```

To inspect a specific network:

```bash
docker network inspect bridge
```

---

### 🧹 Step: Cleanup All Containers and Images

```bash
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi nginx
```

> ⚠️ Use with caution – this removes all containers and the image.

---

## 📘 Summary

| Command                        | Purpose                           |
| ------------------------------ | --------------------------------- |
| `docker pull`                  | Fetch image from registry         |
| `docker run`                   | Start new container               |
| `docker ps`, `ps -a`           | View containers (running / all)   |
| `docker stop/start/restart/rm` | Manage container lifecycle        |
| `docker run -it`               | Get shell access inside container |
| `docker inspect`               | View container details            |
| `docker network ls`            | List Docker networks              |

---

### 🧹 Bonus: Remove unused (dangling) images

```bash
docker image prune
```

---


### 🔄 Step: Stop, Start, Restart, and Remove the Container

```bash
docker stop mynginx     # Gracefully stops container
docker start mynginx    # Starts previously stopped container
docker restart mynginx  # Restarts the container
docker rm mynginx       # Removes container (must be stopped)
```

> 💡 Use `docker rm -f mynginx` to force remove if running.

---

### 🖥️ Step: Run Container with Interactive Shell (TTY)

```bash
docker run -it --name nginxshell nginx /bin/bash
```

**Explanation:**

* `-it`: Interactive + TTY
* `/bin/bash`: Starts shell inside the container (note: nginx image uses `sh`, not `bash`)

If bash is unavailable, use:

```bash
docker run -it --name nginxshell nginx /bin/sh

```

Great — now that you're **inside the running NGINX container** via `-it` and using `/bin/bash` (or `/bin/sh`), you can explore various aspects of the container from **within**, such as:

---

## 🧩 🔧 Application-Level: NGINX Runtime and Files

```bash
nginx -v                      # Show nginx version
nginx -T                     # Dump full nginx config (if supported)
cat /etc/nginx/nginx.conf    # View the main config file

```

---

## 🌐 Network Insight

```bash

cat /proc/net/fib_trie

cat /etc/hosts

```


---

## 🔍 🐳 Docker Runtime/Metadata (from inside container)

Note: Limited visibility from inside, but a few indicators:

```bash
cat /proc/1/cgroup
```

* Shows container runtime paths. Look for `docker` in the output.

```bash
hostname
```

* Shows the container's hostname (same as its container ID by default).

```bash
env
```

* Shows environment variables, which may include metadata passed at `docker run` time.

---

## 📦 📁 Filesystem / OS Insight

```bash
df -h                      # View disk usage INSIDE CONTAINER (***Copy the results for a comparison)

exit                       # Le
```

---

## 🧼 Back to EC2 terminal: 

From **outside** the container (in host shell):

```bash
df -h                      # View disk usage OUTSIDE CONTAINER (***Copy the results for a comparison)

```

---


Let’s compare and **explain what’s happening inside vs. outside** the container using your `df -h` results:

---

## 📍 Host (EC2) Filesystem

```text
/dev/nvme0n1p1   30G  4.1G   26G  14% /
```

This is your **primary EBS volume** mounted as the root (`/`) on the EC2 instance. All Docker data, container layers, images, logs, etc., are stored under:

```
/var/lib/docker/
```

This path is **on the same EBS volume** — `nvme0n1p1`.

---

## 📍 Inside the Container

```text
Filesystem        Mounted on        Notes
overlay           /                Docker union FS combining layers (container’s root FS)
tmpfs             /dev             In-memory for device files
shm               /dev/shm         Shared memory between processes
/dev/nvme0n1p1    /etc/hosts       This is a *bind mount* from the host for container name resolution
tmpfs             /proc/acpi       Dummy tmpfs (read-only or empty)
tmpfs             /sys/firmware    Dummy tmpfs (read-only or empty)
```

---

## 📦 Explanation of Container Storage Allocation

| Layer                    | Purpose                                                                               |
| ------------------------ | ------------------------------------------------------------------------------------- |
| `overlay`                | Union filesystem that combines image layers + container's write layer. Mounted as `/` |
| `/dev/nvme0n1p1`         | **Same physical EBS volume as host** — only mounted for `hosts` file override         |
| `tmpfs`, `shm`           | Ephemeral memory-based filesystems created by Docker during runtime                   |
| Image & Container Layers | Pulled image layers stored on host under `/var/lib/docker/overlay2/`                  |
| Writeable Container FS   | Each container has a unique *write layer* (changes only persist here)                 |

---

## 🧠 Key Takeaways

* ✅ **Containers do not get their own disks**; they share the host’s disk via Docker’s `overlay` driver.
* ✅ The `overlay` FS is a **virtual union** of:

  * Read-only image layers (from `docker pull`)
  * A thin writable layer unique to each container (stored in `/var/lib/docker/overlay2/CONTAINER_ID`)
* ✅ Containers can't see or access host's entire filesystem unless explicitly mounted.
* ✅ You saw `/dev/nvme0n1p1` inside the container because Docker **bind-mounts** specific files like `/etc/hosts`, `/etc/resolv.conf`, and `/etc/hostname`.

---

## 🔍 Visual Diagram

```
[ EC2 Host Disk (EBS Volume: /dev/nvme0n1p1) ]
        |
  /var/lib/docker/
        |
     overlay2/
        |
  +----------------------------+
  | Container Read-Only Image |
  | Container Writable Layer  |
  |   => Mounted as `/`       |
  +----------------------------+
```

---


## 🧼 Full Cleanup Commands Before the next Lab

### 🔻 Stop and Remove All Containers

```bash
docker stop $(docker ps -aq) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null
```

> Stops and removes **all containers** (running and exited). `2>/dev/null` hides "no container" errors if none exist.

---

### 🧯 Remove All Docker Images

```bash
docker rmi -f $(docker images -q) 2>/dev/null
```

> Removes **all images**, including intermediate layers. Use `-f` to force remove even if they're in use.

---

### 🗑️ Remove All Volumes (Optional)

```bash
docker volume rm $(docker volume ls -q) 2>/dev/null
```

> Removes all Docker-managed volumes. Skip this if you want to **retain volume data** from earlier labs.

---

### 🌐 Remove All User-Created Networks (Optional)

```bash
docker network prune -f
```

> Cleans up all **custom networks** (default ones like `bridge`, `host`, and `none` will remain).

---

## ⚠️ Caution Summary

| Command Group   | What it Removes              | Is It Safe? |
| --------------- | ---------------------------- | ----------- |
| `ps -aq` + `rm` | All containers               | ✅ Yes       |
| `images -q`     | All images (used/unused)     | ⚠️ Be sure  |
| `volume ls -q`  | All volumes (DBs, user data) | ⚠️ Confirm  |
| `network prune` | All custom networks          | ✅ Yes       |

---

### 💡 Dry-Run Tip

If you're unsure, try this first:

```bash
docker ps -a
docker images
docker volume ls
```

Then selectively remove what you need.

---

### End of Lab

---
