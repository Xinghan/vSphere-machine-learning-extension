#!/bin/bash

# set -x

cd $(dirname $0)

wget --quiet https://github.com/kubeflow/manifests/archive/refs/tags/v1.8.1.zip -O v1.8.1.zip
unzip -q v1.8.1.zip

kubeflow_ytt=bundle/config/upstream/kubeflow
kubeflow_dir=./manifests-1.8.1

# $1: dir
# $2: order: 1, 2, 3, 4, ...
function generate_upstream() {
    dir=$1
    order=$2
    mkdir -p ${kubeflow_ytt}/${dir}
    kustomize build ${kubeflow_dir}/${dir} -o ${kubeflow_ytt}/${dir}/install.yaml
    cat > ${kubeflow_ytt}/${dir}/orders.yaml << EOF
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.all, expects="1+"
---
metadata:
  #@overlay/match missing_ok=True
  annotations:
    #@overlay/match missing_ok=True
    kapp.k14s.io/change-group: "apps.kubeflow.org/order-${order}"
#@ if ${order} >= 2:
    #@overlay/match missing_ok=True
    kapp.k14s.io/change-rule: "upsert after upserting apps.kubeflow.org/order-$((order-1))"
#@ end
EOF
ytt --file ${kubeflow_ytt}/${dir} > ${kubeflow_ytt}/${dir}/install_order.yaml
rm ${kubeflow_ytt}/${dir}/install.yaml ${kubeflow_ytt}/${dir}/orders.yaml
}

# cert-manager
generate_upstream common/cert-manager/cert-manager/base 1
generate_upstream common/cert-manager/kubeflow-issuer/base 2

# istio
generate_upstream common/istio-1-17/istio-crds/base  3
generate_upstream common/istio-1-17/istio-namespace/base 3
generate_upstream common/istio-1-17/istio-install/base 3

# dex 
generate_upstream common/dex/overlays/istio 4

# oauth2-proxy
generate_upstream common/oidc-client/oidc-authservice/base 5

# Knative Serving
generate_upstream common/knative/knative-serving/overlays/gateways 6
generate_upstream common/istio-1-17/cluster-local-gateway/base 6
generate_upstream common/knative/knative-eventing/base 6

# kubeflow namespace
generate_upstream common/kubeflow-namespace/base 7

# kubeflow roles
generate_upstream common/kubeflow-roles/base 7

# istio resources
generate_upstream common/istio-1-17/kubeflow-istio-resources/base 7

# kubeflow pipelines
# generate_upstream apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user 8
generate_upstream apps/pipeline/upstream/env/platform-agnostic-multi-user-pns 8

# KServe
generate_upstream contrib/kserve/kserve 9
generate_upstream contrib/kserve/models-web-app/overlays/kubeflow 9

# profiles and KFAM
generate_upstream apps/profiles/upstream/overlays/kubeflow 10

# apps
generate_upstream apps/katib/upstream/installs/katib-with-kubeflow 11
generate_upstream apps/centraldashboard/upstream/overlays/kserve 11
generate_upstream apps/admission-webhook/upstream/overlays/cert-manager 11
generate_upstream apps/jupyter/notebook-controller/upstream/overlays/kubeflow 11
generate_upstream apps/jupyter/jupyter-web-app/upstream/overlays/istio 11
generate_upstream apps/pvcviewer-controller/upstream/default 11

generate_upstream apps/volumes-web-app/upstream/overlays/istio 11
generate_upstream apps/tensorboard/tensorboards-web-app/upstream/overlays/istio 11
generate_upstream apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow 11
generate_upstream apps/training-operator/upstream/overlays/kubeflow 11
generate_upstream common/user-namespace/base 11
