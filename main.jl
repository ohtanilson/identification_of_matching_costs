using CSV
using Plots
using JuMP#, Ipopt
using Random
using Distributions
using LinearAlgebra
using Dates
using DataFrames
using Gurobi
using DataFramesMeta
using Combinatorics
using Optim
using BlackBoxOptim # on behalf of DEoptim
using LaTeXTabulars
using LaTeXStrings
using DelimitedFiles
include("functions_plot_identification_power_with_score_function.jl")

# setup implementation
want_to_run_all_plots = true
want_to_run_all_estimations = true
want_to_run_safety_level_check = true
want_to_run_all_estimations_different_penalty = true
#----------------------#
# single variable plots
#----------------------#
#model = [withtrans, use_only_matched_data]
model_list = [true false; # (TU)
              true true; # (T)
              false false; # (U)
			  false true # (None)
			  ]
safety_level_check = false
different_penalty_level_check = false
num_agents_temp = 100
sd_temp = 1.0
temp_true_β = -2.0
temp_means  = [3.0, 3.0]
temp_covars = [1 0.25;
		       0.25 1]
temp_random_seed = 1
importance_weight_lambda = 100
domain1 = [-3:0.05:2;]
domain2 = [-3:0.05:2;]
if want_to_run_all_plots == true
    plots_all(dimension = 1)
end

#--------------------#
# two variables plots
#--------------------#
num_agents_temp = 100
sd_temp = 1.0
benchmark_β = 0.5
temp_true_β = [benchmark_β, -2.0]
temp_means  = [3.0, 3.0, 3.0]
temp_covars = [1 0.25 0.25;
		       0.25 1 0.25;
		       0.25 0.25 1]
domain1 = [0.1:0.005:1.1;]
domain2 = [-3.0:0.015:-0.0;]

if want_to_run_all_plots == true
    @time plots_all(dimension = 2)
end
#---------------#
# Estimation
#---------------#
#--------------------#
# single variable
#--------------------#
sd_temp = 1.0
temp_means  = [3.0, 3.0]
temp_covars = [1 0.25;
		       0.25 1]
num_agents_list = [10, 20, 30, 50, 100]
true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0]
if want_to_run_all_estimations == true
   estimate_single_param_all(
               sd_temp = 1.0,
			   temp_means  = [3.0, 3.0],
			   temp_covars = [1 0.25;
			    		       0.25 1],
			   num_agents_list = [10, 20, 30, 50, 100],
			   true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
end
#--------------------#
# two variables
#--------------------#
sd_temp = 1.0
benchmark_β = 0.5
temp_true_β = [benchmark_β, -2.0]
temp_means  = [3.0, 3.0, 3.0]
temp_covars = [1 0.25 0.25;
		       0.25 1 0.25;
		       0.25 0.25 1]
num_agents_list = [10, 20, 30, 50, 100]
true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0]
if want_to_run_all_estimations == true
	estimate_two_param_all(sd_temp = 1.0,
	                        benchmark_β = 0.5,
	                        temp_true_β = [benchmark_β, -2.0],
	                        temp_means  = [3.0, 3.0, 3.0],
	                        temp_covars = [1 0.25 0.25;
	                                       0.25 1 0.25;
	                                       0.25 0.25 1],
	                        num_agents_list = [10, 20, 30, 50, 100],
	                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
end
