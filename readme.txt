"Individual Rationality Conditions of Identifying Matching Costs in Transferable Utility Matching Games. (2024) Economics Bulletin"

Finalized by Suguru Otani, May 22, 2024
Written by Suguru Otani, July 19, 2021
Title updated April 04, 2020

The repository is prepared for replications of computational results in the paper.

After setting the root path to /identification_of_matching_costs, 
run main.jl which contains all computational procedures.
It will take about a day for all computations and 
automatically update results restored in corresponding folders. 

If you want to skip some parts, please switch 
  want_to_run_all_plots = true
  want_to_run_all_estimations = true
  want_to_run_all_estimations_different_penalty = true
into false.

- julia_results
  The folder restores intermediate results generated by main.jl.
- julia_figures
  The folder restores figures generated by main.jl.
- julia_tables
  The folder restores Latex formatted results converted from intermediate results.

The followig julia scripts are used in main.jl.

- compute_one_param.jl
- compute_two_param.jl
- compute_two_param_safety_level_check.jl
- plot_one_param.jl
- plot_two_param.jl
- functions_plot_identification_power_with_score_function.jl
