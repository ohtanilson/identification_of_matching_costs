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
want_to_run_safety_level_check = false
want_to_run_plot_across_importance_weight_lambda = false
want_to_run_all_estimations_different_penalty = true

sd_temp = 1.0
benchmark_β = 0.5
temp_true_β = [benchmark_β, -2.0]
temp_means  = [3.0, 3.0, 3.0]
temp_covars = [1 0.25 0.25;
		       0.25 1 0.25;
		       0.25 0.25 1]
#------------------------------#
# safety level check
#------------------------------#
model_list = [false false] # (U)
num_agents_list = [10, 20, 30, 50, 100]
true_β_list = [-1.0:-0.1:-3.0;] # finer grids
importance_weight_lambda = 100
# with IR
global temp_dummy_included = true
global temp_IR_condition_included = true
global dummy_index = "with_dummy"
global IR_index = "with_IR"
if want_to_run_safety_level_check == true
    include("compute_two_param_safety_level_check.jl")
end
#-------------------------------------------------#
# Plot two param under different penalty levels
#-------------------------------------------------#
# with IR
if want_to_run_plot_across_importance_weight_lambda == true
	global temp_dummy_included = true
	global temp_IR_condition_included = true
	global dummy_index = "with_dummy"
	global IR_index = "with_IR"
	temp_random_seed = 1
	num_agents_temp = 100
	domain1 = [0.1:0.005:1.1;]
	domain2 = [-3.0:0.015:-0.0;]
	safety_level_check = true
	temp_true_β = [0.5 -2]
	different_beta_plot = false
	importance_weight_lambda = 1
	include("plot_two_param.jl")
	importance_weight_lambda = 10
	include("plot_two_param.jl")
	importance_weight_lambda = 25
	include("plot_two_param.jl")
	importance_weight_lambda = 50
	include("plot_two_param.jl")

	temp_true_β = [0.5 -1]
	different_beta_plot = true
	importance_weight_lambda = 1
	include("plot_two_param.jl")
	importance_weight_lambda = 10
	include("plot_two_param.jl")
	importance_weight_lambda = 25
	include("plot_two_param.jl")
	importance_weight_lambda = 50
	include("plot_two_param.jl")
end


#-------------------------------------------------#
# Estimation of two param under different penalty levels
#-------------------------------------------------#
model_list = [true false; # (TU)
              true true; # (T)
              false false; # (U)
			  false true # (None)
			  ]
different_beta_plot = false
if want_to_run_all_estimations_different_penalty == true
	safety_level_check = false
	different_penalty_level_check = true
	importance_weight_lambda = 1
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

	importance_weight_lambda = 2
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
	importance_weight_lambda = 5
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
	importance_weight_lambda = 10
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
	importance_weight_lambda = 20
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
