apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
apiServer:
  certSANs:
    - 127.0.0.1
    - ${master_public_ip}
    - ${master_hostname}
  extraArgs:
    bind-address: "0.0.0.0"
    advertise-address: ${master_public_ip}
    cloud-provider: external
clusterName: ${cluster_name}
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    cloud-provider: external
networking:
  podSubnet: "10.244.0.0/16"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: ${master_hostname}
  kubeletExtraArgs:
    cloud-provider: external

