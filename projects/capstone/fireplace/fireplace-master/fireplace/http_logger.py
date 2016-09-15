import requests

class http_logger:

    current_game_id = 0
    cookies = False

    def __init__(self):

        self.set_new_game()

    def get_http_json(self, url):

        ss              =   requests.Session()
        r               =   ss.get(url)
        self.cookies    =   r.cookies

        return r.json()

    def set_new_game(self):

        response = self.get_http_json("http://localhost:5000/create/game")
        self.current_game_id = response['game_id']

        print("Creating new game: ", response['game_id'])

    def set_current_game_id(self):
        response = self.get_http_json("http://localhost:5000/get/session")
        self.current_game_id = response['game_id']

    def log_event(self, event_key = "generic", event_value = "default event", player = "some_player"):
        #response = self.get_http_json("http://localhost:5000/get/session")
        data = {
            "game_id":      self.current_game_id,
            "event_key":    event_key,
            "event_value":  event_value,
            "player":       player,
        }
        if "'" in event_value:
            event_value = event_value.replace("'", '')
        r = requests.Session().get("http://localhost:5000/log?player=%s&event_key=%s&event_value=%s" % (player, event_key, str(event_value)), data = data, cookies=self.cookies)


df_logger = http_logger()
