# Rancher `questions.yaml` — Base Template & Schema Reference

This directory holds a reusable base `questions.yaml` (the standard tabs
every chart in this repo should have) and this README, which documents the
schema conventions used across all charts here. None of the existing
`questions.yaml` files in this repo had any in-repo schema documentation
before this file was added.

## What `questions.yaml` is

Rancher's Apps & Marketplace UI reads `questions.yaml` from a chart to
render a guided install form instead of a raw values editor. It is not read
by Helm itself — `helm install`/`helm template` ignore it entirely. This
repo uses the **legacy Rancher schema**: a flat top-level `questions:` list.
No chart here uses the newer `Questions:`/`Categories:` schema, and this
template follows that same legacy schema for consistency.

## Field reference

| Field | Required | Notes |
|---|---|---|
| `variable` | yes | Dot-path into `values.yaml`. Must match the ACTUAL shape of your chart's values.yaml exactly, including any wrapper-chart nesting (see "Wrapper charts" below). A wrong path renders the field but silently never applies the value. |
| `label` | recommended | Short field title shown in the form. |
| `description` | recommended | Tooltip/help text. Supports basic HTML (`<b>`, `<br>`, `<code>` render correctly — used in `charts/rancher-ai-vllm/questions.yaml`). Use sparingly, not on every field, for a clean UI. |
| `type` | yes | See "Type catalog" below. |
| `group` | yes | Tab name. **Tabs render in first-occurrence order in the file** — not alphabetical, not declared elsewhere. To make a tab appear first, put its fields first in the file. |
| `default` | recommended | Pre-filled value. Should match `values.yaml`'s actual default so the form and the chart agree before any user edits. |
| `required` | no | Blocks install until filled. |
| `show_if` | no | Conditional visibility. See syntax below. |
| `options` | for `enum` | List of allowed values. |
| `min` / `max` | for `int` | Numeric bounds. |

## Type catalog (in use across this repo)

- `string`
- `boolean`
- `enum` (needs `options: [...]`)
- `int` — use `int`, not `integer`. One chart in this repo (`stable-diffusion`) uses `integer` inconsistently; every other chart uses `int`. Standardize on `int` going forward.
- `password` — masks the value in the UI (secrets)
- `storageclass` — renders Rancher's native storage-class picker widget. Prefer this over plain `string` for any StorageClass field.
- `secret` — existing-Secret picker
- `hostname`

**Not used anywhere in this repo, and therefore unverified against a live
Rancher instance:** `type: map`, `type: array`/list-widgets, `subquestions:`.
If you need one of these, confirm it works in a real Rancher UI before
shipping — don't assume from documentation alone.

## `show_if` syntax

Quote the whole expression; leave the right-hand value unquoted:

```yaml
show_if: "service.type=LoadBalancer"
```

Booleans compare bare `true`/`false`:

```yaml
show_if: "gpu.enabled=true"
```

Combine conditions with `&&`:

```yaml
show_if: "ollama.enabled=true && ollama.gpu.type=nvidia"
```

Test for an empty string by leaving nothing after `=`:

```yaml
show_if: "ollama.persistence.existingClaim="
```

## Basic/Advanced toggle (tab-level show_if)

`show_if` doesn't just hide individual fields — if **every** question in a
`group` evaluates to hidden, Rancher collapses that tab out of the sidebar
entirely. This makes a "Basic vs. Advanced" split possible: add a boolean
toggle on your first-page tab, then apply `show_if: "<path>.showAdvanced=true"`
to every field in a tab you want hidden by default.

```yaml
# 1. The toggle (put it on your Quick Start / first tab)
- variable: showAdvanced
  label: "Show Advanced Options"
  description: "Reveals less-common settings across every tab below."
  type: "boolean"
  default: false
  group: "Quick Start"

# 2. Every field in a tab you want fully hidden by default carries the
#    same condition — once ALL of them evaluate false, the whole tab
#    disappears from the sidebar, not just the fields.
- variable: priorityClassName
  type: "string"
  default: ""
  show_if: "showAdvanced=true"
  group: "Advanced"
```

