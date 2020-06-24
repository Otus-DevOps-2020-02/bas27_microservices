# Введение в Kubernetes

---

## THW

### _Установка клиентских инструментов_

- cfssl
- cfssljson
- kubectl

```wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson
```

`chmod +x cfssl cfssljson`\
`sudo mv cfssl cfssljson /usr/local/bin/` \

Проверка `cfssl` и `cfssljson` версия 1.3.4 или выше устанавливается:

`cfssl version`

```Version: 1.3.4
Revision: dev
Runtime: go1.13
```

cfssljson --version

```Version: 1.3.4
Revision: dev
Runtime: go1.13
```

`kubectl` Утилита командной строки используется для взаимодействия с API сервером Kubernetes. Загрузите и установите `kubectl` из официальных выпусков двоичных файлов:

`wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl`\
`chmod +x kubectl`\
`sudo mv kubectl /usr/local/bin/`

Убедитесь, что установлена `kubectl` версия 1.15.3 или выше:

`kubectl version --client`

`Client Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.3", GitCommit:"2d3c76f9091b6bec110a5e63777c332469e0cba2", GitTreeState:"clean", BuildDate:"2019-08-19T11:13:54Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}`

### Предоставление вычислительных ресурсов

Virtual Private Cloud Network

`gcloud compute networks create kubernetes-the-hard-way --subnet-mode custom`

Create the kubernetes subnet in the kubernetes-the-hard-way VPC network:

```gcloud compute networks subnets create kubernetes \
  --network kubernetes-the-hard-way \
  --range 10.240.0.0/24
  ```

### _Firewall Rules_

Create a firewall rule that allows internal communication across all protocols:

```gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 10.240.0.0/24,10.200.0.0/16
  ```

Create a firewall rule that allows external SSH, ICMP, and HTTPS:

```gcloud compute firewall-rules create kubernetes-the-hard-way-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 0.0.0.0/0
  ```

An external load balancer will be used to expose the Kubernetes API Servers to remote clients.

List the firewall rules in the kubernetes-the-hard-way VPC network:

`gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"`

### Kubernetes Public IP Address

`gcloud compute addresses create kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region)`

`gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"`

## Compute Instances

Kubernetes Controllers

```for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done
```

Kubernetes Workers

```for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,worker
done
```

Verification

`gcloud compute instances list`

Configuring SSH Access

`gcloud compute ssh controller-0`

### Provisioning a CA and Generating TLS Certificates

Certificate Authority

Создайте файл конфигурации CA, сертификат и закрытый ключ:

```{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}
```

Сертификаты клиента и сервера

В этом разделе вы создадите клиентские и серверные сертификаты для каждого компонента Kubernetes и клиентский сертификат для adminпользователя Kubernetes

Сертификат администратора клиента

Сгенерируйте adminклиентский сертификат и закрытый ключ:

```{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}
```

The Kubelet Client Certificates

```for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

INTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].networkIP)')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
```

The Controller Manager Client Certificate

```{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}
```

The Kube Proxy Client Certificate

```{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}
```

The Scheduler Client Certificate

```{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}
```

The Kubernetes API Server Certificate

kubernetes-the-hard-wayСтатический IP - адрес будет включен в список подлежащих альтернативных имен для сертификата Kubernetes API сервера. Это гарантирует, что сертификат может быть проверен удаленными клиентами.

Создайте сертификат и закрытый ключ сервера API Kubernetes:

```{

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}
```

Серверу API Kubernetes автоматически присваивается `kubernetes` внутреннее DNS-имя, которое будет связано с первым IP-адресом ( 10.32.0.1) из диапазона адресов ( 10.32.0.0/24), зарезервированного для внутренних служб кластера во время начальной загрузки плоскости управления .

***Пара ключей учетной записи службы***

Kubernetes Controller Manager использует пару ключей для создания и подписи токенов учетных записей служб, как описано в документации по управлению учетными записями служб .

Сгенерируйте service-accountсертификат и закрытый ключ:

```{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}
```

***Раздайте клиентские и серверные сертификаты***

Скопируйте соответствующие сертификаты и закрытые ключи для каждого рабочего экземпляра:

```for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done
```

Скопируйте соответствующие сертификаты и закрытые ключи для каждого экземпляра контроллера:

