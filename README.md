# bas27_microservices

### _Устройство Gitlab CI. Построение процесса непрерывной поставки_


- Подготовить инсталляцию Gitlab CI

С помощью Terraform развернули хост для поднятия сервера Gitlab CI.\
Для запуска Gitlab CI мы будем использовать omnibus-установку.

https://docs.gitlab.com/omnibus/README.html \
https://docs.gitlab.com/omnibus/docker/README.html

Устанавливаем необходимую среду на сервере (скрипт `terraform\files\inst_docker copy.sh`)

В той же директории, где docker-compose.yml ( /srv/gitlab ) выполняем: `docker-compose up -d`
https://docs.gitlab.com/omnibus/docker/README.html#install-gitlab-using-docker-compose

- Подготовить репозиторий с кодом приложения

После входа на сервер Gitlab CI создаем группу, создаем проект

• Каждый проект в Gitlab CI принадлежит к группе проектов \
• В проекте может быть определен CI/CD пайплайн \
• Задачи (jobs) входящие в пайплайн должны исполняться на runners

```
> git checkout -b gitlab-ci-1
> git remote add gitlab http://<your-vm-ip>/homework/example.git
> git push gitlab gitlab-ci-1
```

- Описать для приложения этапы пайплайна

Чтобы сделать это нам нужно добавить в репозиторий файл .gitlab-ci.yml

```
> git add .gitlab-ci.yml
> git commit -m 'add pipeline definition'
> git push gitlab gitlab-ci-1
```

Создаем раннер:
```
docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
После запуска Runner нужно зарегистрировать, это можно сделать командой:
```
root@gitlab-ci:~# docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://<YOUR-VM-IP>/
Please enter the gitlab-ci token for this runner:
<TOKEN>
Please enter the gitlab-ci description for this runner:
[38689f5588fe]: my-runner
Please enter the gitlab-ci tags for this runner (comma separated):
linux,xenial,ubuntu,docker
Please enter the executor:
docker
Please enter the default Docker image (e.g. ruby:2.1):
alpine:latest
Runner registered successfully.
```

Разворачиваем приложение reddit

### _Системы мониторинга_

• Prometheus: запуск, конфигурация, знакомство с Web UI
• Мониторинг состояния микросервисов
• Сбор метрик хоста с использованием экспортера
• Задания со *

Создадим правило фаервола для Prometheus и Puma:
```
gcloud compute firewall-rules create prometheus-default --allow tcp:9090
gcloud compute firewall-rules create puma-default --allow tcp:9292
```

Создадим Docker хост в GCE и настроим локальное окружение на работу с ним
(ссылка на gist):
```
export GOOGLE_PROJECT=docker-275709
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```
eval $(docker-machine env docker-host)

Prometheus будем запускать внутри Docker контейнера. Для начального знакомства воспользуемся готовым образом с DockerHub:

`docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus:v2.1.0`

docker ps

IP адрес созданной VM можно узнать, используя команду:

docker-machine ip docker-host

создайте простой Dockerfile, который будет копировать файл конфигурации с нашей машины внутрь контейнера:

monitoring/prometheus/Dockerfile

FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/

prometheus.yml
```
---
global:
scrape_interval: '5s'
scrape_configs:
- job_name: 'prometheus'
static_configs:
- targets:
- 'localhost:9090'
- job_name: 'ui'
static_configs:
- targets:
- 'ui:9292'
- job_name: 'comment'
static_configs:
- targets:
- 'comment:9292'
```

В директории prometheus собираем Docker образ:

export USER_NAME=bas27
docker build -t $USER_NAME/prometheus .

Где USER_NAME - ВАШ логин от DockerHub.
