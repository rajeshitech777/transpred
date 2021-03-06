#!/bin/bash
cd data/traffic

# redis
# TODO move this to config file
# cluster
#redis_prfx="redis-cluster-m-"
#redis_port='7001'
#redis_cli="redis-cli -c -h $redis_prfx$redis_port -p $redis_port"
# standalone
redis_host='redis'
redis_cli="redis-cli -h $redis_host -p 6379"
#readonly NAME_PREFIX="redis-cluster-m-"
#readonly LOCAL_CONTAINER_ID=$(docker ps -f name="$NAME_PREFIX" -q | head -n 1)
#readonly LOCAL_PORT=$(docker inspect --format='{{index .Config.Labels "com.docker.swarm.service.name"}}' "$LOCAL_CONTAINER_ID" | sed 's|.*-||')
#host_node="$NAME_PREFIX$LOCAL_PORT"
#host_ip=$(docker service inspect -f '{{index .Endpoint.VirtualIPs 1).Addr}}' "$host_node" | sed 's|/.*||')
#redis_cli="docker exec -it \"$LOCAL_CONTAINER_ID\"\
#           redis-cli -c -h \"$host_ip\" -p \"$LOCAL_PORT\""

q1="{tf}:q"
q2="{tf}:p"
chunk_size=60000000
#chunk_size=60
chunks_per_block=5
max_bl_num=20

# check blocks (file block_queue in directory cabs)
# pick next block to fetch (pop first line of block_queue)
while true;do
    block_num=$(echo "RPOPLPUSH $q1 $q2" | ${redis_cli})
    if [[ ! -z "$block_num" ]]
    then
        break
    fi
    sleep 2
done

# for each item in block (total items = 6)
# build url and fetch file (spawn curl in parallel)
# save file in cabs directory
echo "spawning traffic curl processes for block number $block_num"

start_chunk=$(( (block_num-1)*chunks_per_block+1 ))
end_chunk=$(( block_num*chunks_per_block ))
start_byte=$(( (start_chunk-1)*chunk_size ))

if [ "$block_num" -eq "$max_bl_num" ]
then
    (( end=end -1 ))
fi

for chunk_number in $( seq ${start_chunk} ${end_chunk} ); do
    echo "fetching chunk $start_byte to $(( start_byte + chunk_size - 1 ))"
    curl --range $start_byte-$(( start_byte + chunk_size - 1 )) -o traffic_speed.part$chunk_number  https://data.cityofnewyork.us/api/views/i4gi-tjb9/rows.csv?accessType=DOWNLOAD&bom=true&query=select+* &
    echo "spawned traffic data thread "
    (( start_byte = start_byte + chunk_size ))

done

if [ "$block_num" -eq "$max_bl_num" ]
then
    echo "fetching chunk $start_byte to last byte of traffic file"
    curl --range $start_byte- -o traffic_speed.part100  https://data.cityofnewyork.us/api/views/i4gi-tjb9/rows.csv?accessType=DOWNLOAD&bom=true&query=select+* &
    echo "spawned traffic data thread 100"
fi


echo "spawned traffic data threads for $block_num"

wait

# block finished , remove from processing queue
echo "LREM $q2 1 \"$block_num\"" | ${redis_cli}

echo "fetched block for $block_num"