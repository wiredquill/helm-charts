# helm-charts

Helm Charts Repository — the dedicated home for standalone Helm charts used across the WiredQuill / SUSE AI infrastructure. Application source (the ai-compare and hr-assistant apps and their charts) lives in `wiredquill/ai-demos`; this repo holds the shared, independently-deployable charts that both are built from and reference.

## Charts

### App / demo charts
- `ollama-suse` — Ollama wrapper chart pulling from the SUSE Application Collection (OCI `dp.apps.rancher.io/charts`).
- `ollama-upstream` — Ollama wrapper chart pulling from the upstream `helm.otwld.com` chart.
- `ollama-webui-upstream` — Ollama + Open WebUI combination from upstream charts.
- `rancher-ai-ollama` — Ollama + LiteLLM with GPU support, questions.yaml for Rancher UI installs.
- `rancher-ai-vllm` — vLLM serving chart (vendored `charts/vllm` subchart), Rancher UI ready.
- `stable-diffusion` — Stable Diffusion (AUTOMATIC1111 / ComfyUI / InvokeAI) with CPU/GPU values.
- `genai-observability-demo` — GenAI observability demo stack.
- `mlflow`, `n8n`, `pytorch`, `suse-ai-deployer`, `suse-ai-observability-extension` — general SUSE AI platform charts.

### Notes
- Charts are packaged and published to `gh-pages` automatically by CI on push to `main` (see `.github/workflows/`). Do not commit `.tgz` packages — CI regenerates them.
- Vendored subchart dependencies (`.tgz` under each `charts/<chart>/charts/` or the `file://` vllm subchart) are committed so packaging works offline / in CI.

## Install via the Rancher UI

App > Repositories > Add:

- Target: `Git repo`
- Git Repo URL: `https://github.com/wiredquill/helm-charts.git`
- Branch: `gh-pages`

```yaml
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: wq-charts
spec:
  gitBranch: gh-pages
  gitRepo: https://github.com/wiredquill/helm-charts.git
```
