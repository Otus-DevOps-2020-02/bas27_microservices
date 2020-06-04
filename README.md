### _Мониторинг приложения и инфраструктуры_

Мониторинг Docker контейнеров \
Визуализация метрик \
Сбор метрик работы приложения и бизнес метрик \
Настройка и проверка алертинга \
Много заданий со ⭐ (необязательных)


1. Открывать порты в файрволле для новых сервисов нужно самостоятельно по мере их добавления.

2. Создадим Docker хост в GCE и настроим локальное окружение на работу с ним

`$ export GOOGLE_PROJECT=_ваш-проект_`

### Создать докер хост
```
docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host
```

Создадим правило фаервола для Prometheus и Puma:

```
gcloud compute firewall-rules create prometheus-default --allow tcp:9090 &&
gcloud compute firewall-rules create puma-default --allow tcp:9292
```

### Настроить докер клиент на удаленный докер демон
`eval $(docker-machine env docker-host)`

### Переключение на локальный докер

`eval $(docker-machine env --unset)`

`$ docker-machine ip docker-host`

`gcloud compute firewall-rules create cadvisor-default --allow tcp:8080`
```
$ export USER_NAME=xxx # где username - ваш логин на Docker Hub
$ docker build -t $USER_NAME/prometheus .
```
Запустим сборку образов:

`for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done`

Запустим сервисы:
```
$ docker-compose up -d
$ docker-compose -f docker-compose-monitoring.yml up -d
```
`gcloud compute firewall-rules create grafana-default --allow tcp:3000`

Запустим новый сервис:

`$ docker-compose -f docker-compose-monitoring.yml up -d grafana`


Ссылки на образы в DockerHub:

https://hub.docker.com/u/bas27
