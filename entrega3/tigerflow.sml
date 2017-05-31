structure tigerflow =
struct
  open tigergraph
  
  (*structure G = tigergraph*)
  
  type flowgraph = { control: graph,
                     def: tigertemp.temp Splayset.set table,
                     use: tigertemp.temp Splayset.set table,
                     ismove: bool table }
end