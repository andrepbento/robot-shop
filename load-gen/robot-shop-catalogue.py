import random
from listeners import init_csv_file, request_event_listener

from locust import FastHttpUser, task, constant_throughput, events

class UserBehavior(FastHttpUser):
    wait_time = constant_throughput(1)

    # source: https://tools.tracemyip.org/search--ip/list
    fake_ip_addresses = [
        # white house
        "156.33.241.5",
        # Hollywood
        "34.196.93.245",
        # Chicago
        "98.142.103.241",
        # Los Angeles
        "192.241.230.151",
        # Berlin
        "46.114.35.116",
        # Singapore
        "52.77.99.130",
        # Sydney
        "60.242.161.215"
    ]

    def on_start(self):
        init_csv_file()

    @task
    def load(self):
        fake_ip = random.choice(self.fake_ip_addresses)

        self.client.get('/api/catalogue/products', headers={'x-forwarded-for': fake_ip})

    @events.request.add_listener
    def on_request(context, **kwargs):
        request_event_listener(context, **kwargs)
