
root = exports ? this

# TODO: most of this really shouldn't have to wait till the page
# is loaded to execute.
# Pull out
$ ->

  # ---
  # These are constants we would like availible anywhere in the visualization
  # ---
  width = 860
  height = 450
  key_h = 150
  key_w = 400
  [key_pt, key_pr, key_pb, key_pl] = [10, 10, 10, 15]
  [pt, pr, pb, pl] = [20, 20, 50, 60]

  # ---
  # default options
  #
  # the options hash is modified in the UI and then update_options is called
  # to refresh the visualization with the new options.
  # 
  # TODO:
  # Could be easily extended to save the state of the visualization in the url
  # so people could link to specific sorts/filters
  #
  # ---
  root.options = {top: 50, bottom: 0, genres: null, year: "all", stories: null, sort:"rating"}

  # ---
  # used to map between UI and underlying data columns
  # ---
  data_key = {
    budget: "Budget",
    gross: "Worldwide Gross",
    rating: "Rotten Tomatoes",
    profit: "Profit"
  }

  # ---
  # These are variables we would like availible anywhere in the visualization
  # ---
  data = null
  all_data = null
  base_vis = null
  vis = null
  body = null
  vis_g = null
  zero_line = null
  middle_line = null

  # !!!
  # here is the text used for the labels on the main chart
  # !!!
  y_label = "Rating (Rotten Tomatoes %)"
  x_label = "Profit ($ mil)"

  # !!!
  # functions to acess values of data used for scales
  # they correspond to columns in our csv data.
  # To use another column for this property simply change
  # the name here.
  # !!!
  x = (d) -> d["Profit"]
  y = (d) -> d["Rotten Tomatoes"]
  r = (d) -> d["Budget"]
  color = (d) -> d["Genre"]


  # the domain of these scales will be set based
  # on the data below
  x_scale = d3.scale.linear().range([0, width])
  y_scale = d3.scale.linear().range([0, height])
  y_scale_reverse = d3.scale.linear().range([0, height])

  # !!!
  # set domain manually for r scale
  # will need to be changed
  # !!!
  r_scale = d3.scale.sqrt().range([0, 29]).domain([0,310])

  xAxis = d3.svg.axis().scale(x_scale).tickSize(5).tickSubdivide(true)
  yAxis = d3.svg.axis().scale(y_scale_reverse).ticks(5).orient("left")


  # !!!
  # set range manually for color
  # if we have more/less colors we can change them here 
  # !!!
  color_scale = d3.scale.category10()
  color_scale = d3.scale.ordinal().range(["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf", "#078B78", "#5C1509", "#CECECE", "#FFEA0A"])

  # ---
  # Function used to ensure our raw data is in the correct format for the rest
  # of the visualization.
  # Right now, it ensures the columns listed in data_key are floats
  # ---
  prepare_data = (data) ->
    data.forEach (d) ->
      d3.values(data_key).forEach (k) ->
        d[k] = parseFloat(d[k])
    data

  # ---
  # Sorts underlying data based on input data_key key
  # ---
  sort_data = (sort_type) =>
    data = data.sort (a,b) ->
      b1 = parseFloat(a[data_key[sort_type]]) ? 0
      b2 = parseFloat(b[data_key[sort_type]]) ? 0
      b2 - b1

  # ---
  # Various filters
  #
  # not sure if the => is necessary...
  # ---
  filter_year = (year) ->
    data = data.filter (d) -> if year == "all" then true else d.year == year

  filter_genres = (genres) =>
    if genres
      data = data.filter (d) -> $.inArray(d["Genre"], genres) != -1

  filter_stories = (stories) =>
    if stories
      data = data.filter (d) -> $.inArray(d["Story"], stories) != -1

  filter_number = (top, bottom) ->
    bottom_start_index = data.length - bottom
    bottom_start_index = 0 if bottom_start_index < 0

    if top >= bottom_start_index
      data = data
    else
      top_data = data[0...top]
      bottom_data = data[bottom_start_index..-1]
      data = d3.merge([top_data, bottom_data])

  # ---
  # updates x and y scales to conform to newly 
  # filtered dataset
  # ---
  update_scales = () =>
    min_y_padding = 3
    min_x_padding = 5

    [min_x, max_x] = d3.extent data, (d) -> parseFloat(x(d))
    min_x = if min_x > 0 then 0 else min_x

    [min_y, max_y] = d3.extent data, (d) -> parseFloat(y(d))
    y_padding = parseInt(Math.abs(max_y - min_y) / 5)
    y_padding = if y_padding > min_y_padding then y_padding else min_y_padding

    min_y = min_y - y_padding
    min_y = if min_y < 0 then 0 else min_y
    max_y = max_y + y_padding
    max_y = if max_y > 100 then 100 else max_y
    
    x_padding = parseInt(Math.abs(max_x - min_x) / 12)
    x_padding = if x_padding > min_x_padding then x_padding else min_x_padding

    min_x = min_x - x_padding
    max_x = max_x + x_padding

    x_scale.domain([min_x, max_x])
    y_scale.domain([min_y, max_y])
    y_scale_reverse.domain([max_y, min_y])

  # ---
  # Resets data, executes current filters, and then
  # updates scales
  # ---
  update_data = () =>
    data = all_data
    filter_year(root.options.year)
    filter_genres(root.options.genres)
    filter_stories(root.options.stories)
    sort_data(root.options.sort)
    filter_number(root.options.top, root.options.bottom)
    update_scales()

  # ---
  # creates / updates / deletes bubbles
  # ---
  draw_bubbles = () ->
    bubbles = vis_g.selectAll(".bubble")
      .data(data, (d) -> d.id)

    bubbles.enter().append("g")
      .attr("class", "bubble")
      .on("mouseover", (d, i) -> show_details(d,i,this))
      .on("mouseout", hide_details)
    .append("circle")
      .attr("opacity", 0.85)
      .attr("fill", (d) -> color_scale(color(d)))
      .attr("stroke", (d) -> d3.hsl(color_scale(color(d))).darker())
      .attr("stroke-width", 2)
      .attr("r", (d) -> r_scale(r(d)))

    bubbles.transition()
      .duration(1000)
      .attr("transform", (d) -> "translate(#{x_scale(x(d))},#{y_scale(y(d))})")

    base_vis.transition()
      .duration(1000)
      .select(".x_axis").call(xAxis)

    zero_line.transition()
      .duration(1000)
      .attr("x1", x_scale(0))
      .attr("x2", x_scale(0))

    middle_line.transition()
      .duration(1000)
      .attr("y1", y_scale(50.0))
      .attr("y2", y_scale(50.0))

    base_vis.transition()
      .duration(1000)
      .select(".y_axis").call(yAxis)

    bubbles.exit().transition()
      .duration(1000)
      .attr("transform", (d) -> "translate(#{0},#{0})")
    .remove()

    bubbles.exit().selectAll("circle").transition()
      .duration(1000)
      .attr("r", 0)

  # ---
  # helper function to create 
  # the detail listings for movies
  # ---
  draw_movie_details = (detail_div) ->
    detail_div.enter().append("div")
      .attr("class", "bubble-detail")
      .attr("id", (d) -> "bubble-detail-#{d.id}")
    .append("h3")
      .text((d) -> d["Film"])
    .append("span")
      .attr("class", "detail-rating")
      .text((d) -> " #{d["Rotten Tomatoes"]}%")

    detail_div.exit().remove()

  # ---
  # updates the lower 'details' section
  # ---
  draw_details = () ->
    if root.options.top == 0
      $("#detail-love").hide()
    else
      $("#detail-love").show()

    if root.options.bottom == 0
      $("#detail-hate").hide()
    else
      $("#detail-hate").show()

    top_data = data[0...root.options.top]

    detail_top = d3.select("#detail-love").selectAll(".bubble-detail")
      .data(top_data, (d) -> d.id)

    draw_movie_details(detail_top)

    bottom_data = data[root.options.top..-1].reverse()

    detail_bottom = d3.select("#detail-hate").selectAll(".bubble-detail")
      .data(bottom_data, (d) -> d.id)

    draw_movie_details(detail_bottom)

  # ---
  # creates the key used to show colors
  # ---
  draw_key = () ->
    genres = {}
    all_data.forEach (d) -> genres[d["Genre"]] = 1
    key_r = 10

    key = d3.select("#key")
      .append("svg")
      .attr("id", "key-svg")
      .attr("width", key_w )
      .attr("height", key_h + key_pb + key_pt)

    key.append("rect")
      .attr("width", key_w)
      .attr("height", key_h + key_pb + key_pt)
      .attr("fill", "#ffffff")
      .attr("opacity", 0.0)

    key = key.append("g")
      .attr("transform", "translate(#{key_pl},#{key_pt})")

    key_group = key.selectAll(".key-group")
      .data(d3.keys(genres))
      .enter().append("g")
        .attr("class", "key-group")
        .attr("transform", (d,i) -> "translate(#{if i*25 >= key_h then 140 else 0},#{i*25 % key_h})")

    key_group.append("circle")
        .attr("r", key_r)
        .attr("fill", (d) -> color_scale(d))
        .attr("transform", (d) -> "translate(#{key_r}, #{key_r})")

    key_group.append("text")
        .attr("class", "key-text")
        .attr("dy", 15)
        .attr("dx", key_r * 2 + 6)
        .text((d) -> d)

    key_demo_group = key.append("g")
      .attr("transform", "translate(#{0},0)")

    example_x = 280
    example_r = 20
    example_y = key_h / 2 - example_r

    key_demo_group.append("circle")
      .attr("r", example_r)
      .attr("fill", color_scale("Comedy"))
      .attr("transform", (d) -> "translate(#{example_r}, #{example_r})")
      .attr("cx", example_x)
      .attr("cy", example_y)

    key_demo_group.append("line")
      .attr("x1", example_x)
      .attr("x2", example_x + example_r * 2)
      .attr("y1", example_y + example_r)
      .attr("y2", example_y + example_r)
      .attr("stroke", "#333")
      .attr("stroke-dasharray", "3")
      .attr("stroke-width", 2)

    key_demo_group.append("text")
      .attr("dx", example_x + (example_r * 2) + 4 )
      .attr("dy", example_y + example_r - 8)
      .text("Film's")

    key_demo_group.append("text")
      .attr("dx", example_x + (example_r * 2) + 4 )
      .attr("dy", example_y + example_r + 6)
      .text("Budget")

  # ---
  # Creates initial framework for visualization
  # ---
  render_vis = (error, csv) ->
    if error
      console.log(error)
    all_data = prepare_data(csv)
    update_data()

    base_vis = d3.select("#vis")
      .append("svg")
      .attr("width", width + (pl + pr) )
      .attr("height", height + (pt + pb) )
      .attr("id", "vis-svg")

    base_vis.append("g")
      .attr("class", "x_axis")
      .attr("transform", "translate(#{pl},#{height + pt})")
      .call(xAxis)

    base_vis.append("text")
      .attr("x", width / 2)
      .attr("y", height + (pt + pb) - 10)
      .attr("text-anchor", "middle")
      .attr("class", "axisTitle")
      .attr("transform", "translate(#{pl},0)")
      .text(x_label)

    base_vis.append("g")
      .attr("class", "y_axis")
      .attr("transform", "translate(#{pl},#{pt})")
      .call(yAxis)

    vis = base_vis.append("g")
      .attr("transform", "translate(#{0},#{height + (pt + pb)})scale(1,-1)")

    vis.append("text")
      .attr("x", height/2)
      .attr("y", 20)
      .attr("text-anchor", "middle")
      .attr("class", "axisTitle")
      .attr("transform", "rotate(270)scale(-1,1)translate(#{pb},#{0})")
      .text(y_label)
   
    body = vis.append("g")
      .attr("transform", "translate(#{pl},#{pb})")
      .attr("id", "vis-body")

    zero_line = body.append("line")
      .attr("x1", x_scale(0))
      .attr("x2", x_scale(0))
      .attr("y1", 0 + 5)
      .attr("y2", height - 5)
      .attr("stroke", "#aaa")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "2")

    middle_line = body.append("line")
      .attr("x1", 0 + 5)
      .attr("x2", width + 5)
      .attr("y1", y_scale(50.0))
      .attr("y2", y_scale(50.0))
      .attr("stroke", "#aaa")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "2")
 
    vis_g = body.append("g")
      .attr("id", "bubbles")

    draw_bubbles()
    draw_details()
    draw_key()

  # ---
  # function that is called when a bubble is 
  # hovered over
  # ---
  show_details = (bubble_data, index, element) ->
    bubbles = body.selectAll(".bubble")

    bBox = element.getBBox()
    box = { "height": Math.round(bBox.height), "width": Math.round(bBox.width), "x": width + bBox.x, "y" : height + bBox.y}
    box.x = Math.round(x_scale(x(bubble_data)))  - (pr+109) + r_scale(r(bubble_data))
    box.y = Math.round(y_scale_reverse(y(bubble_data))) - (r_scale(r(bubble_data)) + pt + -55)

    tooltipWidth = parseInt(d3.select('#tooltip').style('width').split('px').join(''))

    msg = '<p class="title">' + bubble_data["Film"] + '</p>'
    msg += '<table>'
    msg += '<tr><td>Rating:</td><td>' +  bubble_data["Rotten Tomatoes"] + '%</td></tr>'
    msg += '<tr><td>Budget:</td><td>' +  bubble_data["Budget"] + ' mil</td></tr>'
    msg += '<tr><td>Worldwide Gross:</td><td>' +  bubble_data["Worldwide Gross"] + ' mil</td></tr>'
    msg += '<tr><td>Profit:</td><td>' +  bubble_data["Profit"] + ' mil' + '</td></tr>'
    msg += '<tr><td>Story:</td><td>' +  bubble_data["Story"] + '</td></tr>'
    msg += '</table>'

    d3.select('#tooltip').classed('hidden', false)
    d3.select('#tooltip .content').html(msg)
    d3.select('#tooltip')
      .style('left', "#{(box.x + (tooltipWidth / 2)) - box.width / 2}px")
      .style('top', "#{(box.y) }px")


    selected_bubble = d3.select(element)
    selected_bubble.attr("opacity", 1.0)

    unselected_movies = bubbles.filter( (d) -> d.id != bubble_data.id)
    .selectAll("circle")
      .attr("opacity",  0.3)

    crosshairs_g = body.insert("g", "#bubbles")
      .attr("id", "crosshairs")

    crosshairs_g.append("line")
      .attr("class", "crosshair")
      .attr("x1", 0 + 3)
      .attr("x2", x_scale(x(bubble_data)) - r_scale(r(bubble_data)))
      .attr("y1", y_scale(y(bubble_data)))
      .attr("y2", y_scale(y(bubble_data)))
      .attr("stroke-width", 1)

    crosshairs_g.append("line")
      .attr("class", "crosshair")
      .attr("x1", x_scale(x(bubble_data)))
      .attr("x2", x_scale(x(bubble_data)))
      .attr("y1", 0 + 3)
      .attr("y2", y_scale(y(bubble_data)) - r_scale(r(bubble_data)))
      .attr("stroke-width", 1)

  # ---
  # function that is called when
  # mouse leaves a bubble
  # ---
  hide_details = (bubble_data) ->
    d3.select('#tooltip').classed('hidden', true)

    bubbles = body.selectAll(".bubble").selectAll("circle")
      .attr("opacity", 0.85)

    body.select("#crosshairs").remove()

# ---
# MAIN
# ---
     
  # load the data then call render_vis
  d3.csv "data/movies_all_final_filter.csv", render_vis

  # ---
  # Entry point for updating the visualization
  # called by update_options
  # ---
  update = () =>
    update_data()
    draw_bubbles()
    draw_details()

  # ---
  # UI accessible update function
  # ---
  root.update_options = (new_options) =>
    root.options = $.extend({}, root.options, new_options)
    update()

