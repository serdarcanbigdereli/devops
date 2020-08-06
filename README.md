#       Devops Challenge
#   1)Research the technologies you plan to use
We will use 3 technologies. These technologies are Kubernetes, docker and gitlab-ci/cd.
Gitlab-ci/cd was preferred because there were more possibilities.
PLAN
#     Build
Build image and push registry
#     Test
Deploy test kubernetes cluster and test code
#     Deploy
Deploy kubernetes cluster


#   2) Continuous integration and continuous delivery with Kubernetes (Suggested Approach: 2 and 4)
# 1 Web-app code => app.py(port=11130,htmltext="Hello Hepsiburada from Ufkun") 
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

#     2. Webapp library =>requirements.txt (for install =>pip install -r requirements.txt) 
```bash
flask
```
#     3. Webapp Dockerfile
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

#     4. Web-app gitlab configuration => .gitlab-ci.yaml
     
```.gitlab-ci

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
Apply
```bash
kubectl apply -f hpa-web.yalm
```
```yaml
...
  spec:
    maxReplicas: 5
    minReplicas: 1
    metrics:
#autoscale with http get requested  
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
```
```bash
kubectl get hpa -n gitlab-managed-apps  web
```
NAMESPACE             NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
gitlab-managed-apps   web        Deployment/web         1/10k             1                     5                  1            10m

3 Kubernetes cluster
    1. centos k8s cluster install
```bash
sshpass -p 'password' scp setup root@x.x.x.x:/root/
sshpass -p 'password'  ssh root@x.x.x.x
sh /root/k8s-install.sh
```
    2. metric install 
```bash
sshpass -p 'password'  ssh root@x.x.x.x
sh /root/metric-install.sh
```
    3. kuberenetes cluster destroy 
```bash
sshpass -p ‘password’ ssh root@x.x.x.x
sh /root/k8s-destroy.sh
```
4  Github link
Ufkunkaramna

