project="storage-test1"
origin_pvc="pvc-test-origin"
origin_pod="pod-test-origin"
oc new-project $project

oc create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $origin_pvc
  namespace: $project
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 300Gi
  storageClassName: odf-lvm-vg1
  volumeMode: Filesystem
---
apiVersion: v1
kind: Pod
metadata:
  name: $origin_pod
  namespace: $project
spec:
  containers:
  - image: quay.io/ocsci/nginx:latest
    name: web-server
    volumeMounts:
    - mountPath: /var/lib/www/html
      name: mypvc
  volumes:
  - name: mypvc
    persistentVolumeClaim:
      claimName: $origin_pvc
      readOnly: false

EOF
start=$(date +%s)
while true
do
status=`oc get pods $origin_pod -n $project | grep -vi name`
end=$(date +%s)
elapsed=$(($end-$start))
echo $status+" "+$elapsed+" sec since check start "+$start
if [[ $status == *"Running"* ]]
then
  break
fi
if [ $elapsed -ge 120 ]
then
  echo "Waited 5 minutes and pod is not running "
  exit
fi
done
oc rsh $origin_pod apt-get update
oc rsh $origin_pod apt-get install -y fio
oc rsh $origin_pod fio --name=fio-rand-readwrite --filename=/var/lib/www/html/fio.txt --readwrite=write --bs=100M --direct=1 --numjobs=1 --size=30g --iodepth=4 --invalidate=0 --fsync_on_close=1 --rwmixread=50 --ioengine=libaio --rate=1500m --buffer_pattern=0xdeadface --output-format=json

for i in {1..14}
do
  # if [ i -eq 1 ]
  # then
oc create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: restored-snp-test$i
  namespace: $project
spec:
  source:
    persistentVolumeClaimName: $origin_pvc
  volumeSnapshotClassName: odf-lvm-vg1
EOF
# else
#   minusi=$i-1
#   oc create -f - <<EOF
# apiVersion: snapshot.storage.k8s.io/v1
# kind: VolumeSnapshot
# metadata:
#   name: restored-snp-test$i
#   namespace: $project
# spec:
#   source:
#     persistentVolumeClaimName: restored-pvc-snp-test$minusi
#   volumeSnapshotClassName: odf-lvm-vg1
# EOF
# fi
sleep 10
oc create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc-snp-test$i
  namespace: $project
spec:
  accessModes:
  - ReadWriteOnce
  dataSource:
    apiGroup: snapshot.storage.k8s.io
    kind: VolumeSnapshot
    name: restored-snp-test$i
  resources:
    requests:
      storage: '322122547200'
  storageClassName: odf-lvm-vg1
  volumeMode: Filesystem
---
EOF
sleep 10
oc create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-restored-test-$i
  namespace: $project
spec:
  containers:
  - image: quay.io/ocsci/nginx:latest
    name: web-server
    volumeMounts:
    - mountPath: /var/lib/www/html
      name: mypvc
  volumes:
  - name: mypvc
    persistentVolumeClaim:
      claimName: restored-pvc-snp-test$i
      readOnly: false
EOF
start=$(date +%s)
while true
do
status=`oc get pods pod-restored-test-$i -n $project | grep -vi name`
end=$(date +%s)
elapsed=$(($end-$start))
echo $status+" "+$elapsed+" sec since check start "+$start
if [[ $status == *"Running"* ]]
then
  break
fi
if [ $elapsed -ge 120 ]
then
  echo "Waited 5 minutes and pod is not running "
  exit
fi
done
sleep 10
oc delete VolumeSnapshot restored-snp-test$i
done
oc delete pod $origin_pod
oc delete pvc $origin_pvc