import os
import time
import datetime
import json
from random import gauss

import awsiot.greengrasscoreipc
from awsiot.greengrasscoreipc.model import (
    PublishToIoTCoreRequest,
    QOS,
)

class DummySensor(object):
    def __init__(self, mean=25, variance=1):
        self.mu = mean
        self.sigma = variance

    def read_value(self):
        return float("%.2f" % (gauss(1000, 20)))

TIMEOUT = 10
publish_rate = 0.3

ipc_client = awsiot.greengrasscoreipc.connect()

sensor = DummySensor()

topic = os.environ["TARGET_IOT_TOPIC"]


while True:
    message = {"timestamp": str(datetime.datetime.now()),
               "value": sensor.read_value()}
    message_json = json.dumps(message).encode('utf-8')

    request = PublishToIoTCoreRequest()
    request.topic_name = topic
    request.qos = QOS.AT_LEAST_ONCE
    request.payload = message_json

    operation = ipc_client.new_publish_to_iot_core()
    operation.activate(request)
    future = operation.get_response()
    future.result(TIMEOUT)

    print(f"publish to {topic}")
    print(message)
    time.sleep(1/publish_rate)