from flask import Flask, session, request, jsonify
from sqlalchemy import create_engine, func, text, dialects
from datetime import datetime
import sqlalchemy
import pymysql
pymysql.install_as_MySQLdb()
import MySQLdb
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base



# import db_orm as orm
import uuid

app = Flask(__name__)

app.secret_key = 'A0Zr98j/3yX R~XHH!jmN]LWX/,?RT'

def get_dbh():

    db   =   create_engine("mysql://fireplace@localhost:3306/fireplace", echo=True, pool_size=20, max_overflow=10)
    # print("THIS GAR SDFJLDSFJKLJSFKL")
    return db.connect() # connection handler to database

@app.route("/")
def hello():
    return "Hello World!"

@app.route("/create/game")
def create_game_id(methods=['GET', 'POST']):
    # dbh = get_dbh()
    # dbh.merge(orm.User(=item.resource, updated=func.now()))

    game_id = uuid.uuid1()
    print("setting game ID to ", game_id)
    session['game_id'] = game_id
    return jsonify({ "game_id": game_id})

    # dbh.commit()

@app.route("/log")
def log(methods=['GET', 'POST']):

    # session["game_id"] = request.args.get("game_id", "default")
    # test = request.args.get("test", "no set yo")
    print(session)

    data = {
            "game_id"   :    session['game_id'],
            "event_key"  :   request.args.get("event_key"),
            "event_value":   request.args.get("event_value"),
            "player"     :   request.args.get("player"),
            "created"    :   func.sysdate()
    }

    # print("this far")
    sql = """
    INSERT INTO game_events (`game_id`, `player`, `event_key`, `event_value`, `created`)
    VALUES('%s', '%s', '%s', '%s', NOW(6))
    """ % (data['game_id'], data['player'],data['event_key'],data['event_value'])
    # print("this far 2")
    db = get_dbh()
    # print("this far 3")
    sql = text(sql)
    # print("this far 4")
    result = db.execute(sql)
    # print("this far 5")
    print("result from database", result)
    # conn.merge(orm.Event(
    #     game_id     =   session['game_id'],
    #     player      =   request.args.get("player"),
    #     event_key   =   request.args.get("event_key"),
    #     event_value =   request.args.get("event_value"),
    #     created     =   func.now()
    # ))
    # conn.commit()
    db.close()

    return str(session['game_id'])

if __name__ == "__main__":
    app.run()
