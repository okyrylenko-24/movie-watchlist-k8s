# Movie Watchlist API (Kubernetes)

REST API для ведення списку фільмів з використанням Spring Boot та PostgreSQL.

Проєкт виконаний у межах практичного проєкту №2 з дисципліни «Адміністрування Unix-подібних операційних систем» на основі попередньої роботи з Docker Compose.

## Технології

- Java 25, Spring Boot, Maven
- PostgreSQL 17, pgAdmin 4
- Docker, Docker Compose
- Kubernetes, Minikube, kubectl
- Traefik, Bash, GitHub Actions

## Запуск Kubernetes

1. Запустити Docker Desktop.
2. Створити `.env` за прикладом `.env.example`.
3. Відкрити Git Bash у корені проєкту.
4. Виконати:

```bash
bash k8s/deploy.sh
```

Скрипт запускає Minikube, збирає Docker-образ та розгортає всі Kubernetes-об'єкти.

Для доступу до API та pgAdmin в окремому терміналі:

```bash
minikube tunnel
```

API: http://127.0.0.1:8080/api/movies

pgAdmin: http://127.0.0.1:5050

Термінал із `minikube tunnel` повинен залишатися відкритим.

## Підключення pgAdmin

Увійти в pgAdmin, використовуючи `PGADMIN_DEFAULT_EMAIL` та `PGADMIN_DEFAULT_PASSWORD` із `.env`.

Створити нове підключення через Register → Server:

- Name: Movie Watchlist Kubernetes
- Host: watchlist-postgres
- Port: 5432
- Maintenance database: значення POSTGRES_DB
- Username: значення POSTGRES_USER
- Password: значення POSTGRES_PASSWORD

Для перегляду фільмів:

Databases → watchlist → Schemas → public → Tables → movies → View/Edit Data → All Rows.

Дані PostgreSQL та налаштування pgAdmin зберігаються в окремих PersistentVolumeClaim.

## Docker Compose

Для запуску без Kubernetes:

```bash
bash ./deploy.sh
```

Запускаються Spring Boot API, PostgreSQL та pgAdmin.

API: http://localhost:8080/api/movies

pgAdmin: http://localhost:5050

Docker Compose та Kubernetes використовують окремі сховища даних.

## Kubernetes

Spring Boot API, PostgreSQL та pgAdmin розгорнуті в окремих Deployment.

Для взаємодії використовуються Kubernetes Service. Дані зберігаються через PV/PVC, конфігурація — у ConfigMap, облікові дані — у Secret.

Для доступу до API налаштовані ClusterIP, NodePort, LoadBalancer та Traefik Ingress.

Для демонстрації обміну даними використовуються emptyDir та hostPath.

Перевірка Kubernetes:

```bash
kubectl get pods,deploy,rs,svc,ingress,pv,pvc
kubectl top pods
kubectl top nodes
```

Для зупинки кластера:

```bash
minikube stop
```

## CI/CD

GitHub Actions автоматично запускає `k8s/deploy.sh` після push у гілку main.

У тимчасовому кластері Minikube перевіряється запуск Kubernetes-об'єктів, REST API та вебінтерфейсу pgAdmin.

Файл `.env` із паролями не додається до GitHub.