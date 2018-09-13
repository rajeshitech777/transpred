# Use an official Python runtime as a parent image
FROM continuumio/miniconda3 AS base

RUN mkdir app
COPY ./requirements.txt /app/requirements.txt
# this is for geopandas
RUN apt-get update && \
apt-get install -y curl && \
apt-get install -y g++ && \
apt-get install -y make && \
curl -L http://download.osgeo.org/libspatialindex/spatialindex-src-1.8.5.tar.gz | tar xz && \
cd spatialindex-src-1.8.5 && \
./configure && \
make && \
make install && \
ldconfig && \
# this is for fastparquet
pip install numpy && \
# Install any needed packages specified in requirements.txt
pip install --trusted-host pypi.python.org -r /app/requirements.txt



FROM base AS stage1

# Set the working directory to /app
WORKDIR /app
#RUN chmod -R 777 /app
# Copy the current directory contents into the container at /app
#ADD ./transpred/clean_and_wrangle_1.py /app/transpred/clean_and_wrangle_1.py
#ADD ./data/cabs/cabs_green.sh /app/data/cabs/cabs_green.sh
#ADD ./data/cabs/cabs_yellow.sh /app/data/cabs/cabs_yellow.sh
#ADD ./data/gas/2018-2008_monthly_gas_NYC.csv /app/data/gas/2018-2008_monthly_gas_NYC.csv
#ADD ./data/traffic/traffic.sh /app/data/traffic/traffic.sh
#ADD ./data/traffic/process_traffic_data.py /app/data/traffic/process_traffic_data.py
#ADD ./data/transit/stations.sh /app/data/transit/stations.sh
#ADD ./data/transit/turnstile.sh /app/data/transit/turnstile.sh
#ADD ./data/weather/1409973.csv /app/data/weather/1409973.csv
#ADD ./bin/get_cab_data.sh /app/bin/get_cab_data.sh
#ADD ./bin/get_traffic_n_process.sh /app/bin/get_traffic_n_process.sh
#ADD ./bin/get_transit_data.sh /app/bin/get_transit_data.sh
#ADD ./bin/get_data.sh /app/bin/get_data.sh
COPY . /app

# Make port 80 available to the world outside this container
#EXPOSE 80

# Define environment variable
# ENV NAME World
#VOLUME /app
#RUN cd bin && \
#./get_data.sh
# Run transpred/clean_and_wrangle_1.py when the container launches
#CMD ["python", "transpred/stations.py"]
#CMD ["python", "transpred/traffic_links.py"]
#CMD ["python", "transpred/cabs.py"]
#CMD ["python", "transpred/clean_and_wrangle_1.py"]
#CMD ["cd", "bin"]
#ENTRYPOINT ["bin/get_data.sh"]
ENTRYPOINT ["ls","bin"]