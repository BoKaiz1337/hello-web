# 最简镜像：一个 nginx + 一个静态页，没有别的
FROM nginx:alpine

# 课件说「包一个最简镜像（nginx:alpine 就够）」——
# 不用构建工具、不用多阶段，因为没有编译这一步
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
