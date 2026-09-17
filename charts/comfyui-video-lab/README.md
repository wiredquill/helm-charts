# comfyui-video-lab

Browser-accessible, persistent **ComfyUI Video Lab** for **LTX-2.5 + Wan 2.2** on a
single RTX 4090. One whole GPU, one URL, no SSH: the operator just unloads the
other GPU workload and the user opens the page.

## What it does

- Deploys one ComfyUI worker that requests **`nvidia.com/gpu: 1`** (a whole
  card — no time-sharing by design) with `runtimeClassName: nvidia` (RKE2).
- Uses a **pinned runtime image** (no moving `latest`):
  - ComfyUI **v0.35.0** (commit `40c4fcdf513a4523e39d54a9d391908af8df8171`)
  - ComfyUI-Manager **4.2.2** (`security_level=normal`, git-url and pip
    installs disabled)
  - 6 custom-node packs at pinned commits (VideoHelperSuite, WanVideoWrapper,
    efficiency-nodes, Impact-Pack, AnimateDiff-Evolved, Manager)
  - **7 baked workflow templates** in the Blueprints panel: LTX 2.5 Fast,
    LTX 2.5 Experimental, Wan fast previz, Wan 14B T2V, Wan 14B I2V,
    Wan first/last frame, Wan split-denoise.
- An init container downloads the exact pinned model set (16 files,
  byte-verified, resumable) into a persistent PVC on first start. LTX-2.5 is
  auto-gated on Hugging Face — the account must accept the license and an
  `HF_TOKEN` secret is injected; Wan 2.2 is public.
- Web service stays **internal on 8188**; TLS/auth is delegated to the
  cluster ingress (rke2-traefik). WebSocket upgrades work through
  Traefik with no extra annotations.

## Storage

One PVC (default **1000Gi**, RWO, `local-path`) holds
`models/ input/ output/ user/ temp/`. The node's root disk (~106 GB free)
cannot fit the full set (~139 GB) — attach a data disk first, then either
point `local-path`'s storage dir at it or add a StorageClass for the new
disk and set `storage.storageClassName`. The 1 TB fast-NVMe target is the
recommended layout.

Set `models.ltx25.devTransformer: false` (default) to drop the 21.5 GB
experimental model; `models.ltx25.enabled: false` to skip all LTX-2.5
(~118 GB total instead).

## Deploy

```bash
# on the 4090 cluster
kubectl create namespace comfyui
kubectl -n comfyui create secret generic comfyui-video-lab-hf \
  --from-literal=HF_TOKEN="<hf read token, LTX-2.5 license accepted>"

helm install lab ./charts/comfyui-video-lab -n comfyui \
  --set image.repository=ghcr.io/wiredquill/comfyui-video-lab \
  --set image.tag=40c4fcdf \
  --set ingress.host=<your host>
```

First start: `kubectl -n comfyui logs -l app.kubernetes.io/name=comfyui-video-lab -c download-models -f`
(watches the model pull). When the pod is Ready:
`kubectl -n comfyui port-forward svc/<release>-comfyui-video-lab 8188` or use the ingress URL.
Open the **Blueprints** panel and pick a "Video Lab - …" template.

## Smoke-test matrix (from the templates)

- LTX 2.5: 768×448, 65 frames (`frames % 8 == 1`), distilled INT8.
- Wan: 640×640, 81 frames — 14B T2V, 14B I2V, first/last frame, 4-step
  accelerated (LightX2V LoRAs), split-denoise experimentation.
- Video I/O: upload MP4 → extract frames → preserve audio → combine →
  MP4 written to the persistent `output/` dir (VideoHelperSuite).

## Nightly operation

The card is shared with other AI workloads by day (time-sliced replicas).
Unload them at night; this pod holds one whole `nvidia.com/gpu` and the
strategy is `Recreate`, so two workers can never coexist on the card.

## Upgrades

Re-bake: bump `image.tag`, update the model manifest (byte-verified sizes in
`_helpers.tpl`), regenerate blueprints from the pinned ComfyUI tree. The
init container is idempotent — already-present files are skipped.
