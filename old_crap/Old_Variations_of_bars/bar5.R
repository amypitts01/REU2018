#complete BAR - Variation B (interval/interval/Move+Jiggle)

#-------Key:
# k			= x-axis values of starting breakpoints
# time		= integer x-values of the entire data set
# data		= y-values of entire data set
# interations	= number of runs for sampling with Metropolis-Hastings 
# make_murder_p	= the combine proportion (decimal) for make and murder steps
#note: move proportion is 1 - make_murder_p
# percent		= how much a point can jiggle
# lambda		= for Poisson distribution for breakpoint prior

bar5 = function(k, time, data, iterations, make_murder_p, percent, lambda){
  
  library(MASS)
  
  full_data = cbind(as.numeric(time), as.numeric(data)) #combing the time and data inputs from user
  
  n = length(full_data[,1]) #finding max value
  
  k_ends = c(min(full_data[,1]), na.omit(k), n) #adding in end points to k values 
  
  fitMetrics<-function(k_ends, full_data){
    
    #create sum objects
    sum_loglik = 0
    
    #get and sum log likelihood for regressions of all intervals
    if(length(k_ends) < 3 ){
      model = lm(full_data[,2]~full_data[,1])
      sum_loglik = logLik(model)[1]
    }else{
      for(i in 2:length(k_ends)) {
        if(i == 2){
          min = k_ends[i-1]
          x_values = full_data[c(min:k_ends[i]),1] #getting the x values in the interval
          y_values = full_data[c(min:k_ends[i]),2] #getting the y values in the interval
          data = data.frame(x_values, y_values) #re-making this into a dataframe 
          model = lm(y_values~x_values) #running a lm on the selected interval 
          sum_loglik = sum_loglik + logLik(model)[1] #the logLik looks the log likelyhood (relates to both SSR and MLE)
        }else if(i > 2){
          min = k_ends[i-1]
          x_values = full_data[c((min+1):k_ends[i]),1] #getting the x values in the interval
          y_values = full_data[c((min+1):k_ends[i]),2] #getting the y values in the interval
          data = data.frame(x_values, y_values) #re-making this into a dataframe 
          model = lm(y_values~x_values) #running a lm on the selected interval 
          sum_loglik = sum_loglik + logLik(model)[1] #the logLik looks the log likelyhood (relates to both SSR and MLE)
        }
      }
    }
    return(sum_loglik)
  }
  
  #adds a point based on intervals
  barMake1<-function(k_ends, count){
    
    d = diff(k_ends) #finding the distance between all those breakpoints
    location = rmultinom(1, size = 1, prob = (d^4)/sum(d^4))
    if( d[location] > 5) {
      min = k_ends[which.max(location)] #lower bound 
      max = k_ends[(which.max(location) + 1)] #upper bound
      new_bp = sample((min+3):(max-3), 1) #selecting a random number in the correct interval
      k_ends_final = sort(c(k_ends, new_bp))
      d_check = diff(k_ends_final)
      if(min(d_check) > 2) {
        return(k_ends_final)
      } else if (count < 10) {
        count = count + 1
        barMake1(k_ends, count)
      } else {
        return("make failure")
      }
    } else {
      if(count < 10) {
        count = count + 1
        barMake1(k_ends, count)
      } else {
        return("make failure")
      }
    }
    
  }
  
  #random make function, this makes a random point 
  barMake0<-function(k_ends, count){
    
    count <<- count + 1 #this check to make sure we do not get stuck in an infinite loop 
    if(count < 10 ) {
      rand_spot = sample(k_ends[1]:k_ends[length(k_ends)], 1) #selects a random spot
      k_ends_final = sort(c(k_ends, rand_spot)) #adds the random spot and sorts it 
      d = diff(k_ends_final) #finds the difference between all the spots 
      if(min(d) < 3) { #this make sure an additional point is not to close to a point already in existance 
        barMake0(k_ends, count)
      } else {
        return(k_ends_final) #the old breakpoints + the new breakpoints 
      }
    }else {
      return(k_ends)
    }
  }
  
  #function murders based off of intervals
  barMurder1 <- function(k_ends){
    
    all_intv = diff(k_ends) #finds all of the intervals
    intv_1 = all_intv[-1] #takes the first number off
    intv_2 = all_intv[-length(all_intv)] #takes the last number off
    sum_intv = intv_1 + intv_2 #finds the sums of the adjacent intervals
    location = rmultinom(1, size = 1, prob = (1/sum_intv)/sum(1/sum_intv)) #choose a breakpoint based on probabilities
    k_ends_final = k_ends[-(which.max(location)+1)] #find and delete correct break 
    return(k_ends_final)
    
  }
  #this function kills one breakpoint randomly 
  barMurder0<-function(k_ends){
    
    k = k_ends[c(-1,-length(k_ends))] #removes the end points 
    random_num = sample(1:length(k), 1) #selects a random breakpoint
    k_ends_final = k_ends[-(random_num+1)] #removes that selected breakpoint
    return(k_ends_final)
    
  }
  
  #kills a point randomly and then adds a point randomly 
  barMove0<-function(k_ends){
    
    k_ends_less = barMurder0(k_ends) #kills a point
    count <<- 0 #reset count for failed makes 
    k_ends_final = barMake0(k_ends_less, count) #remakes a point
    return(k_ends_final)
    
  }
  
  #jiggles an existing breakpoint
  barJiggle<-function(percent, k_ends, count){
    
    count <<- count + 1
    data_length = max(k_ends)
    
    #determines how much the knot shoud jiggle
    jiggle_range = ceiling(percent*data_length)
    jiggle_neighborhood = c(1:jiggle_range)
    jiggle_spot = sample(jiggle_neighborhood,1)
    
    #"boolean" variable to make sure that we can jiggle 
    can_jiggle = "good" #default is good and we can jiggle
    
    #determines randomly if knot is jiggling to left or right
    direction = "right" #default direction is right
    u = runif(1) #random number from 0-1 from uniform distribution
    if(u < 0.5){
      direction = "left"
      jiggle_spot = (-1)*jiggle_spot
    }
    
    #determines randomly which knot is jiggling (code related to murders)
    k = k_ends[c(-1, -length(k_ends))] #removes end points
    rando_location = sample(1:length(k),1) #chooses random knot 
    rando_knot = k[rando_location]
    
    #check if we can jiggle towards an endpoint
    possible_knot = rando_knot+jiggle_spot
    if(direction == "right"){
      right_end = k_ends[length(k_ends)]
      possible_diff = (abs(possible_knot - right_end) < 3)
      if(possible_diff == TRUE){
        can_jiggle = "bad"
      }
    }else{
      left_end = k_ends[1]
      possible_diff = (abs(possible_knot - left_end) < 3)
      if(possible_diff == TRUE){
        can_jiggle = "bad"
      }
    }
    
    #check if new knot location already has a knot there 
    for(i in 1:length(k)){
      possible_diff = (abs(possible_knot - k[i]) < 3)
      if(rando_knot != k[i] & possible_diff == TRUE){
        can_jiggle = "bad"
      }
    }
    
    #check if we can jiggle, then jiggle!!!
    if(can_jiggle == "bad" & count < 10){
      barJiggle(percent, k_ends, count)
    }else if(can_jiggle == "bad"){
      return("jiggle failure")
    }else{
      middle_set = k_ends[-(rando_location+1)]
      final_set = sort(c(middle_set,possible_knot))
      return(final_set)
    }
  }
  
  
  #initializing matrices 
  ratio_data = data.frame()
  all_k_new = matrix(NA, nrow=1, ncol=(n/3))
  all_k_best = matrix(NA, nrow=1, ncol=(n/3))
  
  bar_v = 0
  bar_beta = 0
  fit = 0
  all_MSE = data.frame()
  all_BIC = data.frame()
  accept_count = 0
  
  #setting up counters (these will tell us how many type it does a certain step and how many time it accept each step)
  type = "0"
  a.count = 0
  s.count = 0 
  m.count = 0
  j.count = 0
  add.accept.count = 0
  sub.accept.count = 0
  move.accept.count = 0
  jiggle.accept.count = 0
  
  #setting up priors for drawing from betas
  
  beta_lm = function(par) {#function to minimize to get MLE of betas
    
    beta0 = par[1]  #current intercept
    beta1 = par[2]  #current slope
    sigma = sd(full_data[,2]) #standard deviation
    
    #calculated likelihoods
    lik = dnorm(full_data[,2], mean = full_data[,1] * beta1 + beta0, sd = sigma)
    
    #convert likelihood to summary deviance score (minimizing deviance = maximizing likelihood)
    log_lik = log(lik) #log likelihood of each data point
    deviance = -2 * sum(log_lik) #calculate deviance
    
    return(deviance)
    
  }
  
  beta_fits = optim(par = c(0, 0), fn = beta_lm, hessian = T) #get parameter estimates for betas
  fisher = 0.5*beta_fits$hessian #if minimizing deviance, observed Fisher information is half of hessian
  smiley = n * solve(fisher) #smiley face is total number of observations times the inverse of Fisher information
  
  b_0 = matrix(beta_fits$par,2,1) #matrix of beta means for posterior draw
  B_0 = smiley #variance-covariance matrix for posterior draw
  
  #getting constants for qs (b_k and d_k in papers)
  starting_bkpts = 1 #due to interval subtraction, only 1 breakpoint is likely to be murdered
  starting_d = diff(k_ends) #interval sizes between starting breakpoints
  starting_nfree = max(starting_d) - 4 #number of free spaces in largest starting interval
  starting_ttl = starting_bkpts + starting_nfree #total to get percentages
  make_k = make_murder_p * starting_nfree/starting_ttl #proportion for make
  murder_k = make_murder_p * starting_bkpts/starting_ttl #proportion for murder

  #Metroplis Hastings 
  for(i in 1:iterations){
    
    old_loglik = fitMetrics(k_ends, full_data) #calls fit matrix to have a function to start with
    
    u_step = runif(1) #random number from 0 to 1 taken from a uniform distribution for selecting step
    
    if(length(k_ends) < 3 | u_step <= make_k){
      type = "add"
      a.count = a.count + 1
      count <<- 0 #reset count for failed makes 
      k_ends_new = barMake1(k_ends, count) #make

      #setting up qs for ratio
      if(k_ends_new[1] != "make failure"){
        all_intv = diff(k_ends_new) #finds all of the intervals
        intv_1 = all_intv[-1] #takes the first number off
        intv_2 = all_intv[-length(all_intv)] #takes the last number off
        sum_intv = intv_1 + intv_2 #finds the sums of the adjacent intervals
        i = which(k_ends_new == abs(sum(k_ends_new) - sum(k_ends))) #finds the location of the point that was deleted
        q1 = murder_k*(1/sum_intv[i-1] ) / (sum(sum_intv))
        
        i_q = which(k_ends_new == sum(k_ends_new)- sum(k_ends))
        d = diff(k_ends)
        q2 = make_k * ( ( ( (d[i_q-1])^4  / sum(d)^4) ) * ( 1 / ( d[i_q-1] - 4 ) ) )
      }else{
        k_ends_new = k_ends
        q1 = 1
        q2 = 1		
      }
      
    } else if(u_step > make_k & u_step <= (make_k + murder_k)){
      type = "sub"
      s.count = s.count + 1
      k_ends_new = barMurder1(k_ends) #murder
      
      #setting up qs for ratio
      all_intv = diff(k_ends) #finds all of the intervals
      intv_1 = all_intv[-1] #takes the first number off
      intv_2 = all_intv[-length(all_intv)] #takes the last number off
      sum_intv = intv_1 + intv_2 #finds the sums of the adjacent intervals
      i = which(k_ends == abs(sum(k_ends_new) - sum(k_ends))) #finds the location of the point that was deleted
      q2 = murder_k*(1/sum_intv[i-1] ) / (sum(sum_intv))

      i_q = which(k_ends == sum(k_ends) - sum(k_ends_new) )
      d = diff(k_ends_new)
      q1 = make_k * ( ( ( (d[i_q-1])^4  / sum(d)^4) ) * ( 1 / ( d[i_q-1] - 4 ) ) )

      
    } else{
      move_u = runif(1)
      if(move_u > 0.75){
        type = "move"
        m.count = m.count + 1
        k_ends_new = barMove0(k_ends) #move
        
        #fake qs because they cancel
        q1 = 1
        q2 = 1
      }else{
        type = "jiggle"
        j.count = j.count + 1
        count <<- 0 #resetting failed jiggle attempts
        k_ends_new = barJiggle(percent, k_ends, count) #move
        if(k_ends_new[[1]] == "jiggle failure"){
          k_ends_new = k_ends
        }
        
        #fake qs because they cancel
        q1 = 1
        q2 = 1
      }
      
    }
    
    new_loglik = fitMetrics(k_ends_new, full_data)
    
    delta_bic = (-2*new_loglik + log(n)*(length(k_ends_new)-1)*(3+1)) - (-2*old_loglik + log(n)*(length(k_ends)-1)*(3+1))
    ratio = (-1*delta_bic/2) + (log(q1*dpois(length(k_ends_new)-2,lambda)) - log(q2*dpois(length(k_ends)-2,lambda)))
    u_ratio = log(runif(1)) #random number from 0 to 1 taken from a uniform distribution and then log transformed
    
    ratio_data_print = c(ratio, u_ratio, delta_bic, (-delta_bic/2), log(q1), log(q2))
    
    if(abs(delta_bic) == Inf){ #safe guard against random models creating infinite ratios
      k_ends = k_ends #old
      bic = (-2*old_loglik + log(n)*(length(k_ends)-1)*(3+1))
    } else if(ratio > u_ratio) {
      k_ends = k_ends_new #new
      bic = (-2*new_loglik + log(n)*(length(k_ends_new)-1)*(3+1))
      accept_count = accept_count + 1
      #looking at what type of step is done and accepted
      if(type == "add") {
        add.accept.count = add.accept.count + 1
      } else if(type == "sub") {
        sub.accept.count = sub.accept.count + 1
      } else if(type == "move") {
        move.accept.count = move.accept.count + 1
      } else if(type == "jiggle") {
        jiggle.accept.count = jiggle.accept.count + 1
      }
    } else {
      k_ends = k_ends #old
      bic = (-2*old_loglik + log(n)*(length(k_ends)-1)*(3+1))
    }
    
    #condensing the data
    k_ends_new_print = c(k_ends_new, rep(NA, (n/3)-length(k_ends_new)))
    k_ends_best_print = c(k_ends, rep(NA, (n/3)-length(k_ends)))
    
    ratio_data = rbind(ratio_data, ratio_data_print)
    all_k_new = rbind(all_k_new, k_ends_new_print)
    all_k_best = rbind(all_k_best, k_ends_best_print)
    
    all_BIC = rbind(all_BIC, bic)
    
    #setting up the posterior
    
    ##loop through the k_ends to find the intervals 
    fit = NULL
    for(m in 2:length(k_ends)) {
      len = length(k_ends)
      if(m > 2){
        min = k_ends[m-1]+1
      }else{
        min = k_ends[m-1]
      }
      x_values = full_data[c(min:k_ends[m]),1] #getting the x values in the interval
      x_j = matrix(c( rep(1, each=length(x_values)), x_values), nrow= length(x_values), ncol= 2)
      y_j = full_data[c(min:k_ends[m]),2] #getting the y values in the interval
      sigma = sd(y_j)
      
      #bar_v
      v = solve( (1/sigma) * (t(x_j) %*% x_j )+ solve(B_0) )
      #bar_beta 
      beta = v %*% ( (1/sigma) * (t(x_j) %*% y_j) + solve(B_0) %*% b_0 )
      
      predicted_x = x_j %*% beta
      fit = c(fit, predicted_x)
      
      #drawing a random variable from a multivariate normal pdf 
      post_beta = mvrnorm(1, beta, v)
      
      bar_v = c(bar_v, v)
      bar_beta = c(bar_beta, beta)
      
      if(m == len ) {
        MSE = mean((full_data[,2]-fit)^2)
        all_MSE = rbind(all_MSE, MSE)
      }
    }
  }
  
  
  #cleaning up the matrices 
  all_k_new = all_k_new[-1,colSums(is.na(all_k_new))<nrow(all_k_new)]
  all_k_best = all_k_best[-1,colSums(is.na(all_k_best))<nrow(all_k_best)]
  clean_max = max(all_k_new[1,], na.rm=TRUE)
  all_k_new = ifelse(all_k_new == clean_max,NA,all_k_new)
  all_k_best = ifelse(all_k_best == clean_max,NA,all_k_best)
  all_k_new = data.frame(all_k_new[,c(-1,-ncol(all_k_new))], row.names=NULL)
  all_k_best = data.frame(all_k_best[,c(-1,-ncol(all_k_best))], row.names=NULL)
  
  colnames(ratio_data) = c("Ratio", "Random", "DeltaBIC", "LikeApprox", "LogQOldNew", "LogQNewOld")
  colnames(all_MSE) = "MSE"
  colnames(all_BIC) = "BIC"
  
  final.propose = c(a.count, s.count, m.count, j.count)
  final.accept = c(add.accept.count, sub.accept.count, move.accept.count, jiggle.accept.count)
  
  #getting distribution of k (number of breakpoints)
  num_bkpts = list()
  for(i in 1:iterations){
    current_k = length(all_k_best[i,][!is.na(all_k_best[i,])])
    num_bkpts = c(num_bkpts, current_k, recursive=T)
  }
  
  final_list = list(accept_count / iterations, final.propose, final.accept, all_MSE, all_BIC, all_k_best, num_bkpts)
  names(final_list) = c("AcceptRate", "ProposedSteps", "AcceptedSteps", "MSE", "BIC", "Breakpoints", "NumBkpts")
  
  return(final_list)
}

#calling the function
#current_result = bar5(bkpts_2$breakpoints, test_data_2[,1], test_data_2[,2], 2500, 0.5, 0.02, 1)
#hist(current_result$NumBkpts)
#current_result$ProposedSteps
#current_result$AcceptedSteps