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
