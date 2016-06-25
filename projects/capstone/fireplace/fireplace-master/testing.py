import requests
from flask import Flask, session, request, jsonify

# $ export FLASK_APP=hello.py
# $ flask run
#  * Running on http://127.0.0.1:5000/

# get/create game id
#
s = requests.Session()
r = s.get("http://localhost:5000/create/game")

json_data = r.json()
# cookies =
# cookies = dict(r.cookies)

# print(response['game_id'])


for game in range(0, 20):

    print("creating game.. %d" % game)

    ss          =   requests.Session()
    r           =   ss.get("http://localhost:5000/create/game")
    response    =   r.json()

    original_cookies = r.cookies

    print("Creating new game: ", response['game_id'])

    for event in range(0, 10):

        print("inserting crap data")

        data = {
            "game_id":   response['game_id'],
            "player":    "playerTEST",
            "event_key": "event_test",
            "event_value": event,
        }

        print("using cookies from previous create game request: ", original_cookies)

        r = ss.get("http://localhost:5000/log?player=123&event_key=234234234", data = data, cookies=original_cookies)
        print("Cookies after request: ", original_cookies)
