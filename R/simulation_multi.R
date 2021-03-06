#' Simulate read count (multi-SNP model)
#'
#' Given gene configuration, genotype (mutliple SNP), range of variation due to genetic effect,
#' and other parameters, simulate read count.
#' Essentially, the function first samples the true effect according to
#' the number of causal variants and variation due to genetic effect.
#' And then, it follows the sampling scheme mostly resembles the single-SNP scenario.
#'
#' @section About sampling Y^h:
#' To specify read count of each haplotype (Y^h) given library size and relative abundance.
#' It is set in y_dist.
#' Currently it supports three distribution types: 'poisson', 'lognormal', and 'negbinom'.
#' Specifically, y_dist is a list with distribution name in 'type'.
#' For y_dist$type = 'poisson', no other parameter is required.
#' For y_dist$type = 'lognormal', 'sigma' needs to specify, and
#' Y^h = round(library_size * relative_abundance * rlnorm(1, 0, y_dist$sigma))
#' For y_dist$type = 'negbinom', 'prob' and 'size_factor' need to specify, and
#' Y^h = rnbinom(1, size = y_dist$size_factor * library_size * relative_abundance, prob = y_dist$prob)
#'
#' @param gene gene instance generated from \code{\link{create_gene}}
#' @param genotype genotype generated from \code{\link{create_genotype}} (the 'genotype' object in the list)
#' @param betas log(aFC) vector
#' @param L_read length of read
#' @param y_dist distribution of Y^h | library size, relative abundance.
#'   It specifies the shape of the distribution whereas
#'   the mean is given by library size and relative abundance.
#'
#' @return read counts, where observed count include y1, y2 (AS count of each haplotypes) and
#' ystar (total count - y1 - y2) along with library size Ti_lib.
#' Also, it includes unobserved count as 'hidden' (y1star and y2star)
#' and the true effect size vector.
#'
#' @examples
#' gene = create_gene()
#' genotype = list(
#'   h1 = matrix(
#'     sample(c(0, 1), 1000, replace = TRUE),
#'     ncol = 100,
#'     nrow = 10
#'   ),
#'   h2 = matrix(
#'     sample(c(0, 1), 1000, replace = TRUE),
#'     ncol = 100,
#'     nrow = 10
#'   )
#' )
#' betas = create_betas(
#'   maf = colMeans(genotype$h1 + genotype$h2) / 2,
#'   genetic_var = c(0.015, 0.075),
#'   ncausal = c(1, 3)
#' )
#' simulate_read_count_multi(
#'   gene = gene,
#'   genotype = genotype,
#'   betas = betas,
#'   L_read = 75,
#'   y_dist = list(
#'     type = 'negbinom',
#'     prob = 2/3,
#'     size_factor = 2
#'   )
#' )
#'
#' @export
#' @importFrom stats rbeta rlnorm rnbinom rpois
simulate_read_count_multi = function(gene, genotype, betas, L_read, y_dist) {
  ## gene: generated by generate_gene_instance
  ## betas: log(fold change) vector
  ## L_read: length of read
  ## genotype: N x 2 genotype data.frame (N: sample size)

  N = nrow(genotype$h1)
  observed = data.frame()
  hidden = data.frame()
  nindiv = nrow(genotype$h1)
  nvar = ncol(genotype$h1)
  G1 = as.matrix(genotype$h1)
  G2 = as.matrix(genotype$h2)
  G1[is.na(G1)] = 0.5
  G2[is.na(G2)] = 0.5
  beta_all = betas

  if(gene$theta$type == 'beta') {
    theta_i = rbeta(nindiv, gene$theta$alpha, gene$theta$beta)
  } else if(gene$theta$type == 'lognormal') {
    theta_i = rlnorm(nindiv, gene$theta$k, sqrt(gene$theta$sigma))
  }
  if(gene$library_dist$type == 'poisson') {
    T_lib_all = rpois(nindiv, gene$library_dist$lambda)
  } else if(gene$library_dist$type == 'negbinom'){
    T_lib_all = rnbinom(nindiv, prob = gene$library_dist$prob, size = gene$library_dist$size)
  }
  # T_lib_all = rpois(nindiv, gene$lambda_lib)
  theta_prime1_all = exp(G1 %*% beta_all) * theta_i
  theta_prime2_all = exp(G2 %*% beta_all) * theta_i

  alpha_obs = c()
  Li_collect = c()
  for(i in 1 : nindiv) {
    theta_prime1 = theta_prime1_all[i]
    theta_prime2 = theta_prime2_all[i]
    T_lib = T_lib_all[i]

    if(y_dist$type == 'poisson') {
      Ti1 = rpois(1, T_lib * theta_prime1)
      Ti2 = rpois(1, T_lib * theta_prime2)
    } else if(y_dist$type == 'lognormal') {
      Ti1 = round(T_lib * theta_prime1 * rlnorm(1, 0, y_dist$sigma / sqrt(T_lib)))
      Ti2 = round(T_lib * theta_prime2 * rlnorm(1, 0, y_dist$sigma / sqrt(T_lib)))
    } else if(y_dist$type == 'negbinom') {
      Ti1 = rnbinom(1, size = y_dist$size_factor * T_lib * theta_prime1, prob = eval(parse(text = y_dist$prob)))
      Ti2 = rnbinom(1, size = y_dist$size_factor * T_lib * theta_prime2, prob = eval(parse(text = y_dist$prob)))
    }

    P1 = sample(1 : gene$L_gene, Ti1, replace = T, prob = gene$vec_pos)
    P2 = sample(1 : gene$L_gene, Ti2, replace = T, prob = gene$vec_pos)
    Zij = rbinom(length(gene$fj), 1, 2 * gene$fj * (1 - gene$fj))
    temp = read2data(P1, P2, gene$S, Zij, L_read)
    observed_i = temp$observed
    # observed_i$Gi1 = t(G1)[i, ]
    # observed_i$Gi2 = t(G2)[i, ]
    observed_i$Ti_lib = T_lib

    observed_i$Y1 = Ti1
    observed_i$Y2 = Ti2
    observed = rbind(observed, observed_i)
    hidden = rbind(hidden, temp$hidden)
  }


  if(gene$theta$type == 'beta') {
    sigma0 = NA
  } else if(gene$theta$type == 'lognormal') {
    sigma0 = sqrt(gene$theta$sigma)
  }
  if(y_dist$type == 'poisson') {
    sigma = 1
  } else if(y_dist$type == 'lognormal') {
    sigma = y_dist$sigma
  }

  # observed = data.frame(y1 = y1, y2 = y2, ystar = ystar, L = Li_collect, T_lib)
  hidden = list(betas = betas, sigma = sigma, sigma0 = sigma0, hidden = hidden)

  return(list(observed = observed, hidden = hidden))
}

