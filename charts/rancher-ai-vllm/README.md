# rancher-ai-vllm

vLLM model serving optimized for **SUSE Rancher AI (Liz)**, wrapping the SUSE
Application Collection `vllm` chart (engine + router) and providing full **SUSE
Observability** integration — native Prometheus token metrics PLUS GenAI topology
(inference-engine → models).

## Why no proxy for metrics?

vLLM exposes token counts natively via `/metrics`
(`vllm_prompt_tokens_total`, `vllm_generation_tokens_total`,
`vllm_time_to_first_token_seconds`, `vllm_time_per_output_token_seconds`, ...).
The SUSE Observability collector scrapes this endpoint and uses the metrics to
infer that vLLM is an inference engine. No sidecar, no proxy.

## SUSE Observability Integration

The chart provides two modes:

### Mode: `existing` (default)
A shared OpenTelemetry collector already runs on the cluster (e.g.,
`suse-observability` or `observability` namespace). The chart:
- Auto-discovers the collector Service at install time
- Runs a pre-install connectivity check (fails the install if unreachable)
- Exports Prometheus metrics from vLLM to the collector
- No extra resources — just metrics collection

### Mode: `operator`
The OpenTelemetry Operator creates a SUSE AI collector in this release's
namespace. Requires the OTel Operator to be installed cluster-wide. The
collector is pre-configured with:
- SUSE Observability topology exporter (infers app → inference-engine → model)
- GenAI metric processors (groups metrics by model and provider)
- API key auto-copy from `suse-observability` namespace

The topology inference reads `vllm_*` metrics and builds the SUSE AI view.

## Observability Setup

### Step 1: Choose a mode

**Default mode `existing`:** Leave it as-is if you already have a shared collector
running (e.g., from SUSE Observability deploying one in the `suse-observability`
or `observability` namespace).

```bash
helm install my-vllm rancher-ai-vllm --set observability.mode=existing
```

**Operator mode:** If you have the OpenTelemetry Operator installed and SUSE
Observability credentials:

```bash
helm install my-vllm rancher-ai-vllm \
  --set observability.mode=operator \
  --set opentelemetry.operator.suseObservability.apiUrl=https://observability.example.com \
  --set opentelemetry.operator.suseObservability.otlpEndpoint=collector.observability.suse.com:4317
```

The chart auto-copies the API key from `suse-observability` namespace if it exists.

### Step 2: Verify collector connectivity (shared mode only)

The pre-install hook checks collector reachability before deployment. If the
check fails, the install aborts and suggests the correct endpoint:

```bash
kubectl get svc -n observability | grep opentelemetry
```

### Step 3: View the topology in SUSE Observability

Once vLLM is running and producing metrics:
1. Open SUSE Observability → **SUSE AI** section
2. Look for an **inference-engine** component named **vllm**
3. Prometheus metrics flow through: `vllm_prompt_tokens_total`,
   `vllm_generation_tokens_total`, `vllm_time_to_first_token_seconds`, ...
4. The chart auto-infers the component type (inference-engine) from the metric names

### Key metrics available

- **`vllm_prompt_tokens_total`** — cumulative input tokens processed
- **`vllm_generation_tokens_total`** — cumulative output tokens generated
- **`vllm_time_to_first_token_seconds`** — TTFT per request (latency-sensitive)
- **`vllm_time_per_output_token_seconds`** — per-token latency (throughput)
- **`vllm_cache_utilization`** — KV-cache memory pressure

Query tokens/sec with PromQL:
```
rate(vllm_generation_tokens_total[1m])
```

## Highlights

- Model dropdown organized by GPU VRAM class (16/24/64/100 GB)
- OpenAI-compatible router endpoint (port 80) — the sanctioned Rancher AI hook
- Model weights cached in a PVC (fast restarts); storage class is a dropdown
  with 'Default' = cluster default, plus optional shared NFS model cache
  (enable/disable + server/path/size) so new instances skip re-downloading
- Scrape target Service `<release>-engine-scrape` labelled
  `app.kubernetes.io/part-of=vllm` (+ `prometheus.io/*` annotations)
- Router traces via `routerSpec.otel.endpoint` (gRPC → collector)
- Native ingress via `routerSpec.ingress` for cross-cluster Rancher AI access

## Quick start (Rancher UI)

1. Add the ai-demos Cluster Repo
2. Apps → Charts → rancher-ai-vllm → Install
3. Pick your GPU class model, storage class, ingress host
4. Point Rancher AI at `http://<release>-router-service:80/v1`

Full walkthrough: [docs/rancher-ai-vllm.md](../../docs/rancher-ai-vllm.md)
Metrics & tokens/sec: [docs/rancher-ai-observability.md](../../docs/rancher-ai-observability.md)

## Notes

- Dependency: `vllm` 0.1.10 from `oci://dp.apps.rancher.io/charts` (vendored in
  `charts/`). Bump via `helm dependency update`.
- The collector scrape job lives in
  `templates/otel-collector-values-suse-ai.yaml` (cluster-level, not part of
  this chart).
