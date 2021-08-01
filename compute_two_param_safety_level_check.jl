res_mean_list_beta1 = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
res_bias_list_beta1 = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
res_sqrt_list_beta1 = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
res_mean_list_beta2 = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
res_bias_list_beta2 = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
res_sqrt_list_beta2 = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
mean_matched_num_list = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
mean_unmatched_num_list = zeros(size(model_list)[1], length(num_agents_list), length(true_β_list))
JULIA_NUM_THREADS=8
@time for i = 1:length(num_agents_list), j = 1:length(true_β_list)
	iter_num_agents = num_agents_list[i]
	iter_true_β = vcat(benchmark_β, true_β_list[j])
	Threads.@threads for k = 1:size(model_list)[1]
		iter_withtrans, iter_use_only_matched_data = model_list[k,:]
		res1,res2,res3,res4,res5 = maxscore_mc2(num_agents = iter_num_agents,
		                        temp_true_β = iter_true_β,
								sd_err = sd_temp,
								means  = temp_means,
			                    covars = temp_covars,
								num_its = 100,
		                        withtrans = iter_withtrans,
								use_only_matched_data = iter_use_only_matched_data,
								dummy_included = temp_dummy_included,
								IR_condition_included = temp_IR_condition_included)
		res_mean_list_beta1[k,i,j] = res1[1]
		res_bias_list_beta1[k,i,j] = res2[1]
		res_sqrt_list_beta1[k,i,j] = res3[1]
		res_mean_list_beta2[k,i,j] = res1[2]
		res_bias_list_beta2[k,i,j] = res2[2]
		res_sqrt_list_beta2[k,i,j] = res3[2]
		mean_matched_num_list[k,i,j] = res4
		mean_unmatched_num_list[k,i,j] = res5
	end
	#restore results
	if temp_IR_condition_included == true
		IR_index = "with_IR"
	else
		IR_index = "without_IR"
	end
	if temp_dummy_included == true
		dummy_index = "with_dummy"
	else
		dummy_index = "without_dummy"
	end
	for k in 1:size(model_list)[1]
		open("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, res_mean_list_beta1[k,:,:],",")
		end
		open("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, res_bias_list_beta1[k,:,:],",")
		end
		open("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, res_sqrt_list_beta1[k,:,:],",")
		end
		open("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, res_mean_list_beta2[k,:,:],",")
		end
		open("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, res_bias_list_beta2[k,:,:],",")
		end
		open("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, res_sqrt_list_beta2[k,:,:],",")
		end
		open("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, mean_matched_num_list[k,:,:],",")
		end
		open("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_safety_level_check.txt", "w") do io
			DelimitedFiles.writedlm(io, mean_unmatched_num_list[k,:,:],",")
		end
	end
	#95.696645 seconds (1.69 G allocations: 123.763 GiB, 15.61% gc time, 0.16% compilation time)
end
# read results
for k = 1:size(model_list)[1]
  res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64), digits =2)
  res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64) , digits =2)
  res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64), digits =2)
  res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64), digits =2)
  res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64) , digits =2)
  res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64), digits =2)
  mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64), digits =2)
  mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_safety_level_check.txt",',',Float64), digits =2)
end

global bias_list = vcat("","U","Bias",res_bias_list_beta1[1,:,1],
                 "", res_bias_list_beta2[1,:,1])
for tt = 2:size(res_bias_list_beta1)[3]
	temp = vcat("","U","Bias",res_bias_list_beta1[1,:,tt],
	"", res_bias_list_beta2[1,:,tt])
	global bias_list = hcat(bias_list, temp)
end

global RMSE_list = vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,1]))", "($(res_sqrt_list_beta1[1,2,1]))",
	 "($(res_sqrt_list_beta1[1,3,1]))", "($(res_sqrt_list_beta1[1,4,1]))", "($(res_sqrt_list_beta1[1,5,1]))",
	 "",
	 "($(res_sqrt_list_beta2[1,1,1]))", "($(res_sqrt_list_beta2[1,2,1]))",
	 "($(res_sqrt_list_beta2[1,3,1]))", "($(res_sqrt_list_beta2[1,4,1]))", "($(res_sqrt_list_beta2[1,5,1]))")
for tt = 2:size(res_sqrt_list_beta1)[3]
	temp = vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,tt]))", "($(res_sqrt_list_beta1[1,2,tt]))",
		 "($(res_sqrt_list_beta1[1,3,tt]))", "($(res_sqrt_list_beta1[1,4,tt]))", "($(res_sqrt_list_beta1[1,5,tt]))",
		 "",
		 "($(res_sqrt_list_beta2[1,1,tt]))", "($(res_sqrt_list_beta2[1,2,tt]))",
		 "($(res_sqrt_list_beta2[1,3,tt]))", "($(res_sqrt_list_beta2[1,4,tt]))", "($(res_sqrt_list_beta2[1,5,tt]))")
	global RMSE_list = hcat(RMSE_list, temp)
