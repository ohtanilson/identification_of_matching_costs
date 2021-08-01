function expand_grid(args...)
    nargs= length(args)
    if nargs == 0
      error("expand_grid need at least one argument")
    end
    iArgs= 1:nargs
    nmc= "Var" .* string.(iArgs)
    nm= nmc
    d= map(length, args)
    orep= prod(d)
    rep_fac= [1]
    # cargs = []
    if orep == 0
        error("One or more argument(s) have a length of 0")
    end
    cargs= Array{Any}(undef,orep,nargs)
    for i in iArgs
        x= args[i]
        nx= length(x)
        orep= Int(orep/nx)
        mapped_nx= vcat(map((x,y) -> repeat([x],y), collect(1:nx), repeat(rep_fac,nx))...)
        cargs[:,i] .= x[repeat(mapped_nx,orep)]
        rep_fac= rep_fac * nx
    end
    convert(DataFrame,cargs)
end

## ------------------------------ ##
## A script to implement Fox's    ##
## matching estimator.            ##
## ------------------------------ ##
function matchval(Ab,At,Bb,Bt,true_β;dummy_included = false)
  if dummy_included == false
    val = 1.0.*Ab.*At .+ true_β.*Bb.*Bt
  else
    constant = 4
    val = 1.0.*Ab.*At .+ true_β.*Bb.*Bt
  end
  return val
