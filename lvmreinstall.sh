date +%T; oc get pods -A | grep test | awk {'print $1," ", $2'} | xargs -l bash -c 'oc delete pod $1 -n $0'
date +%T; oc get pvc -A | grep test | awk {'print $1," ", $2'} | xargs -l bash -c 'oc delete pvc $1 -n $0'
date +%T; oc get volumesnapshot -A | grep test | awk {'print $1," ", $2'} | xargs bash -c 'oc delete volumesnapshot $1 -n $0'
date +%T; oc get pv -A | grep -vi name | awk {'print $1'} | xargs oc delete pv
date +%T; oc get logicalvolume -A | grep -vi name | awk {'print $1'} | xargs oc delete logicalvolume
date +%T; oc get namespace | grep test |awk {'print $1'} | xargs oc delete namespace
date +%T; oc get storageclass | grep -vi name | grep test | awk {'print $1'} | xargs oc delete storageclass
date +%T; oc project openshift-storage
date +%T; oc delete lvmcluster lvmcluster -n openshift-storage
date +%T; oc delete subscriptions.operators.coreos.com odf-lvm-operator
date +%T; oc delete  operatorgroup openshift-storage-operatorgroup
date +%T; oc project default
date +%T; oc delete namespace openshift-storage
date +%T; oc delete catalogsource redhat-operators -n openshift-marketplace
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  labels:
    ocs-operator-internal: 'true'
  name: redhat-operators
  namespace: openshift-marketplace
spec:
  displayName: Openshift Container Storage
  icon:
    base64data: ''
    mediatype: ''
  image: quay.io/rhceph-dev/ocs-registry:4.11.0-98
  publisher: Red Hat
  sourceType: grpc
EOF
while true;do
status=`oc get catalogsource redhat-operators -n openshift-marketplace -o yaml | grep lastObservedState`
echo $status
if [[ $status == *"READY"* ]]
then
	break
fi
done
oc create -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-storage
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
    - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-lvm-operator
  namespace: openshift-storage
spec:
  installPlanApproval: Automatic
  name: odf-lvm-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: odf-lvm-operator.v4.11.0
EOF
start=$(date +%s)
while true;do
status=`oc get pods -n openshift-storage | grep lvm-operator`
echo $status
if [[ $status == *"Running"* ]]
then
	break
fi
end=$(date +%s)
elapsed=$(($end-$start))
echo $elapsed
if [ $elapsed -ge 600 ]
then
	echo "Waited 5 minutes and pod is not running "
	break
fi
done
oc create -f - <<EOF
apiVersion: lvm.topolvm.io/v1alpha1
kind: LVMCluster
metadata:
  finalizers:
  - lvmcluster.topolvm.io
  generation: 1
  name: lvmcluster
  namespace: openshift-storage
spec:
  storage:
    deviceClasses:
    - name: vg1
      thinPoolConfig:
        name: thin-pool-1
        overprovisionRatio: 50
EOF
start=$(date +%s)


while true;do
status=`oc get pods -n openshift-storage | grep topolvm-controller`
echo $status
if [[ $status == *"Running"* ]]
then
	break
fi
end=$(date +%s)
elapsed=$(($end-$start))

if [ $elapsed -ge 600 ]
then
	echo "Waited 5 minutes and pod is not running "
	break
fi
done
start=$(date +%s)
while true;do
status=`oc get pods -n openshift-storage | grep topolvm-node`
echo $status
if [[ $status == *"Running"* ]]
then
	break
fi
end=$(date +%s)
elapsed=$(($end-$start))
echo $elapsed
if [ $elapsed -ge 600 ]
then
	echo "Waited 5 minutes and pod is not running "
	break
fi
done
start=$(date +%s)
while true;do
status=`oc get pods -n openshift-storage | grep vg-manager`
echo $status
if [[ $status == *"Running"* ]]
then
	break
fi
end=$(date +%s)
elapsed=$(($end-$start))
echo $elapsed
if [ $elapsed -ge 600 ]
then
	echo "Waited 5 minutes and pod is not running "
	break
fi
done
oc get pods -n openshift-storage



