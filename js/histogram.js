
function value(e) {
    v = d3.select(e)[0][0].value
    if (v) {
        return JSON.parse(v);
    } else {
        return null;
    }
}

function draw(xDomainEle, valuesEle) {
    var bin_range = 100;
    var response_times = value(valuesEle);
    var title = response_times["title"];
    var values = response_times["data"].map(function(d){return parseInt(d/bin_range) * bin_range});
    var xMax = d3.max(values, function(d) { return d })
    var xDomain = value(xDomainEle) || xMax;

    var avg = parseInt(values.reduce(function(a,b){return a+b;}) / values.length)

    // A formatter for counts.
    var formatCount = d3.format("d");

    var margin = {top: 10, right: 30, bottom: 30, left: 30},
        width = 960 - margin.left - margin.right,
        height = 500 - margin.top - margin.bottom;

    var x = d3.scale.linear()
        .domain([0, xDomain])
        .range([0, width]);

    // Generate a histogram using twenty uniformly-spaced bins.
    var data = d3.layout.histogram()
        .bins(x.ticks(1000))
    (values);

    var y = d3.scale.linear()
        .domain([0, d3.max(data, function(d) { return d.y; })])
        .range([height, 0]);

    var yAxis = d3.svg.axis()
        .scale(y)
        .orient("left");
    var xAxis = d3.svg.axis()
        .scale(x)
        .orient("bottom");

    var svg = d3.select("body").append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    svg.append("text")
        .attr("dy", "0.75em")
        .attr("y", 6)
        .attr("x", width/2 - 50)
        .attr("text-anchor", "middle")
        .text(title);
    svg.append("text")
        .attr("dy", ".75em")
        .attr("y", 6)
        .attr("x", width - 50)
        .attr("text-anchor", "middle")
        .text("x-max: " + xMax);
    var bar = svg.selectAll(".bar")
        .data(data)
        .enter().append("g")
        .attr("class", "bar")
        .attr("transform", function(d) { return "translate(" + x(d.x) + "," + y(d.y) + ")"; });

    bar.append("rect")
        .attr("x", 1)
        .attr("width", x(data[0].dx))
        .attr("height", function(d) { return height - y(d.y); });
    /*
      bar.append("text")
      .attr("dy", ".75em")
      .attr("y", 6)
      .attr("x", x(data[0].dx) / 2)
      .attr("text-anchor", "middle")
      .text(function(d) { return formatCount(d.y); });
    */
    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis);
    svg.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(0,0)")
        .call(yAxis);
    medium = svg.append("g")
        .attr("class", "medium")
        .attr("transform", "translate("+x(avg)+",0)");
    medium.append("rect")
          .attr("x", 1)
          .attr("width", 1)
          .attr("height", height);
}
