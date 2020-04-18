from Services.FlyzooChat import FlyzooChat
import cProfile
import time

sam_chat = FlyzooChat()

while(True):
    sam_chat.refresh()
    time.sleep(2)