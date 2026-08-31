FROM nginx:1.27-alpine
ENV API_UPSTREAM=http://api:3001
COPY apps/web/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY apps/web/index.html /usr/share/nginx/html/index.html
COPY apps/web/app.js /usr/share/nginx/html/app.js
COPY apps/web/manifest.webmanifest /usr/share/nginx/html/manifest.webmanifest
COPY apps/web/sw.js /usr/share/nginx/html/sw.js
EXPOSE 3000
