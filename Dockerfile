# cgroup v2 노드용 isolate 2.x. 기본 이미지의 Debian 10 헤더로는 빌드되지 않아 정적 빌드한 바이너리만 복사한다.
FROM debian:bookworm-slim AS isolate-v2-build
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates gcc git libc6-dev libcap-dev libseccomp-dev make && \
    git clone --depth 1 --branch v2.7 https://github.com/ioi/isolate.git /tmp/isolate && \
    make -C /tmp/isolate isolate CONFIG=/usr/local/etc/isolate-v2 CFLAGS_HARDEN= LDFLAGS_HARDEN=-static && \
    install -m 4755 /tmp/isolate/isolate /isolate-v2

FROM judge0/compilers:1.4.0 AS production

ENV JUDGE0_HOMEPAGE "https://judge0.com"
LABEL homepage=$JUDGE0_HOMEPAGE

ENV JUDGE0_SOURCE_CODE "https://github.com/judge0/judge0"
LABEL source_code=$JUDGE0_SOURCE_CODE

ENV JUDGE0_MAINTAINER "Herman Zvonimir Došilović <hermanz.dosilovic@gmail.com>"
LABEL maintainer=$JUDGE0_MAINTAINER

ENV PATH "/usr/local/ruby-2.7.0/bin:/opt/.gem/bin:$PATH"
ENV GEM_HOME "/opt/.gem/"

# The compilers:1.4.0 image uses Debian 10 (buster), now hosted in the archive.
RUN sed -i \
      -e 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' \
      -e 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' \
      /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends \
      cron \
      libpq-dev \
      sudo && \
    rm -rf /var/lib/apt/lists/* && \
    echo "gem: --no-document" > /root/.gemrc && \
    gem install bundler:2.1.4 && \
    npm install -g --unsafe-perm aglio@2.3.0

# 실행 시 scripts/isolate-compat가 cgroup 버전에 맞는 isolate를 고른다.
COPY --from=isolate-v2-build /isolate-v2 /usr/local/bin/isolate-v2
RUN chmod 4755 /usr/local/bin/isolate-v2 && \
    mv /usr/local/bin/isolate /usr/local/bin/isolate-v1 && \
    printf 'box_root = /var/local/lib/isolate\ncg_root = /sys/fs/cgroup/isolate\nfirst_uid = 60000\nfirst_gid = 60000\nnum_boxes = 2147483647\nlock_root = /run/isolate/locks\n' > /usr/local/etc/isolate-v2

EXPOSE 2358

WORKDIR /api

COPY Gemfile* ./
RUN RAILS_ENV=production bundle

COPY cron /etc/cron.d
RUN cat /etc/cron.d/* | crontab -

COPY . .
RUN install -m 0755 /api/scripts/isolate-compat /usr/local/bin/isolate

ENTRYPOINT ["/api/docker-entrypoint.sh"]
CMD ["/api/scripts/server"]

RUN useradd -u 1000 -m -r judge0 && \
    echo "judge0 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
    chown judge0: /api/tmp/

USER judge0

ENV JUDGE0_VERSION "1.13.1"
LABEL version=$JUDGE0_VERSION


FROM production AS development

CMD ["sleep", "infinity"]