end

LaTeXTabulars.latex_tabular("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index)_safety_level_check_model_T.tex",
			  Tabular("@{\\extracolsep{5pt}}lc|cccccc|lccccc"),
			  [Rule(:top),
			   ["","Num of agents","",
				num_agents_list[1], num_agents_list[2],
				num_agents_list[3], num_agents_list[4],
				num_agents_list[5],
		        "", num_agents_list[1], num_agents_list[2],
				num_agents_list[3], num_agents_list[4],
				num_agents_list[5]],
			   [L"\beta_1","","",
		        "", "", "", "", "",
		        L"\beta_2", "", "", "", "", ""],
			   Rule(:mid),
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,1],
			   true_β_list[1],
			   mean_unmatched_num_list[1,:,1]),
			   bias_list[:,1],
			   RMSE_list[:,1],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,2],
			   true_β_list[2],
			   mean_unmatched_num_list[1,:,2]),
			   bias_list[:,2],
			   RMSE_list[:,2],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,3],
			   true_β_list[3],
			   mean_unmatched_num_list[1,:,3]),
			   bias_list[:,3],
			   RMSE_list[:,3],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,4],
			   true_β_list[4],
			   mean_unmatched_num_list[1,:,4]),
			   bias_list[:,4],
			   RMSE_list[:,4],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,5],
			   true_β_list[5],
			   mean_unmatched_num_list[1,:,5]),
			   bias_list[:,5],
			   RMSE_list[:,5],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,6],
			   true_β_list[6],
			   mean_unmatched_num_list[1,:,6]),
			   bias_list[:,6],
			   RMSE_list[:,6],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,7],
			   true_β_list[7],
			   mean_unmatched_num_list[1,:,7]),
			   bias_list[:,7],
			   RMSE_list[:,7],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,8],
			   true_β_list[8],
			   mean_unmatched_num_list[1,:,8]),
			   bias_list[:,8],
			   RMSE_list[:,8],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,9],
			   true_β_list[9],
			   mean_unmatched_num_list[1,:,9]),
			   bias_list[:,9],
			   RMSE_list[:,9],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,10],
			   true_β_list[10],
			   mean_unmatched_num_list[1,:,10]),
			   bias_list[:,10],
			   RMSE_list[:,10],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,11],
			   true_β_list[11],
			   mean_unmatched_num_list[1,:,11]),
			   bias_list[:,11],
			   RMSE_list[:,11],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,12],
			   true_β_list[12],
			   mean_unmatched_num_list[1,:,12]),
			   bias_list[:,12],
			   RMSE_list[:,12],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,13],
			   true_β_list[13],
			   mean_unmatched_num_list[1,:,13]),
			   bias_list[:,13],
			   RMSE_list[:,13],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,14],
			   true_β_list[14],
			   mean_unmatched_num_list[1,:,14]),
			   bias_list[:,14],
			   RMSE_list[:,14],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,15],
			   true_β_list[15],
			   mean_unmatched_num_list[1,:,15]),
			   bias_list[:,15],
			   RMSE_list[:,15],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,16],
			   true_β_list[16],
			   mean_unmatched_num_list[1,:,16]),
			   bias_list[:,16],
			   RMSE_list[:,16],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,17],
			   true_β_list[17],
			   mean_unmatched_num_list[1,:,17]),
			   bias_list[:,17],
			   RMSE_list[:,17],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,18],
			   true_β_list[18],
			   mean_unmatched_num_list[1,:,18]),
			   bias_list[:,18],
			   RMSE_list[:,18],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,19],
			   true_β_list[19],
			   mean_unmatched_num_list[1,:,19]),
			   bias_list[:,19],
			   RMSE_list[:,19],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,20],
			   true_β_list[20],
			   mean_unmatched_num_list[1,:,20]),
			   bias_list[:,20],
			   RMSE_list[:,20],
			   # ---------
			   vcat(benchmark_β,"unmatched","Mean Num",
	           mean_unmatched_num_list[1,:,21],
			   true_β_list[21],
			   mean_unmatched_num_list[1,:,21]),
			   bias_list[:,21],
			   RMSE_list[:,21],
			   #
			   ["","", "", "","", "", "", "",
	            "", "","", "", "", ""],
			   Rule(),           # a nice \hline to make it ugly
			   Rule(:bottom)])
