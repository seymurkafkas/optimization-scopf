set BUSES;
set LINES within {1..1000} cross BUSES cross BUSES; #Allow up to 1000 branches
set CONTINGENCIES within LINES;
set LODF_INDICES:= setof{(i,j,k) in LINES} (i) cross setof{(i,j,k) in LINES} (i);

param line_from      {LINES};
param line_to        {LINES};
param line_type      {LINES};
param line_r         {LINES};
param line_x         {LINES};
param line_c         {LINES};
param line_tap       {LINES};
param line_tap_min   {LINES};
param line_tap_max   {LINES};
param line_def0      {LINES};
param line_def_min   {LINES};
param line_def_max   {LINES};

param bus_type       {BUSES};
param bus_name       {BUSES} symbolic;
param bus_voltage    {BUSES};
param bus_angle0     {BUSES};
param bus_p_gen      {BUSES};
param bus_q_gen      {BUSES};
param bus_q_min      {BUSES};
param bus_q_max      {BUSES};
param bus_p_load     {BUSES};
param bus_q_load     {BUSES};
param bus_g_shunt    {BUSES};
param bus_b_shunt    {BUSES};
param bus_b_shunt_min{BUSES};
param bus_b_shunt_max{BUSES};
param bus_b_dispatch {BUSES};
param bus_area       {BUSES};

param generator_cost_square_component{BUSES};
param generator_cost_linear_component{BUSES};
param generator_cost_constant_component{BUSES};

param contingency_from {CONTINGENCIES};
param contingency_to {CONTINGENCIES};

param LODF{LODF_INDICES};

param line_g {(l,k,m) in LINES} := line_r[l,k,m]/(line_r[l,k,m]^2+line_x[l,k,m]^2); #Line Conductance
param losses;
param max_delta;
param dist_losses{BUSES}; 

param p_max{(l,k,m) in LINES} := max_delta*3.14159/(2*line_x[l,k,m]); # Determines power flow limits for the lines

var bus_angle   {i in BUSES}; # Voltage Phase angle
var line_def  {(l,k,m) in LINES} >= line_def_min[l,k,m], <= line_def_max[l,k,m]; # Phase shifters

var p_d {LINES}; # Forward active power flow (helper data structure)
var p_r {LINES}; # Reverse active power flow (helper data structure)

var p_d_contingency {CONTINGENCIES cross LINES}; # Forward active power flow under contingency (helper data structure)
var p_r_contingency {CONTINGENCIES cross LINES}; # Forward active power flow under contingency (helper data structure)

# Bus Admittance Matrix
set B_INDICES := setof{i in BUSES} (i,i) union 
setof {(l,k,m) in LINES} (k,m) union
setof {(l,k,m) in LINES} (m,k);
   
param B{(k,m) in B_INDICES} :=
if(k == m)
         then ( sum{(l,k,i) in LINES} (1/line_x[l,k,i])  #  DIAGONAL
               +sum{(l,i,k) in LINES} (1/line_x[l,i,k]))
else if(k != m) 
         then (-sum{(l,k,m) in LINES} 1/line_x[l,k,m] # OFF DIAGONAL
               -sum{(l,m,k) in LINES} 1/line_x[l,m,k]);


#Decision variable p_g for each bus. Represents the generated power
var p_g {k in BUSES} = bus_p_load[k] + dist_losses[k] + sum{(k,m) in B_INDICES} 
   (B[k,m]*(bus_angle[k]-bus_angle[m]+sum{(l,k,m) in LINES} line_def[l,k,m]+sum{(l,m,k) in LINES} -line_def[l,m,k]));
   

#Objective (Cost) Function: Added Generator Costs
minimize generation_costs: sum {bus in BUSES : bus_type[bus] == 2 || bus_type[bus] == 3}  
   (generator_cost_square_component[bus]*p_g[bus]^2 + generator_cost_linear_component[bus]*p_g[bus] + generator_cost_constant_component[bus]);


#Power Balance Constraints 
subject to p_load {k in BUSES : bus_type[k] == 0}:
   bus_p_gen[k] - bus_p_load[k] - dist_losses[k] - sum{(k,m) in B_INDICES} 
      (B[k,m]*(bus_angle[k]-bus_angle[m]+sum{(l,k,m) in LINES} line_def[l,k,m]+sum{(l,m,k) in LINES} -line_def[l,m,k] )) = 0;


#Generator Upper Limits 
subject to p_gen {bus in BUSES : bus_type[bus] == 2 || bus_type[bus] == 3}:
   0  <= p_g[bus] <= bus_p_gen[bus];


#Line Flow Constraints (Maximum Permissible Flow)
subject to p_flow {(l,k,m) in LINES}:
   -p_max[l,k,m] 
      <= (bus_angle[k]-bus_angle[m]+sum{(i,k,m) in LINES} line_def[i,k,m] + sum{(i,m,k) in LINES} -line_def[i,m,k])/line_x[l,k,m]
         <= p_max[l,k,m]; 


#Extra Security Constraints 
subject to p_contingency_flow {(l,k,m,a,b,c) in CONTINGENCIES cross LINES : l!=a and k!= b and m!=c}:
   -p_max[a,b,c] 
      <= ((bus_angle[b]-bus_angle[c]+sum{(i,b,c) in LINES} line_def[i,b,c] + sum{(i,c,b) in LINES} -line_def[i,c,b])/line_x[a,b,c])
         + LODF[a,l] * (bus_angle[k]-bus_angle[m]+sum{(i,k,m) in LINES} line_def[i,k,m] + sum{(i,m,k) in LINES} -line_def[i,m,k])/line_x[l,k,m]
            <= p_max[a,b,c];