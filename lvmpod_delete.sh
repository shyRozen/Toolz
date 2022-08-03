oc get pods -n openshift-storage | grep -vi name | awk {'print $1'} | xargs oc -n openshift-storage delete pod
oc get pods -n openshift-storage