end
function givemedata(num_agents::Int64,
                    sd_err,
                    true_β;
                    means  = [1.0, 2.0],
                    covars = [1 0.25;
                              0.25 1],
                    random_seed = 1,
                    dummy_included = false)
    Random.seed!(random_seed)
    N = num_agents
    # construct buydata
    #buydata = rand(Distributions.MvNormal(means, covars), N)
    buydata = rand(Distributions.MvNormal(means, covars), N)
    buyid = Array{Int64,1}(1:N)
    buydata = hcat(buyid, buydata')
    buydata = convert(DataFrame, buydata)
    rename!(buydata, [:id, :Ab,  :Bb])
    # construct tardata
    tardata = rand(Distributions.MvNormal(means, covars), N)
    tarid = Array((1+N):(N+N))
    tardata = hcat(tarid, tardata')
    tardata = convert(DataFrame, tardata)
    rename!(tardata, [:id, :At, :Bt])

    #matchmaker = expand.grid(buyid = buydata$buyid, tarid = tardata$tarid)
    matchmaker = expand_grid(buyid, tarid)
    rename!(matchmaker, [:buyid, :tarid])
    matchdat = DataFrames.leftjoin(matchmaker, tardata, on = [:tarid => :id])
    matchdat = DataFrames.leftjoin(matchdat, buydata, on = [:buyid => :id])
    sort!(matchdat, [:buyid, :tarid]);
    mval = matchval(matchdat.Ab,matchdat.At,
                    matchdat.Bb,matchdat.Bt,
                    true_β;
                    dummy_included = dummy_included)
    mval = mval .+ rand(Distributions.Normal(0, sd_err), length(mval))
    matchdat = hcat(matchdat, mval)
    rename!(matchdat, :x1 => :mval)
    Buy = N#_with_unmatched
    Tar = N#_with_unmatched
    obj = matchdat.mval
    rhs = ones(N + N)
    utility = zeros(N,N)
    for i = 1:N, j = 1:N
            utility[i,j] = obj[(i-1)*N+j]
    end
    model = JuMP.Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "TimeLimit", 100)
    set_optimizer_attribute(model, "Presolve", 0)
    JuMP.@variable(model, 0<=x[i=1:N,j=1:N]<=1)
    @constraint(model, feas_i[i=1:N],
                sum(x[i,j] for j in 1:N)<= 1)
    @constraint(model, feas_j[j=1:N],
                sum(x[i,j] for i in 1:N)<= 1)
    JuMP.@objective(model, Max,
                    sum(x[i,j]*utility[i,j] for i in 1:N, j in 1:N))
    println("Time for optimizing model:")
    @time JuMP.optimize!(model)
    # show results
    objv = JuMP.objective_value(model)
    println("objvalue　= ", objv)
    matches = JuMP.value.(x)
    # restore unmatched
    unmatched_buyid = [1:1:N;][vec(sum(matches,dims=2) .== 0)]
    unmatched_tarid = [(N+1):1:(N+N);]'[sum(matches,dims=1) .== 0]

    matches = vec(matches')
    matchdat = hcat(matchdat, matches)
    rename!(matchdat, :x1 => :matches)
    model = JuMP.Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "TimeLimit", 100)
    set_optimizer_attribute(model, "Presolve", 0)
    JuMP.@variable(model, 0 <= u[i=1:N])
    JuMP.@variable(model, 0 <= v[i=1:N])
    @constraint(model,
                dual_const[i=1:N,j=1:N],
                u[i]+v[j]>= utility[i,j])
    JuMP.@objective(model, Min,
                    sum(u[i] for i in 1:N) +
                     sum(v[j] for j in 1:N))
    println("Time for optimizing model:")
    @time JuMP.optimize!(model)
    duals = vcat(JuMP.value.(u), JuMP.value.(v))
    println("sum of duals equal to obj value?: ",
             round(sum(duals),digits = 4)==round(objv,digits = 4))
    # tar price must be positive!
    lo = N + 1
    hi = N + N
    duals = DataFrame(tarid=Array((1+N):(N+N)),
                      tarprice = duals[lo:hi])
    matchdat = DataFrames.leftjoin(matchdat,
                                   duals,
                                   on = [:tarid => :tarid])
    @linq obsd = matchdat |>
  	  where(:matches .== 1.0)
    for i in unmatched_buyid
        @linq obsd_unmatched = matchdat |>
          where(:buyid .== i)
        obsd_unmatched = obsd_unmatched[1:2,:]
        obsd_unmatched.tarid .= N + N + 2
        obsd_unmatched.At .= 0
        obsd_unmatched.Bt .= 0
        obsd_unmatched.tarprice .== copy(0)
        obsd = vcat(obsd, obsd_unmatched)
        obsd = obsd[1:size(obsd)[1]-1,:]
    end
    for j in unmatched_tarid
        @linq obsd_unmatched = matchdat |>
          where(:tarid .== j)
        obsd_unmatched = obsd_unmatched[1:2,:]
        obsd_unmatched.buyid .= N + N + 1
        obsd_unmatched.Ab .= 0
        obsd_unmatched.Bb .= 0
        obsd_unmatched.tarprice .== copy(0)
        obsd = vcat(obsd, obsd_unmatched)
        obsd = obsd[1:size(obsd)[1]-1,:]
    end
    return(obsd)
end

## ------------------------ ##
## Form the Inequalities    ##
## for both "with" and      ##
## "without" estimators.    ##
## ------------------------ ##
function ineq(mat::Array{Float64,2},
              idx::Vector{Int64})
    prin = mat[idx,idx]
    ineq = prin[1,1]+prin[2,2]-prin[1,2]-prin[2,1]
    return ineq
end
function with_ineq(comper::Array{Float64,2},
                   prc::Vector{Float64},
                   idx::Vector{Int64})
    iq1 = (comper[idx[2], idx[2]] - prc[idx[2]]) - (comper[idx[2], idx[1]] - prc[idx[1]])
    iq2 = (comper[idx[1], idx[1]] - prc[idx[1]]) - (comper[idx[1], idx[2]] - prc[idx[2]])
    res_ineq = vcat(iq1, iq2) ## ifelse( (iq1 > 0) & (iq2 > 0) , 1, 0)
    return res_ineq
end
function score_b_with(beta::Vector{Float64},
                      data::DataFrame;
                      dummy_included = false,
                      IR_condition_included = false)
    beta = beta[1] # for Optim
    A = kron(data.Ab, data.At') #Take care of row and column
    B = kron(data.Bb, data.Bt') #Take care of row and column
    prc = convert(Vector{Float64}, data.tarprice)
    temp = [Combinatorics.combinations(1:size(data)[1],2)...]
    index_list = Array{Int64,2}(undef, length(temp), 2)
    for i in 1:length(temp)
        index_list[i,1] = temp[i][1]
        index_list[i,2] = temp[i][2]
    end
    ineqs = Array{Float64,2}(undef,length(index_list[:,1]),2)
    if dummy_included == true
      B_unmatched_index = B .== 0.0
      constant = 5
	  	comper = 1*A + beta[1]*(1 .-B_unmatched_index).*constant
	  else
	  	comper = 1*A + beta*B
	  end
    for j in 1:length(index_list[:,1])
        ineqs[j,:] = with_ineq(comper, prc, index_list[j,:])
    end
    # level of ineq is too big
    if IR_condition_included == false
        res = sum(ineqs.>0)
    else
        @linq data_only_matched = data |>
            where(:matches .== 1.0)
        if dummy_included == true
          constant = 5
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                   beta[1]*constant
        else
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                   beta[1]*data_only_matched.Bb.*data_only_matched.Bt
    	  end
        #balance number of unmatched and matched
        #sampled_ineqs_IR = sample(ineqs_IR, length(comper))
        #res = sum(ineqs.>0) + sum(sampled_ineqs_IR.>0) #+ sum(comper_unmatched.<0)
        global importance_weight_lambda
        res = sum(ineqs.>0) + sum(ineqs_IR.>0).*importance_weight_lambda
        #res = sum(ineqs.>0) + sum(comper_unmatched.<0)
    end
    return res
end

function score_b(beta::Vector{Float64},
                 data::DataFrame;
                 dummy_included = false,
                 IR_condition_included = false)
    #N = num_agents
    # @linq data_only_matched = data |>
    #   where(:matches .== 1.0)
    beta = beta[1] # for Optim
    A = kron(data.Ab, data.At') #Take care of row and column
    B = kron(data.Bb, data.Bt') #Take care of row and column
    temp = [Combinatorics.combinations(1:size(data)[1],2)...]
    index_list = Array{Int64,2}(undef, length(temp), 2)
    for i in 1:length(temp)
        index_list[i,1] = temp[i][1]
        index_list[i,2] = temp[i][2]
    end
    ineqs = fill(-1000.0, length(index_list[:,1]))
    if dummy_included == true
      B_unmatched_index = B .== 0.0
      constant = 5
	  	comper = 1*A + beta[1]*(1 .-B_unmatched_index).*constant
	  else
	  	comper = 1*A + beta*B
	  end

    for j in 1:length(index_list[:,1])
        ineqs[j] = ineq(comper, index_list[j,:])
    end

    if IR_condition_included == false
        res = sum(ineqs.>0)
    else
        @linq data_only_matched = data |>
            where(:matches .== 1.0)
        if dummy_included == true
          constant = 5
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                   beta[1]*constant
        else
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                   beta[1]*data_only_matched.Bb.*data_only_matched.Bt
    	  end
        #balance number of unmatched and matched
        #sampled_ineqs_IR = sample(ineqs_IR, length(comper))
        #res = sum(ineqs.>0) + sum(sampled_ineqs_IR.>0) #+ sum(comper_unmatched.<0)
        global importance_weight_lambda
        res = sum(ineqs.>0) + sum(ineqs_IR.>0).*importance_weight_lambda
        #res = sum(ineqs.>0) + sum(comper_unmatched.<0)
    end
    return res
end

function maxscore_mc(;num_agents::Int64,
	                   temp_true_β,
                     sd_err::Float64,
					           means = [1.0, 2.0],
					           covars = [1 0.25;
							                 0.25 1],
                     num_its::Int64 = 100,
                     withtrans::Bool = true,
                     use_only_matched_data = true,
                     dummy_included = false,
                     IR_condition_included = false)
    myests = Array{Float64,2}(undef, num_its*1, 1)
	  matched_num_res = zeros(num_its)
  	unmatched_num_res = zeros(num_its)
    for i = 1:num_its
       println("Create obsdat for iteration $i \n" )
       obsdat = givemedata(num_agents,
	                       sd_err,
						   temp_true_β,
                           means  = means,
                           covars = covars,
                           random_seed = i)
	   @linq data_only_matched = obsdat |>
	     where(:matches .== 1.0)
	   @linq data_unmatched_only = obsdat |>
	     where(:matches .== 0)
	   global matched_num = Int(sum(obsdat.matches))
  	   global unmatched_num = num_agents - matched_num
	   if withtrans == true
		   function score_bthis_with(beta::Vector{Float64},
			                         obsdat::DataFrame)
			   res = -1.0*score_b_with(beta, obsdat) + 100000.0 # need to be Float64 for bboptimize
			   return res
		   end
		   if use_only_matched_data == true
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis_with(beta, data_only_matched);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 200)
		   else
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis_with(beta, obsdat);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 200)
		   end
		   #println("score: ",score_bthis_with(m_res.archive_output.best_candidate, obsdat))
	   else
		   function score_bthis(beta::Vector{Float64},
			                    obsdat::DataFrame)
			   res = -1.0*score_b(beta, obsdat) + 100000.0 # need to be Float64 for bboptimize
			   return res
		   end
		   if use_only_matched_data == true
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis(beta, data_only_matched);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 200)
		   else
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis(beta, obsdat);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 200)
		   end
		   #println("score: ", score_bthis(m_res.archive_output.best_candidate, obsdat))
		   #println("score of correct: ", score_b(m_res.archive_output.best_candidate, obsdat, num_agents))
		   #println("TRUE score of correct: ", score_b([temp_true_β], obsdat, num_agents))
	   end
	   m = m_res.archive_output.best_candidate
	   myests[i,:] = m
	   matched_num_res[i] = matched_num
	   unmatched_num_res[i] = unmatched_num
   end
   meanmat = temp_true_β # true parameter
   res_mean = mean(myests)
   res_bias = mean(myests.-meanmat)
   res_sqrt = sqrt(mean((myests.-meanmat).^2))
   mean_matched_num = mean(matched_num_res)
   mean_unmatched_num = mean(unmatched_num_res)
   global myests
   @show myests
   return res_mean,res_bias, res_sqrt, mean_matched_num, mean_unmatched_num
end

#-----------------#
# two variables
#-----------------#

function matchval2(Ab,At,Bb,Bt,Cb,Ct,true_β;dummy_included = false)
	if dummy_included == true
    constant = 8
		val = 1.0.*Ab.*At .+ true_β[1].*Bb.*Bt .+ true_β[2].*constant
	else
		val = 1.0.*Ab.*At .+ true_β[1].*Bb.*Bt .+ true_β[2].*Cb.*Ct
	end
  return val
end
function givemedata2(num_agents::Int64,
	                   sd_err,
                     true_β;
                     means  = [0.0, 0.0, 0.0],
                     covars = [1 0.25 0.25;
                               0.25 1 0.25;
                               0.25 0.25 1],
                     random_seed = 1,
					           dummy_included = false)
    Random.seed!(random_seed)
    N = num_agents
    buydata = rand(Distributions.MvNormal(means, covars), N)
    buyid = Array{Int64,1}(1:N)
    buydata = hcat(buyid, buydata')
    buydata = convert(DataFrame, buydata)
    rename!(buydata, [:id, :Ab,  :Bb, :Cb])

    tardata = rand(Distributions.MvNormal(means, covars), N)
    tarid = Array((1+N):(N+N))
    # non-interactive term
    println("non-interactive Match specific term: Ct = rnorm(N, 10, 1)")
    #Ct = rand(Distributions.Normal(10, 1), N)
    tardata = hcat(tarid, tardata')
    tardata = convert(DataFrame, tardata)
    rename!(tardata, [:id, :At, :Bt, :Ct])

    matchmaker = expand_grid(buyid, tarid)
    rename!(matchmaker, [:buyid, :tarid])
    matchdat = DataFrames.leftjoin(matchmaker, tardata, on = [:tarid => :id])
    matchdat = DataFrames.leftjoin(matchdat, buydata, on = [:buyid => :id])
    sort!(matchdat, [:buyid, :tarid]);
    #matchdat = within(matchdat, mval <- matchval(Ab,At,Bb,Bt))
    mval = matchval2(matchdat.Ab,matchdat.At,
                     matchdat.Bb,matchdat.Bt,
                     matchdat.Cb,matchdat.Ct,
                     true_β,
                     dummy_included = dummy_included)
    #matchdat = within(matchdat, mval <- mval + rnorm(length(matchdat$mval), mean = 0, sd_err) )
    mval = mval .+ rand(Distributions.Normal(0, sd_err), length(mval))
    matchdat = hcat(matchdat, mval)
    rename!(matchdat, :x1 => :mval)

    obj = matchdat.mval
    rhs = ones(N + N)
    utility = zeros(N,N)
    for i = 1:N
        for j = 1:N
            utility[i,j] = obj[(i-1)*N+j]
        end
    end
    model = JuMP.Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "TimeLimit", 100)
    set_optimizer_attribute(model, "Presolve", 0)
    JuMP.@variable(model, 0<=x[i=1:N,j=1:N]<=1)
    @constraint(model, feas_i[i=1:N], sum(x[i,j] for j in 1:N)<= 1)
    @constraint(model, feas_j[j=1:N], sum(x[i,j] for i in 1:N)<= 1)
    JuMP.@objective(model, Max, sum(x[i,j]*utility[i,j] for i in 1:N, j in 1:N))
    println("Time for optimizing model:")
    @time JuMP.optimize!(model)
    # show results
    objv = JuMP.objective_value(model)
    println("objvalue　= ", objv)
    matches = JuMP.value.(x)
    # restore unmatched
    unmatched_buyid = [1:1:N;][vec(sum(matches,dims=2) .== 0)]
    unmatched_tarid = [(N+1):1:(N+N);]'[sum(matches,dims=1) .== 0]
    matches = vec(matches')
    matchdat = hcat(matchdat, matches)
    rename!(matchdat, :x1 => :matches)
    model = JuMP.Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "TimeLimit", 100)
    set_optimizer_attribute(model, "Presolve", 0)
    JuMP.@variable(model, 0 <= u[i=1:N])
    JuMP.@variable(model, 0 <= v[i=1:N])
    @constraint(model,
                dual_const[i=1:N,j=1:N],
                u[i]+v[j]>= utility[i,j])
    JuMP.@objective(model, Min,
                    sum(u[i] for i in 1:N) +
                     sum(v[j] for j in 1:N))
    println("Time for optimizing model:")
    @time JuMP.optimize!(model)
    duals = vcat(JuMP.value.(u), JuMP.value.(v))
    println("sum of duals equal to obj value?: ",
             round(sum(duals),digits = 4)==round(objv,digits = 4))
    # tar price must be positive!
    lo = N + 1
    hi = N + N
    duals = DataFrame(tarid=Array((1+N):(N+N)),
                      tarprice = duals[lo:hi])
    matchdat = DataFrames.leftjoin(matchdat,
                                   duals,
                                   on = [:tarid => :tarid])
    @linq obsd = matchdat |>
  	  where(:matches .== 1.0)
    for i in unmatched_buyid
        @linq obsd_unmatched = matchdat |>
          where(:buyid .== i)
	    	obsd_unmatched = obsd_unmatched[1:2,:]
        obsd_unmatched.tarid .= N + N + 2
        obsd_unmatched.At .= 0
        obsd_unmatched.Bt .= 0
	    	obsd_unmatched.Ct .= 0
        obsd_unmatched.tarprice .== copy(0) #unmatched transfer
        obsd = vcat(obsd, obsd_unmatched)
        obsd = obsd[1:size(obsd)[1]-1,:]
    end
    for j in unmatched_tarid
        @linq obsd_unmatched = matchdat |>
          where(:tarid .== j)
	    	obsd_unmatched = obsd_unmatched[1:2,:]
        obsd_unmatched.buyid .= N + N + 1
	    	obsd_unmatched.Ab .= 0
        obsd_unmatched.Bb .= 0
	    	obsd_unmatched.Cb .= 0
        obsd_unmatched.tarprice .== copy(0) #unmatched transfer
        obsd = vcat(obsd, obsd_unmatched)
        obsd = obsd[1:size(obsd)[1]-1,:]
    end
    return(obsd)
end

function score_b_with_non(beta::Vector{Float64},
                          data::DataFrame;
                          dummy_included = false,
                          IR_condition_included = false)
    #beta = beta[1] # for Optim
    A = kron(data.Ab, data.At') #Take care of row and column
    B = kron(data.Bb, data.Bt') #Take care of row and column
    C = kron(data.Cb, data.Ct') #Take care of row and column
    prc = convert(Vector{Float64}, data.tarprice)
    temp = [Combinatorics.combinations(1:size(data)[1],2)...]
    index_list = Array{Int64,2}(undef, length(temp), 2)
    for i in 1:length(temp)
        index_list[i,1] = temp[i][1]
        index_list[i,2] = temp[i][2]
    end
    #ineqs = matrix(rep(-1000, 2*length(index_list[,1])), ncol = 2)
    ineqs = Array{Float64,2}(undef,length(index_list[:,1]),2)
    # comper = beta[3]*A + beta[1]*B + beta[2]*C
	  if dummy_included == true
      constant = 8
      C_unmatched_index = C .== 0.0
		  comper = 1*A + beta[1]*B .+ beta[2]*(1 .-C_unmatched_index).*constant
	  else
		  comper = 1*A + beta[1]*B .+ beta[2]*C
	  end
    for j in 1:length(index_list[:,1])
        ineqs[j,:] = with_ineq(comper, prc, index_list[j,:])
    end
    # calculate num of correct inequalities
    if IR_condition_included == false
        res = sum(ineqs.>0)
    else
        @linq data_only_matched = data |>
            where(:matches .== 1.0)
        if dummy_included == true
          constant = 8
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                     beta[1]*data_only_matched.Bb.*data_only_matched.Bt .+
                     beta[2]*constant .- data_only_matched.tarprice
    	  else
          constant = 8
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                     beta[1]*data_only_matched.Bb.*data_only_matched.Bt .+
                     beta[2]*data_only_matched.Cb.*data_only_matched.Ct .- data_only_matched.tarprice
    	  end
        #balance number of unmatched and matched
        global importance_weight_lambda
        res = sum(ineqs.>0) + sum(ineqs_IR.>0).*importance_weight_lambda
        #res = sum(ineqs.>0) + sum(comper_unmatched.<0)
    end
    return res
end


function score_b_non(beta::Vector{Float64},
                     data::DataFrame;
                     dummy_included = false,
                     IR_condition_included = false)
    A = kron(data.Ab, data.At') #Take care of row and column
    B = kron(data.Bb, data.Bt') #Take care of row and column
    C = kron(data.Cb, data.Ct') #Take care of row and column
    temp = [Combinatorics.combinations(1:size(data)[1],2)...]
    index_list = Array{Int64,2}(undef, length(temp), 2)
    for i in 1:length(temp)
        index_list[i,1] = temp[i][1]
        index_list[i,2] = temp[i][2]
    end
    ineqs = fill(-1000.0, length(index_list[:,1]))
	  if dummy_included == true
      C_unmatched_index = C .== 0.0
      constant = 8
	  	comper = 1*A + beta[1]*B .+ beta[2]*(1 .-C_unmatched_index).*constant
	  else
	  	comper = 1*A + beta[1]*B .+ beta[2]*C
	  end
    for j in 1:length(index_list[:,1])
        ineqs[j] = ineq(comper, index_list[j,:])
    end
    # calculate num of correct inequalities
    if IR_condition_included == false
        res = sum(ineqs.>0)
    else
        @linq data_only_matched = data |>
            where(:matches .== 1.0)
        if dummy_included == true
          constant = 8
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                     beta[1]*data_only_matched.Bb.*data_only_matched.Bt .+
                     beta[2]*constant #.- data_only_matched.tarprice
    	  else
          constant = 8
          ineqs_IR = 1*data_only_matched.Ab.*data_only_matched.At .+
                     beta[1]*data_only_matched.Bb.*data_only_matched.Bt .+
                     beta[2]*data_only_matched.Cb.*data_only_matched.Ct #.- data_only_matched.tarprice
    	  end
        #balance number of unmatched and matched
        global importance_weight_lambda
        res = sum(ineqs.>0) + sum(ineqs_IR.>0).*importance_weight_lambda
        #res = sum(ineqs.>0) + sum(comper_unmatched.<0)
    end
    return res
end


function maxscore_mc2(;num_agents::Int64,
	                     temp_true_β,
                       sd_err::Float64,
					             means  = [1.0, 1.0, 2.0],
                       covars = [1 0.25 0.25;
  				                       0.25 1 0.25;
  							                 0.25 0.25 1],
                       num_its = 100,
                       withtrans::Bool = true,
					             use_only_matched_data = true,
                       dummy_included = false,
                       IR_condition_included = false)
    myests = Array{Float64,2}(undef, num_its*1, 2)
    matched_num_res = zeros(num_its)
	  unmatched_num_res = zeros(num_its)
    for i = 1:num_its
       println("Create obsdat for iteration $i \n" )
       obsdat = givemedata2(num_agents,
	                         sd_err,
						               temp_true_β,
                           means  = means,
                           covars = covars,
                           random_seed = i,
						               dummy_included = dummy_included)
	   @linq data_only_matched = obsdat |>
	     where(:matches .== 1.0)
	   @linq data_unmatched_only = obsdat |>
	     where(:matches .== 0)
	   global matched_num = Int(sum(obsdat.matches))
  	   global unmatched_num = num_agents - matched_num
	   if withtrans == true
		   function score_bthis_with(beta::Vector{Float64},
			                         obsdat::DataFrame)
			   res = -1.0*score_b_with_non(beta, obsdat,
                                     dummy_included = dummy_included,
                                     IR_condition_included = IR_condition_included) + 100000.0 # need to be Float64 for bboptimize
			   return res
		   end
		   if use_only_matched_data == true
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis_with(beta, data_only_matched);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 400)
		   else
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis_with(beta, obsdat);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 400)
		   end
		   #println("score: ",score_bthis_with(m_res.archive_output.best_candidate, obsdat))
	   else
		   function score_bthis(beta::Vector{Float64},
			                    obsdat::DataFrame)
			   res = -1.0*score_b_non(beta, obsdat,
                                dummy_included = dummy_included,
                                IR_condition_included = IR_condition_included) + 100000.0 # need to be Float64 for bboptimize
			   return res
		   end
		   if use_only_matched_data == true
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis(beta, data_only_matched);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 400)
		   else
			   m_res = BlackBoxOptim.bboptimize(beta -> score_bthis(beta, obsdat);
												SearchRange = (-10.0, 10.0),
												NumDimensions = length(temp_true_β),
												Method = :de_rand_1_bin,
												MaxSteps = 400)
		   end
		   #println("score: ", score_bthis(m_res.archive_output.best_candidate, obsdat))
		   #println("score of correct: ", score_b(m_res.archive_output.best_candidate, obsdat, num_agents))
		   #println("TRUE score of correct: ", score_b([temp_true_β], obsdat, num_agents))
	   end
	   m = m_res.archive_output.best_candidate
	   myests[i,:] = m
	   matched_num_res[i] = matched_num
	   unmatched_num_res[i] = unmatched_num
   end
   meanmat = temp_true_β # true parameter
   res_mean = mean(myests, dims = 1)
   res_bias = mean(myests.-meanmat', dims = 1)
   res_sqrt = sqrt.(mean((myests.-meanmat').^2, dims = 1))
   mean_matched_num = mean(matched_num_res)
   mean_unmatched_num = mean(unmatched_num_res)
   global myests
   @show myests
   return res_mean,res_bias, res_sqrt, mean_matched_num, mean_unmatched_num
end

function write_table_one_param(filename,
	                 num_agents_list,
					 true_β_list,
					 res_mean_list,
					 res_bias_list,
					 res_sqrt_list,
					 mean_matched_num_list,
					 mean_unmatched_num_list)
    LaTeXTabulars.latex_tabular(filename,
    			  Tabular("@{\\extracolsep{5pt}}lc|cccccc"),
    			  [Rule(:top),
    			   ["","Num of agents","",
    			    num_agents_list[1], num_agents_list[2],
    			    num_agents_list[3], num_agents_list[4],
    				num_agents_list[5]],
    			   [L"\beta","","","", "", "", "", ""],
    			   Rule(:mid),
    			   vcat(true_β_list[1],"unmatched","Mean Num",mean_unmatched_num_list[1,:,1]),
    			   vcat("","U,T","Bias",res_bias_list[1,:,1]),
    			   vcat("","","RMSE","($(res_sqrt_list[1,1,1]))", "($(res_sqrt_list[1,2,1]))",
    			        "($(res_sqrt_list[1,3,1]))", "($(res_sqrt_list[1,4,1]))", "($(res_sqrt_list[1,5,1]))"),
    			   vcat("","T","Bias",res_bias_list[2,:,1]),
    			   vcat("","","RMSE","($(res_sqrt_list[2,1,1]))", "($(res_sqrt_list[2,2,1]))",
    			        "($(res_sqrt_list[2,3,1]))", "($(res_sqrt_list[2,4,1]))", "($(res_sqrt_list[2,5,1]))"),
    			   vcat("","U","Bias",res_bias_list[3,:,1]),
    			   vcat("","","RMSE","($(res_sqrt_list[3,1,1]))", "($(res_sqrt_list[3,2,1]))",
    			        "($(res_sqrt_list[3,3,1]))", "($(res_sqrt_list[3,4,1]))", "($(res_sqrt_list[3,5,1]))"),
    			   vcat("","Non","Bias",res_bias_list[4,:,1]),
    			   vcat("","","RMSE","($(res_sqrt_list[4,1,1]))", "($(res_sqrt_list[4,2,1]))",
    			        "($(res_sqrt_list[4,3,1]))", "($(res_sqrt_list[4,4,1]))", "($(res_sqrt_list[4,5,1]))"),
    			   ["","","", "", "", "", "", ""],
    			   vcat(true_β_list[2],"unmatched","Mean Num",mean_unmatched_num_list[1,:,2]),
    			   vcat("","U,T","Bias",res_bias_list[1,:,2]),
    			   vcat("","","RMSE","($(res_sqrt_list[1,1,2]))", "($(res_sqrt_list[1,2,2]))",
    			        "($(res_sqrt_list[1,3,2]))", "($(res_sqrt_list[1,4,2]))", "($(res_sqrt_list[1,5,2]))"),
    			   vcat("","T","Bias",res_bias_list[2,:,2]),
    			   vcat("","","RMSE","($(res_sqrt_list[2,1,2]))", "($(res_sqrt_list[2,2,2]))",
    			        "($(res_sqrt_list[2,3,2]))", "($(res_sqrt_list[2,4,2]))", "($(res_sqrt_list[2,5,2]))"),
    			   vcat("","U","Bias",res_bias_list[3,:,2]),
    			   vcat("","","RMSE","($(res_sqrt_list[3,1,2]))", "($(res_sqrt_list[3,2,2]))",
    			        "($(res_sqrt_list[3,3,2]))", "($(res_sqrt_list[3,4,2]))", "($(res_sqrt_list[3,5,2]))"),
    			   vcat("","Non","Bias",res_bias_list[4,:,2]),
    			   vcat("","","RMSE","($(res_sqrt_list[4,1,2]))", "($(res_sqrt_list[4,2,2]))",
    			        "($(res_sqrt_list[4,3,2]))", "($(res_sqrt_list[4,4,2]))", "($(res_sqrt_list[4,5,2]))"),
    			   ["","", "", "","", "", "", ""],
    			   vcat(true_β_list[3],"unmatched","Mean Num",mean_unmatched_num_list[1,:,3]),
    			   vcat("","U,T","Bias",res_bias_list[1,:,3]),
    			   vcat("","","RMSE","($(res_sqrt_list[1,1,3]))", "($(res_sqrt_list[1,2,3]))",
    			        "($(res_sqrt_list[1,3,3]))", "($(res_sqrt_list[1,4,3]))", "($(res_sqrt_list[1,5,3]))"),
    			   vcat("","T","Bias",res_bias_list[2,:,3]),
    			   vcat("","","RMSE","($(res_sqrt_list[2,1,3]))", "($(res_sqrt_list[2,2,3]))",
    			        "($(res_sqrt_list[2,3,3]))", "($(res_sqrt_list[2,4,3]))", "($(res_sqrt_list[2,5,3]))"),
    			   vcat("","U","Bias",res_bias_list[3,:,3]),
    			   vcat("","","RMSE","($(res_sqrt_list[3,1,3]))", "($(res_sqrt_list[3,2,3]))",
    			        "($(res_sqrt_list[3,3,3]))", "($(res_sqrt_list[3,4,3]))", "($(res_sqrt_list[3,5,3]))"),
    			   vcat("","Non","Bias",res_bias_list[4,:,3]),
    			   vcat("","","RMSE","($(res_sqrt_list[4,1,3]))", "($(res_sqrt_list[4,2,3]))",
    			        "($(res_sqrt_list[4,3,3]))", "($(res_sqrt_list[4,4,3]))", "($(res_sqrt_list[4,5,3]))"),
    			   ["","", "", "","", "", "", ""],
    			   vcat(true_β_list[4],"unmatched","Mean Num",mean_unmatched_num_list[1,:,4]),
    			   vcat("","U,T","Bias",res_bias_list[1,:,4]),
    			   vcat("","","RMSE","($(res_sqrt_list[1,1,4]))", "($(res_sqrt_list[1,2,4]))",
    			        "($(res_sqrt_list[1,3,4]))", "($(res_sqrt_list[1,4,4]))", "($(res_sqrt_list[1,5,4]))"),
    			   vcat("","T","Bias",res_bias_list[2,:,4]),
    			   vcat("","","RMSE","($(res_sqrt_list[2,1,4]))", "($(res_sqrt_list[2,2,4]))",
    			        "($(res_sqrt_list[2,3,4]))", "($(res_sqrt_list[2,4,4]))", "($(res_sqrt_list[2,5,4]))"),
    			   vcat("","U","Bias",res_bias_list[3,:,4]),
    			   vcat("","","RMSE","($(res_sqrt_list[3,1,4]))", "($(res_sqrt_list[3,2,4]))",
    			        "($(res_sqrt_list[3,3,4]))", "($(res_sqrt_list[3,4,4]))", "($(res_sqrt_list[3,5,4]))"),
    			   vcat("","Non","Bias",res_bias_list[4,:,4]),
    			   vcat("","","RMSE","($(res_sqrt_list[4,1,4]))", "($(res_sqrt_list[4,2,4]))",
    			        "($(res_sqrt_list[4,3,4]))", "($(res_sqrt_list[4,4,4]))", "($(res_sqrt_list[4,5,4]))"),
    			   ["","", "", "","", "", "", ""],
    			   vcat(true_β_list[5],"unmatched","Mean Num",mean_unmatched_num_list[1,:,5]),
    			   vcat("","U,T","Bias",res_bias_list[1,:,5]),
    			   vcat("","","RMSE","($(res_sqrt_list[1,1,5]))", "($(res_sqrt_list[1,2,5]))",
    			        "($(res_sqrt_list[1,3,5]))", "($(res_sqrt_list[1,4,5]))", "($(res_sqrt_list[1,5,5]))"),
    			   vcat("","T","Bias",res_bias_list[2,:,5]),
    			   vcat("","","RMSE","($(res_sqrt_list[2,1,5]))", "($(res_sqrt_list[2,2,5]))",
    			        "($(res_sqrt_list[2,3,5]))", "($(res_sqrt_list[2,4,5]))", "($(res_sqrt_list[2,5,5]))"),
    			   vcat("","U","Bias",res_bias_list[3,:,5]),
    			   vcat("","","RMSE","($(res_sqrt_list[3,1,5]))", "($(res_sqrt_list[3,2,5]))",
    			        "($(res_sqrt_list[3,3,5]))", "($(res_sqrt_list[3,4,5]))", "($(res_sqrt_list[3,5,5]))"),
    			   vcat("","Non","Bias",res_bias_list[4,:,5]),
    			   vcat("","","RMSE","($(res_sqrt_list[4,1,5]))", "($(res_sqrt_list[4,2,5]))",
    			        "($(res_sqrt_list[4,3,5]))", "($(res_sqrt_list[4,4,5]))", "($(res_sqrt_list[4,5,5]))"),
    			   #delta subsidy sensitivity
    			   ["","", "", "","", "", "", ""],
    			   Rule(),           # a nice \hline to make it ugly
    			   Rule(:bottom)])
end

function write_table_two_param(filename_beta,
	                 num_agents_list,
					 true_β_list,
					 res_mean_list_beta1,
					 res_mean_list_beta2,
					 res_bias_list_beta1,
					 res_bias_list_beta2,
					 res_sqrt_list_beta1,
					 res_sqrt_list_beta2,
					 mean_matched_num_list,
					 mean_unmatched_num_list)
	LaTeXTabulars.latex_tabular(filename_beta,
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
				   vcat(benchmark_β,"unmatched","Mean Num",
           mean_unmatched_num_list[1,:,1],
           true_β_list[1], mean_unmatched_num_list[1,:,1]),
				   vcat("","U,T","Bias",res_bias_list_beta1[1,:,1],
           "", res_bias_list_beta2[1,:,1]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,1]))", "($(res_sqrt_list_beta1[1,2,1]))",
				        "($(res_sqrt_list_beta1[1,3,1]))", "($(res_sqrt_list_beta1[1,4,1]))", "($(res_sqrt_list_beta1[1,5,1]))",
                "",
                "($(res_sqrt_list_beta2[1,1,1]))", "($(res_sqrt_list_beta2[1,2,1]))",
     				        "($(res_sqrt_list_beta2[1,3,1]))", "($(res_sqrt_list_beta2[1,4,1]))", "($(res_sqrt_list_beta2[1,5,1]))"),
				   vcat("","T","Bias",res_bias_list_beta1[2,:,1],
           "", res_bias_list_beta2[2,:,1]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[2,1,1]))", "($(res_sqrt_list_beta1[2,2,1]))",
				        "($(res_sqrt_list_beta1[2,3,1]))", "($(res_sqrt_list_beta1[2,4,1]))", "($(res_sqrt_list_beta1[2,5,1]))",
                "",
                "($(res_sqrt_list_beta2[2,1,1]))", "($(res_sqrt_list_beta2[2,2,1]))",
     				        "($(res_sqrt_list_beta2[2,3,1]))", "($(res_sqrt_list_beta2[2,4,1]))", "($(res_sqrt_list_beta2[2,5,1]))"),
				   vcat("","U","Bias",res_bias_list_beta1[3,:,1],
           "", res_bias_list_beta2[3,:,1]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[3,1,1]))", "($(res_sqrt_list_beta1[3,2,1]))",
				        "($(res_sqrt_list_beta1[3,3,1]))", "($(res_sqrt_list_beta1[3,4,1]))", "($(res_sqrt_list_beta1[3,5,1]))",
                "",
                "($(res_sqrt_list_beta2[3,1,1]))", "($(res_sqrt_list_beta2[3,2,1]))",
     				        "($(res_sqrt_list_beta2[3,3,1]))", "($(res_sqrt_list_beta2[3,4,1]))", "($(res_sqrt_list_beta2[3,5,1]))"),
				   vcat("","Non","Bias",res_bias_list_beta1[4,:,1],
           "", res_bias_list_beta2[4,:,1]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[4,1,1]))", "($(res_sqrt_list_beta1[4,2,1]))",
				        "($(res_sqrt_list_beta1[4,3,1]))", "($(res_sqrt_list_beta1[4,4,1]))", "($(res_sqrt_list_beta1[4,5,1]))",
                "",
                "($(res_sqrt_list_beta2[4,1,1]))", "($(res_sqrt_list_beta2[4,2,1]))",
     				        "($(res_sqrt_list_beta2[4,3,1]))", "($(res_sqrt_list_beta2[4,4,1]))", "($(res_sqrt_list_beta2[4,5,1]))"),
				   ["","","", "", "", "", "", "",
            "", "", "", "", "", ""],
				   vcat(benchmark_β,"unmatched","Mean Num",mean_unmatched_num_list[1,:,2],
           true_β_list[2], mean_unmatched_num_list[1,:,2]),
				   vcat("","U,T","Bias",res_bias_list_beta1[1,:,2],
           "", res_bias_list_beta2[1,:,2]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,2]))", "($(res_sqrt_list_beta1[1,2,2]))",
				        "($(res_sqrt_list_beta1[1,3,2]))", "($(res_sqrt_list_beta1[1,4,2]))", "($(res_sqrt_list_beta1[1,5,2]))",
                "",
                "($(res_sqrt_list_beta2[1,1,2]))", "($(res_sqrt_list_beta2[1,2,2]))",
     				        "($(res_sqrt_list_beta2[1,3,2]))", "($(res_sqrt_list_beta2[1,4,2]))", "($(res_sqrt_list_beta2[1,5,2]))"),
				   vcat("","T","Bias",res_bias_list_beta1[2,:,2],
           "", res_bias_list_beta2[2,:,2]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[2,1,2]))", "($(res_sqrt_list_beta1[2,2,2]))",
				        "($(res_sqrt_list_beta1[2,3,2]))", "($(res_sqrt_list_beta1[2,4,2]))", "($(res_sqrt_list_beta1[2,5,2]))",
                "",
                "($(res_sqrt_list_beta2[2,1,2]))", "($(res_sqrt_list_beta2[2,2,2]))",
     				        "($(res_sqrt_list_beta2[2,3,2]))", "($(res_sqrt_list_beta2[2,4,2]))", "($(res_sqrt_list_beta2[2,5,2]))"),
				   vcat("","U","Bias",res_bias_list_beta1[3,:,2],
           "", res_bias_list_beta2[3,:,2]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[3,1,2]))", "($(res_sqrt_list_beta1[3,2,2]))",
				        "($(res_sqrt_list_beta1[3,3,2]))", "($(res_sqrt_list_beta1[3,4,2]))", "($(res_sqrt_list_beta1[3,5,2]))",
                "",
                "($(res_sqrt_list_beta2[3,1,2]))", "($(res_sqrt_list_beta2[3,2,2]))",
     				        "($(res_sqrt_list_beta2[3,3,2]))", "($(res_sqrt_list_beta2[3,4,2]))", "($(res_sqrt_list_beta2[3,5,2]))"),
				   vcat("","Non","Bias",res_bias_list_beta1[4,:,2],
           "", res_bias_list_beta2[4,:,2]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[4,1,2]))", "($(res_sqrt_list_beta1[4,2,2]))",
				        "($(res_sqrt_list_beta1[4,3,2]))", "($(res_sqrt_list_beta1[4,4,2]))", "($(res_sqrt_list_beta1[4,5,2]))",
                "",
                "($(res_sqrt_list_beta2[4,1,2]))", "($(res_sqrt_list_beta2[4,2,2]))",
     				        "($(res_sqrt_list_beta2[4,3,2]))", "($(res_sqrt_list_beta2[4,4,2]))", "($(res_sqrt_list_beta2[4,5,2]))"),
				   ["","", "", "","", "", "", "",
           "", "","", "", "", ""],
				   vcat(benchmark_β,"unmatched","Mean Num",mean_unmatched_num_list[1,:,3],
           true_β_list[3], mean_unmatched_num_list[1,:,3]),
				   vcat("","U,T","Bias",res_bias_list_beta1[1,:,3],
           "", res_bias_list_beta2[1,:,3]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,3]))", "($(res_sqrt_list_beta1[1,2,3]))",
				        "($(res_sqrt_list_beta1[1,3,3]))", "($(res_sqrt_list_beta1[1,4,3]))", "($(res_sqrt_list_beta1[1,5,3]))",
                "",
                "($(res_sqrt_list_beta2[1,1,3]))", "($(res_sqrt_list_beta2[1,2,3]))",
     				        "($(res_sqrt_list_beta2[1,3,3]))", "($(res_sqrt_list_beta2[1,4,3]))", "($(res_sqrt_list_beta2[1,5,3]))"),
				   vcat("","T","Bias",res_bias_list_beta1[2,:,3],
           "", res_bias_list_beta2[2,:,3]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[2,1,3]))", "($(res_sqrt_list_beta1[2,2,3]))",
				        "($(res_sqrt_list_beta1[2,3,3]))", "($(res_sqrt_list_beta1[2,4,3]))", "($(res_sqrt_list_beta1[2,5,3]))",
                "",
                "($(res_sqrt_list_beta2[2,1,3]))", "($(res_sqrt_list_beta2[2,2,3]))",
     				        "($(res_sqrt_list_beta2[2,3,3]))", "($(res_sqrt_list_beta2[2,4,3]))", "($(res_sqrt_list_beta2[2,5,3]))"),
				   vcat("","U","Bias",res_bias_list_beta1[3,:,3],
           "", res_bias_list_beta2[3,:,3]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[3,1,3]))", "($(res_sqrt_list_beta1[3,2,3]))",
				        "($(res_sqrt_list_beta1[3,3,3]))", "($(res_sqrt_list_beta1[3,4,3]))", "($(res_sqrt_list_beta1[3,5,3]))",
                "",
                "($(res_sqrt_list_beta2[3,1,3]))", "($(res_sqrt_list_beta2[3,2,3]))",
     				        "($(res_sqrt_list_beta2[3,3,3]))", "($(res_sqrt_list_beta2[3,4,3]))", "($(res_sqrt_list_beta2[3,5,3]))"),
				   vcat("","Non","Bias",res_bias_list_beta1[4,:,3],
           "", res_bias_list_beta2[4,:,3]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[4,1,3]))", "($(res_sqrt_list_beta1[4,2,3]))",
				        "($(res_sqrt_list_beta1[4,3,3]))", "($(res_sqrt_list_beta1[4,4,3]))", "($(res_sqrt_list_beta1[4,5,3]))",
                "",
                "($(res_sqrt_list_beta2[4,1,3]))", "($(res_sqrt_list_beta2[4,2,3]))",
     				        "($(res_sqrt_list_beta2[4,3,3]))", "($(res_sqrt_list_beta2[4,4,3]))", "($(res_sqrt_list_beta2[4,5,3]))"),
				   ["","", "", "","", "", "", "",
           "", "","", "", "", ""],
				   vcat(benchmark_β,"unmatched","Mean Num",mean_unmatched_num_list[1,:,4],
           true_β_list[4], mean_unmatched_num_list[1,:,4]),
				   vcat("","U,T","Bias",res_bias_list_beta1[1,:,4],
           "", res_bias_list_beta2[1,:,4]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,4]))", "($(res_sqrt_list_beta1[1,2,4]))",
				        "($(res_sqrt_list_beta1[1,3,4]))", "($(res_sqrt_list_beta1[1,4,4]))", "($(res_sqrt_list_beta1[1,5,4]))",
                "",
                "($(res_sqrt_list_beta2[1,1,4]))", "($(res_sqrt_list_beta2[1,2,4]))",
     				        "($(res_sqrt_list_beta2[1,3,4]))", "($(res_sqrt_list_beta2[1,4,4]))", "($(res_sqrt_list_beta2[1,5,4]))"),
				   vcat("","T","Bias",res_bias_list_beta1[2,:,4],
           "", res_bias_list_beta2[2,:,4]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[2,1,4]))", "($(res_sqrt_list_beta1[2,2,4]))",
				        "($(res_sqrt_list_beta1[2,3,4]))", "($(res_sqrt_list_beta1[2,4,4]))", "($(res_sqrt_list_beta1[2,5,4]))",
                "",
                "($(res_sqrt_list_beta2[2,1,4]))", "($(res_sqrt_list_beta2[2,2,4]))",
     				        "($(res_sqrt_list_beta2[2,3,4]))", "($(res_sqrt_list_beta2[2,4,4]))", "($(res_sqrt_list_beta2[2,5,4]))"),
				   vcat("","U","Bias",res_bias_list_beta1[3,:,4],
           "", res_bias_list_beta2[3,:,4]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[3,1,4]))", "($(res_sqrt_list_beta1[3,2,4]))",
				        "($(res_sqrt_list_beta1[3,3,4]))", "($(res_sqrt_list_beta1[3,4,4]))", "($(res_sqrt_list_beta1[3,5,4]))",
                "",
                "($(res_sqrt_list_beta2[3,1,4]))", "($(res_sqrt_list_beta2[3,2,4]))",
     				        "($(res_sqrt_list_beta2[3,3,4]))", "($(res_sqrt_list_beta2[3,4,4]))", "($(res_sqrt_list_beta2[3,5,4]))"),
				   vcat("","Non","Bias",res_bias_list_beta1[4,:,4],
           "", res_bias_list_beta2[4,:,4]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[4,1,4]))", "($(res_sqrt_list_beta1[4,2,4]))",
				        "($(res_sqrt_list_beta1[4,3,4]))", "($(res_sqrt_list_beta1[4,4,4]))", "($(res_sqrt_list_beta1[4,5,4]))",
                "",
                "($(res_sqrt_list_beta2[4,1,4]))", "($(res_sqrt_list_beta2[4,2,4]))",
     				        "($(res_sqrt_list_beta2[4,3,4]))", "($(res_sqrt_list_beta2[4,4,4]))", "($(res_sqrt_list_beta2[4,5,4]))"),
				   ["","", "", "","", "", "", "",
           "", "","", "", "", ""],
				   vcat(benchmark_β,"unmatched","Mean Num",mean_unmatched_num_list[1,:,5],
           true_β_list[5], mean_unmatched_num_list[1,:,5]),
				   vcat("","U,T","Bias",res_bias_list_beta1[1,:,5],
           "", res_bias_list_beta2[1,:,5]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[1,1,5]))", "($(res_sqrt_list_beta1[1,2,5]))",
				        "($(res_sqrt_list_beta1[1,3,5]))", "($(res_sqrt_list_beta1[1,4,5]))", "($(res_sqrt_list_beta1[1,5,5]))",
                "",
                "($(res_sqrt_list_beta2[1,1,5]))", "($(res_sqrt_list_beta2[1,2,5]))",
     				        "($(res_sqrt_list_beta2[1,3,5]))", "($(res_sqrt_list_beta2[1,4,5]))", "($(res_sqrt_list_beta2[1,5,5]))"),
				   vcat("","T","Bias",res_bias_list_beta1[2,:,5],
           "", res_bias_list_beta2[2,:,5]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[2,1,5]))", "($(res_sqrt_list_beta1[2,2,5]))",
				        "($(res_sqrt_list_beta1[2,3,5]))", "($(res_sqrt_list_beta1[2,4,5]))", "($(res_sqrt_list_beta1[2,5,5]))",
                "",
                "($(res_sqrt_list_beta2[2,1,5]))", "($(res_sqrt_list_beta2[2,2,5]))",
     				        "($(res_sqrt_list_beta2[2,3,5]))", "($(res_sqrt_list_beta2[2,4,5]))", "($(res_sqrt_list_beta2[2,5,5]))"),
				   vcat("","U","Bias",res_bias_list_beta1[3,:,5],
           "", res_bias_list_beta2[3,:,5]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[3,1,5]))", "($(res_sqrt_list_beta1[3,2,5]))",
				        "($(res_sqrt_list_beta1[3,3,5]))", "($(res_sqrt_list_beta1[3,4,5]))", "($(res_sqrt_list_beta1[3,5,5]))",
                "",
                "($(res_sqrt_list_beta2[3,1,5]))", "($(res_sqrt_list_beta2[3,2,5]))",
     				        "($(res_sqrt_list_beta2[3,3,5]))", "($(res_sqrt_list_beta2[3,4,5]))", "($(res_sqrt_list_beta2[3,5,5]))"),
				   vcat("","Non","Bias",res_bias_list_beta1[4,:,5],
           "", res_bias_list_beta2[4,:,5]),
				   vcat("","","RMSE","($(res_sqrt_list_beta1[4,1,5]))", "($(res_sqrt_list_beta1[4,2,5]))",
				        "($(res_sqrt_list_beta1[4,3,5]))", "($(res_sqrt_list_beta1[4,4,5]))", "($(res_sqrt_list_beta1[4,5,5]))",
                "",
                "($(res_sqrt_list_beta2[4,1,5]))", "($(res_sqrt_list_beta2[4,2,5]))",
     				        "($(res_sqrt_list_beta2[4,3,5]))", "($(res_sqrt_list_beta2[4,4,5]))", "($(res_sqrt_list_beta2[4,5,5]))"),
				   #delta subsidy sensitivity
				   ["","", "", "","", "", "", "",
           "", "","", "", "", ""],
				   Rule(),           # a nice \hline to make it ugly
				   Rule(:bottom)])
