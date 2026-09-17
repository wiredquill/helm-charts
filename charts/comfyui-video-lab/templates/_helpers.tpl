{{/*
ComfyUI Video Lab — helpers
*/}}

{{- define "comfyui-video-lab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "comfyui-video-lab.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "comfyui-video-lab.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "comfyui-video-lab.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "comfyui-video-lab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "comfyui-video-lab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "comfyui-video-lab.modelManifest" -}}
# ComfyUI Video Lab model manifest (chart-generated)
{{- if .Values.models.ltx25.enabled }}
{{- /* LTX-2.5 (gated) — exact byte sizes verified 2026-09-15 */}}
21504034224 Lightricks/LTX-2.5 diffusion_models/ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors models/diffusion_models
15372969374 Lightricks/LTX-2.5 text_encoders/gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors models/text_encoders
1452269922 Lightricks/LTX-2.5 vae/ltx-2.5-video-vae-conv-bf16.safetensors models/vae
364866540 Lightricks/LTX-2.5 vae/ltx-2.5-audio-vae-bf16.safetensors models/checkpoints
8899889568 Lightricks/LTX-2.5 loras/ltx-2.5-22b-distilled-lora-450-bf16.safetensors models/loras
{{- if .Values.models.ltx25.devTransformer }}
21504034224 Lightricks/LTX-2.5 diffusion_models/ltx-2.5-22b-dev-transformer-comfy-int8-convrot.safetensors models/diffusion_models
{{- end }}
{{- end }}
{{- if .Values.models.wan.enabled }}
{{- /* Wan 2.2 (public) */}}
14293923632 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors models/diffusion_models
14293923632 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors models/diffusion_models
14294742832 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors models/diffusion_models
14294742832 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors models/diffusion_models
6735906897 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors models/text_encoders
1409400960 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/vae/wan2.2_vae.safetensors models/vae
1226977424 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors models/loras
1226977424 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors models/loras
1226977424 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors models/loras
1226977424 Comfy-Org/Wan_2.2_ComfyUI_Repackaged split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors models/loras
{{- end }}
{{- end -}}
