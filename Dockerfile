FROM mmochizuki/ubuntu-ml-base:v0.4

USER root
ENV DEBIAN_FRONTEND=noninteractive 

RUN apt-get update && \
    apt-get install -y g++ \
    libeigen3-dev libcairo2-dev \
    postgresql-10 postgresql-server-dev-10

COPY pg_hba.conf /etc/postgresql/10/main/

WORKDIR /tmp

COPY requirements.txt .
RUN pip install -r requirements.txt

ENV RDKIT_VERSION 2019_03_1
RUN wget -q https://github.com/rdkit/rdkit/archive/Release_$RDKIT_VERSION.tar.gz  && \
    tar xf Release_$RDKIT_VERSION.tar.gz
ENV RDBASE=/tmp/rdkit-Release_$RDKIT_VERSION
ENV PYTHONPATH=$RDBASE
RUN echo $LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$RDBASE/lib:$LD_LIBRARY_PATH
ENV PostgreSQL_ROOT=/usr

WORKDIR $RDBASE
RUN mkdir build
WORKDIR build
RUN cmake .. -DPYTHON_EXECUTABLE="/usr/bin/python3" -DRDK_BUILD_PGSQL=ON -DRDK_BUILD_CAIRO_SUPPORT=ON -DRDK_BUILD_INCHI_SUPPORT=ON -DRDK_BUILD_AVALON_SUPPORT=ON 

RUN make -j$(nproc) && make install

RUN service postgresql start && su --login postgres --command "createuser -w -s root" && \
    sh Code/PgSQL/rdkit/pgsql_install.sh && sh Code/PgSQL/rdkit/pgsql_regress.sh && ctest -j4 && \
    service postgresql stop

RUN echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER user
RUN sudo service postgresql start && sudo su --login postgres --command "createuser -w -s user" && \
    createdb && sudo service postgresql stop
WORKDIR /home/user/

WORKDIR /home/user/work
COPY startup.sh .
CMD ["bash", "startup.sh"]
