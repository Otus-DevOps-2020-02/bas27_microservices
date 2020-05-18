# bas27_microservices

```
docker pull mongo:latest
docker build -t <your-dockerhub-login>/post:1.0 ./post-py
docker build -t <your-dockerhub-login>/comment:1.0 ./comment
docker build -t <your-dockerhub-login>/ui:1.0 ./ui
```
`docker network create reddit`
```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest &&\
docker run -d --network=reddit --network-alias=post bas27/post:1.0 &&\
docker run -d --network=reddit --network-alias=comment bas27/comment:1.0 &&\
docker run -d --network=reddit -p 9292:9292 bas27/ui:3.0
```
`docker kill $(docker ps -q)`

используем другие алиасы при запуске
```
docker run -d --network=reddit --network-alias=posts --network-alias=comments mongo:latest &&\
docker run -d --network=reddit --network-alias=post bas27/post:1.0 &&\
docker run -d --network=reddit --network-alias=comment bas27/comment:1.0 &&\
docker run -d --network=reddit -p 9292:9292 bas27/ui:1.0
```
`docker volume create reddit_db`

и подключим созданный раздел к контейнеру с монго:
```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest &&\
docker run -d --network=reddit --network-alias=post bas27/post:1.0 &&\
docker run -d --network=reddit --network-alias=comment bas27/comment:2.0 &&\
docker run -d --network=reddit -p 9292:9292 bas27/ui:3.3
```
## Работа с сетью

docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig

docker network create reddit --driver bridge

docker run -d --network=reddit mongo:latest
docker run -d --network=reddit bas27/post:1.0
docker run -d --network=reddit bas27/comment:2.0
docker run -d --network=reddit -p 9292:9292 bas27/ui:3.3

dns

--name <name> (можно задать только 1 имя)
--network-alias <alias-name> (можно задать множество алиасов)

docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest &&\
docker run -d --network=reddit --network-alias=post bas27/post:1.0 &&\
docker run -d --network=reddit --network-alias=comment bas27/comment:2.0 &&\
docker run -d --network=reddit -p 9292:9292 bas27/ui:3.3

Запустим приложение в 2 разных подсетях бридж

docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24

Запустим контейнеры
docker run -d --network=front_net -p 9292:9292 --name ui bas27/ui:3.3 &&\
docker run -d --network=back_net --name comment bas27/comment:2.0 &&\
docker run -d --network=back_net --name post bas27/post:1.0 &&\
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest

Дополнительные сети подключаются командой:
> docker network connect <network> <container>

docker network connect front_net post &&\
docker network connect front_net comment

## _сетевой стек Linux_

1) Зайдите по ssh на docker-host и установите пакет bridge-utils
docker-machine ssh docker-host
sudo apt-get update && sudo apt-get install bridge-utils
2) Выполните:
> docker network ls
3) Найдите ID сетей, созданных в рамках проекта.
4) Выполните :
> ifconfig | grep br
5) Найдите bridge-интерфейсы для каждой из сетей. Просмотрите
информацию о каждом.
6) Выберите любой из bridge-интерфейсов и выполните команду. Ниже
пример вывода:
> brctl show <interface>
7) Давайте посмотрим как выглядит iptables. Выполним:
sudo iptables -nL -t nat (флаг -v даст чуть больше инфы)
8) В ходе работы у нас была необходимость публикации порта контейнера
UI (9292) для доступа к нему снаружи.
Давайте посмотрим, что Docker при этом сделал. Снова взгляните в iptables
на таблицу nat.
Обратите внимание на цепочку DOCKER и правила DNAT в ней.
DNAT tcp -- 0.0.0.0/0 0.0.0.0/0 tcp dpt:9292 to:172.18.0.2:9292
Они отвечают за перенаправление трафика на адреса уже конкретных
контейнеров.
9) Также выполните:
>

### docker-compose

Linux - (https://docs.docker.com/compose/install/#install-compose)
либо
> pip install docker-compose

создаем файл в ./src docker-compose.yml

Остановим контейнеры, запущенные на предыдущих шагах
> docker kill $(docker ps -q)
docker rm $(docker ps -aq)

Выполните:
export USERNAME1=bas27 &&\
docker-compose up -d &&\
docker-compose ps

имя проекта:
 - docker-compose -p new_project_name up #запуск нескольких копий окружений с одинаковой композицией;
 - имя проекта композиции задается через переменную `COMPOSE_PROJECT_NAME` в файле .env
https://docs.docker.com/compose/compose-file/#aliases

docker-compose up -f docker-compose.yml -f docker-compose.override.yml --debug -w 2
