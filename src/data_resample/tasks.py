from typing import Dict, List, Callable, Union, Optional
import pandas as pd
import dask.dataframe as dd
from data_tools import task_map
from utils import persistence as ps
from functools import reduce, partial
from data_load import tasks as dl_tasks
from toolz.functoolz import compose

resample_map: Dict = {
                        'filter_by': {
                            'key': 'weekday',
                            'value': 2
                        },
                        'freq': '1M'
                    }
prefix_zero = lambda x: "0" + str(x) if x < 10 else str(x)


def make_cabs(cab_type: str,*args) -> List[str]:
    task_type: str = ''
    if cab_type == 'green':
        task_type = 'cl-gcabs'
    elif cab_type == 'yellow':
        task_type = 'cl-ycabs'

    if not task_type == '':
        map: Dict = task_map.task_type_map[task_type]
        out_bucket: str = map['out']
        ps.create_bucket(out_bucket)
        return dl_tasks.make_cabs(*args)
    else:
        return []


def make_transit(*args) -> List[str]:
    map: Dict = task_map.task_type_map['cl-transit']
    out_bucket: str = map['out']
    ps.create_bucket(out_bucket)
    return dl_tasks.make_transit(*args)


def make_traffic(*args) -> List[str]:
    map: Dict = task_map.task_type_map['cl-traffic']
    out_bucket: str = map['out']
    ps.create_bucket(out_bucket)
    return dl_tasks.make_traffic(*args)


def remove_outliers(df, cols: List[str]):
    intqrange: List[float] = [df[col].quantile(0.75) - df[col].quantile(0.25) for col in cols]
    discard_map = lambda reduced_discard, enum_col: reduced_discard | (df[enum_col[1]] < 0) | (df[enum_col[1]] > 3 * intqrange[enum_col[0]])
    discard = reduce(discard_map, enumerate(cols), [False for _ in range(df.size)])
    return df.loc[~discard]



def perform(task_type: str) -> bool:
    task_type_map: Dict = task_map.task_type_map[task_type]
    in_bucket: str = task_type_map['in']
    out_bucket: str = task_type_map['out']
    #cols: Dict[str, str] = task_type_map['cols']
    date_cols: List[str] = task_type_map['date_cols']
    diff: Dict = task_type_map['diff']
    group: Dict = task_type_map['group']
    filter_by_key: str = resample_map['filter_by']['key']
    filter_by_val: int = resample_map['filter_by']['value']
    resample_freq: str = resample_map['freq']
    aggr_func: Callable = task_type_map['aggr_func']


    dtypes: Dict[str, str] = task_type_map['dtypes']
    index_col: str = task_type_map['index']['col']
    s3_options: Dict = ps.fetch_s3_options()

    try:

            s3_in_url: str = 's3://' + in_bucket + '/*.*'
            df = dd.read_csv(urlpath=s3_in_url,
                               storage_options=s3_options,
                               header=0,
                               skipinitialspace=True,
                               parse_dates=date_cols,
                               encoding='utf-8'
                               )


            df = df.set_index(index_col, sorted=True)
            print('after set index ')

            if diff['compute']:
                df[diff['new_cols']] = df[diff['cols']].diff()

            # specific processing for transit
            if task_type == 'rs-transit':
                df = df.map_partitions(partial(remove_outliers, cols=diff['new_cols']), meta=dtypes)

            # filter
            if filter_by_key == 'weekday':
                df = df.loc[df[index_col].dt.weekday == filter_by_val]

            if group['compute']:
                grouper_cols = group['by_cols']
            else:
                grouper_cols = []

            # resample using frequency and aggregate function specified
            #df = compose(df.resample(resample_freq), aggr_func)
            df = compose(df.groupby([pd.Grouper(resample_freq)]+grouper_cols), aggr_func)

            df = df.unstack().reset_index()

            # save in out bucket
            s3_out_url: str = 's3://' + out_bucket + '/turnstile-*.csv'
            df.to_csv(s3_out_url)

    except Exception as err:
        print('error in perform_cabs %s' % str(err))
        raise err

    return True



