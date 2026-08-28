{{/*
Expand the name of the chart.
*/}}
{{- define "rancher-ai-vllm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "rancher-ai-vllm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rancher-ai-vllm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rancher-ai-vllm.labels" -}}
helm.sh/chart: {{ include "rancher-ai-vllm.chart" . }}
{{ include "rancher-ai-vllm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rancher-ai-vllm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rancher-ai-vllm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Whether this release provisions its own OpenTelemetry collector. Driven by observability.mode;
opentelemetry.operator.enabled is still honoured for callers that set it directly.
*/}}
{{- define "rancher-ai-vllm.collectorEnabled" -}}
{{- if or (eq .Values.observability.mode "operator") .Values.opentelemetry.operator.enabled -}}
true
{{- end -}}
{{- end }}

{{/*
Name of the OpenTelemetryCollector CR managed by the OpenTelemetry Operator.
*/}}
{{- define "rancher-ai-vllm.collectorName" -}}
{{- printf "%s-otel" (include "rancher-ai-vllm.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Cluster name stamped on the telemetry. Rancher injects global.cattle.clusterName
on catalog installs, so this is almost never set by hand.
*/}}
{{- define "rancher-ai-vllm.clusterName" -}}
{{- $global := .Values.global | default dict -}}
{{- $cattle := $global.cattle | default dict -}}
{{- .Values.opentelemetry.operator.clusterName | default .Values.clusterName | default $cattle.clusterName | default "unknown" }}
{{- end }}

{{/*
Name of the secret holding the SUSE Observability API key, resolving the three
supported sources in priority order.
*/}}
{{- define "rancher-ai-vllm.apiKeySecretName" -}}
{{- $so := .Values.opentelemetry.operator.suseObservability -}}
{{- if $so.existingSecret -}}
{{ $so.existingSecret }}
{{- else if $so.apiKey -}}
{{ include "rancher-ai-vllm.collectorName" . }}
{{- else -}}
{{ $so.copySecret.name }}
{{- end -}}
{{- end }}

{{/*
Namespace SUSE AI components are attributed to. Defaults to the release namespace
so each install shows up as its own SUSE AI namespace in the topology.
*/}}
{{- define "rancher-ai-vllm.suseAiNamespace" -}}
{{- default .Release.Namespace .Values.opentelemetry.operator.suseAiNamespace }}
{{- end }}

{{/*
Find the shared OpenTelemetry collector Service in the cluster at install time.

Helm's `lookup` runs against the live API server during install/upgrade (it
returns nothing during `helm template`), so this auto-discovers the collector
instead of asking the user to type it. Matches a Service whose name contains
"opentelemetry-collector" or that carries the app.kubernetes.io/name label.
*/}}
{{- define "rancher-ai-vllm.collectorService" -}}
{{- $explicit := .Values.observability.collectorNamespace | default "" -}}
{{- $candidates := list -}}
{{- if $explicit -}}
  {{- $candidates = append $candidates $explicit -}}
{{- end -}}
{{- $candidates = append $candidates "observability" -}}
{{- $candidates = append $candidates "suse-observability" -}}
{{- $svc := "" -}}
{{- range $ns := $candidates -}}
  {{- if not $svc -}}
    {{- $found := lookup "v1" "Service" $ns "" -}}
    {{- range $item := ($found.items | default list) -}}
      {{- if not $svc -}}
        {{- $lbl := dig "app.kubernetes.io/name" "" ($item.metadata.labels | default dict) -}}
        {{- if or (contains "opentelemetry-collector" $item.metadata.name) (eq $lbl "opentelemetry-collector") -}}
          {{- $svc = $item.metadata.name -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $svc -}}
{{- end }}

{{/*
The namespace the auto-discovered collector was found in (or the explicitly
configured one). Used to build the endpoint when the collector lives somewhere
other than the default (observability or suse-observability).
*/}}
{{- define "rancher-ai-vllm.collectorNamespace" -}}
{{- $explicit := .Values.observability.collectorNamespace | default "" -}}
{{- $candidates := list -}}
{{- if $explicit -}}
  {{- $candidates = append $candidates $explicit -}}
{{- end -}}
{{- $candidates = append $candidates "observability" -}}
{{- $candidates = append $candidates "suse-observability" -}}
{{- $ns := "" -}}
{{- range $cand := $candidates -}}
  {{- if not $ns -}}
    {{- $found := lookup "v1" "Service" $cand "" -}}
    {{- range $item := ($found.items | default list) -}}
      {{- if not $ns -}}
        {{- $lbl := dig "app.kubernetes.io/name" "" ($item.metadata.labels | default dict) -}}
        {{- if or (contains "opentelemetry-collector" $item.metadata.name) (eq $lbl "opentelemetry-collector") -}}
          {{- $ns = $cand -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- default "observability" $ns -}}
{{- end }}

{{/*
OTLP endpoint the applications export to. When the OpenTelemetry Operator option is
enabled the apps talk to the collector this chart provisions in its own namespace;
otherwise the endpoint resolves as follows:

1. .Values.otlpEndpoint if explicitly set (used verbatim; the pre-install hook
   validates connectivity and fails the install with the proper URL if wrong).
2. Auto-discovered collector Service in observability.collectorNamespace
   (Helm lookup at install time) - the "right collector" without typing anything.
3. The conventional shared-collector FQDN as a last resort.
*/}}
{{- define "rancher-ai-vllm.otlpEndpoint" -}}
{{- if include "rancher-ai-vllm.collectorEnabled" . -}}
http://{{ include "rancher-ai-vllm.collectorName" . }}-collector.{{ .Release.Namespace }}.svc.cluster.local:4318
{{- else -}}
{{- $endpoint := .Values.otlpEndpoint -}}
{{- if not $endpoint -}}
  {{- $svc := include "rancher-ai-vllm.collectorService" . -}}
  {{- if $svc -}}
    {{- $endpoint = printf "http://%s.%s.svc.cluster.local:4318" $svc (include "rancher-ai-vllm.collectorNamespace" .) -}}
  {{- else -}}
    {{- $endpoint = "http://open-telemetry-collector-opentelemetry-collector.observability.svc.cluster.local:4318" -}}
  {{- end -}}
{{- end -}}
{{- $endpoint -}}
{{- end -}}
{{- end }}

{{/*
The auto-discovered collector endpoint, used by the connectivity-check hook to
suggest the correct URL when the user-supplied one is unreachable.
*/}}
{{- define "rancher-ai-vllm.discoveredCollectorEndpoint" -}}
{{- $svc := include "rancher-ai-vllm.collectorService" . -}}
{{- if $svc -}}
http://{{ $svc }}.{{ include "rancher-ai-vllm.collectorNamespace" . }}.svc.cluster.local:4318
{{- end -}}
{{- end }}

{{/*
The namespace this release's SUSE AI components are grouped under.

SUSE's collector pipeline reads service.namespace off the resource first and only
falls back to its own SUSE_AI_NAMESPACE when the application did not declare one.
Declaring it here is what lets a single shared collector serve many namespaces and
still group each application under its own.
*/}}
{{- define "rancher-ai-vllm.suseAiServiceNamespace" -}}
{{- default .Release.Namespace .Values.observability.serviceNamespace }}
{{- end }}
