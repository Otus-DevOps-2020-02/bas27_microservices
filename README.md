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
