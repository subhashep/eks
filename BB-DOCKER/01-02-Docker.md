Here is the fully regenerated 
---

````markdown
# 🧪 Module 1 - Lab 2: MySQL Server and Client Using Docker

**Reflecting:**

* ✅ MySQL network creation
* ✅ MySQL data volume creation
* ✅ MySQL server initialization with password
* ✅ MySQL client access from another container
* ✅ Practice of basic SQL commands
* ✅ Inspection of persistent volume
* ✅ **Full cleanup** of container, volume, network, and image

**Environment:**  
- EC2 instance (Amazon Linux 2) with Docker and `code-server` running  
- IAM Role: Admin Access

---

## 🎯 Lab Objectives

- Deploy a MySQL server container with persistent volume
- Connect to the server using a MySQL client container via Docker network
- Create a new user with cross-container access
- Practice SQL operations using the MySQL CLI
- Clean up all resources after the lab

---

## ✅ Pre-Lab Setup

Ensure Docker is installed and running:

```bash
sudo service docker start
docker version
````

Clean up any stale Docker resources:

```bash
docker stop $(docker ps -aq) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null
docker rmi -f $(docker images -q) 2>/dev/null
docker volume prune -f
docker network prune -f
```

---

## 🧱 Step 1: Create Custom Docker Network and Volume

```bash
docker network create mysql-net
docker volume create mysql-data
```

---

## 🐬 Step 2: Run MySQL Server Container

```bash
docker run --name mysql-server \
  --network mysql-net \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -v mysql-data:/var/lib/mysql \
  -d mysql:8.0
```

> 💡 Give it a few seconds to fully initialize before the next step.

---

## 🔐 Step 3: Create a Cross-Container Access User

Connect to the server shell:

```bash
docker exec -it mysql-server mysql -uroot -prootpass
```

Inside MySQL:

```sql
CREATE USER 'labuser'@'%' IDENTIFIED BY 'labpass';
GRANT ALL PRIVILEGES ON *.* TO 'labuser'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

---

## 🔌 Step 4: Connect via MySQL Client Container

```bash
docker run -it --rm \
  --network mysql-net \
  mysql:8.0 mysql -h mysql-server -ulabuser -plabpass
```

---

## 🧪 Step 5: Practice SQL Operations

Inside the MySQL prompt:

```sql
CREATE DATABASE labdb;
USE labdb;

CREATE TABLE notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    content TEXT NOT NULL
);

INSERT INTO notes (content) VALUES ('Dockerized MySQL rocks!');
INSERT INTO notes (content) VALUES ('This data is persistent via volume!');

SELECT * FROM notes;


EXIT;
```

---

## 📦 Step 6: Inspect MySQL Volume (Optional)

From a debug container:

```bash
docker run --rm -it --volumes-from mysql-server busybox sh
ls -lh /var/lib/mysql/labdb
```

File: notes.ibd
This is the InnoDB data file where MySQL stores the table notes you created earlier.

The file contains all rows, indexes, and metadata for that specific table.
---

## 🧹 Step 7: Full Cleanup

After completing the lab, clean up all Docker resources:

```bash
docker stop mysql-server
docker rm mysql-server
docker volume rm mysql-data
docker network rm mysql-net
docker rmi mysql:8.0
```

---

## 📝 Lab Validation Checklist

* [ ] MySQL server container runs with password and volume
* [ ] MySQL client connects using a created user
* [ ] SQL queries executed successfully from client
* [ ] Data visible in shared volume
* [ ] All Docker resources cleaned up at the end

---

## 📘 Key Concepts Reinforced

| Concept                    | Demonstrated In                     |
| -------------------------- | ----------------------------------- |
| Docker volumes             | `-v mysql-data:/var/lib/mysql`      |
| Cross-container networking | `--network mysql-net`               |
| MySQL authentication       | `CREATE USER 'user'@'%' ...`        |
| SQL practice               | `mysql` CLI inside client container |
| Cleanup discipline         | `docker stop/rm/volume/network/rmi` |

---
