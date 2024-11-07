{{/*
TODO check if empty .value.Module
*/}}

{{- define "label-generator" -}}
app.kubernetes.io/name: {{.Release.Name}}-{{.Values.module}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: backend-golang-{{.Values.module}}
{{- end -}}
