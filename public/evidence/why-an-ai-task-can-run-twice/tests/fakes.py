from collections import deque
from uuid import uuid4

from src.common.messages import Delivery


class MemoryQueue:
    """Policy double only: deliberately does not simulate broker visibility."""

    def __init__(self):
        self.visible = deque()
        self.dlq = []
        self.received = []
        self.fail_send = False
        self.fail_complete = False

    async def send(self, content, *, dead_letter=False):
        if self.fail_send:
            raise OSError("injected publication outage")
        if dead_letter:
            self.dlq.append(content)
        else:
            self.visible.append(Delivery(str(uuid4()), "receipt", content, 1))

    async def receive(self):
        if not self.visible:
            return None
        item = self.visible.popleft()
        self.received.append(item)
        return item

    async def complete(self, item):
        if self.fail_complete:
            self.fail_complete = False
            raise OSError("injected ack loss")

    async def nack(self, item, delay=0):
        item.count += 1
        self.visible.append(item)

    def redeliver(self):
        item = self.received[-1]
        item.count += 1
        self.visible.append(item)
