kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

kubectl apply  -f $( dirname $0)/metallb-configmap.yaml
#kubectl patch svc kubernetes  -p '{"spec": {"type": "LoadBalancer"}}'
#kubectl apply -f https://k8s.io/examples/application/deployment.yaml