```for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:~/
done
```

### **Генерация конфигурационных файлов Kubernetes для аутентификации**

#### ***Конфигурации аутентификации клиента***

---

#### Публичный IP-адрес Кубернетеса

Каждому kubeconfig требуется сервер API Kubernetes для подключения. Для обеспечения высокой доступности будет использоваться IP-адрес, назначенный внешнему балансировщику нагрузки на серверах API Kubernetes.

Получить `kubernetes-the-hard-way` статический IP-адрес:

```KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
  ```

#### Файл конфигурации kubelet Kubernetes

При создании файлов kubeconfig для Kubelets необходимо использовать сертификат клиента, соответствующий имени узла Kubelet. Это обеспечит надлежащую авторизацию Kubelets авторизатором узлов Kubernetes .

Следующие команды должны выполняться в том же каталоге, который использовался для создания сертификатов SSL во время лаборатории « Создание сертификатов TLS» .

Создайте файл kubeconfig для каждого рабочего узла:

```for instance in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
```

#### Файл конфигурации kube-proxy Kubernetes

```{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}
```

#### Конфигурационный файл kube-controller-manager Kubernetes

```{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}
```

#### Файл конфигурации kube-планировщика Kubernetes

```{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}
```

#### Конфигурационный файл администратора Kubernetes

```{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}
```

#### Распространите конфигурационные файлы Kubernetes

Скопируйте соответствующие файлы kubeletи kube-proxyфайлы kubeconfig в каждый рабочий экземпляр:

```for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
```

Скопируйте соответствующие файлы kube-controller-managerи kube-schedulerфайлы kubeconfig в каждый экземпляр контроллера:

```for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done
```

### **Генерация конфигурации и ключа шифрования данных**

#### ***Ключ шифрования***

---

`ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)`

#### Файл конфигурации шифрования

```cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

Скопируйте encryption-config.yamlфайл конфигурации шифрования на каждый экземпляр контроллера:

```for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp encryption-config.yaml ${instance}:~/
done
```

### **Начальная загрузка кластера etcd**

Компоненты Kubernetes не имеют состояния и хранят состояние кластера в etcd . В этой лабораторной работе вы загрузите кластер etcd с тремя узлами и настроите его для обеспечения высокой доступности и безопасного удаленного доступа.

#### Предпосылки

---

Команды в этой лаборатории , должны выполняться на каждом экземпляре контроллера: controller-0, controller-1и controller-2. Войдите в каждый экземпляр контроллера с помощью gcloudкоманды. Пример:

`gcloud compute ssh controller-0`

#### Запуск команд параллельно с tmux

tmux может использоваться для одновременного запуска команд на нескольких экземплярах вычислений. Смотрите раздел Запуск команд параллельно с разделом tmux в лаборатории предварительных требований.

#### Начальная загрузка члена кластера etcd

Загрузите и установите двоичные файлы etcd

Загрузите официальные двоичные файлы выпуска etcd из проекта etcd GitHub:

```wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
```

Извлеките и установите `etcd` сервер и `etcdctl` утилиту командной строки:

```{
  tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
  sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
}
```

#### Настройте сервер etcd

```{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}
```

Внутренний IP-адрес экземпляра будет использоваться для обслуживания клиентских запросов и связи с одноранговыми кластерами etcd. Получите внутренний IP-адрес для текущего вычислительного экземпляра:

```INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```

Каждый член etcd должен иметь уникальное имя в кластере etcd. Установите имя etcd так, чтобы оно совпадало с именем хоста текущего вычислительного экземпляра:

`ETCD_NAME=$(hostname -s)`

Создайте `etcd.service` файл системного модуля:

```cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Запустите сервер etcd

```{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}
```

Не забудьте выполнить указанные выше команды на каждом узле контроллера: controller-0, controller-1и controller-2.

#### верификация

Список членов кластера etcd:

```sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

### Самозагрузка плоскости управления Кубернетес

#### Предоставление самолета управления Kubernetes

`sudo mkdir -p /etc/kubernetes/config`

#### Загрузите и установите двоичные файлы контроллера Kubernetes

```wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
```

#### Установите двоичные файлы Kubernetes

```{
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
}
```

#### Настройте сервер Kubernetes API

```{
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}
```

Внутренний IP-адрес экземпляра будет использоваться для объявления сервера API членам кластера. Получите внутренний IP-адрес для текущего вычислительного экземпляра:

```INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```

Создайте kube-apiserver.serviceфайл системного модуля:

```cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Настройте диспетчер контроллеров Kubernetes

