from sqlalchemy import create_engine
import pandas as pd
from datetime import datetime

class sql_logger:

    sql_file = False
    engine = False
    last_game_id = 0

    def __init__(self, sql_file="crap.db"):

        self.sql_file = sql_file
        self.set_engine()
        self.set_last_game_id()

    def set_engine(self):
        self.engine = create_engine("sqlite:///%s" % self.sql_file)

    def set_last_game_id(self):
        try:
            last_df = pd.read_sql("SELECT last_insert_id FROM table_row_ids", con=self.engine)
            self.last_game_id = last_df.values[0][0]
        except:
            self.save_increment_last_game_id()

    def save_increment_last_game_id(self):
        self.last_game_id  = self.last_game_id + 1
        pd.DataFrame([{"last_insert_id": self.last_game_id}]).to_sql("table_row_ids", con=self.engine, if_exists="replace")

    def log_event(self, event_key = "generic", event_value = "default event", player = "some_player"):

        event = [{
            "game_id":      self.last_game_id,
            "timestamp":    datetime.now().strftime('%Y-%m-%d %H:%M:%S:%f'),
            "event_key":    event_key,
            "event_value":  event_value,
            "player":       player
        }]

        print(event)
        self.set_last_game_id()
        pd.DataFrame(event).to_sql("events", con=self.engine, if_exists="append")

    def get_events(self):

        return pd.read_sql("SELECT * FROM events", con=self.engine)

df_logger = sql_logger(sql_file = "final_test.db")
