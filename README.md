# helm-charts
Helm Charts Repository


Install via the Rancher UI

App>Repositories>

Target > `Git repo`

Git Repo URL: `https://github.com/wiredquill/helm-charts.git`
Branch: `gh-pages`

<img width="1626" height="870" alt="CleanShot 2026-03-06 at 08 49 18" src="https://github.com/user-attachments/assets/69c01931-f5a1-412b-a972-8e7ca8d251a2" />


```
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  # Updated name as requested
  name: wq-charts
spec:
  gitBranch: gh-pages
  gitRepo: https://github.com/wiredquill/helm-charts.git
```