Переместите `kube-controller-manager` kubeconfig на место:

`sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/`

Создайте `kube-controller-manager.service` файл системного модуля:

```cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Настройте планировщик Kubernetes

Переместите `kube-scheduler` kubeconfig на место:

`sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/`

Создайте `kube-scheduler.yaml` файл конфигурации:

```cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
Создайте kube-scheduler.serviceфайл системного модуля:

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Запустите службы контроллера

```{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
}
```

Разрешите до 10 секунд для полной инициализации сервера API Kubernetes.

#### Включить проверки работоспособности HTTP

Google Network Load Balancer будет использоваться для распределения трафика по трем серверам API и позволяют каждому серверу API прекратить TLS соединений и сертификатов Проверка клиента. Балансировщик сетевой нагрузки поддерживает только проверки работоспособности HTTP, что означает, что конечная точка HTTPS, предоставляемая сервером API, не может использоваться. В качестве обходного пути веб-сервер nginx можно использовать для проверки работоспособности HTTP-прокси. В этом разделе nginx будет установлен и настроен на прием проверок работоспособности HTTP на порт 80и на прокси-соединениях с сервером API <https://127.0.0.1:6443/healthz.>

/healthzКонечные точки сервера API не требуют проверки подлинности по умолчанию.

Установите базовый веб-сервер для обработки проверок состояния HTTP:

```sudo apt-get update &&\
sudo apt-get install -y nginx &&\
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
```

```{
  sudo mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

  sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
}
```

`sudo systemctl restart nginx`
`sudo systemctl enable nginx`

### верификация

`kubectl get componentstatuses --kubeconfig admin.kubeconfig`

```NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
```

Протестируйте прокси проверки работоспособности nginx HTTP:

`curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz`

```HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Sat, 14 Sep 2019 18:34:11 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
X-Content-Type-Options: nosniff

ok
```

Не забудьте выполнить указанные выше команды на каждом узле контроллера: controller-0, controller-1и controller-2.

#### RBAC для авторизации Kubelet

В этом разделе вы настроите разрешения RBAC, чтобы позволить серверу API Kubernetes получать доступ к API Kubelet на каждом рабочем узле. Доступ к API Kubelet необходим для получения метрик, журналов и выполнения команд в модулях.

Этот учебник устанавливает --authorization-modeфлаг Kubelet в Webhook. Режим Webhook использует API SubjectAccessReview для определения авторизации.

Команды в этом разделе влияют на весь кластер, и их нужно запускать только один раз с одного из узлов контроллера.

`gcloud compute ssh controller-0`

Создайте `system:kube-apiserver-to-kubelet` ClusterRole с разрешениями для доступа к API-интерфейсу Kubelet и выполнения наиболее распространенных задач, связанных с управлением модулями:

```cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

Сервер API Kubernetes аутентифицируется в Kubelet как kubernetesпользователь, используя сертификат клиента, как определено `--kubelet-client-certificate` флагом.

Привязать `system:kube-apiserver-to-kubeletClusterRole` к kubernetes пользователю:

```cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

### Балансер нагрузки внешнего интерфейса Kubernetes

В этом разделе вы предоставите внешний балансировщик нагрузки для фронта серверов Kubernetes API. kubernetes-the-hard-wayСтатический IP - адрес будет прикреплен к полученному выравнивателю нагрузки.

Экземпляры вычислений, созданные в этом руководстве, не будут иметь разрешения для завершения этого раздела. Выполните следующие команды с того же компьютера, который использовался для создания экземпляров вычислений .

#### Обеспечение балансировки сетевой нагрузки

Создайте внешние сетевые ресурсы балансировщика нагрузки:

