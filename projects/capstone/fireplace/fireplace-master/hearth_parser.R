library(data.table)
library(lubridate)
library(dplyr)
library(tidyr)
library(magrittr)
library(readr)
library(zoo)
library(lazyeval)


options(digits.secs = 6);

widened_pieces = list()


for (i in 1:250) {
  print('-----------------------------------------')
  print(i)
  partial = read_delim(paste0('./alec_capstone/datasets_split/',paste0('split',i,'.csv')), delim=';', 
                       col_names=c('event_id','game_id','player','event_key','event_value',
                                   'timestamp','updated'))
  partial = data.table(partial)
  partial = partial[, updated := NULL]
  partial = partial[, timestamp := NULL]
  partial = partial[, event_id := as.integer(event_id)]
  
  partial = hearthstone_munger(partial)
  
  # if (uniquecols == 0) {
  #   uniquecols = partial[[2]]
  # } else {
  #   uniquecols = rbindlist(list(uniquecols, partial[[2]]), use.names = T)
  #   uniquecols = uniquecols[!duplicated(uniquecols)]
  # }
  # print(dim(uniquecols))
  
  #partial = partial[[1]]
  save(partial, file=paste0('./alec_capstone/widened_pieces/', paste0('wide',i,'.RData')))
  
  #if (i < 6) {
  #  widened_pieces[[i]] = partial
  #}
  # if (i == 5) {
  #   hs = rbindlist(widened_pieces, use.names=T, fill=T)
  #   hs[is.na(hs)] <- 0
  #   write.csv(hs, file='./alec_capstone/bind15_game.csv', row.names=F)
  #   #print(length(widened_pieces))
  #   #remove(widened_pieces)
  # }
  
  remove(partial)
}



# Forward fills NA values in a column
forward_carrier = function(x) {
  # na.locf is part of the "zoo" package if you're interested
  return(na.locf(x, na.rm=F, fromLast=F))
}



# unique_cards = c('hero')
# 
# for (i in seq(1150)) {
#   print('-----------------------------------------')
#   print(i)
#   partial = read_delim(paste0('./alec_capstone/datasets_split/',paste0('split',i,'.csv')), delim=';', 
#                        col_names=c('event_id','game_id','player','event_key','event_value',
#                                    'timestamp','updated'))
#   partial = data.table(partial)
#   partial = partial[, updated := NULL]
#   partial = partial[, timestamp := NULL]
#   partial = partial[, event_id := as.integer(event_id)]
#   
#   unique_cards = unique(c(unique_cards, get_unique_cards(partial)))
#   print(length(unique_cards))
#   
#   remove(partial)
# }


# get_unique_cards = function(hs) {
#   hs = hs %>%
#     select(event_key, event_value) %>%
#     mutate(event_key = tolower(event_key)) %>%
#     mutate(event_value = tolower(event_value)) %>%
#     filter(event_key %in% c('deck', 'board_state')) %>%
#     mutate(event_value = strsplit(gsub("'","",
#                                        gsub(',',"'",
#                                             gsub('[',"",
#                                                  gsub(']',"",event_value, 
#                                                       fixed=T), fixed=T), fixed=T), fixed=T), " ")) %>%
#     unnest(event_value) %>%
#     filter(!(event_value %in% c('[',', ',']'))) %>%
#     mutate(event_value = replace(event_value, event_value=='[]', 'NA'))
#   
#   cards = unique(hs$event_value)
#   return(cards)
# }


