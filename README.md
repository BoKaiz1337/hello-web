# hello-web

第八课作业「CI/CD 部署 · 提交即上线」的产物：一个 nginx 静态页，练的是**发布闭环**，不是页面本身。

线上地址：https://zbk-web.dev.oaiai.ai

## 这一课的重点是第二遍

| 版本 | 页面那行字 | 做了什么 |
| --- | --- | --- |
| v1 | 「第八课第一次发布 —— 这行字是 v1，一会儿我要把它改掉重发一遍。」 | 建镜像 → 推仓库 → 上线 |
| v2 | 「第八课第二次发布 —— 字变了，说明 v2 真的滚上来了。」 | 改一行字 → 重新打包 → 换镜像 → 滚动更新 |

发布不是「我点过了」，是别人能复核的证据链：**来源 → 产物 → 集群状态 → 用户路径**。

## 内容

| 文件 | 作用 |
| --- | --- |
| `index.html` | 那个页面。改的就是里面 `class="line"` 那行字和 `class="ver"` 的版本号 |
| `Dockerfile` | `nginx:alpine` + 把 `index.html` 拷进去，两行 |
| `k8s.yaml` | Deployment `hello-web` / Service / Ingress |
| `.github/workflows/build.yml` | 推 `v*` tag 自动构建推送 |

## 手动发布（课件里走的就是这条）

因为你没有 Runner，就把流水线里那几步手动做一遍：

```bash
# 1. 构建 —— --platform 不能省，集群是 amd64，Mac 可能不是
docker build --platform linux/amd64 \
  -t registry.dev.oaiai.ai/zbk/hello-web:v2 .

# 2. 推送 —— 推完集群才拉得到
docker push registry.dev.oaiai.ai/zbk/hello-web:v2

# 3. 换镜像 —— 控制器自己去滚
kubectl -n st-zbk set image deployment/hello-web \
  web=registry.dev.oaiai.ai/zbk/hello-web:v2

# 4. 等它滚完
kubectl -n st-zbk rollout status deployment/hello-web --timeout=120s

# 5. 核对集群实际用的 tag
kubectl -n st-zbk describe deploy hello-web | grep -i "image:"
```

第 5 步很多人跳过，但它是**唯一能证明「绿灯 ≠ 上线」的那一步**。

## 自动发布（GitHub Actions）

推到 `main` **不发版** —— tag 才是发布按钮：

```bash
git tag v2
git push origin v2
```

## 拉了新的 tag 但没生效？

按失败发生的边界一段段缩小：

| 症状 | 先看哪 |
| --- | --- |
| 没触发 | tag 名匹配不匹配 `v*` |
| 构建失败 | Dockerfile 首行、构建上下文 |
| 推送失败 | Secret、runner 到 registry 的连通性 |
| `ImagePullBackOff` | 镜像真的存在吗 → 仓库/版本写错没 → 命名空间有没有 `regcred` → Deployment 引用没 |
| Actions 全绿但没上线 | **去看部署那步的日志**，是不是被守卫跳过了 |

## 回滚

回到**已知稳定版本**，不要抹掉现场：

```bash
kubectl -n st-zbk rollout undo deployment/hello-web
kubectl -n st-zbk rollout history deployment/hello-web
```

**不要**把镜像改回 `latest`（漂移标签，今天拉到的不一定是昨天那个），
**不要**删 Pod 当修复，**也不要复用已经推过的失败 tag** —— tag 推过就等于发过，
仓库里那个版本已经存在，别人拉到的可能还是旧的坏版本。要修就发新版号。

## 仓库里不该有的东西

镜像仓库口令存在 **GitHub Actions Secret**（`REGISTRY_PASSWORD`），不在任何文件里。
