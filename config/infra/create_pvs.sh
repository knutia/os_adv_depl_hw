sudo mkdir -p /srv/nfs/user-vols/pv{1..200}

for pvnum in {1..50}; do echo "/srv/nfs/user-vols/pv${pvnum} *(rw,root_squash)" >> openshift-uservols.exports; done
sudo cp ./openshift-uservols.exports /etc/exports.d/


sudo chown -R nfsnobody.nfsnobody  /srv/nfs; 
sudo chmod -R 777 /srv/nfs

sudo systemctl restart nfs-server