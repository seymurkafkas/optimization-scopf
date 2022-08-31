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


#File IO / Read Bus, Line, Contingency, LODF and Cost Data from files
data;

param: BUSES: bus_type bus_name bus_voltage bus_angle0 bus_p_gen bus_q_gen
               bus_q_min bus_q_max bus_p_load bus_q_load bus_g_shunt bus_b_shunt
               bus_b_shunt_min bus_b_shunt_max bus_b_dispatch bus_area := 
include IEEE14.bus;

param: LINES: line_type line_r line_x line_c
               line_tap line_tap_min line_tap_max line_def0 
               line_def_min line_def_max :=
include IEEE14.line;

set CONTINGENCIES:=
include IEEE14.contingency;

param LODF:=
include IEEE14.lodf;

param: generator_cost_square_component generator_cost_linear_component generator_cost_constant_component:=
include IEEE14.cost;
   
# Defines the maximum permissible phase difference across lines (Therefore defining the line overflow limits)
let max_delta := 0.05;

# Unit conversion for model parameters (degrees to radians, base to pu)
for{bus in BUSES} {
   let bus_p_gen[bus] := bus_p_gen[bus]/100;
   let bus_q_gen[bus] := bus_q_gen[bus]/100;
   let bus_q_min[bus] := bus_q_min[bus]/100;
   let bus_q_max[bus] := bus_q_max[bus]/100;
   let bus_angle[bus] := bus_angle0[bus]*3.14159/180;
   let bus_p_load[bus] := bus_p_load[bus]/100;
   let bus_q_load[bus] := bus_q_load[bus]/100;
   let dist_losses[bus] := 0;
};
   
for{(l,k,m) in LINES} {
   let line_def[l,k,m] := -line_def0[l,k,m]*3.14159/180;  #degree to radians
   let line_def_min[l,k,m] := line_def_min[l,k,m]*3.14159/180; #degree to radians
   let line_def_max[l,k,m] := line_def_max[l,k,m]*3.14159/180; # degree to radians
};

fix {bus in BUSES : bus_type[bus] == 3} bus_angle[bus]; # Fix the slack phase angle (Frame of reference)
fix {(l,k,m) in LINES: line_type[l,k,m] !=4} line_def[l,k,m];

option minos_options "summary_file=6 timing=1";

solve;

let losses := sum {(l,k,m) in LINES} line_g[l,k,m]*(bus_angle[k]-bus_angle[m]+line_def[l,k,m])^2;
param active_load := sum {bus in BUSES} abs(bus_p_load[bus]); 

for{bus in BUSES} {
   let dist_losses[bus] := abs(bus_p_load[bus])*losses/active_load; # Distribute total loss to each bus
};
   
solve;

##################################################################
#The remaining code corresponds to printing utilities and loggers#
##################################################################
# Calculates both active and reactive direct and reverse fluxes
for{(l,k,m) in LINES} {
   let p_d[l,k,m] := (bus_angle[k]-bus_angle[m]+line_def[l,k,m])/line_x[l,k,m];
   let p_r[l,k,m] := - p_d[l,k,m];
}

for{(l,k,m,a,b,c) in CONTINGENCIES cross LINES} {
   let p_d_contingency[l,k,m,a,b,c] := ((bus_angle[b]-bus_angle[c]+sum{(i,b,c) in LINES} line_def[i,b,c] + sum{(i,c,b) in LINES} -line_def[i,c,b])/line_x[a,b,c])
   + LODF[a,l] * (bus_angle[k]-bus_angle[m]+sum{(i,k,m) in LINES} line_def[i,k,m] + sum{(i,m,k) in LINES} -line_def[i,m,k])/line_x[l,k,m];
   let p_r_contingency[l,k,m,a,b,c] := - p_d_contingency[l,k,m,a,b,c];
}

# Loggers and Printing Utilities. Adapted from https://vanderbei.princeton.edu/ampl/nlmodels/power/#
printf "Objective (Cost)  %8.2f\n", sum {bus in BUSES : bus_type[bus] == 2 || bus_type[bus] == 3} 
   (generator_cost_square_component[bus]*p_g[bus]^2 + generator_cost_linear_component[bus]*p_g[bus] + generator_cost_constant_component[bus]) > scopf_result.txt;
printf "Total Losses  %8.2f MW\n", losses*100 >> scopf_result.txt;
printf "Active Generation %8.2f MW\n", sum {k in BUSES} p_g[k]*100 >> scopf_result.txt;
printf "  #      Name    Voltage  Angle     PGen    PLoad  #Line  To    PFlux     Pmax\n" >> scopf_result.txt;
printf "-----------------------------------------------------------------------\n" >> scopf_result.txt; 

for{i in BUSES} {
   printf "%4d %s %6.4f %6.2f %8.2f %8.2f", i, bus_name[i], bus_voltage[i], bus_angle[i]*180/3.14159,
   p_g[i]*100, bus_p_load[i]*100 >> scopf_result.txt;

   printf " ------------\n" >> scopf_result.txt;

   for{(l,i,m) in LINES} 
   printf "%48s %4d %4d %8.2f %8.2f \n", "", l, m, p_d[l,i,m]*100, 100*p_max[l,i,m] >> scopf_result.txt;

   for{(l,k,i) in LINES} 
   printf "%48s %4d %4d %8.2f %8.2f\n", "", l, k, p_r[l,k,i]*100, 100*p_max[l,k,i] >> scopf_result.txt;
}

# Generates contingency logs
for {(a,b,c) in CONTINGENCIES} {
   printf "CONTINGENCY OF BRANCH %d \n", a > contingency_result.txt;
   printf "Active Generation %8.2f MW\n", sum {k in BUSES} p_g[k]*100 >> contingency_result.txt;
   printf "  #      Name    Voltage  Angle     PGen    PLoad  #Line  To    PFlux     Pmax\n" >> contingency_result.txt;
   printf "-----------------------------------------------------------------------\n" >> contingency_result.txt; 

   for{i in BUSES} {
      printf "%4d %s %6.4f %6.2f %8.2f %8.2f", i, bus_name[i], bus_voltage[i], bus_angle[i]*180/3.14159,
      p_g[i]*100, bus_p_load[i]*100 >> contingency_result.txt;

      printf " ------------\n" >> contingency_result.txt;

      for{(l,i,m) in LINES} 
      printf "%48s %4d %4d %8.2f %8.2f \n", "", l,m, p_d_contingency[a,b,c,l,i,m]*100, 100*p_max[l,i,m] >> contingency_result.txt;

      for{(l,k,i) in LINES} 
      printf "%48s %4d %4d %8.2f %8.2f\n", "", l,k, p_r_contingency[a,b,c,l,k,i]*100, 100*p_max[l,k,i] >> contingency_result.txt;
   }
}