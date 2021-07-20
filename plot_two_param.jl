data = givemedata2(num_agents_temp,
				   sd_temp,
				   temp_true_β,
				   means  = temp_means,
				   covars = temp_covars,
				   random_seed = temp_random_seed,
				   dummy_included = temp_dummy_included)
@show matched_num = Int(sum(data.matches))
@show unmatched_num = num_agents_temp - matched_num
data.mval
@linq data_only_matched = data |>
  where(:matches .== 1.0)
res_contor = zeros(length(domain1),length(domain2))
res_contor_only_matched = zeros(length(domain1),length(domain2))
res_contor_with = zeros(length(domain1),length(domain2))
res_contor_with_only_matched = zeros(length(domain1),length(domain2))
@time for i in 1:length(domain1), j in 1:length(domain2)
	#@show i,j
	res_contor[i,j] = score_b_non([domain1[i],domain2[j]],
							  data,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
	global max_index_res_contor = vcat(domain1[findmax(res_contor)[2][1]],
					  domain2[findmax(res_contor)[2][2]])
	res_contor_only_matched[i,j] = score_b_non([domain1[i],domain2[j]],
							  data_only_matched,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
	global max_index_res_contor_only_matched = vcat(domain1[findmax(res_contor_only_matched)[2][1]],
					  domain2[findmax(res_contor_only_matched)[2][2]])
	res_contor_with[i,j] = score_b_with_non([domain1[i], domain2[j]],
							  data,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
	global max_index_res_contor_with = vcat(domain1[findmax(res_contor_with)[2][1]],
					  domain2[findmax(res_contor_with)[2][2]])
	res_contor_with_only_matched[i,j] = score_b_with_non([domain1[i], domain2[j]],
							  data_only_matched,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
	global max_index_res_contor_with_only_matched = vcat(domain1[findmax(res_contor_with_only_matched)[2][1]],
					  domain2[findmax(res_contor_with_only_matched)[2][2]])
end

if safety_level_check == true
	if different_beta_plot == true
		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 3 (U)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2, res_contor',fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor)[1].==res_contor)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		# scatter!([max_index_res_contor[1]],
		#          [max_index_res_contor[2]],
		#          label="Maximum ($(max_index_res_contor[1]),$(max_index_res_contor[2]))")
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_without_transfer_with_unmatched_$(IR_index)_beta_2_minus1_penalty_level_$(importance_weight_lambda)")

		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 4 (None)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2,
					   res_contor_only_matched',
					   fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor_only_matched)[1].==res_contor_only_matched)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		# scatter!([max_index_res_contor_only_matched[1]],
		#          [max_index_res_contor_only_matched[2]],
		#          label="Maximum ($(max_index_res_contor_only_matched[1]),$(max_index_res_contor_only_matched[2]))")
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_without_transfer_without_unmatched_$(IR_index)_beta_2_minus1_penalty_level_$(importance_weight_lambda)")

		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 1 (U, T)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2, res_contor_with',fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor_with)[1].==res_contor_with)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		# scatter!([max_index_res_contor_with[1]],
		#          [max_index_res_contor_with[2]],
		#          label="Maximum ($(max_index_res_contor_with[1]),$(max_index_res_contor_with[2]))")
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_with_transfer_with_unmatched_$(IR_index)_beta_2_minus1_penalty_level_$(importance_weight_lambda)")

		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 2 (T)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2,
				   res_contor_with_only_matched',fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor_with_only_matched)[1].==res_contor_with_only_matched)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		# scatter!([max_index_res_contor_with_only_matched[1]],
		#          [max_index_res_contor_with_only_matched[2]],
		#          label="Maximum ($(max_index_res_contor_with_only_matched[1]),$(max_index_res_contor_with_only_matched[2]))")
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_with_transfer_without_unmatched_$(IR_index)_beta_2_minus1_penalty_level_$(importance_weight_lambda)")
	else
		# beta2 is scaled down for illustration
		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 3 (U)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2, res_contor',fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor)[1].==res_contor)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_without_transfer_with_unmatched_$(IR_index)_penalty_level_$(importance_weight_lambda)")

		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 4 (None)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2,
					   res_contor_only_matched',
					   fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor_only_matched)[1].==res_contor_only_matched)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		# scatter!([max_index_res_contor_only_matched[1]],
		# 		 [max_index_res_contor_only_matched[2]],
		# 		 label="Maximum ($(max_index_res_contor_only_matched[1]),$(max_index_res_contor_only_matched[2]))")
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_without_transfer_without_unmatched_$(IR_index)_penalty_level_$(importance_weight_lambda)")

		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 1 (U, T)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2, res_contor_with',fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor_with)[1].==res_contor_with)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		# scatter!([max_index_res_contor_with[1]],
		# 		 [max_index_res_contor_with[2]],
		# 		 label="Maximum ($(max_index_res_contor_with[1]),$(max_index_res_contor_with[2]))")
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_with_transfer_with_unmatched_$(IR_index)_penalty_level_$(importance_weight_lambda)")

		Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 2 (T)",
				   legend = :topright,
				   xlabel = "β₁ (importance weight = $(importance_weight_lambda))",
				   ylabel = "β₂ × 1/8")
		Plots.contour!(domain1, domain2,
				   res_contor_with_only_matched',fill = true)
		Plots.vline!([temp_true_β[1]], label="true β₁",
				   linestyle = :dash,
				   color = :black)
		Plots.hline!([temp_true_β[2]], label="true β₂",
				   linestyle = :dash,
				   color = :black)
		max_index = findall(findmax(res_contor_with_only_matched)[1].==res_contor_with_only_matched)
		for ii = 1:length(max_index)
			scatter!([domain1[max_index[ii][1]]],
					 [domain2[max_index[ii][2]]],
					 color = :red,
					 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
					 label="")
		end
		savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_with_transfer_without_unmatched_$(IR_index)_penalty_level_$(importance_weight_lambda)")
	end #end different_beta_plot == true
else
	Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 3 (U)",
			   legend = :topright,
			   xlabel = "β₁",
			   ylabel = "β₂ × 1/8")
	Plots.contour!(domain1, domain2, res_contor',fill = true)
	Plots.vline!([temp_true_β[1]], label="true β₁",
			   linestyle = :dash,
			   color = :black)
	Plots.hline!([temp_true_β[2]], label="true β₂",
			   linestyle = :dash,
			   color = :black)
	max_index = findall(findmax(res_contor)[1].==res_contor)
	for ii = 1:length(max_index)
		scatter!([domain1[max_index[ii][1]]],
				 [domain2[max_index[ii][2]]],
				 color = :red,
				 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
				 label="")
	end
	# scatter!([max_index_res_contor[1]],
	#          [max_index_res_contor[2]],
	#          label="Maximum ($(max_index_res_contor[1]),$(max_index_res_contor[2]))")
	savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_without_transfer_with_unmatched_$(IR_index)")

	Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 4 (None)",
			   legend = :topright,
			   xlabel = "β₁",
			   ylabel = "β₂ × 1/8")
	Plots.contour!(domain1, domain2,
				   res_contor_only_matched',
				   fill = true)
	Plots.vline!([temp_true_β[1]], label="true β₁",
			   linestyle = :dash,
			   color = :black)
	Plots.hline!([temp_true_β[2]], label="true β₂",
			   linestyle = :dash,
			   color = :black)
	max_index = findall(findmax(res_contor_only_matched)[1].==res_contor_only_matched)
	for ii = 1:length(max_index)
		scatter!([domain1[max_index[ii][1]]],
				 [domain2[max_index[ii][2]]],
				 color = :red,
				 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
				 label="")
	end
	# scatter!([max_index_res_contor_only_matched[1]],
	#          [max_index_res_contor_only_matched[2]],
	#          label="Maximum ($(max_index_res_contor_only_matched[1]),$(max_index_res_contor_only_matched[2]))")
	savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_without_transfer_without_unmatched_$(IR_index)")

	Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 1 (U, T)",
			   legend = :topright,
			   xlabel = "β₁",
			   ylabel = "β₂ × 1/8")
	Plots.contour!(domain1, domain2, res_contor_with',fill = true)
	Plots.vline!([temp_true_β[1]], label="true β₁",
			   linestyle = :dash,
			   color = :black)
	Plots.hline!([temp_true_β[2]], label="true β₂",
			   linestyle = :dash,
			   color = :black)
	max_index = findall(findmax(res_contor_with)[1].==res_contor_with)
	for ii = 1:length(max_index)
		scatter!([domain1[max_index[ii][1]]],
				 [domain2[max_index[ii][2]]],
				 color = :red,
				 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
				 label="")
	end
	# scatter!([max_index_res_contor_with[1]],
	#          [max_index_res_contor_with[2]],
	#          label="Maximum ($(max_index_res_contor_with[1]),$(max_index_res_contor_with[2]))")
	savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_with_transfer_with_unmatched_$(IR_index)")

	Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp), Model 2 (T)",
			   legend = :topright,
			   xlabel = "β₁",
			   ylabel = "β₂ × 1/8")
	Plots.contour!(domain1, domain2,
			   res_contor_with_only_matched',fill = true)
	Plots.vline!([temp_true_β[1]], label="true β₁",
			   linestyle = :dash,
			   color = :black)
	Plots.hline!([temp_true_β[2]], label="true β₂",
			   linestyle = :dash,
			   color = :black)
	max_index = findall(findmax(res_contor_with_only_matched)[1].==res_contor_with_only_matched)
	for ii = 1:length(max_index)
		scatter!([domain1[max_index[ii][1]]],
				 [domain2[max_index[ii][2]]],
				 color = :red,
				 #label="Maximum ($(domain1[max_index[ii][1]]),$(domain1[max_index[ii][2]]))")
				 label="")
	end
	# scatter!([max_index_res_contor_with_only_matched[1]],
	#          [max_index_res_contor_with_only_matched[2]],
	#          label="Maximum ($(max_index_res_contor_with_only_matched[1]),$(max_index_res_contor_with_only_matched[2]))")
	savefig("julia_figures/N_$(num_agents_temp)_$(dummy_index)_with_transfer_without_unmatched_$(IR_index)")
end
