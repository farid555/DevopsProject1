
# STEP2: CREATE A K8S EC2 INSTANCE USING EXISTING PEM KEY
# Note: i. First create a pem-key manually from the AWS console
#      ii. Copy it in the same directory as your terraform code
resource "aws_instance" "my_ec2_instance2" {
  ami                    = "ami-0cf10cdf9fcd62d37"
  instance_type          = "t2.medium" # K8s requires min 2CPU & 4G RAM
  vpc_security_group_ids = [aws_security_group.my_security_group2.id]
  key_name               = var.instance_keypair # paste your key-name here, do not use extension '.pem'
  subnet_id              = module.vpc.public_subnets[0]

  # Consider EBS volume 30GB
  root_block_device {
    volume_size = 30    # Volume size 30 GB
    volume_type = "gp2" # General Purpose SSD
  }

  tags = {
    Name = local.owners
  }

  # STEP3: USING REMOTE-EXEC PROVISIONER TO INSTALL TOOLS
  provisioner "remote-exec" {
    # ESTABLISHING SSH CONNECTION WITH EC2
    connection {
      type        = "ssh"
      private_key = file("./terraform_newKey.pem") # replace with your key-name 
      user        = "ec2-user"
      host        = self.public_ip
    }

    inline = [
      "sleep 200",

      # Install Docker
      # REF: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
      "sudo yum update -y",
      "sudo yum install docker -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo chmod 777 /var/run/docker.sock",

      # Install K8s
      # REF: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
      "sudo setenforce 0",
      "sudo sed -i 's/^SELINUX=enforcing$$/SELINUX=permissive/' /etc/selinux/config",
      "cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo",
      "[kubernetes]",
      "name=Kubernetes",
      "baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/",
      "enabled=1",
      "gpgcheck=1",
      "gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key",
      "exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni",
      "EOF",
      "sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes",
      "sudo systemctl enable --now kubelet",
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16  --ignore-preflight-errors=NumCPU --ignore-preflight-errors=Mem",
      "sudo mkdir -p $HOME/.kube",
      "sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "kubectl apply -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml",
      "kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml",
      "kubectl taint nodes --all node-role.kubernetes.io/control-plane-",
    ]
  }

}