#' Generate a beta vector
#'
#' This functions simulate a beta vector with the variation of genetic effect
#' being controlled in a pre-specified range.
#' It takes maf vector of length P, range of desired variation due to genetic effect, and
#' the range of the number of causal variants.
#' The variation is calculated by \deqn{2 \sum_p \beta_p^2 f_p (1 - f_p)} where \eqn{f_p} is the allele frequency of variant p and \eqn{\beta_p} is the log aFC of variant p.
#'
#' @param maf allele frequencies of the variants of interest
#' @param genetic_var the range of variation due to genetic effect
#' @param ncausal the range of the number of causal variants
#'
#' @return a vector of simulated beta vector
#'
#' @examples
#' create_betas(
#'   maf = runif(100),
#'   genetic_var = c(0.015, 0.075),
#'   ncausal = c(1, 3)
#' )
#'
#' @export
create_betas = function(maf, genetic_var, ncausal) {
  gen_var = runif(1, genetic_var[1], genetic_var[2])
  ncausal = sample(ncausal[1] : ncausal[2], size = 1, replace = F)
  non_zero_maf = maf > 0
  maf_index = 1 : length(maf)
  maf_index_nonzero = maf_index[non_zero_maf]
  causals = sample(maf_index_nonzero, size = ncausal, replace = F)
  betas = get_betas_controlling_var(gen_var, maf[causals])
  out = rep(0, length(maf))
  out[causals] = betas
  out
}

get_betas_controlling_var = function(gen_var, maf) {
  ncausal = length(maf)
  fraction = runif(ncausal); fraction = fraction / sum(fraction)
  beta = rep(NA, ncausal)
  var_by_beta = gen_var * fraction
  var_log_beta = var_by_beta / (2 * maf * (1 - maf))
  log_beta = sqrt(var_log_beta)
  sign = sample(c(1, -1), size = ncausal, replace = T)
  sign * log_beta
}
