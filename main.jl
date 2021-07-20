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
arbitrary_high_IR_violation = 100
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
domain1 = [-3:0.1:3;]
domain2 = [-3:0.1:3;]

if want_to_run_all_plots == true
    plots_all(dimension = 2)
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

#------------------------------#
# safety level check
#------------------------------#
model_list = [false false] # (U)
num_agents_list = [10, 20, 30, 50, 100]
true_β_list = [-1.0:-0.1:-3.0;] # finer grids
# with IR
global temp_dummy_included = true
global temp_IR_condition_included = true
global dummy_index = "with_dummy"
global IR_index = "with_IR"
include("compute_two_param_safety_level_check.jl")

#-------------------------------------------------#
# Plot two param under different penalty levels
#-------------------------------------------------#
# with IR
global temp_dummy_included = true
global temp_IR_condition_included = true
global dummy_index = "with_dummy"
global IR_index = "with_IR"
safety_level_check = true
arbitrary_high_IR_violation = 1
include("plot_two_param.jl")
arbitrary_high_IR_violation = 10
include("plot_two_param.jl")
arbitrary_high_IR_violation = 25
include("plot_two_param.jl")
arbitrary_high_IR_violation = 50
include("plot_two_param.jl")


#-------------------------------------------------#
# Estimation of two param under different penalty levels
#-------------------------------------------------#

if want_to_run_all_estimations_different_penalty == true
	safety_level_check = false
	different_penalty_level_check = true
	arbitrary_high_IR_violation = 1
	estimate_two_param_all_different_penalty(;
	                        sd_temp = 1.0,
	                        benchmark_β = 0.5,
	                        temp_true_β = [0.5, -2.0],
	                        temp_means  = [3.0, 3.0, 3.0],
	                        temp_covars = [1 0.25 0.25;
	                                       0.25 1 0.25;
	                                       0.25 0.25 1],
	                        num_agents_list = [10, 20, 30, 50, 100],
	                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])

	arbitrary_high_IR_violation = 2
	estimate_two_param_all_different_penalty(;
	                        sd_temp = 1.0,
	                        benchmark_β = 0.5,
	                        temp_true_β = [0.5, -2.0],
	                        temp_means  = [3.0, 3.0, 3.0],
	                        temp_covars = [1 0.25 0.25;
	                                       0.25 1 0.25;
	                                       0.25 0.25 1],
	                        num_agents_list = [10, 20, 30, 50, 100],
	                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
	arbitrary_high_IR_violation = 5
	estimate_two_param_all_different_penalty(;
	                        sd_temp = 1.0,
	                        benchmark_β = 0.5,
	                        temp_true_β = [0.5, -2.0],
	                        temp_means  = [3.0, 3.0, 3.0],
	                        temp_covars = [1 0.25 0.25;
	                                       0.25 1 0.25;
	                                       0.25 0.25 1],
	                        num_agents_list = [10, 20, 30, 50, 100],
	                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
	arbitrary_high_IR_violation = 10
	estimate_two_param_all_different_penalty(;
	                        sd_temp = 1.0,
	                        benchmark_β = 0.5,
	                        temp_true_β = [0.5, -2.0],
	                        temp_means  = [3.0, 3.0, 3.0],
	                        temp_covars = [1 0.25 0.25;
	                                       0.25 1 0.25;
	                                       0.25 0.25 1],
	                        num_agents_list = [10, 20, 30, 50, 100],
	                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
	arbitrary_high_IR_violation = 20
	estimate_two_param_all_different_penalty(;
	                        sd_temp = 1.0,
	                        benchmark_β = 0.5,
	                        temp_true_β = [0.5, -2.0],
	                        temp_means  = [3.0, 3.0, 3.0],
	                        temp_covars = [1 0.25 0.25;
	                                       0.25 1 0.25;
	                                       0.25 0.25 1],
	                        num_agents_list = [10, 20, 30, 50, 100],
	                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
end
