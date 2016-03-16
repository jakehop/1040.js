m4_changequote(<|,|>)
<meta charset="utf-8">
<!-- Licensed under GPLv2, with one clarification; see https://github.com/b-k/1040.js . -->
<html>
<title>The tax graph</title>

<!--<link rel="stylesheet" href="demo.css">-->
<script>
m4_include(d3.v3.js)

m4_include(graphlib-dot.js)

m4_include(dagre-d3.js)
</script>

<style id="css">
g.u > rect {
  fill: #caf2bd;
}

text {
  font-weight: 300;
  font-family: "Helvetica Neue", Helvetica, Arial, sans-serf;
  font-size: 19px;
}

input[type=checkbox]
{
   /* Double-sized Checkboxes, via http://stackoverflow.com/questions/306924/checkbox-size-in-html-css */
   -ms-transform: scale(2); /* IE */
   -moz-transform: scale(2); /* FF */
   -webkit-transform: scale(2); /* Safari and Chrome */
   -o-transform: scale(2); /* Opera */
   padding: 10px;
}


body{
  font-size: 25px;
}

.node rect {
  stroke: #999;
  fill: #fff;
  stroke-width: 1.5px;
}

.edgePath path {
  stroke: #333;
  stroke-width: 1.5px;
}
</style>

<body>

<INPUT class=check TYPE=CHECKBOX NAME="dependents" id=".over_65" onclick="checkbox(id, checked)" checked>I am over 65.<BR>
<INPUT class=check TYPE=CHECKBOX NAME="mortgage" id=".mort" onclick="checkbox(id, checked)" checked>I have a mortgage.<BR>
<INPUT class=check TYPE=CHECKBOX NAME="itemizing" id=".itemizing" onclick="checkbox(id, checked)" checked>I am itemizing deductions.<BR>
<INPUT class=check TYPE=CHECKBOX NAME="itemizing" id=".have_rr" onclick="checkbox(id, checked)" checked>I have rental or royalty income.<BR>
<INPUT class=check TYPE=CHECKBOX NAME="itemizing" id=".hide_zeros" onclick="hidezeros(id, checked)">Hide everything that is currently zero.<BR>
<a href="http://github.com/b-k/1040.js">I want to make this tax calculator better.</a>

<svg id="svg-canvas" width=960 height=600></svg>


<script id="js">
<!-- Much of this started at http://cpettitt.github.io/project/dagre-d3/latest/demo/sentence-tokenization.html -->

var itemizing = 0;
var over_65 = 0;
var spouse_over_65 = 0;

m4_include(fns)


// Create the input graph
var g = new dagreD3.graphlib.Graph()
  .setGraph({})
  .setDefaultEdgeLabel(function() { return {}; });


m4_include(nodes)

var nodestorage=[]
var edgestorage=[]

var fixboxsize= function(node) {
  // Round the corners of the nodes
  node.rx = node.ry = 5;
  size = Math.sqrt(Math.max(node.val, 1000));
  //node.width = size*2.5;
  node.height = size*.9;
  node.label = node.baselabel + ": " + node.val
};

var fb2 = function(v){
    fixboxsize(g.node(v)); 
}

g.nodes().forEach(fb2);

var set_edges = function(from, toset){
    if (typeof g._nodes[from] === "undefined") return;
    for (i in toset){
        if (toset[i]=="") return;
        if (typeof g._nodes[toset[i]] === "undefined") return;
        g.setEdge(toset[i], from);
    }
}

// Set up edges, no special attributes.
var reedge = function(){

m4_include(edges)

}

reedge();

g.graph().rankdir="lr";

// Create the renderer
var render = new dagreD3.render();

// Set up an SVG group so that we can translate the final graph.
var svg = d3.select("svg"),
    svgGroup = svg.append("g");

// Run the renderer. This is what draws the final graph.
render(d3.select("svg g"), g);

// Center the graph
    svg.attr("width", g.graph().width + 40);
    svg.attr("height", g.graph().height + 40);
var xCenterOffset = (svg.attr("width") - g.graph().width) / 2;
svgGroup.attr("transform", "translate(" + xCenterOffset + ", 20)");

