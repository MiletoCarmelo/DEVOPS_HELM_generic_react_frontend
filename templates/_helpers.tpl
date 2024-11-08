{{/*
TODO check if empty .value.Module
*/}}

{{- define "label-generator" -}}
app.kubernetes.io/name: {{.Values.module}}-{{ .Values.environment }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: frontend-react-{{.Values.module}}-{{ .Values.environment }}
{{- end -}}
