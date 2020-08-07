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
