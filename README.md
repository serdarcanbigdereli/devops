## Documentation Plan

- [Technologies](#1-Technologies) 
- [Ci/Cd](#2-CiCd)
- [Kubernetes Process](#3-Kubernetes)
- [Bonus](#4-Bonus)
- [Link](#5-link)
---
# Devops Challenge

This challenge should demonstrate that you understand the world of containers and
microservices. We want to build a simple but resilient Hello World app, deploy it to
Kubernetes as a minimal. There are 4 main Challenges:
- [x] writing a Docker container
- [x] automating the build of the container
- [x] defining the whole infrastructure as code
- [x] Autoscale k8s cluster
- [x] K8s cluster resources list
## 1-Technologies  
>Suggested Approach: 1

<img align="center" width="500" height="250" src="https://github.com/ufkunkaraman/devops/blob/master/images/gitlab_ci_cd_kubernetes.jpg">

We will use 2 technologies. These technologies are Kubernetes and gitlab-ci/cd.

Kubernetes is a portable, extensible, open-source platform for managing containerized workloads and services, that facilitates both declarative configuration and automation. It has a large, rapidly growing ecosystem. Kubernetes services, support, and tools are widely available.

GitLab CI has been around for a couple of years and it has become one of the most popular CI tools in the community. GitLab products have a great documentation and their feature development is so fast and we get new features so frequent and they are generally very useful.GitLab provides much more than just a code repository, such as a docker registry, error tracking, wiki, issue tracking, CI etc.
- PLAN
   1) Build stage  => Build image and push registry
   2) Test stage   => Deploy test kubernetes cluster and test code
   3) Deploy stage => Deploy kubernetes cluster

## 2-CiCd
> Suggested Approach: 2 and 4

Continuous integration and continuous delivery with Kubernetes
1. Web-app code => app.py(port=11130,htmltext="Hello Hepsiburada from Ufkun") 
```python
#web-app python code
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return "Hello Hepsiburada from Ufkun"

@app.route('/user/<name>')
def user(name):
	return 'Hello Hepsiburada from {0}'.format(name)

#Expose port 
if __name__ == '__main__':
    app.run(host="0.0.0.0",port=11130)

```
2. Webapp library =>requirements.txt (for install =>pip install -r requirements.txt) 
```bash
flask
```
3. Webapp Dockerfile
```Dockerfile
# Web-app Dockerfile with secure
FROM python:3-alpine
MAINTAINER Ufkun KARAMAN <ufkunkaraman@gmail.com> 

# Create user with minimal permission
# Define argument 
ARG USER=hepsiburada

# Install sudo as root
RUN apk add --update sudo

#Add new user
RUN adduser -D $USER \
        && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
        && chmod 0440 /etc/sudoers.d/$USER
# User change
USER $USER

# Python add libraries
COPY ./requirements.txt $HOME/requirements.txt
RUN pip install -r $HOME/requirements.txt

# Python code copy 
COPY app.py $HOME/

# Delete sudo for security
RUN apk del sudo


# Expose the Flask port
EXPOSE 11130

CMD [ "python", "./app.py" ]
```

4. Web-app gitlab configuration => .gitlab-ci.yaml


<img align="center" width="600" height="100" src="https://github.com/ufkunkaraman/devops/blob/master/images/ci-cd.png">


```yaml

#gitlab-ci.yalm configuration
image: docker:latest
services:
  - docker:dind
# There are  3 stages in our gitlab-ci/cd configuration. 
stages:
  - build
  - test
  - deploy

# There are some parameters need for automation.
variables:
# automatic imaging with tag
  image: ufkunkaraman/web
  tag: random
# kubernetes yaml files 
  yaml: web.yaml
# autoscale yaml file
  hpayaml: hpa-web.yaml
# To login the docker hub 
  user: ufkunkaraman
  password: xxxx
# To build  the dockerfile
  DOCKER_HOST: tcp://x.x.x.x:2375
# To control the deployment 
  label: app=web
  namespace: gitlab-managed-apps
# To test the code
  port: 11130
  testclusterip: x.x.x.x
# To access  the test kubernetes cluster
  TESTTOKEN: xxxx
  TESTCERT: xxxx
  TESTSERVER: https://x.x.x.x:6443
# To access the kubernetes cluster
  SERVER: https://x.x.x.x:6443
  TOKEN: xxxx
  CERT: xxxx

# At this stage, the image is built and the image is pushed registry
build_dev:
  stage: build
  script:
    - export COMMIT_TIME=$(date '+%d%m%Y')
    - echo $COMMIT_TIME
    - docker login -u $user -p $password
    - docker build -t $image:$tag-$COMMIT_TIME .
    - docker tag $image:$tag-$COMMIT_TIME $image:latest
    - docker push $image:$tag-$COMMIT_TIME
    - docker push $image:latest
    - docker image rm $image:$tag-$COMMIT_TIME $image:latest
  only:
    - master

 # At this stage, the image is deployed in the test cluster. Testing is done here.
test_dev:
  stage: test
  image: dtzar/helm-kubectl
  environment:
    name: master  
  script:
# To access  the test kubernetes cluster
    - kubectl config set-cluster k8s --server=$TESTSERVER
    - kubectl config set clusters.k8s.certificate-authority-data $TESTCERT
    - kubectl config set-credentials gitlab --token=$TESTTOKEN
    - kubectl config set-context default --cluster=k8s --user=gitlab
    - kubectl config use-context default
    - chmod +x ./test.sh
    - ./test.sh -y $yaml -l $label -p $port -i $testclusterip
  only:
    - master
#NOTE: test.sh is a code written for cluster publishing and testing

    # At this stage, the image is deployed in the cluster.
deploy_dev:
  stage: deploy
  image: dtzar/helm-kubectl
  environment:
    name: master
  script:
# To access  the kubernetes cluster
    - kubectl config set-cluster k8s --server=$SERVER
    - kubectl config set clusters.k8s.certificate-authority-data $CERT
    - kubectl config set-credentials gitlab --token=$TOKEN
    - kubectl config set-context default --cluster=k8s --user=gitlab
    - kubectl config use-context default
    - chmod +x ./deploy.sh
    - ./deploy.sh -y $yaml -l $label -h $hpayaml 
  only:
    - master
# NOTE: deploy.sh is a code written for cluster publishing
```
If the build stage is successful, the output looks like this

<img align="center" width="700" height="150" src="https://github.com/ufkunkaraman/devops/blob/master/images/build.png">


test.sh
```bash
#test.sh
#input parameters
while getopts "y:n:l:p:i:" opt
do
   case "$opt" in
      y ) yaml="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      l ) label="$OPTARG" ;;
      p ) port="$OPTARG" ;;
      i ) testclusterip="$OPTARG" ;;
   esac
done

#control pods 
status=$( kubectl get pods -n $namespace  -l $label | tail -1 |awk '{print $3}')

if  [ "$status" == "Running" ]
then
	echo "Delete Running Pods!!"
	kubectl delete -f $yaml
	echo "Waiting..."
	sleep 2
fi
echo "New Pods Creating ... "
kubectl apply -f $yaml

max_variable=60

#Show logs 
for (( int=1; int<10; int++ ))
do
    statu=$(kubectl logs -n  $namespace  -l $label)
    echo "Time-->" $int
    echo "Status-->" $statu
    sleep 1
done

#Checks if the pod is opened for 120 seconds
for (( variable=1; variable<max_variable; variable++ ))
do
   status=$( kubectl get pods -n $namespace  -l  $label | tail -1 |awk '{print $3}')
    if [ "$status" == "Running" ]
    then
    kubectl get pods -n $namespace  -l  $label
    echo "Status--> " $status
    variable=max_variable
    else
    kubectl get pods -n $namespace  -l  $label
    echo "Status--> " $status
    sleep 2
    fi
done

    if [ "$status" == "Running" ]
    then
        echo "Status--> " $status
    else
        echo "test case not open"
        timeout 1 watch kubectl get pods -o wide
    fi
#test code 
echo "healthcheck begin"
healthcheck=$(curl -Is $testclusterip:$port | head -n 1 | awk '{print $2}') 
    if [ "$healthcheck" == "200" ]
    then
        echo "healthcheck--> " $status
    else
        echo "healthcheck fail"
        timeout 1 watch kubectl get pods -o wide
    fi

```

If the test stage is successful, the output looks like this

<img align="center" width="700" height="150" src="https://github.com/ufkunkaraman/devops/blob/master/images/test.png">

deploy.sh
```bash
#input parameters
while getopts "y:n:l:h:" opt
do
   case "$opt" in
      y ) yaml="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      l ) label="$OPTARG" ;;
      h ) hpayaml ="$OPTARG" ;;

   esac
done

#control pods 
status=$( kubectl get pods -n $namespace  -l $label | tail -1 |awk '{print $3}')

if  [ "$status" == "Running" ]
then
	echo "Delete Running Pods!!"
	kubectl delete -f $yaml
	echo "Waiting..."
	sleep 2
fi
echo "New Pods Creating ... "
kubectl apply -f $yaml

max_variable=60
#Show logs 
for (( int=1; int<10; int++ ))
do
    statu=$(kubectl logs -n  $namespace  -l $label)
    echo "Time-->" $int
    echo "Status-->" $statu
    sleep 1
done
#Checks if the pod is opened for 120 seconds
for (( variable=1; variable<max_variable; variable++ ))
do
   status=$( kubectl get pods -n $namespace  -l  $label | tail -1 |awk '{print $3}')
    if [ "$status" == "Running" ]
    then
    kubectl get pods -n $namespace  -l  $label
    echo "Status--> " $status
    variable=max_variable
    else
    kubectl get pods -n $namespace  -l  $label
    echo "Status--> " $status
    sleep 2
    fi
done

    if [ "$status" == "Running" ]
    then
        echo "Status--> " $status
	kubectl apply -f $hpayaml
    else
        timeout 1 watch kubectl get pods -o wide
    fi
```

If the deploy stage is successful, the output looks like this

<img align="center" width="700" height="150" src="https://github.com/ufkunkaraman/devops/blob/master/images/deploy.png">

5. Web-app kubernetes yaml => web.yaml
```yaml
# Web-app deployments
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: web
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: ufkunkaraman/web
        imagePullPolicy: Always
        name: web
      hostname: web
        resources:
          requests:
            cpu: 50m
---
#web service
apiVersion: v1
kind: Service
metadata:
  name: web-service
  labels:
    app: web
spec:
  type: NodePort
  ports:
  - name: "11130"
    port: 11130
    nodePort: 11130 # node port
    protocol: TCP
    targetPort: 11130
  selector:
    app: web
```

6. Web-app autoscale yaml=>hpa-web.yaml 

minimun pod = 1

maximum pod = 5

autoscale with http get requested (10k)

```yaml
...
  spec:
    maxReplicas: 5
    minReplicas: 1
    metrics:
    - type: Object
      object:
        metric:
          name: requests-per-second
          selector: {matchLabels: {verb: GET}}
        describedObject:
          apiVersion: networking.k8s.io/v1beta1
          kind: Ingress
          name: main-route
        target:
          type: Value
          value: 10k
    scaleTargetRef:
      apiVersion: apps/v1
      kind: Deployment
      name: web
...
```

Let's check Kubernetes deployments
```bash
kubectl get deployments -n gitlab-managed-apps  web

NAMESPACE             NAME         READY   UP-TO-DATE   AVAILABLE   AGE
gitlab-managed-apps   web           1/1     1            1           10m

```

Let's check Kubernetes auto-scaling
```bash
kubectl get hpa -n gitlab-managed-apps  web

NAMESPACE                NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
gitlab-managed-apps      web        Deployment/web             1/10k            1        5           1        10m
```


## 3-Kubernetes
> Suggested Approach: 5

1. Centos k8s cluster install

   Send setup files to the machine where Kubernetes will be installed
   
```bash
sshpass -p 'password' scp setup root@x.x.x.x:/root/
```
   Kubernetes install 
```bash
sshpass -p 'password'  ssh root@x.x.x.x sh /root/setup/k8s-install.sh
```
k8s-install.sh
```bash
#input ip for Kubernetes cluster setup
helpFunction()
{
   echo ""
   echo "Usage: $0 -i ip -e ethernetname ($0 -i x.x.x.x -e eth0)"
   echo -e "\t-i Description of what is ip"
   exit 1 # Exit script after printing help
}

while getopts "i:" opt
do
   case "$opt" in
      i ) ip="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$ip" ]  
then
   echo "Please write, $0 -i ip ";
   helpFunction
fi


echo "docker install"
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
echo "Configure the docker-ce repo"
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
echo "Install docker-ce:"
sudo yum install docker-ce -y
echo "Add your user to the docker group with the following command."
sudo usermod -aG docker $(whoami)
echo "Set Docker to start automatically at boot time:"
sudo systemctl enable docker.service
echo "Finally, start the Docker service:"
sudo systemctl start docker.service



echo "k8s install !!!"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

echo "centos install"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet


echo "service enable"
systemctl daemon-reload
systemctl enable docker
swapoff -a
systemctl enable kubelet.service





#Docker best practise to Control and configure Docker with systemd. (Api)
echo '{"hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]}' > /etc/docker/daemon.json
sed -i "s/-H fd:\/\//-H fd:\/\/ -H tcp:\/\/0.0.0.0:2375/g" /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker


#Kubadm cluster setup
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$ip
#kubernetes cluster setup
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Flannel install
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml     
          
#Make both slave and master
kubectl taint nodes --all node-role.kubernetes.io/master-

```
2. Metric install 
```bash
sshpass -p 'password'  ssh root@x.x.x.x sh /root/setup/metric-install.sh
```

metric-install.sh

```bash
#metrics install
kubectl apply -f /root/setup/metric.yaml
```

3. Gitlab configration helper
```bash
sshpass -p 'password'  ssh root@x.x.x.x sh /root/setup/gitlab-install-helper.sh
```
gitlab-install-helper.sh

```bash
echo "gitlab configration helper"
echo "kubernetes api"
kubectl cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}'
echo "kubernetes CA certification"
kubectl get secrets
echo "Service Token Process"
echo "kubectl get secret <secret name> -o jsonpath="{['data']['ca\.crt']}" | base64 --decode"
echo "Service Token"
echo """
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: gitlab-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: gitlab-admin
    namespace: kube-system
""" >/root/gitlab-admin-service-account.yaml
kubectl apply -f gitlab-admin-service-account.yaml --username=admin --password=admin
#Retrieve the token for the gitlab-admin service account:
echo "authentication_token"
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab-admin | awk '{print $1}') |grep token:|awk '{print $2}'
```
4. Kuberenetes cluster destroy 

```bash
sshpass -p ‘password’ ssh root@x.x.x.x sh /root/setup/k8s-destroy.sh
```
k8s-destroy.sh
```bash
#cluster delete
sudo kubeadm  reset
```
## 4-Bonus

List k8s cluster resources using bash. (Note: metric-install.sh must be run)

```bash
sshpass -p ‘password’ ssh root@x.x.x.x sh /root/setup/metric.sh -n <namespaces>

```
metric.sh 

```bash
#input parameter
helpFunction()
{
   echo ""
   echo "Usage: $0 -n namespace"
   echo -e "\t-n Description of what is namespace"
   exit 1 # Exit script after printing help
}

while getopts "n:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$namespace" ]  
then
   echo "Please write, $0 -n namespace ";
   helpFunction
fi

kubectl top pods -n $namespace

```
usage
```
./metric.sh -n gitlab-managed-apps 

NAMESPACE             NAME      CPU(cores)   MEMORY(bytes)   
gitlab-managed-apps   web        13m          12Mi       

```


## 5-link
- Github at <a href="https://github.com/ufkunkaraman/devops" target="_blank">`Devops Challenge`</a>

