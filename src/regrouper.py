import pandas as pd
import sys
from data_tools import task_map
from typing import List
from utils import persistence as ps
from urllib3.response import HTTPResponse
from s3fs import S3FileSystem as s3fs


def regroup(task_type: str) -> bool:
    try:
        # determine in and out buckets
        # and split_by from task type map
        in_bucket: str = task_map.task_type_map[task_type]['in']
        out_bucket: str = task_map.task_type_map[task_type]['out']
        split_by: List[str] = task_map.task_type_map[task_type]['split_by']

        # read files from in bucket and concat into one df
        filestreams: List[HTTPResponse] = ps.get_all_filestreams(bucket=in_bucket)
        df = pd.concat([pd.read_csv(stream, encoding='utf-8') for stream in filestreams], ignore_index=True)

        # group by split_by and write each group to a separate file
        s3: s3fs = ps.get_s3fs_client()
        # create out bucket
        ps.create_bucket(out_bucket)
        for name, group in df.groupby(split_by):
            filename: str = name
            group.to_csv(s3.open('s3://'+out_bucket+'/'+filename, 'w'))

    except Exception as err:
        print('Error: %(error)s in regrouper for task_type %(task)s' % {'error': err, 'task': task_type})
        raise err

    return True


if __name__ == 'main':
    task_type: str = sys.argv[1]
    print('regrouping for task type %s' % task_type)
    status: bool = regroup(task_type)