# main function to parse data
hearthstone_munger = function(hs) {
  
  # hs is the raw csv of data
  
  # the "pipe" operator: %>%
  # puts data through different transformations, and after each one it gets
  # sent to the next. It's like Pipeline in sklearn but way better
  
  # modifying the csv through the first piping system. This converts
  # columns to lowercase.
  #
  # The mutate function is the function to create a new variable (or replace
  # a variable) inside the dataframe
  hs = hs %>%
    mutate(event_key = tolower(event_key)) %>%
    mutate(event_value = tolower(event_value)) %>%
    mutate(player = tolower(player))
  
  print('Make player event number...')
  # We're going to make the player event number, which will essentially
  # be the event_id but for each player specifically, starting at 1.
  #
  # arrange() is just a sorting function, so this sorts hs by game_id, 
  # player, and event_id, in that order. It's like .sort_values() in pandas.
  #
  # group_by() is like the .groupby() operator in pandas (but.. better.)
  # here we are grouping by game_id and player
  # You don't have to write some apply function or whatever, it just knows
  # that the things coming after it (here the mutate command) will be done
  # on each group individually before the ungroup(), which puts the groups
  # back together.
  hs = hs %>%
    arrange(game_id, player, event_id) %>%
    group_by(game_id, player) %>%
    mutate(player_event_num = seq(n())) %>%
    ungroup()
  
  
  print('Make game turns...')
  # Here we make the game turns. Players switch off turns and we want to keep track
  # of what turn it is because these are going to be the rows in our final dataset.
  #
  # I make a new dataframe that I'm going to join to the original dataframe. This new
  # dataframe is just going to have event_id, player, game_id, and a new variable
  # game_turn.
  #
  # First, group by game_id and player. On each of those groups:
  # 1. filter() the internal group to just be where event_key == 'turn_begins'. 
  #    filter is a way to select the specific rows of the dataframe you want.
  # 2. create the variable game_turn, which is just the event_value at turn_begins rows.
  # 3. select(one_of(c(...))) lets me select the columns i want, which i mentioned above,
  #    from these specific filtered rows.
  to_join = hs %>%
    group_by(game_id, player) %>%
    filter(event_key == 'turn_begins') %>%
    mutate(game_turn = event_value) %>%
    select(one_of(c('event_id','player','game_id', 'game_turn'))) %>%
    ungroup()
  
  # join this small dataframe with the game_turn column back onto the 
  # hs dataframe, joining on event_id, player, and game_id.
  #
  # joining on those allows it to match the game_turn column exactly
  # to where it matches the event_id, player, and game_id in the original.
  hs = hs %>%
    left_join(to_join, by=c('event_id','player','game_id'))
  
  # We have a problem though, which is that the game_turn column is NA
  # every place where the event_key is not "turn_begins".
  #
  # So, i group by game_id and player, then sort those groups by event_id.
  # At this point i use the na.locf() function to first send values forward
  # filling in the NA values. Then set fromLast=T to send the values backwards
  # filling in NA values (the backwards fill is to fill in the NA values that
  # are in turn 1/2 that happened before the turn_begins row.)
  hs = hs %>%
    group_by(game_id, player) %>%
    arrange(event_id) %>%
    mutate(game_turn = na.locf(game_turn, na.rm=F)) %>%
    mutate(game_turn = na.locf(game_turn, fromLast=T, na.rm=F)) %>%
    mutate(game_turn = as.numeric(game_turn)) %>%
    ungroup()
  
  
  print('Identify first player and winning player...')
  # Now i set a column that identifies if the player is the first player. This is
  # pretty easy, i just group by the game_id and the player, then say
  # "if there is a 1 in the game_turn column, make first_player 1 else make
  # first_player 0"
  hs = hs %>% 
    group_by(game_id, player) %>%
    mutate(first_player = as.numeric(ifelse(1 %in% game_turn, 1, 0))) %>%
    ungroup()
  
  
  # This is similar to the logic for first player. I group by game_id and player, 
  # then say "if there is a "lost" in the event key, then check if the game_turn
  # is the penultimate turn (cuz of that weird bug). If both are met, the player lost.
  # otherwise the player won. If there isn't a lost key at all in event_key, the player
  # won."
  #
  # I also make sure there are two unique values of won per game.
  hs = hs %>%
    group_by(game_id, player) %>%
    mutate(player_won = as.numeric(ifelse(('lost' %in% event_key),
                                          ifelse((game_turn == max(game_turn) -1),
                                                 0, 1), 0))) %>%
    ungroup() %>%
    group_by(game_id) %>%
    filter(length(unique(player_won)) == 2) %>%
    ungroup()
  
  
  # This section changes the player class event_key to be either "player_class" or
  # "enemy_class".
  # I actually think this might just make them all "player_class", since I don't think
  # that the other player's class ever appears in one player's rows, but i still
  # need to make player1_class and player2_class into just player_class anyways.
  #
  # It could in this case just change player1_class to player_class and player2_class
  # to player_class as well, but I'm not gonna change it right now. Would have to
  # make sure that the other player's class actually doesn't appear in their rows.
  # print('Parse player class...')
  # hs = hs %>%
  #   group_by(game_id) %>%
  #   mutate(event_key = ifelse(event_key == 'player1_class',
  #                             ifelse(player == 'player1', 'player_class', 'enemy_class'),
  #                             ifelse(event_key == 'player2_class',
  #                                    ifelse(player == 'player2', 'player_class','enemy_class'),
  #                                    event_key))) %>%
  #   ungroup()
  
  # new version:
  hs = hs %>%
    group_by(game_id) %>%
    mutate(event_key = ifelse(event_key %in% c('player1_class', 'player2_class'), 'player_class',
                              event_key)) %>%
    ungroup()
  
  # This is a list of uneccessary keys that I will remove, because we have this
  # information elsewhere.
  keys_to_remove = c('player2_class','player1_class','first_player','turn_begins',
                     'turn_end', 'lost')
  
  # just filter hs to be all the keys that arent the keys above.
  hs = hs %>%
    filter(!(event_key %in% keys_to_remove))
  
  
  print('Unlist the card-type event_values...')
  # Here is the big bad function, that will unlist the card related values. I'll go through
  # piece by piece within the pipe for clarity. This is assigned to a new 'hs_listev' dataframe
  # that is just the card ones.
  hs_listev = hs %>% 
    # 1. filter for just the card/list related event_keys
    filter(event_key %in% c('deck', 'cards_mulliganed', 'cards_kept', 'discover_choices',
                            'hand', 'mulligan_choices', 'board_state','attack')) %>%
    # 2. Remove characters ' , [ ] 
    mutate(event_value = strsplit(gsub("'|,|\\[|\\]","",event_value), " ")) %>%
    # 3. unnest() is the dplyr command that takes the column with list cells and converts each
    #    list element to individual row.
    unnest(event_value) %>%
    # 4. Remove any rows that are bad. The first three should already be removed but i still
    #    need to take out space and 'attacks', which is the middle of the attack event_key cells
    #    in event_value
    filter(!(event_value == 'attacks')) %>%
    # 5. make any empty cells into a string NA (not a real NA)
    mutate(event_value = replace(event_value, event_value=='', 'NA')) %>%
    # 6. the attack cells have different suffixes for different heros, but we already have this
    #    info in the player_class, so we can remove the suffixes
    mutate(event_value = ifelse((event_key == 'attack') & (startsWith(event_value, 'hero')),
                                'hero', event_value)) %>%
    # 7. group by game, player, player event. This one is a BIT tricky, but essentially
    #    it is saying if the event_key is "attack" and the row number of the current
    #    group, defined by the event_key (within game, player) is 1, then this is the
    #    attacker. Otherwise this is the target. And finally, if none of those conditions
    #    are true just leave the event_key alone.
    group_by(game_id, player, player_event_num) %>%
    mutate(event_key = ifelse((event_key == 'attack') & (row_number(event_key) == 1),
                              'attacker',
                              ifelse(event_key == 'attack', 'target', event_key))) %>%
    ungroup() 
  
  
  # join the list and non-list key datasets
  # The expanded card dataframe and the original dataframe without the card keys get
  # merged together vertically using bind_rows()
  hs = hs %>%
    filter(!(event_key %in% c('deck', 'cards_mulliganed', 'cards_kept', 'discover_choices',
                              'hand', 'mulligan_choices', 'board_state', 'attack'))) %>%
    bind_rows(hs_listev)
  
  remove(hs_listev)
  
  # make value col for the event_value subkey
  # This value column, which i am going to call indicator_value, will have the value
  # for the event_keys. This is different than the event_values we had before, which
  # had string cards and also numbers. This new column will only have numbers - either
  # stuff like mana number or whether the event happend and how often per turn.
  #
  # 1. rename the event_value column to "indicator_column"
  # 2. sort by game_id, player, game_turn, event_key, indicator_column (basically, individual rows)
  # 3. Make an "indicator_value" column by trying to convert the indicator_column (which was
  #    the old event_value column) indicator va.
  # indicator_value for the string indicator columns are counts.
  hs = hs %>%
    rename(indicator_column = event_value) %>%
    arrange(game_id, player, game_turn, event_key, indicator_column) %>%
    mutate(indicator_value = try(as.numeric(indicator_column), silent=T)) %>%
    group_by(game_id, player, game_turn, event_key, indicator_column) %>%
    mutate(indicator_value = ifelse(is.na(indicator_value), as.numeric(n()), 
                                    indicator_value)) %>%
    ungroup()
  
  
  print('Make the enemy dataset...')
  # make the enemy dataframe with specific enemy only columns:
  enemy_keys = c('board_state','hero_health','card_played',
                 'hero_power','player_class')
  
  hs_enemy = hs %>%
    filter(event_key %in% enemy_keys) %>%
    select(one_of('game_id','event_key','indicator_column','game_turn',
                  'indicator_value','player_event_num','player'))
  
  
  # append the non-numeric indicators to their event keys - will become
  # dummy coded columns down the line
  non_str_columns = c('deck_cost','num_minions','num_spells','num_weapons',
                      'mulligan_count','max_mana','avg_hand_cost','mana_used',
                      'hero_health','board_state','hand')
  
  
  # to carry forward:
  # deck, deck_cost, player_class, current_hero_power
  
  print('Merge the string-type values to event_key...')
  # combine the event key and indicator column for the string indicators
  hs_str_keyed = hs %>%
    filter(!(event_key %in% non_str_columns)) %>%
    mutate(event_key = paste0(event_key,'[',indicator_column,']'))
  
  # bind the string indicator dataframe with non-string and remove the
  # indicator column as it is represented by the event_key at this point
  hs = hs %>%
    filter(event_key %in% non_str_columns) %>%
    bind_rows(hs_str_keyed) %>%
    arrange(game_id, game_turn, player_event_num) %>%
    select(-indicator_column)
  
  remove(hs_str_keyed)
  
  print('Merge the string-type values to key for enemy data...')
  # do the same for the enemy dataframe
  hs_enemy_str_keyed = hs_enemy %>%
    filter(!(event_key %in% non_str_columns)) %>%
    mutate(event_key = paste0(event_key,'[',indicator_column,']'))
  
  hs_enemy = hs_enemy %>%
    filter(event_key %in% non_str_columns) %>%
    bind_rows(hs_enemy_str_keyed) %>%
    arrange(game_id, game_turn, player_event_num) %>%
    select(-indicator_column)
  
  remove(hs_enemy_str_keyed)
  
  # make the player widened dataset, spreading the event key to widened columns
  # using the indicator value
  hs_wide = hs %>%
    distinct() %>%
    group_by(game_id, game_turn) %>%
    filter(!duplicated(event_key)) %>%
    spread(event_key, indicator_value) %>%
    ungroup()
  
  remove(hs)
  
  print('Widen the players data...')
  # carry forward values by player/game across turns (where theyare left NA)
  # for the columns that require it.
  hs_wide = hs_wide %>%
    arrange(game_id, game_turn) %>%
    group_by(game_id, player) %>%
    mutate_each(funs(forward_carrier), starts_with('deck'), starts_with('player_class'),
                starts_with('current_hero_power')) %>%
    ungroup()
  
  hs_wide[is.na(hs_wide)] <- 0
  
  print('Widen the enemy data...')
  # make the enemy widened dataset
  hs_enemy_wide = hs_enemy %>%
    select(-player_event_num) %>%
    distinct() %>%
    mutate(event_key = paste0('enemy_',event_key)) %>%
    mutate(player = ifelse(player == 'player1', 'player2', 'player1')) %>%
    group_by(game_id, game_turn) %>%
    filter(!duplicated(event_key)) %>%
    spread(event_key, indicator_value) %>%
    ungroup()
  
  remove(hs_enemy)
  
  # carry forward values by player/game across turns (where theyare left NA)
  # for the columns that require it.
  hs_enemy_wide = hs_enemy_wide %>%
    arrange(game_id, game_turn) %>%
    group_by(game_id, player) %>%
    mutate_each(funs(forward_carrier), starts_with('enemy_deck'), 
                starts_with('enemy_player_class'),
                starts_with('enemy_current_hero_power')) %>%
    mutate(game_turn = game_turn + 1) %>%
    ungroup()
  
  hs_enemy_wide[is.na(hs_enemy_wide)] <- 0
  
  print('Merge the player and enemy widened data together...')
  # merge the player and enemy:
  player_enemy = hs_wide %>%
    left_join(hs_enemy_wide, by=c('game_id','player','game_turn')) %>%
    group_by(game_id) %>%
    mutate(game_event_id = seq(n())) %>%
    ungroup()
  
  player_enemy[is.na(player_enemy)] <- 0
  
  #return(list(player_enemy, colcounter))
  return(player_enemy)
}


