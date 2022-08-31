from string import Template


DATA_FILE_TEMPLATE = Template(r''' 
data;
param: BUSES: bus_type bus_name bus_voltage bus_angle0 bus_p_gen bus_q_gen
               bus_q_min bus_q_max bus_p_load bus_q_load bus_g_shunt bus_b_shunt
               bus_b_shunt_min bus_b_shunt_max bus_b_dispatch bus_area := 
$bus_data;

param: LINES: line_type line_r line_x line_c
               line_tap line_tap_min line_tap_max line_def0 
               line_def_min line_def_max :=
$line_data;

set CONTINGENCIES:=
$contingency_data;

param LODF:=
$lodf_data;

param: generator_cost_square_component generator_cost_linear_component generator_cost_constant_component:=
$cost_data;

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


let losses := sum {(l,k,m) in LINES} line_g[l,k,m]*(bus_angle[k]-bus_angle[m]+line_def[l,k,m])^2;
param active_load := sum {bus in BUSES} abs(bus_p_load[bus]); 

for{bus in BUSES} {
   let dist_losses[bus] := abs(bus_p_load[bus])*losses/active_load; # Distribute total loss to each bus
};


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
  ''')