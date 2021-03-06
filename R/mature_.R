#' Calculate traits relating to the age of reproductive maturity from a matrix
#' population model
#'
#' Apply Markov chain approaches to decompose moments along the age-specific
#' trajectory of reproduction for individuals in a matrix population model.
#' Includes functions to calculated the probability of achieving reproductive
#' maturity (\code{mature_prob}), mean age at first reproduction
#' (\code{mature_age}), and distribution of individuals first achieving
#' reproductive maturity among stage class (\code{mature_distrib}).
#' 
#' @param matU The survival component of a matrix population model (i.e. a
#'   square projection matrix reflecting survival-related transitions; e.g.
#'   progression, stasis, and retrogression)
#' @param matR The reproductive component of a matrix population model (i.e. a
#'   square projection matrix reflecting transitions due to reproduction; either
#'   sexual, clonal, or both)
#' @param start The index of the first stage at which the author considers
#'   the beginning of life. Defaults to 1.
#' @param repro_stages Logical vector indicating which stages are reproductive.
#'   Must be of length \code{ncol(matU)}.
#'   
#' @return For \code{mature_distrib}, a vector giving the proportion of
#'   individuals that first reproduce within each stage class. For all others, a
#'   scalar trait value.
#' 
#' @author Roberto Salguero-Gomez <rob.salguero@@zoo.ox.ac.uk>
#' @author Hal Caswell <hcaswell@@whoi.edu>
#' @author Owen R. Jones <jones@@biology.sdu.dk>
#' @author Patrick Barks <patrick.barks@@gmail.com>
#' 
#' @references Caswell, H. (2001) Matrix Population Models: Construction,
#'   Analysis, and Interpretation. Sinauer Associates; 2nd edition. ISBN:
#'   978-0878930968
#'   
#' @examples
#' data(mpm1)
#' 
#' mature_prob(mpm1$matU, mpm1$matF, start = 2)
#' mature_age(mpm1$matU, mpm1$matF, start = 2)
#' 
#' ### distribution of first reproductive maturity among stage classes
#' repstage <- repro_stages(mpm1$matF)
#' mature_distrib(mpm1$matU, start = 2, repro_stages = repstage)
#' 
#' @name repro_maturity
NULL


#' @rdname repro_maturity
#' @export mature_prob
mature_prob <- function(matU, matR, start = 1L) {
  
  # validate arguments
  checkValidMat(matU, warn_surv_issue = TRUE)
  checkValidMat(matR)
  checkValidStartLife(start, matU)
  
  fec_stages <- apply(matR, 2, function(x) any(x > 0))
  Bprime <- calc_Bprime(matU, fec_stages)
  
  return(Bprime[2, start])
}


#' @rdname repro_maturity
#' @export mature_age
mature_age <- function(matU, matR, start = 1L) {

  # validate arguments
  checkValidMat(matU, warn_surv_issue = TRUE)
  checkValidMat(matR)
  checkValidStartLife(start, matU)
  
  m <- nrow(matU)
  fec_stages <- apply(matR, 2, function(x) any(x > 0))
  
  Uprime <- matU
  Uprime[,fec_stages] <- 0
  
  Bprime <- calc_Bprime(matU, fec_stages)
  
  if (Bprime[2, start] == 0) {
    # if Pr[maturity] == 0
    return(NA_real_)
  } else {
    # mean age at first reproduction ('L_a' in Caswell 2001, p 124)
    D <- diag(c(Bprime[2,]))
    Uprimecond <- D %*% Uprime %*% .matrix_inverse(D)
    expTimeReprod <- colSums(.matrix_inverse(diag(m) - Uprimecond))
    return(expTimeReprod[start])
  }
}


#' @rdname repro_maturity
#' @export mature_distrib
mature_distrib <- function(matU, start = 1L, repro_stages) {
  
  # validate arguments
  checkValidMat(matU, warn_surv_issue = TRUE)
  checkValidStartLife(start, matU)
  if (ncol(matU) != length(repro_stages)) {
    stop("length(repro_stages) must equal ncol(matU)", call. = FALSE)
  }
  
  primeU <- matU
  primeU[,repro_stages] <- 0
  
  N <- .matrix_inverse(diag(nrow(primeU)) - primeU)
  
  n1 <- rep(0, nrow(matU))
  n1[repro_stages] <- N[repro_stages,start] / sum(N[repro_stages,start])
  
  n1[is.nan(n1)] <- 0.0 # coerce NaN to 0
  names(n1) <- colnames(matU)
  return(n1)
}


#' @noRd
calc_Bprime <- function(matU, fec_stages) {
  
  m <- ncol(matU)
  
  # Probability of survival to first sexual reproductive event
  # Note: U matrices are called 'T' in Caswell (2001)
  Uprime <- matU
  Uprime[,fec_stages] <- 0
  
  Mprime <- matrix(0, nrow = 2, ncol = m)
  
  for (p in 1:m) {
    if (fec_stages[p]) {
      Mprime[2, p] <- 1
    } else {
      Mprime[1, p] <- 1 - colSums(matU)[p]
    }
  }
  
  Bprime <- Mprime %*% .matrix_inverse(diag(m) - Uprime)
  return(Bprime)
}
