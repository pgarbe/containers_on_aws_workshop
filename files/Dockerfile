FROM python:alpine
RUN apk update && apk add --no-cache groff less mailcap bash openssh
RUN pip install awscli

CMD "/bin/bash"