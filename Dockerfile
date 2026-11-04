FROM intersystemsdc/iris-community:latest

USER root
WORKDIR /opt/irisapp
COPY --chown=irisowner:irisowner . /opt/irisapp
RUN chown -R irisowner:irisowner /opt/irisapp
USER irisowner

RUN iris start IRIS \
 && (iris session IRIS < /opt/irisapp/docker/load.script | tee /tmp/load.log) \
 && ! grep -qi "error" /tmp/load.log \
 && iris stop IRIS quietly

EXPOSE 52773 1972