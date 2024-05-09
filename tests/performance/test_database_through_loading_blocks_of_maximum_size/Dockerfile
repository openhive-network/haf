FROM registry.gitlab.syncad.com/hive/haf/base_instance:55c0ca89fd8fa92c3f503e88f1a085bd782760ed

RUN sudo cp /home/hived_admin/hive_base_config/faketime/src/libfaketime.so.1 /usr/local/lib
RUN cd /home/haf_admin/source && python3 -m venv haf_venv && source haf_venv/bin/activate && cd /home/haf_admin/source/tests/integration/haf-local-tools && poetry install
RUN pip install requests

CMD ["/bin/bash"]
