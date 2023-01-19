{{/*
Expand the name of the chart.
*/}}
{{- define "travelshift-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
# {{- define "travelshift-template.fullname" -}}
# {{- if .Values.fullnameOverride }}
# {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
# {{- else }}
# {{- $name := default .Chart.Name .Values.nameOverride }}
# {{- if contains $name .Release.Name }}
# {{- .Release.Name | trunc 63 | trimSuffix "-" }}
# {{- else }}
# {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
# {{- end }}
# {{- end }}
# {{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "travelshift-template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "travelshift-template.labels" -}}
helm.sh/chart: {{ include "travelshift-template.chart" . }}
{{ include "travelshift-template.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
app: {{ .Values.app }}
commit: {{ .Values.commit }}
env: {{ .Values.environment }}
team: {{ .Values.team }}
version: {{ .Values.version }}
{{/*
Selector labels
*/}}
{{- define "travelshift-template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "travelshift-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Values.app }}
version: {{ .Values.version }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "travelshift-template.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- printf "%s-%s" .Values.version .Values.app}}
{{- else }}
{{- default "default"}}
{{- end }}
{{- end }}

{{/*
Set the environment name for routing
*/}}
{{- define "travelshift-template.routingEnvironment" -}}
{{- if eq .Values.environment "prod" }}
{{- default "prod" }}
{{- else }}
{{- default "staging" }}
{{- end }}
{{- end }}

# {{ .Values.version}}-{{ .Values.app }}