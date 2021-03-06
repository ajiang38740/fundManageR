% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/indicies.R
\name{get_data_msci_realtime_index_values}
\alias{get_data_msci_realtime_index_values}
\title{MSCI indicies values}
\usage{
get_data_msci_realtime_index_values(return_wide = TRUE,
  return_message = TRUE)
}
\arguments{
\item{return_wide}{\code{TRUE} return data in wide form}

\item{return_message}{\code{TRUE} return a message after data import}
}
\value{
\code{data_frame}
}
\description{
This function returns the most recent
index values for the
41 primary MSCI indicies on a 15 minute time delay.
}
\examples{
get_data_msci_realtime_index_values()
}
\references{
\href{http://msci.com}{MSCI Inc}
}
\seealso{
Other MSCI: \code{\link{get_data_msci_indicies_constituents}},
  \code{\link{get_data_msci_indicies}}

Other index values: \code{\link{get_data_crsp_indicies_returns}},
  \code{\link{get_data_fred_symbols}},
  \code{\link{get_data_nareit_annual_subsector_returns}},
  \code{\link{get_data_nareit_monthly_returns}}

Other real-time data: \code{\link{get_data_dtcc_most_recent_trades}},
  \code{\link{get_data_us_public_companies}}
}
