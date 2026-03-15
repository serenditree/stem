{{- define "st-default-labels" }}
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: {{ .Chart.Name }}
    app.kubernetes.io/part-of: serenditree
{{- end }}
{{- define "st-default-labels-range" }}
    app.kubernetes.io/name: {{ .name }}
    app.kubernetes.io/version: {{ .context.Chart.AppVersion }}
    app.kubernetes.io/component: {{ regexReplaceAll "-.*" .name "" }}
    app.kubernetes.io/part-of: serenditree
{{- end }}
