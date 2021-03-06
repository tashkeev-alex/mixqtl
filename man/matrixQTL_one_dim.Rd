% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rlib_matrix_ls.R
\name{matrixQTL_one_dim}
\alias{matrixQTL_one_dim}
\title{Solve Y = Xb + e in matrix form}
\usage{
matrixQTL_one_dim(Y, X, n)
}
\arguments{
\item{Y}{response to regress against (dimension = N x K)}

\item{X}{P predictors to perform regression separately (dimension = N x P)}

\item{n}{sample size (dimension = P x K)}
}
\value{
a list of summary statistics
        beta_hat: estimated b, b_hat (dimension = K x P)
        beta_se: standard deviation of b_hat (dimension = K x P)
}
\description{
For each column i in X, solve Y_k = X_i b_i + e as least squares problem and output estimated effect size and standard deviation
}
\examples{
matrixQTL_one_dim(
  Y = matrix(rnorm(300), ncol = 3),
  X = matrix(sample(c(0, 0.5, 1), 200, replace = TRUE), ncol = 2),
  n = matrix(100, ncol = 2, nrow = 3)
)

}