```{
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  gcloud compute http-health-checks create kubernetes \
    --description "Kubernetes Health Check" \
    --host "kubernetes.default.svc.cluster.local" \
    --request-path "/healthz"

  gcloud compute firewall-rules create kubernetes-the-hard-way-allow-health-check \
    --network kubernetes-the-hard-way \
    --source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16 \
    --allow tcp

  gcloud compute target-pools create kubernetes-target-pool \
    --http-health-check kubernetes

  gcloud compute target-pools add-instances kubernetes-target-pool \
   --instances controller-0,controller-1,controller-2

  gcloud compute forwarding-rules create kubernetes-forwarding-rule \
    --address ${KUBERNETES_PUBLIC_ADDRESS} \
    --ports 6443 \
    --region $(gcloud config get-value compute/region) \
    --target-pool kubernetes-target-pool
}
```

### верификация

Экземпляры вычислений, созданные в этом руководстве, не будут иметь разрешения для завершения этого раздела. Выполните следующие команды с того же компьютера, который использовался для создания экземпляров вычислений .

Получить kubernetes-the-hard-wayстатический IP-адрес:

```KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```

Сделайте HTTP-запрос для информации о версии Kubernetes:

`curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version`

вывод

```{
  "major": "1",
  "minor": "15",
  "gitVersion": "v1.15.3",
  "gitCommit": "2d3c76f9091b6bec110a5e63777c332469e0cba2",
  "gitTreeState": "clean",
  "buildDate": "2019-08-19T11:05:50Z",
  "goVersion": "go1.12.9",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

### Начальная загрузка рабочих узлов Kubernetes

#### Предпосылки

Команды в этой лаборатории , должны выполняться на каждом экземпляре рабочего: worker-0, worker-1и worker-2. Войдите в каждый рабочий экземпляр, используя gcloudкоманду. Пример:

`gcloud compute ssh worker-0`

#### Предоставление рабочего узла Kubernetes

Установите зависимости ОС:

```{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}
```

Двоичный файл socat обеспечивает поддержку kubectl port-forward команды.

#### Отключить своп

По умолчанию кублет не запустится, если включен своп . Это рекомендуется , что замена будет отключена , чтобы обеспечить Kubernetes может обеспечить надлежащее распределение ресурсов и качество обслуживания.

Проверьте, включен ли обмен:

`sudo swapon --show`

Если вывод пуст, то подкачка не включена. Если swap включен, выполните следующую команду, чтобы немедленно отключить swap:

`sudo swapoff -a`

Чтобы своп остался выключенным после перезагрузки, обратитесь к документации по дистрибутиву Linux.

#### Загрузите и установите рабочие бинарные файлы

```wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet
```

Создайте каталоги установки:

```sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

Установите рабочие двоичные файлы:

```{
  mkdir containerd
  tar -xvf crictl-v1.15.0-linux-amd64.tar.gz
  tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd
  sudo tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
  sudo mv runc.amd64 runc
  chmod +x crictl kubectl kube-proxy kubelet runc
  sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  sudo mv containerd/bin/* /bin/
}
```

#### Настройте сеть CNI

Получите диапазон Pod CIDR для текущего вычислительного экземпляра:

```POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)
```

Создайте bridge файл конфигурации сети:

```cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

Создайте loopback файл конфигурации сети:

```cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
```

#### Настроить в контейнере

Создайте containerd файл конфигурации:

`sudo mkdir -p /etc/containerd/`

```cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
```

Создайте containerd.service файл системного модуля:

```cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

#### Настроить Кубеле

```{
  sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/
}
```

Создайте kubelet-config.yaml файл конфигурации:

```cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF
```

resolvConf Конфигурация используется, чтобы избежать петель при использовании CoreDNS для обнаружения службы в системах , работающих под управлением systemd-resolved.

Создайте kubelet.service файл системного модуля:

```cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Настройте прокси Kubernetes

`sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig`

Создайте kube-proxy-config.yaml файл конфигурации:

```cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

Создайте kube-proxy.serviceфайл системного модуля:

```cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Запустите Рабочие Сервисы

```{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet kube-proxy
  sudo systemctl start containerd kubelet kube-proxy
}
```

Не забудьте выполнить вышеуказанные команды на каждом узле рабочего: worker-0, worker-1и worker-2.

#### Верификация

Экземпляры вычислений, созданные в этом руководстве, не будут иметь разрешения для завершения этого раздела. Выполните следующие команды с того же компьютера, который использовался для создания экземпляров вычислений.

Список зарегистрированных узлов Kubernetes:

```gcloud compute ssh controller-0 \
  --command "kubectl get nodes --kubeconfig admin.kubeconfig"
