# ollama-webui-upstream

Integrated Ollama + Open WebUI wrapper chart. Bundles the upstream
[Ollama](https://helm.otwld.com/) and [Open WebUI](https://helm.openwebui.com/)
charts as dependencies, providing a single `helm install` for a complete,
self-hosted AI chat platform backed by local LLM inference.

## Usage

```bash
helm repo add ollama-webui https://github.com/wiredquill/helm-charts
helm install my-llm ollama-webui/ollama-webui-upstream
```

Expose Open WebUI by setting `open-webui.service.type` (e.g. `NodePort` or
`LoadBalancer`); the default Open WebUI service port is `8080`.

## Configuration

Values are passed through to the bundled `ollama` and `open-webui` subcharts
using standard Helm dependency scoping (`ollama.*` and `open-webui.*`).

Key Open WebUI options:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `open-webui.service.type` | Service type (ClusterIP / NodePort / LoadBalancer) | `ClusterIP` |
| `open-webui.service.port` | Open WebUI HTTP port | `8080` |
| `open-webui.ollama.baseUrl` | Ollama API URL for Open WebUI | `http://ollama:11434` |

Key Ollama options:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ollama.image.tag` | Ollama image tag | latest |
| `ollama.gpu.enabled` | Enable NVIDIA GPU acceleration | `false` |
