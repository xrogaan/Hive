# Setting up a whole bunch of global functions to make rendering pages more convenient.

# lastP is always the most recent person referenced (by one of these functions or by displaying their image or name). This makes things like "#{He @CrewMember} hands #{his} cup to her" possible - notice how the second use doesn't require an argument.
lastP = null
window.q = (person = lastP)->
  lastP = person
  return "<q style='color: #{person.text or '#FFF'}'>"
q.toString = q

# Minor linguistic note - events have to be written in the male form in code because his->her, him->her are impossible to tell apart from the feminine side.
window.he = (p = lastP)-> lastP = p; if p.gender is 'f' then 'she' else 'he'
window.He = (p = lastP)-> lastP = p; if p.gender is 'f' then 'She' else 'He'
window.him = (p = lastP)-> lastP = p; if p.gender is 'f' then 'her' else 'him'
window.his = (p = lastP)-> lastP = p; if p.gender is 'f' then 'her' else 'his'
window.His = (p = lastP)-> lastP = p; if p.gender is 'f' then 'Her' else 'His'
window.boy = (p = lastP)-> lastP = p; if p.gender is 'f' then 'girl' else 'boy'
window.man = (p = lastP)-> lastP = p; if p.gender is 'f' then 'woman' else 'man'
window.men = (p = lastP)-> lastP = p; if p.gender is 'f' then 'women' else 'men'
he.toString = he
He.toString = He
him.toString = him
his.toString = his
His.toString = His
boy.toString = boy
man.toString = man
men.toString = men

statSchema = {type: 'number', gte: 0, lte: 100}

window.Person = class Person extends GameObject
  @stats:
    strength: "Strength<br>Good for beating people up and taking their (my) things."
    magic: "Magic<br>Raw power aetheric. Very rare in humans."
    intelligence: "Intelligence<br> On a scale of Liana -> Rock -> Tentacle -> Human -> Me"
    lust: "Lust<br> How much they need and want sex, as well as how good they are at it."
  @schema:
    type: @
    strict: true
    properties:
      name:
        type: 'string'
      gender:
        type: 'string'
        pattern: /^[mf]$/
      image:
        type: ['string', 'function']
      description:
        # description can be a string so that random characters can have the chosen one "stuck" to them.
        type: ['string', 'function']
      strength: statSchema
      magic: statSchema
      intelligence: statSchema
      lust: statSchema

  # Each Person subclass should have @images and optionally @colors.

  strength: 0
  magic: 0
  intelligence: 0
  lust: 0
  description: 'If you see this in-game, it is a bug.'

  constructor: (data, objects, path)->
    super(data, objects, path)

  renderBlock: (key, classes = '')->
    stats = for stat in ['strength', 'magic', 'intelligence', 'lust']
      "<span class='#{stat}'>#{@[stat]}</span>"

    fullStats = for stat in ['strength', 'magic', 'intelligence', 'lust'] when @[stat]?
      """<tr class='#{stat}'><td>#{stat.capitalize()}</td><td>#{@[stat]}</td></tr>"""

    return """<div data-key="#{key}" class="person-info #{classes}">
      <div class="name" style="color: #{@text};">#{@name}</div>
      <div class="stats">#{stats.join ''}</div>
      <div class="full">
        <div class="name">#{@name}</div>
        <table class="stats">#{fullStats.join ''}</table>
        <img src="game/content/images/#{@image?() or @image}">
        <div class="description">#{@description?() or @description}</div>
      </div>
    </div>"""

  toString: ->
    lastP = @
    return @name

  possessive: ->
    lastP = @
    return @name + if @name[@name.length - 1] is 's' then "'" else "'s"

  add: (stat, amount)->
    @[stat] += amount
    # Randomly round non-whole number stats
    @[stat] = Math.floor(@[stat]) + (Math.random() < @[stat] % 1)
    @[stat] = Math.max 0, Math.min(@[stat], 100)

Game.schema.properties.crew =
  type: Collection
  items:
    type: Person
Game.schema.properties.people =
  type: Collection
  items:
    type: Person
Game::crew = new Collection
Game::people = new Collection

$ ->
  c = $ '#content'
  # Bail out if we're not in the live game page
  unless c.length then return

  c.on 'mouseenter', '.person-info', ->
    parentWidth = $(@).parent().width()
    if $(@).position().left < parentWidth / 2
      $('.full', @).removeClass 'right'
    else
      $('.full', @).addClass 'right'

Page.schema.properties.stat = # If this page uses next = Page.statCheck, then its "stat" and "difficulty" properties determine what's checked.
  type: 'string'
  optional: true
  match: Object.keys(Person.stats).join '|'
Page.schema.properties.difficulty =
  type: 'integer'
  gte: 1
  optional: true

statCheckChances = (stat, diff, context)->
  sum = 1
  if context
    sum += Page.sumStat stat, context, context
  else
    sum += Page.sumStat stat, g.officers
  chances = {
    veryBad: Math.pow(diff / (sum * 2), 2)
    bad: diff / sum
    good: sum / diff
    veryGood: Math.pow(sum / (diff * 2), 2)
  }
  normalize = Math.sumObject(chances)
  for key, value of chances
    chances[key] /= normalize
  return chances

Page.statCheck = ->
  items = @constructor.next
  chances = statCheckChances(@stat, @difficulty, @context)
  console.log(items, chances)
  r = Math.random()

  r -= chances.veryBad
  if items.veryBad and r <= 0
    return items.veryBad
  r -= chances.bad
  if r <= 0
    return items.bad
  r -= chances.good
  if r <= 0
    return items.good
  return items.veryGood or items.good

Page.statCheckDescription = (stat, difficulty, items, context)->
  chances = statCheckChances(stat, difficulty, context)
  percent = (chance)-> Math.round(chance * 100) + '%'
  results = []

  if items.veryGood
    results.push "Very Good: #{percent chances.veryGood}"
    results.push "Good: #{percent chances.good}"
  else
    results.push "Good: #{percent chances.good + chances.veryGood}"
  if items.veryBad
    results.push "Bad: #{percent chances.bad}"
    results.push "Very Bad: #{percent chances.veryBad}"
  else
    results.push "Bad: #{percent chances.bad + chances.veryBad}"

  return "<span class='#{stat}'>#{stat.capitalize()}</span>, difficulty #{difficulty}:
  <ul class='stat-check'>
    <li>" + results.join('</li><li>') + '</li>
  </ul>'
