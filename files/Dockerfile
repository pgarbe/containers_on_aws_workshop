FROM python:alpine
RUN apk update && apk add --no-cache groff less mailcap bash openssh
RUN pip install awscli
ENV AWS_DEFAULT_REGION=eu-west-1

CMD "/bin/bash"