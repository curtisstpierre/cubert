# Description:
#   Script for interacting with the Pingdom API.
#
# Dependencies:
#   none
#
# Configuration:
#   HUBOT_PINGDOM_USERNAME
#   HUBOT_PINGDOM_PASSWORD
#   HUBOT_PINGDOM_APP_KEY
#
# Commands:
#   hubot pingdom checks - returns summary of all checks pingdom currently monitoring
#   hubot pingdom alerts - returns list of most recent 10 alerts generated
#   hubot pingdom down - returns a list of checks that are currently failing

username = process.env.HUBOT_PINGDOM_USERNAME
password = process.env.HUBOT_PINGDOM_PASSWORD
app_key = process.env.HUBOT_PINGDOM_APP_KEY

class PingdomClient

  constructor: (@username, @password, @app_key) ->

  checks: (msg) ->
    my = this
    my.request msg, 'checks', (response) ->
      if response.checks.length > 0
        lines = ["Here are our current Pingdom checks:"]
        for check in response.checks
          lines.push "    #{check.name}. Status: #{check.status}. Last response time: #{check.lastresponsetime}ms"
        msg.send lines.join('\n')
      else
        msg.send "No checks found"

  actions: (msg) ->
    my = this
    my.request msg, 'actions?limit=10', (response) ->
      if response.actions.length > 0
        lines = ["Here are the most recent 10 Pingdom alerts:"]
        for alert in response.actions
          lines.push "    At: #{new Date(alert.time).toISOString()}. Message: #{alert.messagefull}"
        msg.send lines.join('\n')
      else
        msg.send "No alerts found"

  down: (msg, tags=["prod"]) ->
    my = this

    if tags.length > 0
      request = 'checks?tags=' + tags.join(',')
    else
      request = 'checks'
   
    my.request msg, request, (response) ->
      ok_message = "Everything looks a-ok, boss!" 
      if response.checks.length > 0
        lines = []
        for alert in response.checks
          if alert.status == "down"
            lines.push "    #{alert.hostname}"
          
        if lines.length > 0
          lines = ["The following systems are offline:\n"].concat lines.sort()
          msg.send lines.join('\n')
        else
          msg.send ok_message
      else
        msg.send "Pingdom says there are no checks that have any of these tags: " + tags.join(', ')
    
  request: (msg, url, handler) ->
    auth = new Buffer("#{@username}:#{@password}").toString('base64')
    pingdom_url = "https://api.pingdom.com/api/2.0"
    msg.http("#{pingdom_url}/#{url}")
      .headers(Authorization: "Basic #{auth}", 'App-Key': @app_key)
        .get() (err, res, body) ->
          if err
            msg.send "    Pingdom says: #{err}"
            return
          content = JSON.parse(body)
          if content.error
            msg.send "    Pingdom says: #{content.error.statuscode} #{content.error.errormessage}"
            return
          handler content

client = new PingdomClient(username, password, app_key)

module.exports = (robot) ->
  robot.respond /pingdom checks/i, (msg) ->
    client.checks msg

  robot.respond /pingdom alerts/i, (msg) ->
    client.actions msg

  robot.respond /pingdom down ?(.*)/i, (msg) ->
    tags = msg.match[1]

    if tags == ''
      client.down msg
    else
      client.down(msg, tags.split " ")
