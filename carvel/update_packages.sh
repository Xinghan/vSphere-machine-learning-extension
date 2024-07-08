#!/bin/bash

# set -x 

cd $(dirname $0)

# export IMGPKG_PACKAGE=projects.registry.vmware.com/kubeflow/kubeflow-carvel-testing:0.12
# export IMGPKG_REPO=projects.registry.vmware.com/kubeflow/kubeflow-carvel-repo:0.12

# this is where to put the images, however, we do not have the access yet. You can edit this to enable vmware.com repo.
export IMGPKG_PACKAGE=tiansiyuan/kubeflow-carvel-testing:0.14
export IMGPKG_REPO=tiansiyuan/kubeflow-carvel-repo:0.14

# export IMGPKG_PACKAGE=harbor-isvlab.liuqi.me/library/kubeflow-carvel-testing:0.12
# export IMGPKG_REPO=harbor-isvlab.liuqi.me/library/kubeflow-carvel-repo:0.12

echo 0. Create preview of yaml results at kubeflow_manifest_preview.yaml
ytt --file bundle/config > kubeflow_manifest_preview.yaml
mkdir -p carvel_temp

echo 1. kbld: lock Package image tags to sha256 digest
kbld --file bundle --imgpkg-lock-output bundle/.imgpkg/images.yml > /dev/null

echo 2. vendir: create lock file
vendir sync --chdir bundle

echo 3. imgpkg push bundle to ${IMGPKG_PACKAGE}
imgpkg push --bundle ${IMGPKG_PACKAGE} --file bundle/ 

echo 4. Update valuesSchema into Package file
ytt --file bundle/config/values-schema.yaml --data-values-schema-inspect -o openapi-v3 > ./carvel_temp/schema-openapi.yml
cat << EOF | ytt --file repo/packages/1.8.1.yml --file - --data-value-file openapi=./carvel_temp/schema-openapi.yml > ./carvel_temp/1.8.1.yml
#@ load("@ytt:overlay", "overlay")
#@ load("@ytt:data", "data") 
#@ load("@ytt:yaml", "yaml") 
#@overlay/match by=overlay.subset({"kind": "Package"}), expects=1
---
spec:
  template:
    spec:
      fetch:
      #@overlay/match by=overlay.index(0)
      - imgpkgBundle:
          image: ${IMGPKG_PACKAGE}
  valuesSchema:
    #@overlay/replace
    openAPIv3: #@ yaml.decode(data.values.openapi)["components"]["schemas"]["dataValues"]
EOF
mv ./carvel_temp/1.8.1.yml repo/packages/1.8.1.yml

echo 5. kbld: lock Repo image tags to sha256 digest
rm repo/.imgpkg/images.yml
kbld --file repo --imgpkg-lock-output repo/.imgpkg/images.yml > /dev/null

echo 6. imgpkg push bundle to ${IMGPKG_REPO} 
imgpkg push --bundle ${IMGPKG_REPO} --file repo/

rm ./carvel_temp/schema-openapi.yml
rmdir ./carvel_temp
