{{- define "st-wait" -}}
{{- $job := printf "%s-wait" .Chart.Name -}}
{{- $wave := sub .Values.global.wave 1 -}}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $job }}
  namespace: terra-argocd
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
  labels:
    serenditree.io/hook: wait
spec:
  template:
    metadata:
      labels:
        serenditree.io/hook: wait
    spec:
      restartPolicy: OnFailure
      serviceAccountName: argocd-wait
      containers:
        - name: wait
          image: docker.io/alpine/kubectl:latest
          command:
            - /bin/sh
            - -c
            - |
              APPLICATIONS=$(
                kubectl get applications.argoproj.io \
                  -o jsonpath='{.items[?(@.metadata.annotations.argocd\.argoproj\.io/sync-wave=="{{ $wave }}")].metadata.name}' |
                  xargs
              )
              echo "Waiting for application(s) $APPLICATIONS in sync-wave {{ $wave }} to become healthy..."
              STATUS="Unknown"
              until [ "$STATUS" == "Healthy" ]; do
                STATUS=$(
                kubectl get applications.argoproj.io \
                  -o jsonpath='{.items[?(@.metadata.annotations.argocd\.argoproj\.io/sync-wave=="{{ $wave }}")].status.health.status}' |
                  tr ' ' '\n' |
                  sort -u
                )

                if [ "$STATUS" != "Healthy" ]; then
                  echo "Current status: ${STATUS}. Retrying in 10s..."
                  sleep 10
                fi
              done
              echo "Previous sync-wave is healthy. Proceeding..."
{{- end }}