```

вывод

```NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   15s   v1.15.3
worker-1   Ready    <none>   15s   v1.15.3
worker-2   Ready    <none>   15s   v1.15.3
```

### Настройка kubectl для удаленного доступа

В этой лабораторной работе вы создадите файл kubeconfig для kubectlутилиты командной строки на основе adminучетных данных пользователя.

Запустите команды в этой лабораторной работе из того же каталога, который использовался для создания клиентских сертификатов администратора.

#### Конфигурационный файл Admin Kubernetes

Каждому kubeconfig требуется сервер API Kubernetes для подключения. Для обеспечения высокой доступности будет использоваться IP-адрес, назначенный внешнему балансировщику нагрузки на серверах API Kubernetes.

Создайте файл kubeconfig, подходящий для аутентификации adminпользователя:

```{
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}
```

#### Верификация

Проверьте работоспособность удаленного кластера Kubernetes:

`kubectl get componentstatuses`

вывод

```NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```

Перечислите узлы в удаленном кластере Kubernetes:

`kubectl get nodes`

вывод

```NAME       STATUS   ROLES    AGE    VERSION
worker-0   Ready    <none>   2m9s   v1.15.3
worker-1   Ready    <none>   2m9s   v1.15.3
worker-2   Ready    <none>   2m9s   v1.15.3
```

### Предоставление сетевых маршрутов Pod

Модули, запланированные для узла, получают IP-адрес из диапазона CIDR Pod узла. В этот момент модули не могут связываться с другими модулями, работающими на разных узлах из-за отсутствия сетевых маршрутов .

В этой лабораторной работе вы создадите маршрут для каждого рабочего узла, который сопоставляет диапазон Pod CIDR узла с внутренним IP-адресом узла.

Есть и другие способы реализации сетевой модели Kubernetes.

### Таблица маршрутизации

В этом разделе вы соберете информацию, необходимую для создания маршрутов в kubernetes-the-hard-wayсети VPC.

Напечатайте внутренний IP-адрес и диапазон Pod CIDR для каждого рабочего экземпляра:

```for instance in worker-0 worker-1 worker-2; do
  gcloud compute instances describe ${instance} \
    --format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[0].value)'
done
```

вывод

```10.240.0.20 10.200.0.0/24
10.240.0.21 10.200.1.0/24
10.240.0.22 10.200.2.0/24
```

#### Маршруты

Создайте сетевые маршруты для каждого рабочего экземпляра:

```for i in 0 1 2; do
  gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
    --network kubernetes-the-hard-way \
    --next-hop-address 10.240.0.2${i} \
    --destination-range 10.200.${i}.0/24
done
```

Перечислите маршруты в kubernetes-the-hard-wayсети VPC:

`gcloud compute routes list --filter "network: kubernetes-the-hard-way"`

вывод

```NAME                            NETWORK                  DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-081879136902de56  kubernetes-the-hard-way  10.240.0.0/24  kubernetes-the-hard-way   1000
default-route-55199a5aa126d7aa  kubernetes-the-hard-way  0.0.0.0/0      default-internet-gateway  1000
kubernetes-route-10-200-0-0-24  kubernetes-the-hard-way  10.200.0.0/24  10.240.0.20               1000
kubernetes-route-10-200-1-0-24  kubernetes-the-hard-way  10.200.1.0/24  10.240.0.21               1000
kubernetes-route-10-200-2-0-24  kubernetes-the-hard-way  10.200.2.0/24  10.240.0.22
```

### Развертывание надстройки DNS-кластера

В этой лабораторной работе вы развернете надстройку DNS, которая обеспечивает обнаружение службы на основе DNS при поддержке CoreDNS для приложений, работающих в кластере Kubernetes.

#### Надстройка DNS-кластера

Разверните `coredns` кластерное дополнение:

`kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml`

вывод

```serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.extensions/coredns created
service/kube-dns created
```

Список модулей, созданных при `kube-dns` развертывании:

`kubectl get pods -l k8s-app=kube-dns -n kube-system`

вывод

```NAME                       READY   STATUS    RESTARTS   AGE
coredns-699f8ddd77-94qv9   1/1     Running   0          20s
coredns-699f8ddd77-gtcgb   1/1     Running   0          20s
```

#### верификация

Создайте `busybox` развертывание:

`kubectl run --generator=run-pod/v1 busybox --image=busybox:1.28 --command -- sleep 3600`

Перечислите модуль, созданный при busyboxразвертывании:

`kubectl get pods -l run=busybox`

вывод

```NAME      READY   STATUS    RESTARTS   AGE
busybox   1/1     Running   0          3s
```

Получить полное имя busyboxстручка:

`POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")`

