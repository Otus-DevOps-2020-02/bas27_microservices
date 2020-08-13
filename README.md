# Kubernetes. Запуск кластера и приложения. Модель безопасности

## Развернуть локальное окружение для работы с Kubernetes

1. `kubectl` Утилита командной строки используется для взаимодействия с API сервером Kubernetes. Загрузите и установите `kubectl` из официальных выпусков двоичных файлов:

`wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl`\
`chmod +x kubectl`\
`sudo mv kubectl /usr/local/bin/`

Убедитесь, что установлена `kubectl` версия 1.15.3 или выше:

`kubectl version --client`

`Client Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.3", GitCommit:"2d3c76f9091b6bec110a5e63777c332469e0cba2", GitTreeState:"clean", BuildDate:"2019-08-19T11:13:54Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}`

2. Директории ~/.kube - содержит служебную инфу для kubectl (конфиги, кеши, схемы API),
3. minikube - утилиты для разворачивания локальной инсталляции Kubernetes

<https://kubernetes.io/docs/tasks/tools/install-minikube/>

Install Minikube via direct download. If you're not installing via a package, you can download a stand-alone binary and use that.

```curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube
  ```

```{
sudo mkdir -p /usr/local/bin/
sudo install minikube /usr/local/bin/
}
```

Запустим наш Minukube-кластер.

`minikube start`

Обновим  kubectl

`curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl`

```chmod +x ./kubectl \
sudo mv ./kubectl /usr/local/bin/kubectl \
kubectl version --client
```

`kubectl get nodes`

Конфигурация kubectl - это контекст.
Контекст - это комбинация:

1) cluster - API-сервер
2) user - пользователь для подключения к кластеру
3) namespace - область видимости (не обязательно, по-умолчанию default)

kubectl apply -f kubernetes/reddit/ui-deployment.yml

kubectl get pods --selector component=ui

NAME                 READY   STATUS    RESTARTS   AGE
ui-948c5fd56-2wzkg   1/1     Running   0          118s
ui-948c5fd56-6zhf7   1/1     Running   0          118s
ui-948c5fd56-dlzht   1/1     Running   0          118s

kubectl port-forward pods/ui-948c5fd56-2wzkg 8080:9292

kubectl apply -f kubernetes/reddit/comment-deployment.yml

kubectl get pods --selector component=comment

Проверить можно так же, пробросив <local-port>: 9292 и зайдя на адрес http://localhost:<local-port>/healthcheck

kubectl apply -f kubernetes/reddit/post-deployment.yml

kubectl get pods --selector component=post

kubectl port-forward pods/post-8bcbb975b-f88hk 8080:5000

kubectl describe service comment | grep Endpoints

kubectl exec -ti post-8bcbb975b-f88hk nslookup comment

kubectl apply -f kubernetes/reddit/mongodb-service.yml

Проверяем:
пробрасываем порт на ui pod
$ kubectl port-forward ui-948c5fd56-2wzkg 9292:9292

...
