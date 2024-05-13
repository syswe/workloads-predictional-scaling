FROM alpine:3.6

RUN apk add --no-cache wget coreutils

COPY load_tester.sh /load_tester.sh

RUN chmod +x /load_tester.sh

CMD [ "/bin/sh", "/load_tester.sh" ]
