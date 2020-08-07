## Documentation Plan

- [Technologies](#1-Technologies) 
- [Ci/Cd](#2-CiCd)
- [Kubernetes Process](#3-Kubernetes)
- [Link](#4-link)
---
# Devops Challenge

This challenge should demonstrate that you understand the world of containers and
microservices. We want to build a simple but resilient Hello World app, deploy it to
Kubernetes as a minimal. There are 4 main Challenges:
- [x] writing a Docker container
- [x] automating the build of the container
- [x] defining the whole infrastructure as code
- [x] Autoscale k8s cluster
## 1-Technologies  
>Suggested Approach: 1

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
  image: ufkunkaraman/web
  tag: random
  label: app=web
  yaml: web.yaml
  namespace: gitlab-managed-apps
  port: 11130
  testclusterip: x.x.x.x
  user: ufkunkaraman
  password: xxxx
  TESTTOKEN: xxxx
  TESTCERT: xxxx
  TESTSERVER: https://x.x.x.x:6443
  DOCKER_HOST: tcp://x.x.x.x:2375
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
    - kubectl config set-cluster k8s --server=$SERVER
    - kubectl config set clusters.k8s.certificate-authority-data $CERT
    - kubectl config set-credentials gitlab --token=$TOKEN
    - kubectl config set-context default --cluster=k8s --user=gitlab
    - kubectl config use-context default
    - chmod +x ./deploy.sh
    - ./deploy.sh -y $yaml -l $label 
  only:
    - master
# NOTE: deploy.sh is a code written for cluster publishing
```
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
deploy.sh
```bash
#input parameters
while getopts "y:n:l:" opt
do
   case "$opt" in
      y ) yaml="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      l ) label="$OPTARG" ;;

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
        timeout 1 watch kubectl get pods -o wide
    fi
```

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
        imagePullPolicy: IfNotPresent
        name: web
      hostname: web
        resources:
          requests:
            cpu: 50m
---
#web loadbalancer
apiVersion: v1
kind: Service
metadata:
  name: web-service
  labels:
    app: web
spec:
  type: LoadBalancer
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

NAMESPACE             NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
gitlab-managed-apps   web        Deployment/web         1/10k             1                     5                  1            10m
```

Let's check Kubernetes auto-scaling
```bash
kubectl get hpa -n gitlab-managed-apps  web

NAMESPACE             NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
gitlab-managed-apps   web        Deployment/web         1/10k             1                     5                  1            10m
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
sshpass -p 'password'  ssh root@x.x.x.x sh /root/k8s-install.sh
```
2. Metric install 

```bash
sshpass -p 'password'  ssh root@x.x.x.x sh /root/metric-install.sh
```
3. Kuberenetes cluster destroy 

```bash
sshpass -p ‘password’ ssh root@x.x.x.x sh /root/k8s-destroy.sh
```
## 4-link
> Suggested Approach: 6
- Github at <a href="https://github.com/ufkunkaraman/devops" target="_blank">`Devops Challenge`</a>
