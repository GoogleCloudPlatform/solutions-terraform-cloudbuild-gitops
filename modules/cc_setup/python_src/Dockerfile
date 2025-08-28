FROM python:3.12-alpine
COPY ./src /src
WORKDIR /src
RUN pip3 install -r requirements.txt
ENTRYPOINT ["python3", "cc_workload.py"]
LABEL "tee.launch_policy.allow_cmd_override"="true"
# LABEL "tee.launch_policy.log_redirect"="always"
CMD []