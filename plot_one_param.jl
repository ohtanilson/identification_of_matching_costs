data = givemedata(num_agents_temp,
                  sd_temp,
				  temp_true_β,
                  means  = temp_means,
                  covars = temp_covars,
                  random_seed = temp_random_seed,
				  dummy_included = temp_dummy_included)
@linq data_unmatched_only = data |>
  where(:matches .== 0)
data.tarprice
data_unmatched_only.tarprice
data_unmatched_only.mval
@show matched_num = Int(sum(data.matches))
@show unmatched_num = num_agents_temp - matched_num
@linq data_only_matched = data |>
  where(:matches .== 1.0)
res_contor = zeros(length(domain1))#,length(domain2))
res_contor_only_matched = zeros(length(domain1))#,length(domain2))
res_contor_with = zeros(length(domain1))#,length(domain2))
res_contor_with_only_matched = zeros(length(domain1))#,length(domain2))
for i in 1:length(domain1)#,j in 1:length(domain2)
	res_contor[i] = score_b([domain1[i]],
                              data,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
    global max_index_res_contor = domain1[findmax(res_contor)[2][1]]
    res_contor_only_matched[i] = score_b([domain1[i]],
                              data_only_matched,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
    global max_index_res_contor_only_matched = domain1[findmax(res_contor_only_matched)[2][1]]
    res_contor_with[i] = score_b_with([domain1[i]],
                              data,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
    global max_index_res_contor_with = domain1[findmax(res_contor_with)[2][1]]
    res_contor_with_only_matched[i] = score_b_with([domain1[i]],
                              data_only_matched,
							  dummy_included = temp_dummy_included,
							  IR_condition_included = temp_IR_condition_included)
    global max_index_res_contor_with_only_matched = domain1[findmax(res_contor_with_only_matched)[2][1]]
end


Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp)",
           xlabel = "β",
           ylabel = "score")
Plots.vline!([temp_true_β], label="true β $(temp_true_β)",
           alpha = 0.4,
           legend=:bottomright,
           markershape = :circle,
           color = :black)
Plots.plot!(domain1, res_contor,
           label = "WITHOUT transfer including unmatched")
Plots.vline!([max_index_res_contor],
           linestyle = :dash,
           label = "WITHOUT transfer including unmatched, maximum($(max_index_res_contor))")
Plots.plot!(domain1, res_contor_with,
           label = "WITH transfer including unmatched")
Plots.vline!([max_index_res_contor_with],
           linestyle = :dash,
           label = "WITH transfer including unmatched, maximum($(max_index_res_contor_with))")
savefig("julia_figures/N_$(num_agents_temp)_single_$(dummy_index)_with_unmatched_$(IR_index)")

Plots.plot(title = "score (N=$(num_agents_temp), Match=$(matched_num), σ=$sd_temp)",
           xlabel = "β",
           ylabel = "score")
Plots.vline!([temp_true_β], label="true β",
           alpha = 0.4,
           legend=:bottomright,
           markershape = :auto,
           color = :black)
Plots.plot!(domain1, res_contor_only_matched,
           label = "WITHOUT transfer/ONLY MATCHED")
Plots.vline!([max_index_res_contor_only_matched],
           linestyle = :dash,
           label = "WITHOUT transfer/ONLY MATCHED, maximum($(max_index_res_contor_only_matched))")
Plots.plot!(domain1, res_contor_with_only_matched,
           label = "WITH transfer/ONLY MATCHED")
Plots.vline!([max_index_res_contor_with_only_matched],
           linestyle = :dash,
           label = "WITH transfer/ONLY MATCHED, maximum($(max_index_res_contor_with_only_matched))")
savefig("julia_figures/N_$(num_agents_temp)_single_$(dummy_index)_without_unmatched_$(IR_index)")