Выполните поиск DNS для `kubernetes` службы внутри busyboxмодуля:

`kubectl exec -ti $POD_NAME -- nslookup kubernetes`

вывод

```Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
```

### Smoke Test

В этой лабораторной работе вы выполните ряд задач, чтобы убедиться, что ваш кластер Kubernetes работает правильно.

#### Шифрование данных

В этом разделе вы проверите возможность шифрования секретных данных в состоянии покоя .

Создайте общий секрет:

```kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"
```

Выведите hexdump kubernetes-the-hard-wayсекрета, хранящегося в etcd:

```gcloud compute ssh controller-0 \
  --command "sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem\
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"
```

вывод

```00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a 44 ac 6e ac 11 2f 28  |:v1:key1:D.n../(|
00000050  02 46 3d ad 9d cd 68 be  e4 cc 63 ae 13 e4 99 e8  |.F=...h...c.....|
00000060  6e 55 a0 fd 9d 33 7a b1  17 6b 20 19 23 dc 3e 67  |nU...3z..k .#.>g|
00000070  c9 6c 47 fa 78 8b 4d 28  cd d1 71 25 e9 29 ec 88  |.lG.x.M(..q%.)..|
00000080  7f c9 76 b6 31 63 6e ea  ac c5 e4 2f 32 d7 a6 94  |..v.1cn..../2...|
00000090  3c 3d 97 29 40 5a ee e1  ef d6 b2 17 01 75 a4 a3  |<=.)@Z.......u..|
000000a0  e2 c2 70 5b 77 1a 0b ec  71 c3 87 7a 1f 68 73 03  |..p[w...q..z.hs.|
000000b0  67 70 5e ba 5e 65 ff 6f  0c 40 5a f9 2a bd d6 0e  |gp^.^e.o.@Z.*...|
000000c0  44 8d 62 21 1a 30 4f 43  b8 03 69 52 c0 b7 2e 16  |D.b!.0OC..iR....|
000000d0  14 a5 91 21 29 fa 6e 03  47 e2 06 25 45 7c 4f 8f  |...!).n.G..%E|O.|
000000e0  6e bb 9d 3b e9 e5 2d 9e  3e 0a                    |n..;..-.>.|
```

К ключу etcd должен быть добавлен префикс `k8s:enc:aescbc:v1:key1`, который указывает, что `aescbc` провайдер использовался для шифрования данных с `key1` помощью ключа шифрования.

#### развертывания

В этом разделе вы проверите возможность создания и управления развертываниями .

Создайте развертывание для веб-сервера nginx :

`kubectl create deployment nginx --image=nginx`

Перечислите модуль, созданный при nginxразвертывании:

`kubectl get pods -l app=nginx`

вывод

```NAME                     READY   STATUS    RESTARTS   AGE
nginx-554b9c67f9-vt5rn   1/1     Running   0          10s
```

#### Перенаправление порта

В этом разделе вы проверите возможность удаленного доступа к приложениям с помощью переадресации портов .

Получить полное имя nginxстручка:

`POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")`

Форвард порт `8080` на локальном компьютере , к порту `80` в `nginx` контейнере:

`kubectl port-forward $POD_NAME 8080:80`

вывод

```Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
```

В новом терминале сделайте HTTP-запрос, используя адрес пересылки:

`curl --head http://127.0.0.1:8080`

вывод

```HTTP/1.1 200 OK
Server: nginx/1.17.3
Date: Sat, 14 Sep 2019 21:10:11 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 13 Aug 2019 08:50:00 GMT
Connection: keep-alive
ETag: "5d5279b8-264"
Accept-Ranges: bytes
Вернитесь к предыдущему терминалу и остановите переадресацию порта на nginxмодуль:

Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080
^C
```