var val_prompt = function(d){
    var promptval = window.prompt(this.textContent, g._nodes[d].val);
    var floated = parseFloat(promptval)
    if(isNaN(floated)) return;
    g._nodes[d].val = floated;
    //console.log(this.textContent + g._nodes[d].val);
    fixboxsize(g._nodes[d]);
    last_eval += 1;
    CV("f1040_refund");
    CV("f1040_tax_owed");
    CV("f8582_carryover_to_next_year");
    redrawIt();
}

var redrawIt = function(){
    render(d3.select("svg g"), g);
    svg.attr("width", g.graph().width + 40);
    svg.attr("height", g.graph().height + 40);
    var xCenterOffset = (svg.attr("width") - g.graph().width) / 2;
    svgGroup.attr("transform", "translate(" + xCenterOffset + ", 20)");
svg.selectAll(".u").on('click', val_prompt);
}


svg.selectAll(".u").on('click', val_prompt);

svg.selectAll("arrowhead").style("opacity", false);

var situations = [];
var have_rr = 0;
var kids = 0;

var last_eval = 0;

function CV(name){
    this_cell = g._nodes[name];
    if (typeof this_cell === "undefined") this_cell = nodestorage[name];
    if (this_cell.eqn==="" || this_cell.last_eval >= last_eval)
        return parseFloat(this_cell.val);
    var out = parseFloat(eval(this_cell.eqn));

    if (g._nodes[name]){
        g._nodes[name].last_eval = last_eval;
        g._nodes[name].val = out;
        fixboxsize(g._nodes[name]);
    } else{
        nodestorage[name].last_eval = last_eval;
        nodestorage[name].val = out;
    }
    return out;
}

function checkbox(id, checked){situations[id]=checked;
    if (!checked){
        svg.selectAll(id).each(function(i){
                if (g._nodes[i].class.match("critical")) return;
                var n = g._nodes[i];
                nodestorage[i] = { label: n.label,
                        baselabel: n.baselabel,
                        fullname:  n.fullname,
                        class: n.class, val:n.val
                        , eqn: n.eqn, last_eval: n.last_eval
                        };
                console.log("storing " + i + ": "+ g._nodes[i].class)
                g.removeNode(i);
                console.log("stored  " + i + ": "+ nodestorage[i].class)
            });
        redrawIt();
    } else {
        for (i in nodestorage){
            var changed = false;
            if (nodestorage[i].class.indexOf(id.replace('\.',''))>0){
                changed=true;
                console.log("exhuming " + i + ": "+ nodestorage[i].class)
                g.setNode(i, nodestorage[i], { label: nodestorage[i].label,
                        baselabel: nodestorage[i].baselabel,
                        fullname:  nodestorage[i].fullname,
                        class: nodestorage[i].class, val:nodestorage[i].val
                        , eqn: nodestorage[i].eqn, last_eval: nodestorage[i].last_eval
                        });
            }
        }
        if (changed){
            reedge();
            redrawIt();
        }
    }
}

function hidezeros(id, checked){
    if (!checked){
        checkbox(id, !checked);
        //svg.selectAll(".a_node").filter(function(d){return g._nodes[d].val==0}).classed('hide_zeros', false)
    } else {
//        svg.selectAll(".a_node").filter(function(d){return g._nodes[d].val==0}).classed('hide_zeros', true)
        for (i in g._nodes)  g._nodes[i].class.replace(/hide_zeros/g, "");
         for (i in nodestorage)  nodestorage[i].class.replace(/hide_zeros/g, "");
        for (i in g._nodes) {console.log(i+ " "+g._nodes[i].class +" "+ g._nodes[i].val);
            if (g._nodes[i].val==0) g._nodes[i].class += " hide_zeros";
console.log(i+" "+ g._nodes[i].class +" "+ g._nodes[i].val);
        }
        redrawIt();
        checkbox(id, !checked);
    }

}

document.getElementById(".have_rr").click()
document.getElementById(".mort").click()
document.getElementById(".itemizing").click()
document.getElementById(".over_65").click()

</script>
</body>
</html>
