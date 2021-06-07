kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# Disable UI
#kubectl patch deploy argocd-server -n argocd -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]' --type json
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
# No LB port forward to API
#kubectl port-forward svc/argocd-server -n argocd 8080:443
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
#argocd login <ARGOCD_SERVER>
# Change password
#argocd account update-password

# Register cluster
#kubectl config get-contexts -o name
#argocd cluster add docker-desktop

curl -L -# https://github.com/argoproj/argo-cd/releases/download/v2.0.3/argocd-linux-amd64 -o argocd
chmod +x argocd
sudo mv argocd /usr/local/bin/
#argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
#argocd completion bash | sudo tee /etc/bash_completion.d/argoocd


# Proxy
#        env:
#        - name: NO_PROXY
#          value: argocd-repo-server,argocd-application-controller,argocd-metrics,argocd-server,argocd-server-metrics,argocd-redis,10.0.0.0/8
#        - name: HTTP_PROXY
#          value: http://:3128
#        - name: HTTPS_PROXY
#          value: http://:3128
