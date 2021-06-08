```
kubectl --namespace=default get secret capi-quickstart-kubeconfig -o jsonpath={.data.value} | base64 --decode > $HOME/capi-quickstart.kubeconfig
export KUBECONFIG=/home/ubuntu/.kube/config:/home/ubuntu/capi-quickstart.kubeconfig
kubectl config use-context capi-quickstart-admin@capi-quickstart
```
