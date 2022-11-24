import locust
import os

import locust.stats

header='timestamp,workflow,load,name,request_type,response_time,status_code'
filename=os.environ['OUT']

def init_csv_file():
    print("implement init_csv_file() method")
    #filesize = 0
    #if(os.path.exists(filename) and os.path.isfile(filename)):
    #    filesize = os.stat(filename).st_size
    #
    #f = open(filename, 'a')
    #if(filesize == 0):
    #    f.write(f'{header}\n')


def request_event_listener(context, **kwargs):
    f = open(filename, 'a')
    start_time = kwargs["start_time"]
    workflow = os.environ['WORKFLOW']
    load = os.environ["LOAD"]
    name = kwargs["name"]
    request_type = kwargs["request_type"]
    response_time = kwargs["response_time"]
    status_code = kwargs["response"].status_code
    line = f"{start_time},{workflow},{load},{name},{request_type},{response_time},{status_code}\n"
    f.write(line)
    f.close()

    #print("context", context)
    #print("kwargs", kwargs)
    #print("request_type", kwargs["request_type"])
    #print("name", kwargs["name"])
    #print("response_time", kwargs["response_time"])
    #print("response_length", kwargs["response_length"])
    #print("response", kwargs["response"])
    #print("exception", kwargs["exception"])
    #print("start_time", )
    #print("url", kwargs["url"])
    #print("request_type", kwargs["request_type"])

