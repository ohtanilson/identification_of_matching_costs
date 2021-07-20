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
	if different_penalty_level_check == true
		for k in 1:size(model_list)[1]
			open("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, res_mean_list_beta1[k,:,:],",")
			end
			open("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, res_bias_list_beta1[k,:,:],",")
			end
			open("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, res_sqrt_list_beta1[k,:,:],",")
			end
			open("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, res_mean_list_beta2[k,:,:],",")
			end
			open("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, res_bias_list_beta2[k,:,:],",")
			end
			open("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, res_sqrt_list_beta2[k,:,:],",")
			end
			open("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, mean_matched_num_list[k,:,:],",")
			end
			open("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt", "w") do io
				DelimitedFiles.writedlm(io, mean_unmatched_num_list[k,:,:],",")
			end
		end
	else
		for k in 1:size(model_list)[1]
			open("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, res_mean_list_beta1[k,:,:],",")
			end
			open("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, res_bias_list_beta1[k,:,:],",")
			end
			open("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, res_sqrt_list_beta1[k,:,:],",")
			end
			open("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, res_mean_list_beta2[k,:,:],",")
			end
			open("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, res_bias_list_beta2[k,:,:],",")
			end
			open("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, res_sqrt_list_beta2[k,:,:],",")
			end
			open("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, mean_matched_num_list[k,:,:],",")
			end
			open("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt", "w") do io
				DelimitedFiles.writedlm(io, mean_unmatched_num_list[k,:,:],",")
			end
		end
	end
	#95.696645 seconds (1.69 G allocations: 123.763 GiB, 15.61% gc time, 0.16% compilation time)
end
