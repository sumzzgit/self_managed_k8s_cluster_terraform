---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    token: master_token
    apiServerEndpoint: "${master_private_ip}:6443"
    caCertHashes:
      - cert_hashes 
nodeRegistration:
  name: ${hostname}
  kubeletExtraArgs:
    cloud-provider: external
    node-ip: ${node-ip}