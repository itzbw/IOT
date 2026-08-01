# Inception-of-thing

All VMs use **CentOS 7** (`centos/7`). The Vagrant `private_network` attaches
to **`eth1`** on VirtualBox (NAT is `eth0`). K3s binds to the eth1 IPs below.

| Part | VM(s) | Private IP (eth1) |
|------|-------|-------------------|
| p1 | bwongS (master) | 192.168.56.110 |
| p1 | bwongSW (worker) | 192.168.56.111 |
| p2 | bwongS (single node) | 192.168.56.110 |
| p3 | imqandylS | 192.168.56.120 |
| bonus | (see bonus/) | 192.168.56.130 |

p1 and p2 both use **192.168.56.110** — destroy each part before starting the
next.

## Defense notes

**Why `kubectl apply --server-side` for the Argo CD install (p3/bonus launch.sh)?**
Plain `kubectl apply` stores a full copy of each object in the
`last-applied-configuration` annotation to diff future applies, and annotations
are capped at 256KB. Argo CD's ApplicationSet CRD is bigger than that, so the
client-side apply is rejected ("Too long: may not be more than 262144 bytes").
With `--server-side`, the API server tracks field ownership itself (managed
fields) instead of using the annotation — same install, no size limit.

**Why `centos-setup.sh` before K3s (p1/p2)?**
CentOS ships with `firewalld`, which blocks K3s ports. The script installs
`curl`, disables firewalld, and verifies that `eth1` is up before K3s starts.

## How to test (full run-book)

Test from a **fresh clone in an empty folder** (that is what the evaluator
does). All `vagrant` commands run from inside the part's folder.

### Part 1 — K3s cluster (~10 min)

```sh
cd p1
rm -f confs/token        # a stale token from an old run breaks the worker join
vagrant up               # bwongS provisions first, then p1-worker

vagrant ssh bwongS
hostname                          # -> bwongS
ip a show eth1                    # -> 192.168.56.110
kubectl get nodes -o wide         # -> bwongS + bwongsw Ready, IPs .110 / .111
exit

vagrant ssh p1-worker
hostname                          # -> bwongSW
ip a show eth1                    # -> 192.168.56.111
systemctl is-active k3s-agent     # -> active
exit

vagrant destroy -f                # before p2!
```

### Part 2 — three apps + ingress (~10 min)

Apps are deployed in the **`kube-system`** namespace (subject requirement).

```sh
cd ../p2
vagrant up
vagrant ssh bwongS

ip a show eth1                              # -> 192.168.56.110
kubectl get nodes -o wide                   # single node, .110
kubectl get deploy -n kube-system           # app-one 1/1, app-two 3/3, app-three 1/1
kubectl get pods -n kube-system             # all Running; POD_NAMESPACE -> kube-system
kubectl get ingress -n kube-system          # the eval asks to "show your ingress"
curl -H "Host: app1.com" localhost          # -> app-one page
curl -H "Host: app2.com" localhost          # -> app-two page
curl localhost                              # -> app-three (default)
exit
```

Repeat the three curls from the host machine against `192.168.56.110`
(browser or `curl -H "Host: app1.com" 192.168.56.110`) — that is how the
evaluator tests it. Refreshing app2.com shows POD_NAME changing across the 3
replicas. Then `vagrant destroy -f`.

### Part 3 — K3d + Argo CD (~20 min)

```sh
cd ../p3
vagrant up
vagrant ssh imqandylS
cd /vagrant/p3/scripts && bash install.sh
exit                                      # required: docker group needs re-login
vagrant ssh imqandylS
cd /vagrant/p3/scripts && bash launch.sh  # save the admin password it prints

kubectl get ns                            # argocd + dev
kubectl get pods -n dev                   # wil-playground Running
curl http://localhost:8888/               # -> {"status":"ok", "message": "v1"}
kubectl port-forward --address 192.168.56.120 svc/argocd-server 8080:80 -n argocd
```

From the host: open `http://192.168.56.120:8080`, login `admin` + printed
password, check `playground-app` is Synced/Healthy.

**v1 -> v2 demo** (rehearse once — it is the core of the defense):

1. In the GitHub repo `itzbw/iot-bwong`, edit `dev/deployment.yaml`:
   `v1` -> `v2`, commit, push.
2. Argo polls every ~3 min — click **Refresh** in the UI to skip the wait.
3. `curl http://localhost:8888/` -> `"message": "v2"`.
4. **Revert to v1, push, confirm curl shows v1 again. Leave it on v1.**

`vagrant destroy -f` before the bonus (it needs the RAM).

### Bonus — GitLab (~45 min, mostly waiting)

```sh
cd ../bonus
vagrant up
vagrant ssh bonus
cd /vagrant/scripts && bash install.sh
exit
vagrant ssh bonus
cd /vagrant/scripts && bash launch.sh     # 15-20 min; save BOTH passwords
```

On the host, add to `/etc/hosts`: `192.168.56.130 gitlab.local`

1. Open `http://gitlab.local`, login `root` + printed password.
2. Create project `iot` under root, **Public**, no README.
3. Push the `dev/` folder to it (only `deployment.yaml` + `service.yaml`,
   image on `v1`). Easiest: GitLab web IDE, or clone
   `http://gitlab.local/root/iot.git` and push with root's password.
4. Check Argo: `kubectl get application -n argocd playground-app`
   -> Synced/Healthy. Argo clones GitLab via the in-cluster address
   (`gitlab-webservice-default.gitlab.svc:8181`), not gitlab.local.
5. `curl http://localhost:8888/` in the VM -> v1.
6. Run the v1 -> v2 -> v1 demo again, editing in GitLab this time.
7. Eval rehearsal: create one extra throwaway repo in GitLab and push a
   file to it — the checklist makes the evaluator do exactly that.

### Before the defense

- `dev/deployment.yaml` on `v1` everywhere (this repo, GitHub, GitLab).
- All VMs destroyed, everything committed and pushed.
