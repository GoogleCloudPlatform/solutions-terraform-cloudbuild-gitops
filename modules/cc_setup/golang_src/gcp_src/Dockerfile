FROM alpine:latest

WORKDIR /test

COPY cc_workload /test

ENTRYPOINT ["/test/cc_workload"]

LABEL "tee.launch_policy.allow_cmd_override"="true"

CMD []