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
export GOOGLE_PROJECT=xxx
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```
`eval $(docker-machine env docker-host)`

Prometheus будем запускать внутри Docker контейнера. Для начального знакомства воспользуемся готовым образом с DockerHub:

`docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus:v2.1.0`

`docker ps`

IP адрес созданной VM можно узнать, используя команду:

`docker-machine ip docker-host`

создайте простой Dockerfile, который будет копировать файл конфигурации с нашей машины внутрь контейнера:

monitoring/prometheus/Dockerfile
```
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
```

prometheus.yml

---
```global:
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

`export USER_NAME=bas27` \
`docker build -t $USER_NAME/prometheus:0.1 .`

Где USER_NAME - ВАШ логин от DockerHub.

Выполните сборку образов при помощи скриптов docker_build.sh в директории каждого сервиса.
```
/src/ui $ bash docker_build.sh
/src/post-py $ bash docker_build.sh
/src/comment $ bash docker_build.sh
```
Или сразу все из корня репозитория:
`for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done`

Определите в вашем
docker/docker-compose.yml файле новый сервис.
```
services:
...
prometheus:
image: ${USERNAME}/prometheus
ports:
- '9090:9090'
volumes:
- prometheus_data:/prometheus
command:
- '--config.file=/etc/prometheus/prometheus.yml'
- '--storage.tsdb.path=/prometheus'
- '--storage.tsdb.retention=1d'
volumes:
prometheus_data:
```
### _Exporters_
• Программа, которая делает метрики доступными для сбора Prometheus \
• Дает возможность конвертировать метрики в нужный для Prometheus формат \
• Используется когда нельзя поменять код приложения


Зайдем на хост: `docker-machine ssh docker-host` \
Добавим нагрузки: `yes > /dev/null`

Запушьте собранные вами образы на DockerHub:
`docker login`
Login Succeeded
```
$ docker push $USER_NAME/ui
$ docker push $USER_NAME/comment
$ docker push $USER_NAME/post
$ docker push $USER_NAME/prometheus
```

Ссылки на докер хаб

https://hub.docker.com/repository/docker/bas27/comment
https://hub.docker.com/repository/docker/bas27/post-py
https://hub.docker.com/repository/docker/bas27/ui
