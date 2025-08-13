{{- define "app.name" -}}
{{- default .Chart.Name .Values.app.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app.fullname" -}}
{{- printf "%s" (include "app.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
