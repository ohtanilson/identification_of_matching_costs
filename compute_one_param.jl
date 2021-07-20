res_mean_list = zeros(4, length(num_agents_list), length(true_β_list))
res_bias_list = zeros(4, length(num_agents_list), length(true_β_list))
res_sqrt_list = zeros(4, length(num_agents_list), length(true_β_list))
mean_matched_num_list = zeros(4, length(num_agents_list), length(true_β_list))
mean_unmatched_num_list = zeros(4, length(num_agents_list), length(true_β_list))
JULIA_NUM_THREADS=8
@time for i in 1:length(num_agents_list), j in 1:length(true_β_list)
	iter_num_agents = num_agents_list[i]
	iter_true_β = true_β_list[j]
	Threads.@threads for k in 1:size(model_list)[1]
		iter_withtrans, iter_use_only_matched_data = model_list[k,:]
		res1,res2,res3,res4,res5 = maxscore_mc(num_agents = iter_num_agents,
		                        temp_true_β = iter_true_β,
								sd_err = sd_temp,
								means  = temp_means,
			                    covars = temp_covars,
		                        withtrans = iter_withtrans,
								use_only_matched_data = iter_use_only_matched_data,
								dummy_included = temp_dummy_included,
								IR_condition_included = temp_IR_condition_included)
		res_mean_list[k,i,j] = res1
		res_bias_list[k,i,j] = res2
		res_sqrt_list[k,i,j] = res3
		mean_matched_num_list[k,i,j] = res4
		mean_unmatched_num_list[k,i,j] = res5
	end
	# restore results
	# restore results
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
		open("julia_results/res_mean_list_model_$(k)_$(dummy_index)_$(IR_index).txt", "w") do io
			DelimitedFiles.writedlm(io, res_mean_list[k,:,:],",")
		end
		open("julia_results/res_bias_list_model_$(k)_$(dummy_index)_$(IR_index).txt", "w") do io
			DelimitedFiles.writedlm(io, res_bias_list[k,:,:],",")
		end
		open("julia_results/res_sqrt_list_model_$(k)_$(dummy_index)_$(IR_index).txt", "w") do io
			DelimitedFiles.writedlm(io, res_sqrt_list[k,:,:],",")
		end
		open("julia_results/mean_matched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt", "w") do io
			DelimitedFiles.writedlm(io, mean_matched_num_list[k,:,:],",")
		end
		open("julia_results/mean_unmatched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt", "w") do io
			DelimitedFiles.writedlm(io, mean_unmatched_num_list[k,:,:],",")
		end
	end
	#95.696645 seconds (1.69 G allocations: 123.763 GiB, 15.61% gc time, 0.16% compilation time)
end
