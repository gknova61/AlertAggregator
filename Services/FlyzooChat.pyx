import service_creds
import hashlib

from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from playsound import playsound
import NotifyDaemon
import time
import pygame
from gtts import gTTS
import pyttsx3
import io

cdef dict whitelisted_users = {
            'keanukc': {
                'settings': {'say_user': True, 'say_keyword': True, 'say_name_on_keyword_match': False},
                'keywords': ['twitter', 'tweetdeck', 'trading']
            },

            'smartertrader': {
                'settings': {'say_user': True, 'say_keyword': True, 'say_name_on_keyword_match': True},
                'keywords': ['aet ', ' at ', 'ate ', 'sodl', 'sold', 'acct']
            },

            'Chubs': {
                'settings': {'say_user': True, 'say_keyword': True, 'say_name_on_keyword_match': True},
                'keywords': ['aet ', ' at ', '@', 'ate ', 'sodl', 'sold', 'acct']
            },

            'AnthonyOhayon': {
                'settings': {'say_user': False, 'say_keyword': True, 'say_name_on_keyword_match': True},
                'keywords': ['aet ', ' at ', '@', 'ate ', 'sodl', 'sold', 'acct', 'are ']
            },

            'GeoTrader': {
                'settings':{'say_user': False, 'say_keyword': True, 'say_name_on_keyword_match': True},
                'keywords':[' at ', '@ ', 'sold ', 'sell ']
            }
}

'''
'ephraim_sng': {
    'settings':{'say_user': False, 'say_keyword': True, 'say_name_on_keyword_match': False},
    'keywords':[' at ', '@ ', 'sold ', 'sell ']
},

'Funjohn': {
    'settings':{'say_user': False, 'say_keyword': True, 'say_name_on_keyword_match': False},
    'keywords':[' at ', '@ ', 'sold ', 'sell ']
}            
'''


class FlyzooChat:

    def __init__(self):
        self._voice_engine = pyttsx3.init()

        self._browser_options = Options()
        self._browser_options.add_argument("window-size=1920,1080")
        self._browser_driver = webdriver.Chrome(options=self._browser_options)

        self._window_info = self._init_chat(self._browser_driver)

        main_window_handle = self._window_info["main_window_handle"]
        popup_window_handle = self._window_info["popup_window_handle"]

        pygame.mixer.init()  # Initialize the mixer module.
        # keyword_match_sound = pygame.mixer.Sound('../sounds/user_posted_with_keyword_match.mp3')  # Load a sound.
        # user_posted_sound = pygame.mixer.Sound('../sounds/user_posted.mp3')  # Load a sound.
        self._last_message_hash = ''

        self.refresh(first_run=True)

    def _wait_for_popup(self, driver, main_window_handle):
        current_handles = self._browser_driver.window_handles
        while(self._browser_driver.window_handles == current_handles):
            time.sleep(1)

        for handle in self._browser_driver.window_handles:
            if handle not in current_handles:
                time.sleep(1)
                try:
                    alert = driver.switch_to.alert
                    if alert.is_displayed():
                        alert.accept()
                        driver.switch_to_window(handle)
                        driver.close()
                        driver.switch_to_window(main_window_handle)
                        print("Error getting chat window, trying again")
                        self._wait_for_popup(driver,main_window_handle)
                except:
                    pass

                return handle

        raise Exception("Something went wrong in wait_for_popup function")

    def _init_chat(self, driver):
        self._browser_driver.get(service_creds.flyzoo.login_url)

        self._browser_driver.find_element_by_id('user_login').send_keys(service_creds.flyzoo.username)
        self._browser_driver.find_element_by_id('user_pass').send_keys(service_creds.flyzoo.password)

        self._browser_driver.find_element_by_id('rememberme').click()
        self._browser_driver.find_element_by_id('wp-submit').click()

        print("Waiting for popup")
        main_window_handle = self._browser_driver.current_window_handle

        popup_window_handle = self._wait_for_popup(driver,main_window_handle)
        self._browser_driver.close()

        self._browser_driver.switch_to.window(popup_window_handle)

        time.sleep(4)
        return {"main_window_handle":main_window_handle,"popup_window_handle":popup_window_handle}

    def say(self,text, lang='en'):
        """ Speak the provided text.
        """
        tts = gTTS(text=text, lang=lang, slow=False)
        pygame.mixer.init()
        pygame.init()  # this is needed for pygame.event.* and needs to be called after mixer.init() otherwise no sound is played
        with io.BytesIO() as f: # use a memory stream
            tts.write_to_fp(f)
            f.seek(0)
            pygame.mixer.music.load(f)
            pygame.mixer.music.set_endevent(pygame.USEREVENT)
            pygame.event.set_allowed(pygame.USEREVENT)
            pygame.mixer.music.play()
            pygame.event.wait() # play() is asynchronous. This wait forces the speaking to be finished before closing f and returning

    def say_offline(self,text):
        print("initing voice")
        self._voice_engine.say(text)
        self._voice_engine.runAndWait()
        print("Said voice")

    def refresh(self,bint first_run=False,bint notify_only=False):
        cpdef str hash = ''

        cpdef bint play_posted = False
        cpdef bint play_keyword_match = False
        cpdef bint last_message_hash_hit = False
        cpdef str notify_username = ''
        cpdef str notify_user_message = ''

        print("getting chat entries")
        chat_entries = self._browser_driver.find_elements_by_class_name("line-layout-row")
        print("Iterating {} chat entries".format(len(chat_entries)))

        cpdef str username
        cpdef str message
        cpdef str notification

        if len(chat_entries) > 30:
            print("REFRESHING")
            self._browser_driver.refresh()

        for i in range(0, len(chat_entries)):
            chat = chat_entries[i]
            username = chat.text[:chat.text.find(': ')]
            message = chat.text[chat.text.find(': ') + 2:]
            hash = hashlib.md5((username + message).encode('utf-8')).hexdigest()

            if last_message_hash_hit or first_run:
                if not play_keyword_match:
                    if username in whitelisted_users:
                        # log post
                        if whitelisted_users[username]['settings']['say_user']:
                            play_posted = True

                        notify_username = username
                        notify_user_message = message

                        for keyword in whitelisted_users[username]['keywords']:
                            if keyword in message.lower():
                                if whitelisted_users[username]['settings']['say_keyword']:
                                    play_keyword_match = True
                                notify_username = username
                                notify_user_message = message
                                break

            if hash == self._last_message_hash:
                last_message_hash_hit = True
        print("Finished iterating")

        self._last_message_hash = hash

        notification = notify_username + ": " + notify_user_message
        if play_keyword_match:
            NotifyDaemon.notify({"service": "sam_chat",
                                 "title": "Keyword Match Found",
                                 "message": notification})
            if not notify_only:
                # keyword_match_sound.play()
                print("{}: Keyword Match Found".format(datetime.now().strftime("%H:%M:%S")))
                print(notification)
                print()
                if whitelisted_users[notify_username]['settings']['say_name_on_keyword_match']:
                    self.say_offline('Keyword match found from ' + notify_username)
                else:
                    self.say_offline('Keyword match found')
                self.say_offline(notify_user_message)
        elif play_posted:
            NotifyDaemon.notify({"service":"sam_chat",
                                 "title":"User Posted",
                                 "message":notification})
            if not notify_only:
                # user_posted_sound.play()
                print("{}: User Posted".format(datetime.now().strftime("%H:%M:%S")))
                print()
                self.say_offline('User Posted')
                # playsound('../sounds/user_posted_with_keyword_match.mp3')

            # TODO: Send Notification


    def kill(self):
        self._browser_driver.close()