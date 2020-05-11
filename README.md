# bas27_microservices

bas27 microservices repository

`https://docs.docker.com/engine/install/ubuntu/` #установка докер


### Создание docker host

`docker run hello-world`
`docker ps` #Список запущенных контейнеров
`docker ps -a` #Список всех контейнеров
`docker images` #Список сохранненных образов

`docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.CreatedAt}}\t{{.Names}}"`

• start запускает остановленный(уже созданный) контейнер
• attach подсоединяет терминал к созданному контейнеру

> docker start <u_container_id>
> docker attach <u_container_id>

`docker run = docker create + docker start + docker attach*`

Через параметры передаются лимиты(cpu/mem/disk), ip, volumes

-i – запускает контейнер в foreground режиме (docker attach)
-d – запускает контейнер в background режиме
-t создает TTY

`docker run -it ubuntu:16.04 bash`

`docker run -dt nginx:latest`

`docker exec -it <u_container_id> bash`#Запускает новый процесс внутри контейнера (здесь bash)

`docker commit <u_container_id> yourname/ubuntu-tmp-file` #Создает image из контейнера

`Docker kill & stop` #kill сразу посылает SIGKILL, a stop посылает SIGTERM, и через 10 секунд(настраивается) посылает SIGKILL

`docker system df` #Отображает сколько дискового пространства занято образами, контейнерами и volume’ами, а также отображает сколько из них не используется и возможно удалить

`Docker rm & rmi` #rm удаляет контейнер, можно добавить флаг -f, чтобы удалялся работающий container (будет послан sigkill)
rmi удаляет image, если от него не зависят запущенные контейнеры


### Настройка среды GSE

Для работы докера из под своего пользователя необходимо добавить в группу docker
```
sudo usermod -aG docker "${USER}"
newgrp docker
sudo service docker restart
```

docker-machine - встроенный в докер инструмент для создания хостов и установки на них docker engine.

Команда создания - `docker-machine create <имя>`. Имен может быть много, переключение между ними через `eval $(docker-machine env <имя>)`. Переключение на локальный докер - `eval $(docker-machine env --unset)`. Удаление - `docker-machine rm <имя>`.

`docker-machine` создает хост для докер демона со указываемым образом в `_--google-machine-image_`, в ДЗ используется ubuntu-16.04. Образы которые используются для построения докер контейнеров к этому никак не относятся.

Все докер команды, которые запускаются в той же консоли после eval $(docker-machine env <имя>) работают с удаленным докер демоном в GCP

`export GOOGLE_PROJECT=docker-xxx`
```
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```
`docker-machine ls` #Проверяем, что наш Docker-хост успешно создан
```eval $(docker-machine env docker-host)
docker-machine env docker-host```

`docker run --name reddit -d --network=host reddit:latest`
