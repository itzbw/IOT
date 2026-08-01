# Run vagrant from a part folder — not the repo root.
#   cd p1 && vagrant up   # K3s cluster (2 nodes)
#   cd p2 && vagrant up   # 3 apps + ingress
#   cd p3 && vagrant up   # K3d + Argo CD

raise <<~MSG

  ERROR: No VM defined at the repo root.

  cd into the part you want to test, then run vagrant up:

    cd p1 && vagrant up   # K3s cluster
    cd p2 && vagrant up   # 3 apps + ingress
    cd p3 && vagrant up   # K3d + Argo CD

MSG
