This folder contains Kubernetes manifests to deploy the kudos frontend to a local `kind` cluster.

How this setup works
- The `Deployment` runs the container image `docker.io/library/kudos-app:dev` and exposes port `80` in the pod.
- The `Service` is a `NodePort` that maps cluster port `80` to node port `30080`.
- `kustomization.yaml` currently includes `deployment.yaml` and `service.yaml`. The `ingress.yaml` is present but commented out — enable it only if you have an ingress controller installed and configured.

Quick start (assumes `kind`, `kubectl`, and `docker` are installed)

1. Build the Docker image from the repository root:

```bash
docker build -t kudos-app:dev .
```

2. Load the image into the `kind` cluster (replace `kind` with your cluster name if different or check what is your cluster name command - `kind get clusters` )

```bash
kind load docker-image kudos-app:dev --name kind
```

3. Apply the manifests:

```bash
kubectl apply -k k8s/
```

Accessing the app
- NodePort (quick): open `http://localhost:30080` in your browser.
- Port-forward (fallback):

```bash
kubectl port-forward svc/kudos-frontend 8080:80
# then open http://localhost:8080
```
- Ingress (optional):
	- Uncomment the `ingress.yaml` entry in `k8s/kustomization.yaml`.
	- Install an ingress controller in your kind cluster (example: ingress-nginx):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

	- Add a hosts-file entry so `kudos.local` resolves to localhost (Windows example — run as Administrator):

```powershell
# Add to C:\Windows\System32\drivers\etc\hosts
Add-Content -Path 'C:\Windows\System32\drivers\etc\hosts' -Value '127.0.0.1 kudos.local'
```

	- Apply the kustomization (after uncommenting):
```bash
kubectl apply -k k8s/
```
	- Visit `http://kudos.local` once the ingress controller is Ready.

Troubleshooting
- If the app process is not reachable on port `80` inside the pod, check pod logs and processes:

```bash
kubectl get pods
kubectl logs <POD_NAME> -c kudos-frontend
kubectl exec -it <POD_NAME> -- sh -c "ps aux; ss -lntp || netstat -lntp || true"
```

- If you change the image or how the app is started (for example Vite needs `--host 0.0.0.0`), rebuild and re-load the image into kind, then restart the deployment:

```bash
docker build -t kudos-app:dev .
kind load docker-image kudos-app:dev --name kind
kubectl rollout restart deployment/kudos-frontend
```

Notes
- The current manifests expect the container to serve on port `80`. If you prefer to run the dev server on `5173`, update `k8s/deployment.yaml` and `k8s/service.yaml` to target `5173` respectively.
- To use a published registry image, change the `image` in `k8s/deployment.yaml` to your tag and push the image before applying manifests.

If you want, I can:
- Uncomment `ingress.yaml` and apply it, then install an ingress controller for you, or
- Update the manifests to use port `5173` instead — tell me which you prefer.