#### Logs

В этом разделе вы проверите возможность получения журналов контейнера .

Распечатать  `nginx` `журналы стручка:

`kubectl logs $POD_NAME`

вывод

`127.0.0.1 - - [14/Sep/2019:21:10:11 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.52.1" "-"`

#### Exec

В этом разделе вы проверите возможность выполнения команд в контейнере .

Напечатайте версию nginx, выполнив `nginx -v` команду в `nginx` контейнере:

`kubectl exec -ti $POD_NAME -- nginx -v`

вывод

`nginx version: nginx/1.17.3`

#### Сервисы

В этом разделе вы проверите возможность выставлять приложения, используя Сервис .

Выставляют `nginx` развертывание с помощью `NodePort` службы:

`kubectl expose deployment nginx --port 80 --type NodePort`

Нельзя использовать тип службы LoadBalancer, поскольку в вашем кластере не настроена интеграция с облачным провайдером . Настройка интеграции с облачным провайдером выходит за рамки данного руководства.

Получить порт узла, назначенный nginxслужбе:

```NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
```

Создайте правило брандмауэра, разрешающее удаленный доступ к nginxпорту узла:

```gcloud compute firewall-rules create kubernetes-the-hard-way-allow-nginx-service \
  --allow=tcp:${NODE_PORT} \
  --network kubernetes-the-hard-way
```

Получить внешний IP-адрес рабочего экземпляра:

```EXTERNAL_IP=$(gcloud compute instances describe worker-0 \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
```

Сделайте HTTP-запрос, используя внешний IP-адрес и nginxпорт узла:

`curl -I http://${EXTERNAL_IP}:${NODE_PORT}`

вывод

```HTTP/1.1 200 OK
Server: nginx/1.17.3
Date: Sat, 14 Sep 2019 21:12:35 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 13 Aug 2019 08:50:00 GMT
Connection: keep-alive
ETag: "5d5279b8-264"
Accept-Ranges: bytes
```

---

```kubectl apply -f ../reddit/ui-deployment.yml &&\
kubectl apply -f ../reddit/post-deployment.yml &&\
kubectl apply -f ../reddit/mongo-deployment.yml &&\
kubectl apply -f ../reddit/comment-deployment.yml
```

смотрим созданные поды:

`kubectl get pods`

вывод

```NAME                                  READY   STATUS    RESTARTS   AGE
busybox                               1/1     Running   12         12h
comment-deployment-5798597f8f-m7tsx   1/1     Running   0          64s
mongo-deployment-86d49445c4-bj8n8     1/1     Running   0          66s
nginx-554b9c67f9-nzpgn                1/1     Running   0          11h
post-deployment-6cfc47c599-wfczq      1/1     Running   0          2m56s
ui-deployment-fc758ff95-5m4hd         1/1     Running   0          3m22s
```

### Clean

#### Compute Instances

Удалите экземпляры контроллера и рабочих вычислений:

```gcloud -q compute instances delete \
  controller-0 controller-1 controller-2 \
  worker-0 worker-1 worker-2 \
  --zone $(gcloud config get-value compute/zone)
```

#### Networks

Удалите внешние сетевые ресурсы балансировщика нагрузки:

```{
  gcloud -q compute forwarding-rules delete kubernetes-forwarding-rule \
    --region $(gcloud config get-value compute/region)

  gcloud -q compute target-pools delete kubernetes-target-pool

  gcloud -q compute http-health-checks delete kubernetes

  gcloud -q compute addresses delete kubernetes-the-hard-way
}
```

Удалить kubernetes-the-hard-way правила брандмауэра:

```gcloud -q compute firewall-rules delete \
  kubernetes-the-hard-way-allow-nginx-service \
  kubernetes-the-hard-way-allow-internal \
  kubernetes-the-hard-way-allow-external \
  kubernetes-the-hard-way-allow-health-check
```

Удалить kubernetes-the-hard-way сеть VPC:

```{
  gcloud -q compute routes delete \
    kubernetes-route-10-200-0-0-24 \
    kubernetes-route-10-200-1-0-24 \
    kubernetes-route-10-200-2-0-24

  gcloud -q compute networks subnets delete kubernetes

  gcloud -q compute networks delete kubernetes-the-hard-way
}
```
