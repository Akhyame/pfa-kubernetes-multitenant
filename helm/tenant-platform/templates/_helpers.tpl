{{/*
Common labels applied to tenant resources.
*/}}
{{- define "tenant-platform.labels" -}}
app.kubernetes.io/name: uptime-kuma
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
tenant: {{ .Values.tenant.name }}
{{- end }}

{{/*
Stable labels used by Services and Deployment selectors.
*/}}
{{- define "tenant-platform.selectorLabels" -}}
app: uptime-kuma
{{- end }}

{{/*
Tenant operator ServiceAccount name.
*/}}
{{- define "tenant-platform.operatorServiceAccountName" -}}
{{ .Values.tenant.name }}-operator
{{- end }}