end

function estimate_single_param_all(;
                                    sd_temp = 1.0,
                                    temp_means  = [3.0, 3.0],
                                    temp_covars = [1 0.25;
                                      		       0.25 1],
                                    num_agents_list = [10, 20, 30, 50, 100],
                                    true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
  # without dummy without IR
  global temp_dummy_included = false
  global temp_IR_condition_included = false
  global dummy_index = "without_dummy"
  global IR_index = "without_IR"
  include("compute_one_param.jl")
  # read results
  for k = 1:size(model_list)[1]
  	res_mean_list[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	res_bias_list[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
  	res_sqrt_list[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  end
  write_table_one_param("julia_tables/estimation_results_single_market_$(dummy_index)_$(IR_index).tex",
  	                 num_agents_list,
  					 true_β_list,
  					 res_mean_list,
  					 res_bias_list,
  					 res_sqrt_list,
  					 mean_matched_num_list,
  					 mean_unmatched_num_list)
  # without dummy with IR
  global temp_dummy_included = false
  global temp_IR_condition_included = true
  global dummy_index = "without_dummy"
  global IR_index = "with_IR"
  include("compute_one_param.jl")
  # read results
  for k = 1:size(model_list)[1]
  	res_mean_list[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	res_bias_list[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
  	res_sqrt_list[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  end
  write_table_one_param("julia_tables/estimation_results_single_market_$(dummy_index)_$(IR_index).tex",
  	                 num_agents_list,
  					 true_β_list,
  					 res_mean_list,
  					 res_bias_list,
  					 res_sqrt_list,
  					 mean_matched_num_list,
  					 mean_unmatched_num_list)
  # with dummy without IR
  global temp_dummy_included = true
  global temp_IR_condition_included = false
  global dummy_index = "with_dummy"
  global IR_index = "without_IR"
  include("compute_one_param.jl")
  # read results
  for k = 1:size(model_list)[1]
  	res_mean_list[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	res_bias_list[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
  	res_sqrt_list[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  end
  write_table_one_param("julia_tables/estimation_results_single_market_$(dummy_index)_$(IR_index).tex",
  	                 num_agents_list,
  					 true_β_list,
  					 res_mean_list,
  					 res_bias_list,
  					 res_sqrt_list,
  					 mean_matched_num_list,
  					 mean_unmatched_num_list)

  # with dummy with IR
  global temp_dummy_included = true
  global temp_IR_condition_included = true
  global dummy_index = "with_dummy"
  global IR_index = "with_IR"
  include("compute_one_param.jl")
  # read results
  for k = 1:size(model_list)[1]
  	res_mean_list[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	res_bias_list[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
  	res_sqrt_list[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
  end
  write_table_one_param("julia_tables/estimation_results_single_market_$(dummy_index)_$(IR_index).tex",
  	                 num_agents_list,
  					 true_β_list,
  					 res_mean_list,
  					 res_bias_list,
  					 res_sqrt_list,
  					 mean_matched_num_list,
  					 mean_unmatched_num_list)
end

function estimate_two_param_all(;
                        sd_temp = 1.0,
                        benchmark_β = 0.5,
                        temp_true_β = [0.5, -2.0],
                        temp_means  = [3.0, 3.0, 3.0],
                        temp_covars = [1 0.25 0.25;
                                       0.25 1 0.25;
                                       0.25 0.25 1],
                        num_agents_list = [10, 20, 30, 50, 100],
                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
    #------------------------------#
    # without a dummy
    #------------------------------#
    # without a dummy with IR
    global temp_dummy_included = false
    global temp_IR_condition_included = true
    global dummy_index = "without_dummy"
    global IR_index = "with_IR"
    include("compute_two_param.jl")
    # read results
    for k = 1:size(model_list)[1]
    	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    end
    write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index).tex",
    	                 num_agents_list,
    					 true_β_list,
    					 res_mean_list_beta1,
    					 res_mean_list_beta2,
    					 res_bias_list_beta1,
    					 res_bias_list_beta2,
    					 res_sqrt_list_beta1,
    					 res_sqrt_list_beta2,
    					 mean_matched_num_list,
    					 mean_unmatched_num_list)

    # without IR
    global temp_dummy_included = false
    global temp_IR_condition_included = false
    global dummy_index = "without_dummy"
    global IR_index = "without_IR"
    include("compute_two_param.jl")
    # read results
    for k = 1:size(model_list)[1]
    	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    end
    write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index).tex",
    	                 num_agents_list,
    					 true_β_list,
    					 res_mean_list_beta1,
    					 res_mean_list_beta2,
    					 res_bias_list_beta1,
    					 res_bias_list_beta2,
    					 res_sqrt_list_beta1,
    					 res_sqrt_list_beta2,
    					 mean_matched_num_list,
    					 mean_unmatched_num_list)

    #------------------------------#
    # with a dummy
    #------------------------------#
    # without IR
    global temp_dummy_included = true
    global temp_IR_condition_included = false
    global dummy_index = "with_dummy"
    global IR_index = "without_IR"
    include("compute_two_param.jl")
    # read results
    for k = 1:size(model_list)[1]
    	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    end
    write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index).tex",
    	                 num_agents_list,
    					 true_β_list,
    					 res_mean_list_beta1,
    					 res_mean_list_beta2,
    					 res_bias_list_beta1,
    					 res_bias_list_beta2,
    					 res_sqrt_list_beta1,
    					 res_sqrt_list_beta2,
    					 mean_matched_num_list,
    					 mean_unmatched_num_list)

    # with IR
    global temp_dummy_included = true
    global temp_IR_condition_included = true
    global dummy_index = "with_dummy"
    global IR_index = "with_IR"
    include("compute_two_param.jl")
    # read results
    for k = 1:size(model_list)[1]
    	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index).txt",',',Float64), digits =2)
    end
    write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index).tex",
    	                 num_agents_list,
    					 true_β_list,
    					 res_mean_list_beta1,
    					 res_mean_list_beta2,
    					 res_bias_list_beta1,
    					 res_bias_list_beta2,
    					 res_sqrt_list_beta1,
    					 res_sqrt_list_beta2,
    					 mean_matched_num_list,
    					 mean_unmatched_num_list)
end

function estimate_two_param_all_different_penalty(;
                        sd_temp = 1.0,
                        benchmark_β = 0.5,
                        temp_true_β = [0.5, -2.0],
                        temp_means  = [3.0, 3.0, 3.0],
                        temp_covars = [1 0.25 0.25;
                                       0.25 1 0.25;
                                       0.25 0.25 1],
                        num_agents_list = [10, 20, 30, 50, 100],
                        true_β_list = [1.0, 0.0, -1.0, -2.0, -3.0])
    #global importance_weight_lambda
    #------------------------------#
    # without a dummy
    #------------------------------#
    # without a dummy with IR
    # global temp_dummy_included = false
    # global temp_IR_condition_included = true
    # global dummy_index = "without_dummy"
    # global IR_index = "with_IR"
    # include("compute_two_param.jl")
    # # read results
    # for k = 1:size(model_list)[1]
    # 	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    # 	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    # 	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # end
    # write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).tex",
    # 	                 num_agents_list,
    # 					 true_β_list,
    # 					 res_mean_list_beta1,
    # 					 res_mean_list_beta2,
    # 					 res_bias_list_beta1,
    # 					 res_bias_list_beta2,
    # 					 res_sqrt_list_beta1,
    # 					 res_sqrt_list_beta2,
    # 					 mean_matched_num_list,
    # 					 mean_unmatched_num_list)
    #
    # # without IR
    # global temp_dummy_included = false
    # global temp_IR_condition_included = false
    # global dummy_index = "without_dummy"
    # global IR_index = "without_IR"
    # include("compute_two_param.jl")
    # # read results
    # for k = 1:size(model_list)[1]
    # 	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    # 	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    # 	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # end
    # write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).tex",
    # 	                 num_agents_list,
    # 					 true_β_list,
    # 					 res_mean_list_beta1,
    # 					 res_mean_list_beta2,
    # 					 res_bias_list_beta1,
    # 					 res_bias_list_beta2,
    # 					 res_sqrt_list_beta1,
    # 					 res_sqrt_list_beta2,
    # 					 mean_matched_num_list,
    # 					 mean_unmatched_num_list)

    #------------------------------#
    # with a dummy
    #------------------------------#
    # without IR
    # global temp_dummy_included = true
    # global temp_IR_condition_included = false
    # global dummy_index = "with_dummy"
    # global IR_index = "without_IR"
    # include("compute_two_param.jl")
    # # read results
    # for k = 1:size(model_list)[1]
    # 	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    # 	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    # 	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # 	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    # end
    # write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).tex",
    # 	                 num_agents_list,
    # 					 true_β_list,
    # 					 res_mean_list_beta1,
    # 					 res_mean_list_beta2,
    # 					 res_bias_list_beta1,
    # 					 res_bias_list_beta2,
    # 					 res_sqrt_list_beta1,
    # 					 res_sqrt_list_beta2,
    # 					 mean_matched_num_list,
    # 					 mean_unmatched_num_list)

    # with IR
    # global temp_dummy_included = true
    # global temp_IR_condition_included = true
    # global dummy_index = "with_dummy"
    # global IR_index = "with_IR"
    temp_dummy_included = true
    temp_IR_condition_included = true
    dummy_index = "with_dummy"
    IR_index = "with_IR"
    include("compute_two_param.jl")
    # read results
    for k = 1:size(model_list)[1]
    	res_mean_list_beta1[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    	res_bias_list_beta1[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta1[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta1_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    	res_mean_list_beta2[k,:,:] = round.(readdlm("julia_results/res_mean_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    	res_bias_list_beta2[k,:,:] = round.(readdlm("julia_results/res_bias_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64) , digits =2)
    	res_sqrt_list_beta2[k,:,:] = round.(readdlm("julia_results/res_sqrt_list_model_$(k)_two_param_beta2_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    	mean_matched_num_list[k,:,:] = round.(readdlm("julia_results/mean_matched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    	mean_unmatched_num_list[k,:,:] = round.(readdlm("julia_results/mean_unmatched_num_list_model_$(k)_two_param_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).txt",',',Float64), digits =2)
    end
    write_table_two_param("julia_tables/estimation_results_single_market_two_param_beta_$(dummy_index)_$(IR_index)_penalty_$(importance_weight_lambda).tex",
    	                 num_agents_list,
    					 true_β_list,
    					 res_mean_list_beta1,
    					 res_mean_list_beta2,
    					 res_bias_list_beta1,
    					 res_bias_list_beta2,
    					 res_sqrt_list_beta1,
    					 res_sqrt_list_beta2,
    					 mean_matched_num_list,
    					 mean_unmatched_num_list)
end


function plots_all(;dimension = 1)
   if dimension == 1
     # without dummy without IR
     global temp_dummy_included = false
     global temp_IR_condition_included = false
     global dummy_index = "without_dummy"
     global IR_index = "without_IR"
     include("plot_one_param.jl")
     # without dummy with IR
     global temp_dummy_included = false
     global temp_IR_condition_included = false
     global dummy_index = "without_dummy"
     global IR_index = "with_IR"
     include("plot_one_param.jl")
     # with dummy without IR
     global temp_dummy_included = true
     global temp_IR_condition_included = false
     global dummy_index = "with_dummy"
     global IR_index = "without_IR"
     include("plot_one_param.jl")
     # with dummy with IR
     global temp_dummy_included = true
     global temp_IR_condition_included = false
     global dummy_index = "with_dummy"
     global IR_index = "with_IR"
     include("plot_one_param.jl")
   elseif dimension == 2
     # without a dummy with IR
     global temp_dummy_included = false
     global temp_IR_condition_included = true
     global dummy_index = "without_dummy"
     global IR_index = "with_IR"
     include("plot_two_param.jl")
     # without a dummy without IR
     global temp_dummy_included = false
     global temp_IR_condition_included = false
     global dummy_index = "without_dummy"
     global IR_index = "without_IR"
     include("plot_two_param.jl")
     # with a dummy with IR
     global temp_dummy_included = true
     global temp_IR_condition_included = true
     global dummy_index = "with_dummy"
     global IR_index = "with_IR"
     include("plot_two_param.jl")
     # with a dummy without IR
     global temp_dummy_included = true
     global temp_IR_condition_included = false
     global dummy_index = "with_dummy"
     global IR_index = "without_IR"
     include("plot_two_param.jl")
   end
end

# function sumfun(vec, temp_true_β)
#     rw = size(vec)[1]
#     co = size(vec)[2]
#     #meanmat = matrix(c(1, 1.5), ncol=co, nrow=rw, byrow=TRUE)
#     meanmat = [1 temp_true_β] # true parameters
#     mean = mean(vec-meanmat)
#     sqrt = sqrt(mean((vec-meanmat)^2))
#     return mean, sqrt
# end
# function myfun(beta::Vector{Float64}, dat::DataFrame, i::Int64)
#     beta = beta[1] # for optim
#     res = dat.Ab[i]*dat.At .+ beta.*dat.Bb[i]*dat.Bt
#     return res
# end
#
# function mylogit(beta::Vector{Float64}, dat::DataFrame, i::Int64)
#     f = exp.(myfun(beta, dat, i) .- dat.tarprice)
#     den = sum(f)
#     res = log(f[1]/den) # log-likelihood
#     return res
# end
#
# function mylogiter(beta::Vector{Float64}, dat::DataFrame)
#     logix = Array{Float64,1}(undef, size(dat)[1])
#     for i in 1:(size(dat)[1])
#         logix[i] = mylogit(beta, dat, i) # log-likelihood
#     end
#     llk = sum(logix) # typo for original code
#     return -llk # minimizing llk by Optim
# end
