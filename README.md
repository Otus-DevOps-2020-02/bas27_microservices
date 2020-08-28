# Kubernetes. Мониторинг и логирование

```kubectl apply -f tiller.yml
helm init --service-account tiller
```

`helm install stable/nginx-ingress --name nginx`

```kubectl get svc
NAME                                  TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)                      AGE
kubernetes                            ClusterIP      10.8.0.1     <none>          443/TCP                      7m10s
nginx-nginx-ingress-controller        LoadBalancer   10.8.1.120   34.67.141.217   80:30063/TCP,443:32616/TCP   59s
nginx-nginx-ingress-default-backend   ClusterIP      10.8.2.244   <none>          80/TCP                       59s
```

Добавим в hosts

`34.67.141.217 reddit reddit-prometheus reddit-grafana reddit-non-prod production reddit-kibana staging prod`

По плану

1. Развертывание Prometheus в k8s
2. Настройка Prometheus и Grafana для сбора метрик
3. Настройка EFK для сбора логов

`cd kubernetes/charts && helm fetch --untar stable/prometheus`

`helm upgrade prom . -f custom_values.yml --install`

```kubeStateMetrics:
  ## If false, kube-state-metrics will not be installed
  ##
  enabled: (false) true
```

`helm upgrade prom . -f custom_values.yml --install`

```nodeExporter:
  ## If false, node-exporter will not be installed
  ##
  enabled: (false) true
```

Запустите приложение из helm чарта reddit

```helm upgrade reddit-test ./reddit --install
helm upgrade production --namespace production ./reddit --install
helm upgrade staging --namespace staging ./reddit --install
```

Модернизируем конфиг prometheus:

```## custom_values.yml
- job_name: 'reddit-endpoints'
    kubernetes_sd_configs:
    - role: endpoints
    relabel_configs:
    - source_labels: [__meta_kubernetes_service_label_app]
      action: keep # Используем действие keep, чтобы оставить regex: reddit # только эндпоинты cервисов с метками “app=reddit”
```

`$ helm upgrade prom . -f custom_values.yml --install`

добавим

```- action: labelmap # Отобразить все совпадения групп из regex в label’ы Prometheus
            regex: __meta_kubernetes_service_label_(.+)
```

`helm upgrade prom . -f custom_values.yml --install`

```- source_labels: [__meta_kubernetes_namespace]
  target_label: kubernetes_namespace
- source_labels: [__meta_kubernetes_service_name]
  target_label: kubernetes_name
```

`helm upgrade prom . -f custom_values.yml --install`

```- job_name: "ui-endpoints"
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_label_component]
            action: keep # Используем действие keep, чтобы оставить только эндпоинты сервисов с метками “app=reddit”
            regex: post
          - action: labelmap # Отобразить все совпадения групп из regex в label’ы Prometheus
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            target_label: kubernetes_name
```

Grafana

```helm upgrade --install grafana stable/grafana --set "adminPassword=admin" \
--set "service.type=NodePort" \
--set "ingress.enabled=true" \
--set "ingress.hosts={reddit-grafana}"
```