For a tab that mixes essential and optional fields (e.g. a "Networking" tab
where Service Type should always show but Ingress shouldn't), only add the
condition to the optional fields — the tab stays visible (because some of
its fields are still shown), but the optional fields inside it reveal
themselves once the toggle is checked. Combine with an existing `show_if`
using `&&`, e.g. `show_if: "ingress.enabled=true && showAdvanced=true"`.

Don't gate everything reflexively — decide per tab whether it's genuinely
optional. Observability, for instance, is deliberately left ungated in the
`ollama-suse` example below: SUSE AI Factory deployments are expected to
have OpenTelemetry configured by default, so hiding it behind "Advanced"
would bury a setting most installs actually need.

See `charts/ollama-suse/questions.yaml` for a worked example: its
`ollama.showAdvanced` toggle fully hides the Advanced tab, and partially
gates fields within Quick Start/Image/Networking/Storage Configuration —
while Observability stays visible unconditionally. That chart also shows
that a tab doesn't need to exist at all: there's no dedicated "Model
Configuration" or "GPU Configuration" tab — Model and GPU settings live on
Quick Start and (for the fuller GPU/model options) Resource Configuration,
rather than getting their own tab each.

## Indexed list variables

Rancher supports binding to a specific index of a YAML list via
`path[0]`, `path[1]`, etc. — used throughout this repo (e.g. a chart's
`models[0]`). This is safe and well-precedented.

**Compound indexing** (`path[0].field`, indexing into a list of *objects*,
e.g. `ingress.hosts[0].host` or `tolerations[0].key`) is used in the
`ollama-suse` example but has limited precedent elsewhere in this repo — it
combines two individually-precedented mechanisms (object field access + list
indexing) and matches what `charts/ollama-suse/charts/ollama/templates/`
actually expects, but hasn't been confirmed through a live Rancher form for
every case. Verify before relying on a new compound path.

## The "duplicate variable across two tabs" idiom (Quick Start / home page)

Rancher renders tabs in first-occurrence order, and the **first tab is what
users see when the install form opens**. To surface a small set of
high-value fields on a "Quick Start" home tab *while keeping their proper,
fully-documented home on a dedicated tab later in the file*, repeat the
**exact same** `variable`, `default`, `type`, `options`, and `description`
as **two separate top-level list entries**, each with a different `group:`:

```yaml
questions:
# --- Quick Start tab (appears first) ---
- variable: service.type
  label: "Service Type"
  description: "Kubernetes service type used to expose the application."
  type: "enum"
  options: ["ClusterIP", "NodePort", "LoadBalancer"]
  default: "ClusterIP"
  group: "Quick Start"

# ... other tabs in between ...

# --- Service tab (its proper home, later in the file) ---
- variable: service.type
  label: "Service Type"
  description: "Kubernetes service type used to expose the application."
  type: "enum"
  options: ["ClusterIP", "NodePort", "LoadBalancer"]
  default: "ClusterIP"
  group: "Service"
```

Rancher renders each occurrence as its own bound form control against the
same `values.yaml` path — editing either one updates the same underlying
value.

This idiom has no precedent anywhere in this repo prior to
`charts/ollama-suse/questions.yaml`. It's a reasonable, low-risk
extrapolation of documented Rancher behavior, but **should be visually
confirmed in a real Rancher install** the first time it's relied on — `helm
template`/`helm lint` cannot validate form-rendering behavior, only that the
YAML is well-formed and the chart still renders.

## Wrapper charts: watch your nesting

If your chart wraps a vendored subchart as a Helm dependency (like
`ollama-suse` wraps `charts/ollama`), the dependency's own root `values.yaml`
keys sit **one level under the dependency's alias name** in your parent
`values.yaml`, and any keys the dependency itself nests further (e.g. its
own internal `ollama:` block) stay nested that deep. Always open the vendored
subchart's actual `values.yaml` and templates and confirm the real path
before writing a question — don't assume flat root-level paths, and don't
assume a `type: string` field is safe to bind straight onto a list-typed
path like `imagePullSecrets` just because it's boilerplate elsewhere (see
`charts/ollama-suse/questions.yaml`'s General tab comment for a worked
example of a case where that assumption breaks).

## Maps and lists: read this before using the Advanced tab as-is

The legacy Rancher schema has no native map/array editor widget. The base
template's Advanced tab shows one way to fake a single fixed
`nodeSelector`/`tolerations` override, but it carries a real, confirmed
failure mode: most deployment templates render `nodeSelector`/`tolerations`
whenever the underlying value is non-empty, with no separate "enabled" flag
to gate on. An empty-string/empty-key default can still make the map/list
non-empty and get rendered — for example, a default `tolerations[0]` entry
with an empty `key` and `operator: Exists` is a Kubernetes **wildcard
toleration** (tolerates every taint), and a `nodeSelector.<key>` defaulting
to `""` can leave a pod permanently unschedulable. `charts/ollama-suse`
deliberately omits these fields from its Advanced tab for exactly this
reason — check your own chart's template logic before copying them.

## Extending the base template for a new chart

1. Copy `questions.yaml` from this directory into `charts/<name>/questions.yaml`.
2. Rename every `[RENAME]`-tagged path in the comments to match your chart's
   real `values.yaml` (including wrapper nesting, per above).
3. Delete tabs/fields that don't apply. Don't leave orphaned bindings.
4. Add chart-specific tabs (e.g. "Model Configuration") by inserting new
   blocks — remember tab order = first-occurrence order in the file.
5. If you want a "Quick Start" home tab, apply the duplicate-variable idiom
   above for your 2-4 highest-value fields, and put that block first in the
   file. `charts/ollama-suse/questions.yaml` is a worked example.
6. Run `helm lint charts/<name>` and `helm template charts/<name>` to catch
   YAML errors and confirm the chart still renders with your new
   `values.yaml` defaults — this validates YAML/template correctness only,
   not the Rancher form UI itself.
7. If possible, install into a real Rancher instance once and visually
   confirm tab order, `show_if` behavior, and (if used) the
   duplicate-variable idiom actually bind correctly — this is the one thing
   that cannot be verified from the CLI.

## Known anti-patterns to avoid (found in this repo, don't replicate)

- Hardcoded personal/dev defaults (e.g. an NFS server hostname pointing at a
  personal machine) baked in as a chart default — use empty strings or
  clearly generic placeholders instead.
- Inconsistent quoting of string scalars — quote all string defaults/options
  consistently within a file.
- `type: integer` — use `type: int`.
- Binding a `type: string` field straight to a values.yaml path your own
  chart's template doesn't explicitly coerce — check the consuming template
  first, especially in wrapper charts around vendored subcharts you don't
  control.
