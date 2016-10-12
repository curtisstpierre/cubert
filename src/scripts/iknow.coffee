# Description:
#   Hollywoo Stars and Celebrities: What Do They Know? Do They Know Things?? Let's Find Out! 
#
#   The goal of this script is to keep track of who knows what and find people who know 
#   things.  There are two essential uses of this script:
#
#     1) I declare I know about X.  If anyone asks about X, send 'em my way
#     2) Who knows about X?  If anyone knows about X, give me some names
#
# Dependencies:
#   none
#
# Configuration:
#   none
#
# Commands:
#   hubot i know about [thing] - register yourself for a mention whenever someone asks about [thing]
#   hubot i know nothing about [thing] - deregister yourself from mentions about [thing]
#   hubot what do i know - list all of the things you know about
#   hubot who knows about [thing] - find a list of people who know about [thing]

class IKnowClient

  constructor: () ->
  
  responses = ["Nothing's a complete load! Not if you can imagine it. That's what being a scientist is all about.",
               "Your explanations are pure weapons grade balognium. It's all impossible.",
               "I don't want to be an inventor. I want to be something useful like a teacher's aide or a prison guard or a science fiction cartoon writer.",
               "That's especially impossible.",
               "As long as I'm going to be in charge here, let me examine my so-called crew, if it can so be called.",
               "Bret, you've compressed our lunches into a singularity for the last time.",
               "You know, I could improve your reflexes by overclocking you.",
               "Help me apply these flame decals I got in my cereal. They'll make the ship go faster.",
               "https://66.media.tumblr.com/tumblr_m08f64HDoF1ql8xx7o1_500.png"]

  # Hubot brain management.  This helps us namespace our knowledge and also will let
  # us list all the things that are known about.
  known = 
    get: (key) ->
      robot.brain.data.knowledge[key] || null
    
    set: (key, users) ->
      robot.brain.data.knowledge[key] = users
      
    all: ->
      Object.keys(robot.brain.data.knowledge)
  
  # Register a new bit of knowledge.  If this user already knows about this, we
  # do nothing.
  register: (msg, username, knowledge) ->
    who_else_knows = known.get(knowledge) || []

    # if this user doesn't already know about this
    if username not in who_else_knows
      who_else_knows.push username
      known.set(knowledge, who_else_knows)

    msg.send msg.random responses

  # Remove this user's registration with a bit of knowledge.  If the user
  # doesn't know about whatever is being specified do nothing.
  deregister: (msg, username, knowledge) ->
    who_knows = known.get(knowledge) || []

    if username not in who_knows
      msg.send "You already know nothing about #{knowledge}"
    else
      # remove this user from the list and store the revised list
      who_knows = who_knows.filter (knower) -> knower isnt username
      known.set(knowledge, who_knows)
      msg.send "I get it.  The responsibility of knowing a thing was too much for you."

  # List all bits of knowledge associated with a given user
  list: (msg, username) ->
    user_knows = []

    # for all the things anybody knows about, find the items where
    # this user's name appears
    for key in known.all()
      if username in known.get(key)
        user_knows.push key

    if user_knows.length > 0
      msg_lines = ["You know about the following things:\n"].concat user_knows.sort()
      msg.send msg_lines.join('\n')
    else
      msg.send "You don't know anything"


  # Search for any users who may know about a thing
  search: (msg, knowledge) ->
    who_knows = known.get(knowledge) || []

    # do fuzzy matching
    other_known_things = known.all().filter (key) -> key isnt knowledge

    matching_knowledge = require('fuzzaldrin').filter(other_known_things, knowledge)
    approximate_knowers = {}

    for key in matching_knowledge
      for user in known.get(key)
        approximate_knowers[user] ?= []
        approximate_knowers[user].push key

    msg_lines = []

    if who_knows.length > 0
      msg_lines = ["Pork at any of these people for help:\n"].concat who_knows.sort()

    if Object.keys(approximate_knowers).length > 0
      msg_lines.push "These people *might* be able to help:\n"
      for user in Object.keys(approximate_knowers).sort()
        msg_lines.push "#{user} (#{approximate_knowers[user].join(', ')})"

    if msg_lines.length == 0
      msg_lines.push "Nobody knows about #{knowledge}"

    msg.send msg_lines.join('\n')

client = new IKnowClient()

module.exports = (robot) ->
  # helper method to get sender of the message
  get_username = (response) ->
    "@#{response.message.user.name}"

  robot.brain.data.knowledge ?= {}

  robot.respond /i know about (.*)/i, (msg) ->
    client.register(msg, get_username(msg), msg.match[1])

  robot.respond /i know nothing about (.*)/i, (msg) ->
    client.deregister(msg, get_username(msg), msg.match[1])

  robot.respond /what do i know/i, (msg) ->
    client.list(msg, get_username(msg))

  robot.respond /who knows about (.*)/i, (msg) ->
    knowledge = msg.match[1].toLowerCase().replace(/\s\s+/g, ' ')

    if knowledge != ''
      client.search(msg, knowledge)
